import Foundation
import Network

final class FTPPreludeState: @unchecked Sendable {
  private let lock = NSLock()
  private var failure: Error?
  func fail(_ error: Error) {
    lock.lock()
    if failure == nil { failure = error }
    lock.unlock()
  }
  func error() -> Error? {
    lock.lock()
    defer { lock.unlock() }
    return failure
  }
}
final class FTPStartTLSFramer: NWProtocolFramerImplementation {
  static let label = "Nastart FTPS AUTH TLS Prelude"
  static let definition = NWProtocolFramer.Definition(implementation: FTPStartTLSFramer.self)
  private var stage = 0
  private var buffer = Data()
  private var code: Int?
  private var bytes = 0
  private var lines = 0
  private var total = 0
  required init(framer: NWProtocolFramer.Instance) {}
  func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { .willMarkReady }
  private func fail(_ error: Error, _ framer: NWProtocolFramer.Instance) {
    (framer.options["state"] as? FTPPreludeState)?.fail(error)
    stage = -1
    buffer.removeAll()
    framer.markFailed(error: .posix(.EPROTO))
  }
  func handleInput(framer: NWProtocolFramer.Instance) -> Int {
    guard stage >= 0, stage < 2 else { return 0 }
    while stage < 2 {
      var incoming = Data()
      var ended = false
      let parsed = framer.parseInput(minimumIncompleteLength: 1, maximumLength: 4096) {
        data, complete in
        ended = complete
        guard let data else { return 0 }
        incoming = Data(data)
        return data.count
      }
      guard parsed, !incoming.isEmpty else {
        if ended { fail(FTPReadError.closed, framer) }
        return 1
      }
      total += incoming.count
      guard total <= 32768 else {
        fail(FTPReadError.limit, framer)
        return 0
      }
      buffer.append(incoming)
      while let end = buffer.range(of: Data([13, 10])) {
        let line = buffer.subdata(in: 0..<end.lowerBound)
        buffer.removeSubrange(0..<end.upperBound)
        bytes += line.count + 2
        lines += 1
        guard line.count <= 1024, bytes <= 16384, lines <= 128, !line.contains(0),
          !line.contains(10), !line.contains(13), String(data: line, encoding: .utf8) != nil
        else {
          fail(FTPReadError.limit, framer)
          return 0
        }
        var complete = false
        if code == nil {
          guard line.count >= 4, (49...53).contains(line[0]), (48...57).contains(line[1]),
            (48...57).contains(line[2]), [UInt8(32), 45].contains(line[3])
          else {
            fail(FTPReadError.invalidReply, framer)
            return 0
          }
          code = Int(line[0] - 48) * 100 + Int(line[1] - 48) * 10 + Int(line[2] - 48)
          complete = line[3] == 32
        } else {
          complete = line.starts(with: Array(String(code!).utf8) + [UInt8(32)])
        }
        if complete {
          let expected = stage == 0 ? 220 : 234
          guard code == expected else {
            fail(FTPReadError.unexpected(code!), framer)
            return 0
          }
          guard buffer.isEmpty else {
            fail(FTPReadError.invalidReply, framer)
            return 0
          }
          code = nil
          bytes = 0
          lines = 0
          if stage == 0 {
            stage = 1
            framer.writeOutput(data: Data("AUTH TLS\r\n".utf8))
          } else {
            guard let tls = framer.options["tls"] as? NWProtocolTLS.Options else {
              fail(FTPReadError.invalidInput, framer)
              return 0
            }
            do { try framer.prependApplicationProtocol(options: tls) } catch {
              fail(error, framer)
              return 0
            }
            stage = 2
            framer.passThroughInput()
            framer.passThroughOutput()
            framer.markReady()
            return 0
          }
        }
      }
      guard buffer.count <= 1024 else {
        fail(FTPReadError.limit, framer)
        return 0
      }
    }
    return 0
  }
  func handleOutput(
    framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int,
    isComplete: Bool
  ) {
    guard stage == 2 else {
      fail(FTPReadError.invalidReply, framer)
      return
    }
    do { try framer.writeOutputNoCopy(length: messageLength) } catch { fail(error, framer) }
  }
  func wakeup(framer: NWProtocolFramer.Instance) {}
  func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
  func cleanup(framer: NWProtocolFramer.Instance) { buffer.removeAll() }
}
