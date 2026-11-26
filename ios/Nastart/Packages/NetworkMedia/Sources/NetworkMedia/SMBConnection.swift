import CryptoKit
import Darwin
import Foundation
import SMB2
import SMB2.Raw

public enum SMBReadError: Error, LocalizedError, Equatable {
  case invalidPath, accountRequired, loginRejected, unreachable, denied, notFound, link, limit
  case timedOut, connectionLost, failed, sharesUnavailable
  public var errorDescription: String? {
    switch self {
    case .invalidPath: return networkL("SMB 路径无效，请核对共享和文件夹名称。")
    case .accountRequired: return networkL("SMB 需要账号和密码，暂不支持访客访问。")
    case .loginRejected: return networkL("SMB 服务器未接受本次登录，请检查账号和密码。")
    case .unreachable: return networkL("无法连接 SMB 服务，请确认服务已开启，并核对地址和端口。")
    case .denied: return networkL("此账号没有读取该 SMB 共享或文件夹的权限。")
    case .notFound: return networkL("SMB 共享或文件夹不存在，请核对路径。")
    case .link: return networkL("这是一个链接，为确保只读取所选文件夹，已跳过。")
    case .limit: return networkL("SMB 目录或资料超过读取上限，请选择更小的文件夹。")
    case .timedOut: return networkL("SMB 连接或读取超时。")
    case .connectionLost, .failed: return networkL("SMB 连接或读取未完成。")
    case .sharesUnavailable: return networkL("无法列出 SMB 共享，请在路径栏填写共享名称，例如 /video。")
    }
  }
}

/// Where and as whom to connect. `DOMAIN\user` names a domain account.
struct SMBEndpoint: Hashable, Sendable {
  let host: String
  let port: Int
  let domain: String?
  let username: String
  let password: String

  init(scope: WebDAVScope, credential: WebDAVCredential?) throws {
    guard scope.isSMB, let host = scope.baseURL.host, !host.isEmpty else {
      throw NetworkMediaError.invalidAddress
    }
    self.host = host
    port = scope.baseURL.port ?? 445
    let parts = (credential?.username ?? "").split(separator: "\\", maxSplits: 1).map(String.init)
    domain = parts.count == 2 ? parts[0] : nil
    username = parts.last ?? ""
    password = credential?.password ?? ""
  }
}

/// Remembers a refused login briefly. A library's posters load independently, and
/// each retrying the same wrong password could get the address blocked by the NAS.
enum SMBLoginGate {
  private static let lock = NSLock()
  private static var refused: [SHA256.Digest: Date] = [:]
  private static func key(_ endpoint: SMBEndpoint) -> SHA256.Digest {
    let text = [endpoint.host, String(endpoint.port), endpoint.domain ?? "", endpoint.username, endpoint.password]
    return SHA256.hash(data: Data(text.joined(separator: "\0").utf8))
  }
  static func isRefused(_ endpoint: SMBEndpoint) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    refused = refused.filter { Date().timeIntervalSince($0.value) < 60 }
    return refused[key(endpoint)] != nil
  }
  static func recordRefusal(_ endpoint: SMBEndpoint) {
    lock.lock()
    defer { lock.unlock() }
    refused[key(endpoint)] = Date()
  }
}

/// Set from any thread when the task waiting on a connection is cancelled.
final class SMBCancelSignal: @unchecked Sendable {
  private let lock = NSLock()
  private var value = false
  func cancel() {
    lock.lock()
    value = true
    lock.unlock()
  }
  var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
}

struct SMBDirectoryEntry: Sendable {
  let name: String
  let isDirectory: Bool
  let isLink: Bool
  let size: Int64
  let modified: UInt64
}

private final class SMBReply {
  enum Kind { case connect, create, close, query, read, shares }
  let kind: Kind
  var done = false
  var authStarted = false
  var status: Int32 = 0
  var ntStatus: UInt32 = 0
  var created = smb2_create_reply()
  var bytes = Data()
  var shares: [String] = []
  init(_ kind: Kind) { self.kind = kind }

