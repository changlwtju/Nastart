import CryptoKit
import Foundation
import NIOCore
import NIOPosix
import NIOSSH

struct SSHHostIdentity: Equatable, Sendable {
    let openSSHKey: String
    let fingerprint: String
}

struct SSHCommandResult: Sendable {
    let exitStatus: Int
    let standardOutput: String
    let standardError: String
}

enum SSHAgentInstallerError: LocalizedError {
    case invalidConnection
    case hostKeyProbeFailed
    case hostKeyChanged
    case passwordAuthenticationUnavailable
    case authenticationFailed
    case bundledPayloadMissing
    case commandTimedOut
    case installationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConnection:
            return NSLocalizedString("agent.ssh.error.invalid_connection", comment: "")
        case .hostKeyProbeFailed:
            return NSLocalizedString("agent.ssh.error.host_key_probe", comment: "")
        case .hostKeyChanged:
            return NSLocalizedString("agent.ssh.error.host_key_changed", comment: "")
        case .passwordAuthenticationUnavailable:
            return NSLocalizedString("agent.ssh.error.password_unavailable", comment: "")
        case .authenticationFailed:
            return NSLocalizedString("agent.ssh.error.authentication", comment: "")
        case .bundledPayloadMissing:
            return NSLocalizedString("agent.ssh.error.payload_missing", comment: "")
        case .commandTimedOut:
            return NSLocalizedString("agent.ssh.error.timeout", comment: "")
        case .installationFailed(let detail):
            return String(
                format: NSLocalizedString("agent.ssh.error.installation", comment: ""),
                detail
            )
        }
    }
}

enum SSHAgentInstaller {
    static func inspectHost(host: String, port: Int) async throws -> SSHHostIdentity {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedHost.isEmpty, (1...65_535).contains(port) else {
            throw SSHAgentInstallerError.invalidConnection
        }

        return try await Task.detached(priority: .userInitiated) {
            try inspectHostBlocking(host: normalizedHost, port: port)
        }.value
    }

    static func install(
        host: String,
        port: Int,
        username: String,
        password: String,
        pairingCode: String,
        trustedHostKey: String
    ) async throws -> SSHCommandResult {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCode = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !normalizedHost.isEmpty,
            (1...65_535).contains(port),
            !normalizedUser.isEmpty,
            !password.isEmpty,
            normalizedCode.count == 6,
            normalizedCode.allSatisfy(\.isNumber),
            !trustedHostKey.isEmpty
        else {
            throw SSHAgentInstallerError.invalidConnection
        }

        let command = try deploymentCommand(pairingCode: normalizedCode)
        return try await Task.detached(priority: .userInitiated) {
            try installBlocking(
                host: normalizedHost,
                port: port,
                username: normalizedUser,
                password: password,
                trustedHostKey: trustedHostKey,
                command: command
            )
        }.value
    }

    private static func inspectHostBlocking(host: String, port: Int) throws -> SSHHostIdentity {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }

