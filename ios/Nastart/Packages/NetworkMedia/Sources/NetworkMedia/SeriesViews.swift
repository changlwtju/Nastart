#if os(iOS) || os(tvOS)
import SwiftUI

@MainActor struct NetworkSeriesPage: View {
    let library: NetworkLibrary
    let series: MediaSeries
    @ObservedObject var model: NetworkLibrariesModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.networkAppearance) private var appearance
    @State private var tmdbMatch: TMDBMatch?
    var body: some View {
        let library = model.libraries.first { $0.id == self.library.id } ?? self.library
        let series = (model.catalogs[library.id] ?? []).compactMap(\.series).first { $0.id == self.series.id }
            ?? MediaSeries(id: self.series.id, title: self.series.title, folder: self.series.folder, files: [])
        NetworkContentPage(title: series.title) {
            NetworkContentSection {
                HStack(alignment: .top, spacing: 20) {
                    if let first = series.files.first(where: { $0.metadata?.artwork != nil }) ?? series.files.first {
                        NetworkLocalPoster(library: library, file: first, model: model, series: series.info, seriesMode: true, tmdb: series.tmdbLookup)
                            .frame(width: 120).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(series.title).font(.title2.weight(.semibold))
                        if let year = series.info?.year ?? series.files.lazy.compactMap({ $0.metadata?.year }).first ?? tmdbMatch?.year { Text(String(year)).foregroundStyle(.secondary) }
                        Text("\(series.seasons.count) 季 · \(series.files.count) 个视频文件").font(NetworkType.caption).foregroundStyle(.secondary)
                        if let plot = MediaDetailSummary.normalized(series.info?.plot) {
                            Text(plot).font(NetworkType.caption).foregroundStyle(.secondary).lineLimit(6)
                        } else if let plot = MediaDetailSummary.normalized(tmdbMatch?.overview) {
                            Text(plot).font(NetworkType.caption).foregroundStyle(.secondary).lineLimit(6)
                        } else if let plot = series.files.lazy.compactMap({ MediaDetailSummary.normalized($0.metadata?.plot) }).first {
                            Text("首集简介：\(plot)").font(NetworkType.caption).foregroundStyle(.secondary).lineLimit(6)
                        }
                        let details = series.files.compactMap { $0.metadata?.details }
                        let localGenres = uniqueValues(details.flatMap(\.genres))
                        let localStudios = uniqueValues(details.flatMap(\.studios))
                        let genres = localGenres.isEmpty ? (tmdbMatch?.genres ?? []) : localGenres
                        let studios = localStudios.isEmpty ? (tmdbMatch?.studios ?? []) : localStudios
                        if !genres.isEmpty { Text(genres.prefix(4).joined(separator: " · ")).font(NetworkType.caption).foregroundStyle(.secondary) }
                        if !studios.isEmpty { Text(studios.prefix(3).joined(separator: " · ")).font(NetworkType.caption).foregroundStyle(.secondary) }
                        if let cast = tmdbMatch?.cast.prefix(5).map(\.name), !cast.isEmpty {
                            Text("主演：\(cast.joined(separator: "、"))").font(NetworkType.caption).foregroundStyle(.secondary)
                        }
                    }
                }.padding(.vertical, 12)
            }
            NetworkContentSection(title: "选择季") {
                if series.files.isEmpty { Text("本剧暂无剧集，可返回媒体库查看其他分类。").foregroundStyle(.secondary) }
                ForEach(series.seasons) { season in
                    NavigationLink {
                        NetworkSeasonPage(library: library, seriesID: series.id, seriesTitle: series.title, season: season, model: model)
                            .environment(\.networkAppearance, appearance)
                    } label: {
                        NetworkActionLabel(title: season.title, symbol: season.number == 0 ? "sparkles.tv" : "rectangle.stack", subtitle: networkL("\(season.files.count) 个视频文件"))
                    }.accessibilityIdentifier("network.season.open")
                }
            }
        }
        .task(id: model.tmdbEnabled ? series.tmdbLookup?.identity : nil) {
            let match = await model.tmdbMatch(series.tmdbLookup)
            guard !Task.isCancelled else { return }
            tmdbMatch = match
        }
    }
}

