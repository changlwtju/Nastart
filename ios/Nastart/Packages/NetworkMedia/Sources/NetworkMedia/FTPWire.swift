import Foundation
import Network
import Security

final class FTPOwnedConnections: @unchecked Sendable {
  private let lock = NSLock()
  private var connections: [NWConnection] = []
  private var reason: Int = 0
  func add(_ c: NWConnection) {
    lock.lock()
    let stopped = reason != 0
    if !stopped { connections.append(c) }
    lock.unlock()
    if stopped { c.cancel() }
  }
  func drop(_ c: NWConnection) {
    lock.lock()
    connections.removeAll { $0 === c }
    lock.unlock()
  }
  func stop(_ why: Int) {
    lock.lock()
    if reason == 0 { reason = why }
    let all = connections
    connections = []
    lock.unlock()
    all.forEach { $0.cancel() }
  }
  func check() throws {
    lock.lock()
    let r = reason
    lock.unlock()
    if r == 1 { throw CancellationError() }
    if r == 2 { throw FTPReadError.deadline }
    if r != 0 { throw FTPReadError.closed }
  }
}
final class FTPTrustState: @unchecked Sendable {
  private let lock = NSLock()
  private var leaf: Data?
  private var rejected = false
  private var count = 0
  func record(_ data: Data?) {
    lock.lock()
    defer { lock.unlock() }
    count += 1
    if let data { leaf = data } else { rejected = true }
  }
  func snapshot() -> (Data?, Bool, Int) {
    lock.lock()
    defer { lock.unlock() }
    return (leaf, rejected, count)
  }
}
final class FTPWire: @unchecked Sendable {
  let connection: NWConnection
  let trust = FTPTrustState()
  let queue = DispatchQueue(label: "Nastart.PassiveWire")
  let owned: FTPOwnedConnections
  let prelude = FTPPreludeState()
  private var readyResult: Result<Void, Error>?
  private var readyWaiters: [CheckedContinuation<Void, Error>] = []
  init(
    host: String, port: Int, protected: Bool, upgrade: Bool = false, name: String, anchor: Data?,
    pin: Data?, owned: FTPOwnedConnections
  ) throws {
    self.owned = owned
    let options: NWProtocolTLS.Options? = protected ? NWProtocolTLS.Options() : nil
    if let options {
      sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv12)
      sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, name)
      let state = trust
      sec_protocol_options_set_verify_block(
        options.securityProtocolOptions,
        { _, value, complete in
          let trust = sec_trust_copy_ref(value).takeRetainedValue()
          SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, name as CFString))
          if let anchor {
            guard let cert = SecCertificateCreateWithData(nil, anchor as CFData),
              SecTrustSetAnchorCertificates(trust, [cert] as CFArray) == errSecSuccess,
              SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess
            else {
              state.record(nil)
              complete(false)
              return
            }
          }
          var error: CFError?
          guard SecTrustEvaluateWithError(trust, &error),
            let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
            let first = chain.first
          else {
            state.record(nil)
            complete(false)
            return
          }
          let leaf = SecCertificateCopyData(first) as Data
          guard pin == nil || pin == leaf else {
            state.record(nil)
            complete(false)
            return
          }
          state.record(leaf)
          complete(true)
        }, DispatchQueue(label: "Nastart.PassiveTrust"))
    }
    let parameters = NWParameters(tls: upgrade ? nil : options, tcp: NWProtocolTCP.Options())
    if upgrade {
      guard let options else { throw FTPReadError.invalidInput }
      let framer = NWProtocolFramer.Options(definition: FTPStartTLSFramer.definition)
      framer["tls"] = options
      framer["state"] = prelude
      parameters.defaultProtocolStack.applicationProtocols.insert(framer, at: 0)
    }
    guard let port = NWEndpoint.Port(rawValue: UInt16(exactly: port) ?? 0), port.rawValue != 0
    else { throw FTPReadError.invalidInput }
    connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: parameters)
    connection.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      switch state {
      case .ready: self.finishReady(.success(()))
      case .failed(let error), .waiting(let error):
        self.finishReady(
          .failure(
            self.trust.snapshot().1 ? FTPReadError.tlsUnverified : self.prelude.error() ?? error))
        self.connection.cancel()
      case .cancelled: self.finishReady(.failure(FTPReadError.closed))
      default: break
      }
    }
    connection.start(queue: queue)
    owned.add(connection)
  }
  private func finishReady(_ result: Result<Void, Error>) {
    guard readyResult == nil else { return }
    readyResult = result
    let waiters = readyWaiters
    readyWaiters = []
    waiters.forEach { $0.resume(with: result) }
  }
  func ready() async throws {
    try owned.check()
    try await withCheckedThrowingContinuation { done in
      queue.async {
        if let result = self.readyResult {
          done.resume(with: result)
        } else {
          self.readyWaiters.append(done)
        }
      }
    }
    try owned.check()
  }
  func peer() throws -> String {
    guard case .hostPort(let host, _) = connection.currentPath?.remoteEndpoint else {
      throw FTPReadError.peerUnavailable
    }
    switch host {
    case .ipv4(let address): return address.debugDescription
    case .ipv6(let address): return address.debugDescription
    default: throw FTPReadError.peerUnavailable
    }
  }
  func send(_ data: Data) async throws {
    try owned.check()
    try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
      connection.send(
        content: data,
        completion: .contentProcessed { error in
          if let error { done.resume(throwing: error) } else { done.resume() }
        })
    }
    try owned.check()
  }
  func receive(maximumLength: Int = 4096) async throws -> (Data, Bool) {
    try owned.check()
    let result: (Data, Bool) = try await withCheckedThrowingContinuation { done in
      connection.receive(minimumIncompleteLength: 1, maximumLength: maximumLength) { data, _, ended, error in
        if let error {
          done.resume(
            throwing: self.trust.snapshot().1
              ? FTPReadError.tlsUnverified : self.prelude.error() ?? error)
        } else {
          done.resume(returning: (data ?? Data(), ended))
        }
      }
    }
    try owned.check()
    return result
  }
}
final class FTPReplies {
  let wire: FTPWire
  var buffer = Data()
  var total = 0
  var lastLines: [String] = []
  init(_ wire: FTPWire) { self.wire = wire }
  /// A long-lived session bounds reply bytes per operation, not over its lifetime.
  func beginOperation() { total = 0 }
  func read(allowQueued: Bool = false) async throws -> (Int, String) {
    var code: Int?
    var bytes = 0
    var lines = 0
    var allLines: [String] = []
    while true {
      if let end = buffer.range(of: Data([13, 10])) {
        let line = buffer.subdata(in: 0..<end.lowerBound)
        buffer.removeSubrange(0..<end.upperBound)
        bytes += line.count + 2
        lines += 1
        guard bytes <= 16384, lines <= 128, line.count <= 1024, !line.contains(0),
          !line.contains(10), !line.contains(13), let text = String(data: line, encoding: .utf8)
        else { throw FTPReadError.limit }
        allLines.append(text)
        if code == nil {
          guard line.count >= 4, (49...53).contains(line[0]), (48...57).contains(line[1]),
            (48...57).contains(line[2]), [UInt8(32), 45].contains(line[3])
          else { throw FTPReadError.invalidReply }
          code = Int(line[0] - 48) * 100 + Int(line[1] - 48) * 10 + Int(line[2] - 48)
          if line[3] == 32 {
            guard allowQueued || buffer.isEmpty else { throw FTPReadError.invalidReply }
            lastLines = allLines
            return (code!, text)
          }
        } else if line.starts(with: Array(String(code!).utf8) + [UInt8(32)]) {
          guard allowQueued || buffer.isEmpty else { throw FTPReadError.invalidReply }
          lastLines = allLines
          return (code!, text)
        }
      } else {
        guard buffer.count <= 1024 else { throw FTPReadError.limit }
        let (data, ended) = try await wire.receive()
        guard !ended || !data.isEmpty else { throw FTPReadError.closed }
        total += data.count
        guard total <= 131072 else { throw FTPReadError.limit }
        buffer.append(data)
      }
    }
  }
  func expect(_ expected: Int) async throws {
    let (code, _) = try await read()
    guard code == expected else { throw FTPReadError.unexpected(code) }
  }
}
enum FTPPassivePort {
  static func parse(_ line: String, epsv: Bool, controlPort: Int) throws -> Int {
    guard let begin = line.firstIndex(of: "("), let end = line.lastIndex(of: ")"), begin < end,
      line.filter({ $0 == "(" }).count == 1, line.filter({ $0 == ")" }).count == 1
    else { throw FTPReadError.invalidPassive }
    let body = Array(line[line.index(after: begin)..<end].utf8)
    let port: Int
    if epsv {
      guard body.count >= 5, (33...126).contains(body[0]), body[0] == body[1], body[0] == body[2],
        body[0] == body.last,
        body[3..<body.count - 1].allSatisfy({ (48...57).contains($0) }),
        let value = Int(String(decoding: body[3..<body.count - 1], as: UTF8.self))
      else { throw FTPReadError.invalidPassive }
      port = value
    } else {
      let parts = body.split(separator: 44, omittingEmptySubsequences: false)
      guard parts.count == 6 else { throw FTPReadError.invalidPassive }
      let values = try parts.map { part -> Int in
        guard !part.isEmpty, part.count <= 3, part.allSatisfy({ (48...57).contains($0) }),
          let value = Int(String(decoding: part, as: UTF8.self)), value <= 255
        else { throw FTPReadError.invalidPassive }
        return value
      }
      port = values[4] * 256 + values[5]  // The advertised address is parsed but never connected to.
    }
    guard (1024...65535).contains(port), port != controlPort else {
      throw FTPReadError.invalidPassive
    }
    return port
  }
}