        let serverDelegate = ProbeHostKeyDelegate()
        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    let pipeline = channel.pipeline.syncOperations
                    try pipeline.addHandler(
                        NIOSSHHandler(
                            role: .client(
                                .init(
                                    userAuthDelegate: RejectingUserAuthenticationDelegate(),
                                    serverAuthDelegate: serverDelegate
                                )
                            ),
                            allocator: channel.allocator,
                            inboundChildChannelInitializer: nil
                        )
                    )
                    try pipeline.addHandler(SSHConnectionErrorHandler())
                }
            }
            .connectTimeout(.seconds(8))
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)

        let channel = try bootstrap.connect(host: host, port: port).wait()
        let timeout = channel.eventLoop.scheduleTask(in: .seconds(10)) {
            channel.close(promise: nil)
        }
        _ = try? channel.closeFuture.wait()
        timeout.cancel()
        guard let identity = serverDelegate.identity else {
            throw SSHAgentInstallerError.hostKeyProbeFailed
        }
        return identity
    }

    private static func installBlocking(
        host: String,
        port: Int,
        username: String,
        password: String,
        trustedHostKey: String,
        command: String
    ) throws -> SSHCommandResult {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }

        let resultPromise = group.next().makePromise(of: SSHCommandResult.self)
        let sshHandlerBox = SSHHandlerBox()
        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    let pipeline = channel.pipeline.syncOperations
                    let sshHandler = NIOSSHHandler(
                        role: .client(
                            .init(
                                userAuthDelegate: PasswordAuthenticationDelegate(
                                    username: username,
                                    password: password
                                ),
                                serverAuthDelegate: PinnedHostKeyDelegate(expectedOpenSSHKey: trustedHostKey)
                            )
                        ),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: nil
                    )
                    sshHandlerBox.store(sshHandler)
                    try pipeline.addHandler(sshHandler)
                    try pipeline.addHandler(SSHConnectionErrorHandler())
                }
            }
            .connectTimeout(.seconds(10))
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)

        let channel: Channel
        do {
            channel = try bootstrap.connect(host: host, port: port).wait()
        } catch {
            throw SSHAgentInstallerError.authenticationFailed
        }

        let childPromise = channel.eventLoop.makePromise(of: Channel.self)
        do {
            channel.eventLoop.execute {
                guard let sshHandler = sshHandlerBox.load() else {
                    childPromise.fail(SSHAgentInstallerError.authenticationFailed)
                    return
                }
                sshHandler.createChannel(childPromise) { childChannel, channelType in
                    guard channelType == .session else {
                        return childChannel.eventLoop.makeFailedFuture(SSHAgentInstallerError.installationFailed("invalid-channel"))
                    }
                    return childChannel.eventLoop.makeCompletedFuture {
                        let pipeline = childChannel.pipeline.syncOperations
                        try pipeline.addHandler(
                            SSHCommandCaptureHandler(command: command, resultPromise: resultPromise)
                        )
                        try pipeline.addHandler(SSHConnectionErrorHandler())
                    }
                }
            }
            let child = try childPromise.futureResult.wait()
            let timeout = child.eventLoop.scheduleTask(in: .seconds(90)) {
                resultPromise.fail(SSHAgentInstallerError.commandTimedOut)
                child.close(promise: nil)
            }
            let result = try resultPromise.futureResult.wait()
            timeout.cancel()
            try? child.close().wait()
            try? channel.close().wait()
            guard result.exitStatus == 0 else {
                let detail = result.standardError.isEmpty
                    ? "exit-\(result.exitStatus)"
                    : String(result.standardError.prefix(240))
                throw SSHAgentInstallerError.installationFailed(detail)
            }
            return result
        } catch let error as SSHAgentInstallerError {
            try? channel.close().wait()
            throw error
        } catch {
            try? channel.close().wait()
            throw SSHAgentInstallerError.authenticationFailed
        }
    }

    private static func deploymentCommand(pairingCode: String) throws -> String {
        let resources = [
            ("nastart_agent", "py", "nastart_agent.py", "700"),
            ("Dockerfile", nil, "Dockerfile", "600"),
            ("compose", "yaml", "compose.yaml", "600")
        ]
        var encoded: [(String, String, String)] = []
        for (name, ext, remoteName, mode) in resources {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext),
                  let data = try? Data(contentsOf: url) else {
                throw SSHAgentInstallerError.bundledPayloadMissing
            }
            encoded.append((remoteName, data.base64EncodedString(), mode))
        }

        var lines = [
            "set -eu",
            "umask 077",
            "agent_dir=\"$HOME/.nastart-agent\"",
            "mkdir -p \"$agent_dir/data\""
        ]
        for (remoteName, payload, mode) in encoded {
            lines.append("printf '%s' '\(payload)' | base64 -d > \"$agent_dir/\(remoteName)\"")
            lines.append("chmod \(mode) \"$agent_dir/\(remoteName)\"")
        }
        lines.append(contentsOf: [
            "cd \"$agent_dir\"",
            "if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then",
            "  NASTART_PAIRING_CODE='\(pairingCode)' docker compose -f compose.yaml up -d --build",
            "elif command -v python3 >/dev/null 2>&1; then",
            "  if [ -f agent.pid ] && kill -0 \"$(cat agent.pid)\" 2>/dev/null; then kill \"$(cat agent.pid)\"; fi",
            "  NASTART_PAIRING_CODE='\(pairingCode)' nohup python3 ./nastart_agent.py --host 0.0.0.0 --port 8787 --data-dir ./data >./agent.log 2>&1 &",
            "  echo $! > agent.pid",
            "else",
            "  echo 'Docker Compose or Python 3 is required' >&2",
            "  exit 69",
            "fi",
            "echo NASTART_AGENT_READY"
        ])
        return lines.joined(separator: "\n")
    }
}