private func uniqueValues(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
}

@MainActor private struct NetworkSeasonPage: View {
    let library: NetworkLibrary
    let seriesID: String
    let seriesTitle: String
    let season: MediaSeason
    @ObservedObject var model: NetworkLibrariesModel
    @State private var selected: RemoteMediaEntry?
    @Environment(\.networkAppearance) private var appearance
    #if os(tvOS)
    @AppStorage(MediaPosterGridLayout.televisionDensityPreference) private var posterDensity = MediaPosterGridLayout.defaultTelevisionDensity
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    #endif
    var body: some View {
        let library = model.libraries.first { $0.id == self.library.id } ?? self.library
        let currentSeries = (model.catalogs[library.id] ?? []).compactMap(\.series).first { $0.id == seriesID }
        let season = currentSeries?.seasons.first { $0.number == self.season.number } ?? MediaSeason(number: self.season.number, files: [])
        Group {
            #if os(tvOS)
            GeometryReader { geometry in
                let layout = MediaPosterGridLayout.television(viewportWidth: geometry.size.width,
                    density: posterDensity, accessibility: typeSize.isAccessibilitySize)
                ScrollView {
                    VStack(alignment: .leading, spacing: 35) {
                        MediaLibraryHeading(title: "\(seriesTitle) · \(season.title)", subtitle: "")
                        if season.files.isEmpty { Text("本季暂无剧集，可返回查看其他季或分类。").foregroundStyle(.secondary) }
                        MediaPosterGrid(layout: layout) {
                            ForEach(season.files) { file in
                                Button { selected = file } label: {
                                    MediaPosterCard(title: episodeTitle(file), subtitle: episodeSubtitle(file),
                                        aspect: 16.0 / 9.0, accent: appearance.accent) {
                                        NetworkLocalPoster(library: library, file: file, model: model, aspect: 16.0 / 9.0)
                                    }.frame(width: max(1, layout.itemWidth - 20), alignment: .topLeading)
                                }.buttonStyle(MediaPosterFocusStyle(accent: appearance.accent))
                                    .accessibilityIdentifier("network.episode.open")
                            }
                        }.accessibilityIdentifier("network.season.episodeGrid").accessibilityValue("\(layout.columns) 列")
                    }.frame(width: layout.contentWidth, alignment: .leading)
                        .padding(.vertical, 70).frame(maxWidth: .infinity)
                }
            }.modifier(NetworkPageStyle()).navigationTitle("")
                .onExitCommand { dismiss() }
            #else
            NetworkContentPage(title: "\(seriesTitle) · \(season.title)") {
                NetworkContentSection(title: "剧集") {
                    if season.files.isEmpty { Text("本季暂无剧集，可返回查看其他季或分类。").foregroundStyle(.secondary) }
                    ForEach(season.files) { file in
                        Button { selected = file } label: {
                            MediaEpisodeRow(title: episodeTitle(file), subtitle: episodeSubtitle(file), accent: appearance.accent) {
                                NetworkLocalPoster(library: library, file: file, model: model, aspect: 16.0 / 9.0)
                            }.padding(.vertical, 8)
                        }.accessibilityIdentifier("network.episode.open")
                    }
                }
            }
            #endif
        }.navigationDestination(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            if let file = selected {
                NetworkLocalMediaDetail(library: library, file: file, group: nil, model: model)
                    .environment(\.networkAppearance, appearance)
            }
        }
    }
    private func episodeTitle(_ file: RemoteMediaEntry) -> String {
        let metadata = file.metadata ?? MediaFilenameParser.identify(file.path)
        return metadata.title.isEmpty ? file.path.name : metadata.title
    }
    private func episodeSubtitle(_ file: RemoteMediaEntry) -> String {
        let metadata = file.metadata ?? MediaFilenameParser.identify(file.path)
        let number = metadata.episode ?? MediaFilenameParser.identify(file.path).episode
        return number.map { value in metadata.episodeEnd.map { networkL("第 \(value)–\($0) 集") } ?? networkL("第 \(value) 集") } ?? ""
    }
}
#endif
