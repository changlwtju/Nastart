import Foundation

/// A single presentation snapshot for category highlights, search and the grid.
/// Filtering retains whole works and never changes their indexed files.
struct MediaWallSelection: Sendable {
    enum EmptyState: Equatable, Sendable { case none, libraryEmpty, noResults, supplementsHidden }
    let categories: [MediaCategory]
    let activeCategory: MediaCategory?
    let query: String
    let matches: [MediaCatalogItem]
    let visibleItems: [MediaCatalogItem]
    let emptyState: EmptyState

    init(catalog: [MediaCatalogItem], preferredCategory: MediaCategory?, query: String,
         includesSupplements: Bool, fileTitle: (RemoteMediaEntry) -> String) {
        let available = MediaCategory.allCases.filter { kind in catalog.contains { $0.category == kind } }
        let active = preferredCategory.flatMap { available.contains($0) ? $0 : nil } ?? available.first
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = catalog.filter { item in
            item.category == active && (cleaned.isEmpty || item.title.localizedStandardContains(cleaned)
                || item.files.contains { fileTitle($0).localizedStandardContains(cleaned)
                    || $0.path.name.localizedStandardContains(cleaned) })
        }
        let visible = matching.filter { includesSupplements || $0.movie?.kind != .supplement }
        categories = available; activeCategory = active; self.query = cleaned
        matches = matching; visibleItems = visible
        if catalog.isEmpty { emptyState = .libraryEmpty }
        else if matching.isEmpty { emptyState = .noResults }
        else if visible.isEmpty { emptyState = .supplementsHidden }
        else { emptyState = .none }
    }
}
