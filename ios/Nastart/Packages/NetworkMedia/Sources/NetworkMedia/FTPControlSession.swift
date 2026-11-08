import Foundation
import Network

/// One logged-in FTP control connection. Owned by a single task at a time; any
/// failure ends it, because the control stream may then be out of step.
final class FTPControlSession: @unchecked Sendable {
  private let server: FTPServer
  private let credential: FTPCredential
  private let anchor: Data?
  private let allowsPASV: Bool
  private let limits: FTPMLSDListing.Limits
  let owned: FTPOwnedConnections
  private var control: FTPWire!
  private var replies: FTPReplies!
  private var peer = ""
  private var protected: Bool { server.security != .plainFTP }

  init(
    server: FTPServer, credential: FTPCredential, anchor: Data? = nil, allowsPASV: Bool = true,
    limits: FTPMLSDListing.Limits = .metadata, owned: FTPOwnedConnections
  ) {
    self.server = server
    self.credential = credential
    self.anchor = anchor
    self.allowsPASV = allowsPASV
    self.limits = limits
    self.owned = owned
  }

  private func command(_ text: String) async throws {
    try await control.send(Data((text + "\r\n").utf8))
  }

  func open() async throws {
    control = try FTPWire(
      host: server.host, port: server.port, protected: protected,
      upgrade: server.security == .explicitTLS, name: server.host, anchor: anchor, pin: nil,
      owned: owned)
    do { try await control.ready() } catch is NWError { throw FTPReadError.unreachable }
    peer = try control.peer()
    replies = FTPReplies(control)
    if server.security != .explicitTLS { try await replies.expect(220) }
    if protected {
      guard control.trust.snapshot().0 != nil else { throw FTPReadError.tlsUnverified }
      try await command("PBSZ 0")
      try await replies.expect(200)
      try await command("PROT P")
      try await replies.expect(200)
    }
    try await command("FEAT")
    try await replies.expect(211)
    try FTPFeatureReply.validate(replies.lastLines)
    let needsFactSelection = !FTPFeatureReply.requiredFactsAreActive(replies.lastLines)
    try await command("USER " + credential.username)
    let user = try await replies.read()
    if user.0 == 331 {
      try await command("PASS " + credential.password)
      try await replies.expect(230)
    } else if user.0 != 230 {
      throw FTPReadError.unexpected(user.0)
    }
    try await command("TYPE I")
    try await replies.expect(200)
    // RFC 2640 makes UTF-8 the default, but Synology DSM sends its legacy code page until asked.
    // A server that refuses the option has already advertised UTF8 in FEAT.
    try await command("OPTS UTF8 ON")
    _ = try await replies.read()
    if needsFactSelection {
      try await command("OPTS MLST type;size;modify;unique;")
      try await replies.expect(200)
    }
  }

  private func openData(_ prepare: (() async throws -> Void)? = nil, operation: String) async throws
    -> FTPWire
  {
    try await command("EPSV")
    var passive = try await replies.read()
    var epsv = true
    if passive.0 != 229 {
      guard allowsPASV, [500, 502, 522].contains(passive.0), !peer.contains(":") else {
        throw FTPReadError.unexpected(passive.0)
      }
      try await command("PASV")
      passive = try await replies.read()
      guard passive.0 == 227 else { throw FTPReadError.unexpected(passive.0) }
      epsv = false
    }
    let port = try FTPPassivePort.parse(passive.1, epsv: epsv, controlPort: server.port)
    let data = try FTPWire(
      host: peer, port: port, protected: protected, name: server.host, anchor: anchor,
      pin: control.trust.snapshot().0, owned: owned)
    try await prepare?()
    try await command(operation)
    let preliminary = try await replies.read(allowQueued: true)
    guard [125, 150].contains(preliminary.0) else {
      throw FTPReadError.unexpected(preliminary.0)
    }
    try await data.ready()
    guard try data.peer() == peer else { throw FTPReadError.peerUnavailable }
    if protected {
      guard data.trust.snapshot().0 != nil,
        data.trust.snapshot().0 == control.trust.snapshot().0
      else { throw FTPReadError.tlsUnverified }
    }
    return data
  }

  func transfer(_ operation: String, maximum: Int, expectedLength: Int? = nil) async throws -> Data
  {
    let data = try await openData(operation: operation)
    var payload = Data()
    while true {
      let (chunk, ended) = try await data.receive()
      guard payload.count + chunk.count <= maximum else { throw FTPReadError.limit }
      if let expectedLength, payload.count + chunk.count > expectedLength {
        throw FTPReadError.sourceChanged
      }
      payload.append(chunk)
      if ended { break }
    }
    data.connection.cancel()
    owned.drop(data.connection)
    try await replies.expect(226)
    if let expectedLength, payload.count != expectedLength {
      throw FTPReadError.sourceChanged
    }
    return payload
  }

