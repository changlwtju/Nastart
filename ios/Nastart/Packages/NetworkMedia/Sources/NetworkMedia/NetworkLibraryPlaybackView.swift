#if os(iOS) || os(tvOS)
import SwiftUI

/// A full-screen player can cover its preparation view or enter PiP without
/// ending playback. Release the source on explicit close or final owner loss,
/// rather than on the covered view's transient onDisappear callback.
@MainActor private final class NetworkPlaybackOwner: ObservableObject {
    let preparation = PlaybackPreparationCoordinator<(source: NetworkMediaPlaybackSource, session: WebDAVPlaybackSession?)>()
    var session: WebDAVPlaybackSession?
    func stop() { preparation.close(); session?.stop(); session = nil }
    deinit { session?.stop() }
}

/// iOS hands the host a validated byte reader; the host owns decoder routing.
/// Keep the package bridge for tvOS until that host has a shared reader proxy.
@MainActor struct NetworkLibraryPlaybackView: View {
    let libraryID: UUID
    let expected: RemoteMediaEntry
    var fromBeginning = false
    let destination: (NetworkMediaPlaybackSource, @escaping () -> Void) -> AnyView
    @Environment(\.dismiss) private var dismiss
    @StateObject private var owner = NetworkPlaybackOwner()
    @State private var source: NetworkMediaPlaybackSource?
    @State private var error: String?
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let source { destination(source, close) }
            else {
                VStack(spacing: 24) {
                    if let error { Text(error).multilineTextAlignment(.center) }
                    else { ProgressView("正在准备播放") }
                    Button(error == nil ? "取消" : "返回") { close() }.accessibilityIdentifier("network.player.close")
                }.padding(40).foregroundStyle(.white).tint(.orange)
            }
        }.preferredColorScheme(.dark)
            .task {
                do {
                    guard let prepared = try await owner.preparation.prepare(operation: { checkCurrent in
                        guard let library = try await NetworkLibraryStore.shared.libraries().first(where: { $0.id == libraryID }) else {
                            throw NetworkMediaPlaybackError.staleFile
                        }
                        try checkCurrent()
                        let credential = try NetworkCredentialVault.load(library)
                        let title = MediaCatalog.effectiveFile(expected, library: library).metadata?.title ?? expected.path.name
                        #if os(iOS)
                        return (try NetworkMediaPlaybackSource(library: library, file: expected,
                            credential: credential, title: title), nil)
                        #else
                        let bridge = WebDAVPlaybackSession(reader: try networkMediaReader(library: library, file: expected, credential: credential))
                        owner.session = bridge
                        do {
                            let address = try await bridge.start()
                            return (try NetworkMediaPlaybackSource(library: library, file: expected,
                                playbackURL: address, title: title), bridge)
                        } catch {
                            bridge.stop()
                            if owner.session === bridge { owner.session = nil }
                            throw error
                        }
                        #endif
                    }, discard: { [owner] prepared in
                        prepared.session?.stop()
                        if owner.session === prepared.session { owner.session = nil }
                    }) else { return }
                    var ready = prepared.source
                    ready.startsFromBeginning = fromBeginning
                    source = ready
                } catch {
                    if let error = error as? NetworkMediaPlaybackError { self.error = error.errorDescription }
                    else if let error = error as? FTPReadError { self.error = error.errorDescription }
                    else if let error = error as? SMBReadError { self.error = error.errorDescription }
                    else if case NetworkMediaError.http(401) = error { self.error = (error as? NetworkMediaError)?.errorDescription }
                    else if error is NetworkMediaError { self.error = networkL("无法准备此文件，请检查连接或重新整理媒体库。") }
                    else { self.error = networkL("播放准备未完成，请返回后重试。") }
                }
            }
        #if os(tvOS)
            .onExitCommand { close() }
        #endif
    }
    private func close() { owner.stop(); dismiss() }
}
#endif
