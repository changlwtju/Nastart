import SwiftUI

struct DirectMediaPlayerSetupView: View {
    @State private var address: String
    @State private var playbackRequest: MediaPlaybackRequest?
    private let usesGreenfieldPlayer = true
    @State private var greenfieldPlaybackRequest: GreenfieldPlaybackLaunchRequest?
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
            }.nastartListSection()

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
                    if usesGreenfieldPlayer && !request.isAudioOnly {
                        PlayerOrientationController.prepareForPresentation(request.initialOrientationMode)
                        greenfieldPlaybackRequest = request.greenfieldPlaybackLaunchRequest()
                    } else {
                        playbackRequest = request
                    }
                } label: {
                    Label("player.play_in_app", systemImage: "play.fill")
                }
            } footer: {
                Text("player.direct.footer")
            }.nastartListSection()
        }
        .nastartReadableWidth().nastartPageTheme()
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
        .greenfieldPlaybackCover(item: $greenfieldPlaybackRequest)
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
