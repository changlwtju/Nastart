import Foundation

enum FTPMetadataReply {
  static func validChild(_ name: String) throws -> Bool {
    !name.isEmpty && name.utf8.count <= 255 && name != "." && name != ".." && !name.contains("/")
      && !name.contains("\\")
      && !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
  }
  static func pwd(_ reply: String) throws -> String {
    guard reply.hasPrefix("257 \""), let first = reply.firstIndex(of: "\"") else {
      throw FTPReadError.invalidReply
    }
    var result = ""
    var cursor = reply.index(after: first)
    var closed = false
    while cursor < reply.endIndex {
      let char = reply[cursor]
      cursor = reply.index(after: cursor)
      if char == "\"" {
        if cursor < reply.endIndex, reply[cursor] == "\"" {
          result.append("\"")
          cursor = reply.index(after: cursor)
        } else {
          closed = true
          break
        }
      } else {
        result.append(char)
      }
    }
    guard closed, result.hasPrefix("/"), result.utf8.count <= 2048, !result.contains("\\"),
      !result.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    else { throw FTPReadError.invalidReply }
    let parts = result.dropFirst().split(separator: "/", omittingEmptySubsequences: false)
    if result != "/" {
      guard
        parts.enumerated().allSatisfy({ index, part in
          part != "." && part != ".." && (!part.isEmpty || index == parts.count - 1)
        })
      else { throw FTPReadError.invalidReply }
    }
    return result
  }
  static func mlst(_ lines: [String], relative: String, absolute: String, name: String) throws
    -> FTPListingEntry
  {
    guard lines.count == 3, lines[0].hasPrefix("250-"), lines[2].hasPrefix("250 "),
      lines[1].hasPrefix(" "), try validChild(name)
    else { throw FTPReadError.invalidReply }
    let row = lines[1].dropFirst()
    guard let separator = row.range(of: "; ") else { throw FTPReadError.invalidReply }
    let path = row[separator.upperBound...]
    guard path.utf8.elementsEqual(relative.utf8) || path.utf8.elementsEqual(absolute.utf8) else {
      throw FTPReadError.sourceChanged
    }
    let parsed = try FTPMLSDListing.parse(Data((String(row[..<separator.upperBound]) + name + "\r\n").utf8))
    guard parsed.entries.count == 1, let entry = parsed.entries.first, entry.kind == .file,
      entry.size != nil, entry.modify != nil
    else { throw FTPReadError.metadataUnavailable }
    return entry
  }
  static func sameVersion(_ a: FTPListingEntry, _ b: FTPListingEntry) -> Bool {
    a.kind == .file && b.kind == .file && a.name.utf8.elementsEqual(b.name.utf8) && a.size != nil
      && a.size == b.size && a.modify != nil && a.modify == b.modify && a.unique == b.unique
  }
}