private final class ProbeHostKeyDelegate: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var capturedIdentity: SSHHostIdentity?

    var identity: SSHHostIdentity? {
        lock.lock()
        defer { lock.unlock() }
        return capturedIdentity
    }

    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        let openSSHKey = String(openSSHPublicKey: hostKey)
        lock.lock()
        capturedIdentity = SSHHostIdentity(
            openSSHKey: openSSHKey,
            fingerprint: Self.fingerprint(openSSHKey: openSSHKey)
        )
        lock.unlock()
        validationCompletePromise.fail(SSHHostKeyProbeCompleted())
    }

    private static func fingerprint(openSSHKey: String) -> String {
        let parts = openSSHKey.split(separator: " ", omittingEmptySubsequences: true)
        let keyData = parts.count > 1 ? Data(base64Encoded: String(parts[1])) : nil
        let digest = SHA256.hash(data: keyData ?? Data(openSSHKey.utf8))
        return "SHA256:" + Data(digest).base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}

private struct SSHHostKeyProbeCompleted: Error {}

private final class SSHHandlerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: NIOSSHHandler?

    func store(_ handler: NIOSSHHandler) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func load() -> NIOSSHHandler? {
        lock.lock()
        defer { lock.unlock() }
        return handler
    }
}

private final class PinnedHostKeyDelegate: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    private let expectedOpenSSHKey: String

    init(expectedOpenSSHKey: String) {
        self.expectedOpenSSHKey = expectedOpenSSHKey
    }

    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        guard String(openSSHPublicKey: hostKey) == expectedOpenSSHKey else {
            validationCompletePromise.fail(SSHAgentInstallerError.hostKeyChanged)
            return
        }
        validationCompletePromise.succeed(())
    }
}

private final class RejectingUserAuthenticationDelegate: NIOSSHClientUserAuthenticationDelegate, @unchecked Sendable {
    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        nextChallengePromise.fail(SSHHostKeyProbeCompleted())
    }
}

private final class PasswordAuthenticationDelegate: NIOSSHClientUserAuthenticationDelegate, @unchecked Sendable {
    private let username: String
    private let password: String
    private let lock = NSLock()
    private var attempted = false

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard availableMethods.contains(.password) else {
            nextChallengePromise.fail(SSHAgentInstallerError.passwordAuthenticationUnavailable)
            return
        }
        guard !attempted else {
            nextChallengePromise.fail(SSHAgentInstallerError.authenticationFailed)
            return
        }
        attempted = true
        nextChallengePromise.succeed(
            NIOSSHUserAuthenticationOffer(
                username: username,
                serviceName: "",
                offer: .password(.init(password: password))
            )
        )
    }
}

private final class SSHCommandCaptureHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = SSHChannelData

    private let command: String
    private var resultPromise: EventLoopPromise<SSHCommandResult>?
    private var standardOutput = Data()
    private var standardError = Data()
    private var exitStatus: Int?

    init(command: String, resultPromise: EventLoopPromise<SSHCommandResult>) {
        self.command = command
        self.resultPromise = resultPromise
    }

    func channelActive(context: ChannelHandlerContext) {
        context.triggerUserOutboundEvent(
            SSHChannelRequestEvent.ExecRequest(command: command, wantReply: true),
            promise: nil
        )
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)
        guard case .byteBuffer(var bytes) = channelData.data,
              let chunk = bytes.readData(length: bytes.readableBytes) else {
            return
        }
        if channelData.type == .stdErr {
            standardError.append(chunk)
        } else {
            standardOutput.append(chunk)
        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let event = event as? SSHChannelRequestEvent.ExitStatus {
            exitStatus = event.exitStatus
            finishIfPossible(context: context)
        } else {
            context.fireUserInboundEventTriggered(event)
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        finishIfPossible(context: context, fallbackExitStatus: 255)
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        resultPromise?.fail(error)
        resultPromise = nil
        context.close(promise: nil)
    }

    private func finishIfPossible(context: ChannelHandlerContext, fallbackExitStatus: Int? = nil) {
        guard let resultPromise, let status = exitStatus ?? fallbackExitStatus else { return }
        self.resultPromise = nil
        resultPromise.succeed(
            SSHCommandResult(
                exitStatus: status,
                standardOutput: String(decoding: standardOutput, as: UTF8.self),
                standardError: String(decoding: standardError, as: UTF8.self)
            )
        )
        context.close(promise: nil)
    }
}

private final class SSHConnectionErrorHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = Any

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }
}
