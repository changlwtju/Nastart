import SwiftUI

struct DirectMediaPlayerSetupView: View {
    @State private var address: String
    @State private var playbackRequest: MediaPlaybackRequest?
#if DEBUG
    @AppStorage(GreenfieldPlaybackDebugSettings.useGreenfieldPlayerKey)
    private var usesGreenfieldPlayer = false
    @AppStorage(GreenfieldPlaybackDebugSettings.forceOriginalKSPlayerKey)
    private var forcesGreenfieldOriginalKSPlayer = false
    @State private var greenfieldPlaybackRequest: GreenfieldPlaybackLaunchRequest?
#endif
    @State private var showValidationError = false

    init(suggestedURL: URL?) {
        _address = State(initialValue: suggestedURL?.absoluteString ?? "")
    }

    var body: some View {
        Form {
            Section {
                Text("player.direct.intro")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                TextField("player.url.placeholder", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Button {
                    guard let url = normalizedURL else {
                        showValidationError = true
                        return
                    }
                    let request = MediaPlaybackRequest(url: url, title: url.lastPathComponent)
#if DEBUG
                    if usesGreenfieldPlayer {
                        greenfieldPlaybackRequest = request.greenfieldPlaybackLaunchRequest(
                            playbackModePreference: forcesGreenfieldOriginalKSPlayer
                                ? .original
                                : .automatic
                        )
                    } else {
                        playbackRequest = request
                    }
#else
                    playbackRequest = request
#endif
                } label: {
                    Label("player.play_in_app", systemImage: "play.fill")
                }
#if DEBUG
                Toggle(isOn: $usesGreenfieldPlayer) {
                    Label("Greenfield player", systemImage: "switch.2")
                        .font(.subheadline.weight(.semibold))
                }
                .toggleStyle(.switch)

                if usesGreenfieldPlayer {
                    Toggle(isOn: $forcesGreenfieldOriginalKSPlayer) {
                        Label("Force original KSPlayer", systemImage: "bolt.horizontal")
                            .font(.subheadline.weight(.semibold))
                    }
                    .toggleStyle(.switch)
                }
#endif
            } footer: {
                Text("player.direct.footer")
            }
        }
        .navigationTitle("player.open_stream")
        .navigationBarTitleDisplayMode(.inline)
        .alert("player.url.invalid", isPresented: $showValidationError) {
            Button("action.ok", role: .cancel) {}
        }
        .fullScreenCover(item: $playbackRequest, onDismiss: {
            PlayerOrientationController.setPlayerActive(false)
        }) { request in
            NavigationStack {
                BuiltInMediaPlayerView(request: request)
            }
        }
#if DEBUG
        .fullScreenCover(item: $greenfieldPlaybackRequest) { request in
            NavigationStack {
                GreenfieldVideoPlayerView(request: request)
            }
        }
#endif
    }

    private var normalizedURL: URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            url.host?.isEmpty == false,
            DirectMediaURLPolicy.canAttemptPlayback(url)
        else {
            return nil
        }
        return url
    }
}