  func listing(_ directory: FTPPath, limits: FTPMLSDListing.Limits? = nil) async throws -> FTPMLSDListing {
    let limits = limits ?? self.limits
    replies.beginOperation()
    // Synology DSM expands [ ] * ? in an MLSD argument and answers an empty listing for a folder
    // named with them, so such a folder is entered first. Every other command uses absolute paths.
    let argument = directory.commandArgument
    var operation = "MLSD " + argument
    if argument.contains(where: { "[]*?".contains($0) }) {
      try await command("CWD " + argument)
      try await replies.expect(250)
      operation = "MLSD"
    }
    let bytes = try await transfer(operation, maximum: limits.bytes)
    return try FTPMLSDListing.parse(bytes, limits: limits)
  }

  func metadata(_ path: FTPPath) async throws -> FTPListingEntry {
    replies.beginOperation()
    let argument = path.commandArgument
    try await command("MLST " + argument)
    do {
      try await replies.expect(250)
      return try FTPMetadataReply.mlst(
        replies.lastLines, relative: argument, absolute: argument, name: path.name)
    } catch FTPReadError.invalidReply {
      return try await listedMetadata(path)
    } catch FTPReadError.unexpected(550) {
      return try await listedMetadata(path)
    }
  }

  /// Synology DSM reports "No such file" inside a 250 MLST reply for some names its own MLSD
  /// lists, so the parent listing is the second source of the same facts.
  private func listedMetadata(_ path: FTPPath) async throws -> FTPListingEntry {
    guard let parent = path.parent else { throw FTPReadError.metadataUnavailable }
    let entries = try await listing(parent, limits: .library).entries
    guard let entry = entries.first(where: { $0.name.utf8.elementsEqual(path.name.utf8) }),
      entry.kind == .file, entry.size != nil, entry.modify != nil
    else { throw FTPReadError.metadataUnavailable }
    return entry
  }

  /// A listed sidecar, read whole and only if its version held across the read.
  func readFile(_ path: FTPPath, maximum: Int) async throws -> Data {
    let before = try await metadata(path)
    guard before.kind == .file, let size = before.size, size >= 0, before.modify != nil else {
      throw FTPReadError.metadataUnavailable
    }
    guard size <= maximum else { throw FTPReadError.limit }
    let data = try await transfer(
      "RETR " + path.commandArgument, maximum: maximum, expectedLength: Int(size))
    let after = try await metadata(path)
    guard FTPMetadataReply.sameVersion(before, after) else { throw FTPReadError.sourceChanged }
    return data
  }

  /// Deliver exactly `count` bytes from `offset`. The caller ends this session
  /// afterwards: a transfer stopped early leaves nothing worth keeping.
  func stream(
    _ path: FTPPath, offset: Int64, count: Int64, activity: FTPReadActivity,
    deliver: (Data) async throws -> Void
  ) async throws {
    let data = try await openData(
      {
        try await self.command("REST \(offset)")
        try await self.replies.expect(350)
      }, operation: "RETR " + path.commandArgument)
    var remaining = count
    while remaining > 0 {
      activity.waiting()
      let (chunk, ended) = try await data.receive(maximumLength: 256 * 1024)
      activity.idle()
      if !chunk.isEmpty {
        let usable = chunk.count > remaining ? chunk.prefix(Int(remaining)) : chunk
        try await deliver(Data(usable))
        remaining -= Int64(usable.count)
      }
      if ended, remaining > 0 { throw FTPReadError.sourceChanged }
    }
    data.connection.cancel()
    owned.drop(data.connection)
  }

  func quit() async throws {
    try await command("QUIT")
    try await replies.expect(221)
  }
}

/// Times only the wait on the server, so a paused player never looks like a stall.
final class FTPReadActivity: @unchecked Sendable {
  private let lock = NSLock()
  private var deadline: Date?
  private let timeout: TimeInterval
  init(timeout: TimeInterval) {
    self.timeout = timeout
    deadline = Date().addingTimeInterval(timeout)
  }
  func waiting() {
    lock.lock()
    deadline = Date().addingTimeInterval(timeout)
    lock.unlock()
  }
  func idle() {
    lock.lock()
    deadline = nil
    lock.unlock()
  }
  var expired: Bool {
    lock.lock()
    defer { lock.unlock() }
    return deadline.map { $0 < Date() } ?? false
  }
}