  func receive(context: UnsafeMutablePointer<smb2_context>?, status: Int32, data: UnsafeMutableRawPointer?) {
    self.status = status
    if status == 0, let data {
      switch kind {
      case .create: created = data.assumingMemoryBound(to: smb2_create_reply.self).pointee
      case .query:
        let value = data.assumingMemoryBound(to: smb2_query_directory_reply.self).pointee
        if value.output_buffer_length > 0, let pointer = value.output_buffer {
          bytes = Data(bytes: pointer, count: Int(value.output_buffer_length))
        }
      case .read:
        let value = data.assumingMemoryBound(to: smb2_read_reply.self).pointee
        if value.data_length > 0, let pointer = value.data {
          bytes = Data(bytes: pointer, count: Int(value.data_length))
        }
      case .shares:
        let value = data.assumingMemoryBound(to: srvsvc_NetrShareEnum_rep.self).pointee
        if value.status == 0, value.ses.ShareInfo.Level == 1, let list = value.ses.ShareInfo.Level1.Buffer {
          let count = min(Int(value.ses.ShareInfo.Level1.EntriesRead), Int(list.pointee.max_count), 4096)
          if let items = list.pointee.share_info_1 {
            for index in 0..<count {
              // Only plain disk shares: bit 31 marks hidden ones, low bits the type.
              guard items[index].type & 0xFFFF == 0, items[index].type & 0x8000_0000 == 0,
                let name = items[index].netname.utf8
              else { continue }
              let share = String(cString: name)
              if !share.hasSuffix("$") { shares.append(share) }
            }
          }
        }
        nastart_smb2_free_data(context, data)
      default: break
      }
    }
    done = true
  }
}

private let smbCallback: smb2_command_cb = { context, status, data, privateData in
  guard let privateData else { return }
  let reply = Unmanaged<SMBReply>.fromOpaque(privateData).takeUnretainedValue()
  if let context { reply.ntStatus = UInt32(bitPattern: nastart_smb2_get_nterror(context)) }
  reply.receive(context: context, status: status, data: data)
}
private let smbAuthStarted: @convention(c) (UnsafeMutableRawPointer?) -> Void = { pointer in
  guard let pointer else { return }
  Unmanaged<SMBReply>.fromOpaque(pointer).takeUnretainedValue().authStarted = true
}

/// One authenticated tree connection. Blocking, and used by one serial worker only.
/// A cancelled or failed command leaves the protocol state unknown, so the connection
/// is marked dead and the worker replaces it.
final class SMBConnection {
  private static let readBufferSize = 1 << 20
  private static let directoryBufferSize = 65536
  private static let maxListingBytes = 8 << 20
  private static let maxListingEntries = 50000

