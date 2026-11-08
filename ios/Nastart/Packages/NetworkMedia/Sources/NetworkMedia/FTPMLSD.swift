import Foundation

enum FTPListingError: Error { case invalidListing, unsupportedEntry, ambiguousListing, limit }
struct FTPListingEntry: Codable, Equatable, Sendable {
  enum Kind: String, Codable, Sendable { case file, directory }
  let name: String
  let kind: Kind
  let size: Int64?
  let modify: String?
  let unique: String?
}
struct FTPMLSDListing: Codable, Equatable, Sendable {
  let entries: [FTPListingEntry]
  let skippedSpecialDirectories: Int
  /// The defaults bound a single small metadata lookup. A library scan passes
  /// `.library`: real media folders are larger, and a link or special entry there
  /// is skipped rather than followed, so it cannot fail the whole folder.
  struct Limits: Sendable {
    let bytes: Int, entries: Int, skipsUnknownTypes: Bool
    static let metadata = Limits(bytes: 32768, entries: 256, skipsUnknownTypes: false)
    static let library = Limits(bytes: 8 * 1024 * 1024, entries: 50_000, skipsUnknownTypes: true)
  }
  static func parse(_ data: Data, limits: Limits = .metadata) throws -> FTPMLSDListing {
    guard data.count <= limits.bytes else { throw FTPListingError.limit }
    if data.isEmpty { return FTPMLSDListing(entries: [], skippedSpecialDirectories: 0) }
    guard data.suffix(2) == Data([13, 10]) else { throw FTPListingError.invalidListing }
    let rows = rows(of: data)
    guard rows.count <= limits.entries + 16 else { throw FTPListingError.limit }
    var entries: [FTPListingEntry] = []
    var names = Set<Data>()
    var skipped = 0
    func parseRow(_ row: Data) throws {
      guard !row.contains(0), let line = String(data: row, encoding: .utf8) else {
        throw FTPListingError.invalidListing
      }
      guard line.utf8.count <= 1024 else { throw FTPListingError.limit }
      guard !line.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
        let separator = line.range(of: "; ")
      else { throw FTPListingError.invalidListing }
      let prefix = line[..<line.index(after: separator.lowerBound)]
      let name = String(line[separator.upperBound...])
      let fields = prefix.dropLast().split(separator: ";", omittingEmptySubsequences: false)
      guard !fields.isEmpty, fields.count <= 32 else { throw FTPListingError.limit }
      var facts: [String: String] = [:]
      for field in fields {
        guard let equal = field.firstIndex(of: "=") else { throw FTPListingError.invalidListing }
        let rawKey = String(field[..<equal])
        let key = rawKey.lowercased()
        let value = String(field[field.index(after: equal)...])
        guard !rawKey.isEmpty, rawKey.utf8.count <= 64,
          rawKey.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45
              || $0 == 46
          }), !value.isEmpty, value.utf8.count <= 512,
          value.utf8.allSatisfy({ (32...126).contains($0) })
        else { throw FTPListingError.invalidListing }
        guard facts[key] == nil else { throw FTPListingError.ambiguousListing }
        facts[key] = value
      }
      guard let type = facts["type"]?.lowercased() else { throw FTPListingError.unsupportedEntry }
      if type == "cdir" || type == "pdir" {
        skipped += 1
        guard skipped <= 16 else { throw FTPListingError.limit }
        return
      }
      let kind: FTPListingEntry.Kind
      if type == "file" {
        kind = .file
      } else if type == "dir" {
        kind = .directory
      } else if limits.skipsUnknownTypes {
        return
      } else {
        throw FTPListingError.unsupportedEntry
      }
      guard !name.isEmpty, name.utf8.count <= 255, name != ".", name != "..", !name.contains("/"),
        !name.contains("\\")
      else { throw FTPListingError.invalidListing }
      guard names.insert(Data(name.utf8)).inserted else { throw FTPListingError.ambiguousListing }
      var size: Int64?
      if let raw = facts["size"] {
        guard raw.utf8.allSatisfy({ (48...57).contains($0) }), raw.utf8.count <= 19,
          let value = Int64(raw)
        else { throw FTPListingError.invalidListing }
        size = value
      }
      if let modify = facts["modify"] { try validateTime(modify) }
      entries.append(
        FTPListingEntry(
          name: name, kind: kind, size: size, modify: facts["modify"], unique: facts["unique"]))
      guard entries.count <= limits.entries else { throw FTPListingError.limit }
    }
    for row in rows {
      do {
        try parseRow(row)
      } catch FTPListingError.limit {
        throw FTPListingError.limit
      } catch where limits.skipsUnknownTypes {
        // One name the library cannot represent must not hide the rest of the folder.
        continue
      }
    }
    return FTPMLSDListing(entries: entries, skippedSpecialDirectories: skipped)
  }
  private static func rows(of data: Data) -> [Data] {
    var rows: [Data] = []
    var start = data.startIndex
    while let end = data[start...].range(of: Data([13, 10])) {
      rows.append(data[start..<end.lowerBound])
      start = end.upperBound
    }
    return rows
  }
  private static func validateTime(_ raw: String) throws {
    let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 1 || parts.count == 2, parts[0].utf8.count == 14,
      parts[0].utf8.allSatisfy({ (48...57).contains($0) })
    else { throw FTPListingError.invalidListing }
    if parts.count == 2 {
      guard (1...9).contains(parts[1].utf8.count),
        parts[1].utf8.allSatisfy({ (48...57).contains($0) })
      else { throw FTPListingError.invalidListing }
    }
    let numbers = Array(parts[0].utf8)
    func number(_ start: Int, _ count: Int) -> Int {
      numbers[start..<start + count].reduce(0) { $0 * 10 + Int($1 - 48) }
    }
    let components = DateComponents(
      year: number(0, 4), month: number(4, 2), day: number(6, 2), hour: number(8, 2),
      minute: number(10, 2), second: number(12, 2))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    guard (1...9999).contains(components.year!), let date = calendar.date(from: components),
      calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        == components
    else { throw FTPListingError.invalidListing }
  }
}
