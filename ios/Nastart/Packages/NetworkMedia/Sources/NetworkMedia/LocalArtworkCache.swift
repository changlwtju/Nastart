import Foundation
import CryptoKit
#if canImport(ImageIO)
import ImageIO
#endif

enum LocalArtworkDecoder {
    static func validate(_ data: Data) throws {
        guard !data.isEmpty, data.count <= LocalArtworkReference.maximumBytes else { throw NetworkMediaError.invalidArtwork }
        #if canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source) as String?, ["public.jpeg", "public.png"].contains(type),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              (1...8192).contains(width.intValue), (1...8192).contains(height.intValue),
              width.intValue * height.intValue <= 32_000_000,
              CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 768,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) != nil else { throw NetworkMediaError.invalidArtwork }
        #else
        throw NetworkMediaError.invalidArtwork
        #endif
    }
}

/// Rebuildable, app-private images. Only visible cards request images; two
/// transfers may run at once, and cancelling the card cancels its own request.
actor LocalArtworkCache {
    static let shared = LocalArtworkCache()
    private let directory: URL
    private let maximumBytes: Int
    private var active = 0
    private init() {
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Nastart", isDirectory: true)
            .appendingPathComponent("NetworkMediaArtwork", isDirectory: true)
        maximumBytes = 64 * 1024 * 1024
    }
    init(directory: URL, maximumBytes: Int = 64 * 1024 * 1024) {
        self.directory = directory; self.maximumBytes = max(1, maximumBytes)
    }
    static func key(library: NetworkLibrary, reference: LocalArtworkReference) throws -> String {
        struct Identity: Encodable {
            let address: String; let account: String?; let root: DAVPath; let reference: LocalArtworkReference
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(Identity(address: library.address, account: library.fileStationAccount, root: library.root, reference: reference))
        return library.id.uuidString + "-" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    func data(library: NetworkLibrary, file: RemoteMediaEntry, source: any ReadOnlyArtworkSource) async throws -> Data {
        guard let reference = file.metadata?.artwork, reference.isValid(root: library.root, video: file.path) else {
            throw NetworkMediaError.invalidArtwork
        }
        return try await data(library: library, reference: reference, source: source)
    }
    func seriesData(library: NetworkLibrary, info: LocalSeriesMetadata, source: any ReadOnlyArtworkSource) async throws -> Data {
        guard let reference = info.artwork, info.folder.isWithin(library.root), reference.path.parent == info.folder,
              reference.isValid(root: library.root) else { throw NetworkMediaError.invalidArtwork }
        return try await data(library: library, reference: reference, source: source)
    }
    func backdropData(library: NetworkLibrary, file: RemoteMediaEntry, reference: LocalArtworkReference,
                      source: any ReadOnlyArtworkSource) async throws -> Data {
        guard reference.isValid(root: library.root, video: file.path) else { throw NetworkMediaError.invalidArtwork }
        return try await data(library: library, reference: reference, source: source)
    }
    private func data(library: NetworkLibrary, reference: LocalArtworkReference, source: any ReadOnlyArtworkSource) async throws -> Data {
        try Task.checkCancellation()
        let cached = directory.appendingPathComponent(try Self.key(library: library, reference: reference))
        if reference.hasVersionHint, let size = try? cached.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size <= LocalArtworkReference.maximumBytes, let data = try? Data(contentsOf: cached),
           reference.size.map({ $0 == Int64(data.count) }) ?? true,
           (try? LocalArtworkDecoder.validate(data)) != nil {
            try Task.checkCancellation()
            return data
        }
        while active >= 2 { try await Task.sleep(nanoseconds: 50_000_000) }
        try Task.checkCancellation(); active += 1
        defer { active -= 1 }
        let data = try await source.readArtwork(reference, root: library.root)
        try Task.checkCancellation(); try LocalArtworkDecoder.validate(data)
        guard reference.size.map({ $0 == Int64(data.count) }) ?? true else { throw NetworkMediaError.invalidArtwork }
        if reference.hasVersionHint {
            // A cache write failure must not hide an image already read safely.
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: cached, options: .atomic)
                trim()
            } catch { }
        }
        return data
    }
    func remove(_ id: UUID) {
        #if canImport(CoreGraphics)
        DecodedArtworkCache.shared.removeAll()
        #endif
        for file in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        where file.lastPathComponent.hasPrefix(id.uuidString + "-") {
            try? FileManager.default.removeItem(at: file)
        }
    }
    private func trim() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))) ?? [])
            .compactMap { url -> (URL, Int, Date)? in
                guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { return nil }
                return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
            }.sorted { $0.2 < $1.2 }
        var bytes = files.reduce(0) { $0 + $1.1 }, count = files.count
        for (url, size, _) in files where bytes > maximumBytes || count > 300 {
            if (try? FileManager.default.removeItem(at: url)) != nil { bytes -= size; count -= 1 }
        }
    }
}