  private var context: UnsafeMutablePointer<smb2_context>!
  private var inFlight: [ObjectIdentifier: SMBReply] = [:]
  private let readBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: SMBConnection.readBufferSize)
  private var openFile: (path: String, handle: smb2_create_reply)?
  private(set) var isDead = false
  var signal: SMBCancelSignal

  /// Connecting tries each address until one reaches authentication. It never logs
  /// in twice, so a refused password counts against the account only once.
  init(endpoint: SMBEndpoint, share: String, signal: SMBCancelSignal) throws {
    self.signal = signal
    guard !endpoint.username.isEmpty else { throw SMBReadError.accountRequired }
    guard !SMBLoginGate.isRefused(endpoint) else { throw SMBReadError.loginRejected }
    var lastError: Error = SMBReadError.unreachable
    for address in try Self.resolve(endpoint.host, signal: signal).prefix(4) {
      guard let context = nastart_smb2_init_context() else { throw SMBReadError.failed }
      self.context = context
      isDead = false
      do {
        let reachedLogin = try connect(endpoint: endpoint, address: address, share: share)
        if reachedLogin { return }
      } catch {
        lastError = error
        if let error = error as? SMBReadError, error == .loginRejected { SMBLoginGate.recordRefusal(endpoint) }
        destroyContext()
        throw error
      }
      destroyContext()
    }
    throw lastError
  }

  deinit {
    if context != nil { destroyContext() }
    readBuffer.deallocate()
  }

  private func destroyContext() {
    // Destruction may complete outstanding callbacks, so their replies stay alive through it.
    nastart_smb2_destroy_context(context)
    context = nil
    inFlight.removeAll()
  }

  /// False means this address was never reached, so the next one may be tried.
  private func connect(endpoint: SMBEndpoint, address: String, share: String) throws -> Bool {
    nastart_smb2_set_timeout(context, 30)
    nastart_smb2_set_version(context, SMB2_VERSION_ANY)
    // Signing is required so a replayed or altered reply is rejected. A server that
    // demands encryption turns it on for the session during login.
    nastart_smb2_set_security_mode(context, UInt16(SMB2_NEGOTIATE_SIGNING_ENABLED | SMB2_NEGOTIATE_SIGNING_REQUIRED))
    nastart_smb2_set_sign(context, 1)
    endpoint.password.withCString { nastart_smb2_set_password(context, $0) }
    if let domain = endpoint.domain { domain.withCString { nastart_smb2_set_domain(context, $0) } }
    let reply = SMBReply(.connect)
    inFlight[ObjectIdentifier(reply)] = reply
    let started = endpoint.host.withCString { identity in
      address.withCString { numeric in
        share.withCString { shareName in
          endpoint.username.withCString { user in
            nastart_smb2_connect_share_resolved_async(
              context, identity, numeric, UInt16(endpoint.port), shareName, user, smbAuthStarted, smbCallback,
              Unmanaged.passUnretained(reply).toOpaque())
          }
        }
      }
    }
    guard started >= 0 else { throw SMBReadError.unreachable }
    do {
      try wait(reply, limit: 25, preAuthenticationLimit: 4, cancelGrace: 0)
    } catch let error as SMBReadError where [.timedOut, .connectionLost].contains(error) {
      if !reply.authStarted { return false }
      // Whether the password was refused is unknown, so treat it as if it was: a
      // login isn't repeated until the gate clears.
      SMBLoginGate.recordRefusal(endpoint)
      throw SMBReadError.failed
    }
    if reply.status == 0 { return true }
    if !reply.authStarted { return false }
    switch reply.ntStatus {
    case UInt32(SMB2_STATUS_LOGON_FAILURE), UInt32(SMB2_STATUS_WRONG_PASSWORD), UInt32(SMB2_STATUS_ACCOUNT_DISABLED),
      UInt32(SMB2_STATUS_PASSWORD_EXPIRED), UInt32(SMB2_STATUS_ACCOUNT_RESTRICTION):
      throw SMBReadError.loginRejected
    case UInt32(SMB2_STATUS_BAD_NETWORK_NAME): throw SMBReadError.notFound
    case UInt32(SMB2_STATUS_ACCESS_DENIED): throw SMBReadError.denied
    default: throw SMBReadError.failed
    }
  }

  /// `getaddrinfo` can't be interrupted, so it runs aside and is abandoned on cancel.
  private static func resolve(_ host: String, signal: SMBCancelSignal) throws -> [String] {
    final class Box: @unchecked Sendable { var addresses: [String] = [] }
    let box = Box()
    let finished = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
      var hints = addrinfo()
      hints.ai_socktype = SOCK_STREAM
      var list: UnsafeMutablePointer<addrinfo>?
      if getaddrinfo(host, nil, &hints, &list) == 0 {
        var numeric: [(family: Int32, text: String)] = []
        var next = list
        while let item = next {
          var text = [CChar](repeating: 0, count: Int(NI_MAXHOST))
          if getnameinfo(item.pointee.ai_addr, item.pointee.ai_addrlen, &text, socklen_t(text.count), nil, 0, NI_NUMERICHOST) == 0 {
            let value = String(cString: text)
            if !numeric.contains(where: { $0.text == value }) { numeric.append((item.pointee.ai_family, value)) }
          }
          next = item.pointee.ai_next
        }
        freeaddrinfo(list)
        // A link-local IPv6 answer for a .local name is often unusable, so IPv4 goes first.
        box.addresses = numeric.filter { $0.family == AF_INET }.map(\.text) + numeric.filter { $0.family != AF_INET }.map(\.text)
      }
      finished.signal()
    }
    let deadline = Date().addingTimeInterval(8)
    while finished.wait(timeout: .now() + .milliseconds(50)) == .timedOut {
      if signal.isCancelled { throw CancellationError() }
      if Date() >= deadline { throw SMBReadError.unreachable }
    }
    guard !box.addresses.isEmpty else { throw SMBReadError.unreachable }
    return box.addresses
  }

  private func wait(_ reply: SMBReply, limit: TimeInterval = 20, preAuthenticationLimit: TimeInterval? = nil, cancelGrace: TimeInterval = 1.5) throws {
    let started = Date()
    var cancelledAt: Date?
    func fail(_ error: Error) -> Error {
      isDead = true
      return error
    }
    while !reply.done {
      if signal.isCancelled {
        // A read about to finish keeps the connection, so a seek need not log in again.
        let since = cancelledAt ?? Date()
        cancelledAt = since
        if Date().timeIntervalSince(since) >= cancelGrace { throw fail(CancellationError()) }
      }
      let elapsed = Date().timeIntervalSince(started)
      if elapsed >= limit { throw fail(SMBReadError.timedOut) }
      if let preAuthenticationLimit, !reply.authStarted, elapsed >= preAuthenticationLimit { throw fail(SMBReadError.timedOut) }
      let socket = nastart_smb2_get_fd(context)
      guard socket >= 0 else { throw fail(SMBReadError.connectionLost) }
      var descriptor = pollfd(fd: socket, events: Int16(nastart_smb2_which_events(context)), revents: 0)
      let ready = Darwin.poll(&descriptor, 1, 20)
      if ready < 0 {
        if errno == EINTR { continue }
        throw fail(SMBReadError.connectionLost)
      }
      if ready > 0, nastart_smb2_service(context, Int32(descriptor.revents)) < 0 {
        isDead = true
        if !reply.done { throw SMBReadError.connectionLost }
      }
    }
    inFlight[ObjectIdentifier(reply)] = nil
  }

  private func send(_ reply: SMBReply, _ make: (UnsafeMutableRawPointer) -> UnsafeMutablePointer<smb2_pdu>?) throws {
    if signal.isCancelled { throw CancellationError() }
    guard !isDead else { throw SMBReadError.connectionLost }
    guard let pdu = make(Unmanaged.passUnretained(reply).toOpaque()) else { throw SMBReadError.failed }
    inFlight[ObjectIdentifier(reply)] = reply
    nastart_smb2_queue_pdu(context, pdu)
    try wait(reply)
  }

  private func check(_ reply: SMBReply) throws {
    guard reply.status != 0 else { return }
    switch UInt32(bitPattern: reply.status) {
    case UInt32(SMB2_STATUS_ACCESS_DENIED): throw SMBReadError.denied
    case UInt32(SMB2_STATUS_OBJECT_NAME_NOT_FOUND), UInt32(SMB2_STATUS_OBJECT_PATH_NOT_FOUND), UInt32(SMB2_STATUS_NO_SUCH_FILE):
      throw SMBReadError.notFound
    case UInt32(SMB2_STATUS_STOPPED_ON_SYMLINK): throw SMBReadError.link
    case UInt32(SMB2_STATUS_NETWORK_NAME_DELETED), UInt32(SMB2_STATUS_USER_SESSION_DELETED):
      isDead = true
      throw SMBReadError.connectionLost
    default:
      throw SMBReadError.failed
    }
  }

  /// Opens for reading without blocking anyone else: other clients may still write,
  /// rename or delete a file while it plays. Links are refused, not followed.
  private func open(_ path: String, directory: Bool) throws -> smb2_create_reply {
    let reply = SMBReply(.create)
    var request = smb2_create_request()
    request.impersonation_level = UInt32(SMB2_IMPERSONATION_IMPERSONATION)
    request.desired_access = UInt32(SMB2_FILE_READ_ATTRIBUTES | (directory ? SMB2_FILE_LIST_DIRECTORY : SMB2_FILE_READ_DATA))
    request.share_access = UInt32(SMB2_FILE_SHARE_READ | SMB2_FILE_SHARE_WRITE | SMB2_FILE_SHARE_DELETE)
    request.create_disposition = UInt32(SMB2_FILE_OPEN)
    request.create_options = UInt32(SMB2_FILE_OPEN_REPARSE_POINT | (directory ? SMB2_FILE_DIRECTORY_FILE : SMB2_FILE_NON_DIRECTORY_FILE))
    try path.withCString { name in
      request.name = name
      try send(reply) { nastart_smb2_cmd_create_async(context, &request, smbCallback, $0) }
    }
    try check(reply)
    if reply.created.file_attributes & UInt32(SMB2_FILE_ATTRIBUTE_REPARSE_POINT) != 0 {
      try? close(reply.created)
      throw SMBReadError.link
    }
    return reply.created
  }

  private func close(_ handle: smb2_create_reply) throws {
    let reply = SMBReply(.close)
    var request = smb2_close_request()
    request.file_id = handle.file_id
    try send(reply) { nastart_smb2_cmd_close_async(context, &request, smbCallback, $0) }
    try check(reply)
  }

  /// The names on the server. Only meaningful on a connection to `IPC$`.
  func listShares() throws -> [String] {
    let reply = SMBReply(.shares)
    if signal.isCancelled { throw CancellationError() }
    inFlight[ObjectIdentifier(reply)] = reply
    guard nastart_smb2_share_enum_async(context, SHARE_INFO_1, smbCallback, Unmanaged.passUnretained(reply).toOpaque()) >= 0 else {
      inFlight[ObjectIdentifier(reply)] = nil
      throw SMBReadError.sharesUnavailable
    }
    try wait(reply)
    guard reply.status == 0 else { throw SMBReadError.sharesUnavailable }
    return reply.shares
  }

  func list(_ path: String) throws -> [SMBDirectoryEntry] {
    let handle = try open(path, directory: true)
    var entries: [SMBDirectoryEntry] = []
    var total = 0
    var first = true
    pages: while true {
      let reply = SMBReply(.query)
      var request = smb2_query_directory_request()
      request.file_id = handle.file_id
      request.file_information_class = UInt8(SMB2_FILE_DIRECTORY_INFORMATION)
      request.flags = first ? UInt8(SMB2_RESTART_SCANS) : 0
      request.output_buffer_length = UInt32(Self.directoryBufferSize)
      try "*".withCString { pattern in
        request.name = pattern
        try send(reply) { nastart_smb2_cmd_query_directory_async(context, &request, smbCallback, $0) }
      }
      first = false
      switch UInt32(bitPattern: reply.status) {
      case UInt32(SMB2_STATUS_NO_MORE_FILES), UInt32(SMB2_STATUS_NO_SUCH_FILE): break pages
      default: try check(reply)
      }
      total += reply.bytes.count
      guard !reply.bytes.isEmpty, total <= Self.maxListingBytes else { throw SMBReadError.limit }
      entries += try Self.parseDirectoryPage(reply.bytes)
      guard entries.count <= Self.maxListingEntries else { throw SMBReadError.limit }
    }
    try close(handle)
    return entries
  }

  /// `FILE_DIRECTORY_INFORMATION` records. Every offset is checked: the bytes come from the server.
  static func parseDirectoryPage(_ bytes: Data) throws -> [SMBDirectoryEntry] {
    let data = [UInt8](bytes)
    func number(_ offset: Int, _ count: Int) throws -> UInt64 {
      guard offset >= 0, count <= data.count, offset <= data.count - count else { throw SMBReadError.failed }
      return (0..<count).reduce(0) { $0 | UInt64(data[offset + $1]) << (8 * $1) }
    }
    var result: [SMBDirectoryEntry] = []
    var offset = 0
    while true {
      let next = Int(try number(offset, 4))
      let nameSize = Int(try number(offset + 60, 4))
      let end = next == 0 ? data.count : offset + next
      guard nameSize > 0, nameSize % 2 == 0, end <= data.count, offset + 64 + nameSize <= end, next == 0 || next >= 64 else {
        throw SMBReadError.failed
      }
      let attributes = UInt32(try number(offset + 56, 4))
      if let name = String(bytes: data[(offset + 64)..<(offset + 64 + nameSize)], encoding: .utf16LittleEndian),
        name != ".", name != ".."
      {
        result.append(SMBDirectoryEntry(
          name: name, isDirectory: attributes & UInt32(SMB2_FILE_ATTRIBUTE_DIRECTORY) != 0,
          isLink: attributes & UInt32(SMB2_FILE_ATTRIBUTE_REPARSE_POINT) != 0,
          size: Int64(truncatingIfNeeded: try number(offset + 40, 8)), modified: try number(offset + 24, 8)))
      }
      if next == 0 { return result }
      offset = end
    }
  }

  private func read(_ handle: smb2_create_reply, offset: Int64, count: Int) throws -> Data {
    let maximum = Int(nastart_smb2_get_max_read_size(context))
    // SMB 2.0.2 has no multi-credit reads, whatever the server advertises.
    let wire = nastart_smb2_get_dialect(context) == UInt16(SMB2_VERSION_0202.rawValue) ? 65536 : Self.readBufferSize
    let length = min(count, wire, maximum > 0 ? maximum : wire)
    let reply = SMBReply(.read)
    var request = smb2_read_request()
    request.file_id = handle.file_id
    request.offset = UInt64(offset)
    request.length = UInt32(length)
    request.buf = readBuffer
    try send(reply) { nastart_smb2_cmd_read_async(context, &request, smbCallback, $0) }
    try check(reply)
    guard !reply.bytes.isEmpty, reply.bytes.count <= length else { throw SMBReadError.failed }
    return reply.bytes
  }

  /// A small sidecar file, whole.
  func readFile(_ path: String, maximum: Int) throws -> Data {
    let handle = try open(path, directory: false)
    guard handle.end_of_file <= UInt64(maximum) else {
      try? close(handle)
      throw SMBReadError.limit
    }
    var result = Data()
    while result.count < Int(handle.end_of_file) {
      result.append(try read(handle, offset: Int64(result.count), count: Int(handle.end_of_file) - result.count))
    }
    try close(handle)
    return result
  }

  /// Part of a video. The handle stays open between reads; reopening it, including on
  /// a new connection, compares the file with the version the library indexed.
  func read(_ path: String, size: Int64, modified: String, offset: Int64, count: Int) throws -> Data {
    if openFile?.path != path {
      if let previous = openFile {
        openFile = nil
        try? close(previous.handle)
      }
      let handle = try open(path, directory: false)
      guard handle.end_of_file == UInt64(size), String(handle.last_write_time) == modified else {
        try? close(handle)
        throw NetworkMediaPlaybackError.staleFile
      }
      openFile = (path, handle)
    }
    return try read(openFile!.handle, offset: offset, count: count)
  }
}

/// Serializes blocking SMB work for one share on its own queue, and replaces a dead
/// connection. Only a connection that had been idle is retried, once: it may simply
/// have timed out on the server. A refused login is never retried.
final class SMBWorker: @unchecked Sendable {
  private let endpoint: SMBEndpoint
  private let share: String
  private let queue = DispatchQueue(label: "Nastart.SMBWorker", qos: .userInitiated)
  private var connection: SMBConnection?

  init(endpoint: SMBEndpoint, share: String) {
    self.endpoint = endpoint
    self.share = share
  }

  func run<T: Sendable>(_ body: @escaping @Sendable (SMBConnection) throws -> T) async throws -> T {
    try await run(timing: nil, body)
  }

  /// `timing` hears, on the worker's queue, how long this call waited for the
  /// queue and how long it then ran. Observation only: nothing is reordered.
  func run<T: Sendable>(
    timing: (@Sendable (_ queueWait: TimeInterval, _ work: TimeInterval) -> Void)?,
    _ body: @escaping @Sendable (SMBConnection) throws -> T
  ) async throws -> T {
    let signal = SMBCancelSignal()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        Self.timed(on: queue, timing: timing, { [self] in try perform(signal: signal, body) }) {
          continuation.resume(with: $0)
        }
      }
    } onCancel: {
      signal.cancel()
    }
  }

  /// Blocking work on a serial queue, with its wait for the queue told apart
  /// from its own duration. A request behind an unfinished read waits here
  /// before it reaches the connection.
  static func timed<T: Sendable>(
    on queue: DispatchQueue,
    timing: (@Sendable (_ queueWait: TimeInterval, _ work: TimeInterval) -> Void)?,
    _ work: @escaping @Sendable () throws -> T,
    completion: @escaping @Sendable (Result<T, Error>) -> Void
  ) {
    let enqueued = ProcessInfo.processInfo.systemUptime
    queue.async {
      let started = ProcessInfo.processInfo.systemUptime
      let result = Result { try work() }
      timing?(max(started - enqueued, 0), max(ProcessInfo.processInfo.systemUptime - started, 0))
      completion(result)
    }
  }

  private func perform<T>(signal: SMBCancelSignal, _ body: (SMBConnection) throws -> T) throws -> T {
    if signal.isCancelled { throw CancellationError() }
    if let current = connection {
      current.signal = signal
      do {
        let result = try body(current)
        if current.isDead { connection = nil }
        return result
      } catch {
        if current.isDead { connection = nil }
        guard let failure = error as? SMBReadError, failure == .connectionLost else { throw error }
      }
    }
    let fresh = try SMBConnection(endpoint: endpoint, share: share, signal: signal)
    connection = fresh
    defer { if fresh.isDead { connection = nil } }
    return try body(fresh)
  }
}

/// Keeps a share's connection for a short time, since each poster and sidecar asks
/// for its source separately. Playback gets its own worker and doesn't compete here.
final class SMBWorkerPool: @unchecked Sendable {
  static let shared = SMBWorkerPool()
  private struct Key: Hashable {
    let endpoint: SMBEndpoint
    let share: String
  }
  private let lock = NSLock()
  private var workers: [Key: (worker: SMBWorker, used: Date)] = [:]

  func worker(endpoint: SMBEndpoint, share: String) -> SMBWorker {
    lock.lock()
    defer { lock.unlock() }
    let key = Key(endpoint: endpoint, share: share)
    let worker = workers[key]?.worker ?? SMBWorker(endpoint: endpoint, share: share)
    workers[key] = (worker, Date())
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 35) { [weak self] in self?.dropIdle() }
    return worker
  }
  private func dropIdle() {
    lock.lock()
    defer { lock.unlock() }
    workers = workers.filter { Date().timeIntervalSince($0.value.used) < 30 }
  }
}
