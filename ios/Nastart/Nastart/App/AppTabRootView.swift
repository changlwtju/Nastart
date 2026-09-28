import SwiftUI
import UIKit

struct AppTabRootView: View {
    @State private var selectedSection: AppSection? = .launchpad
    @StateObject private var mediaLibraryRouter = MediaLibraryRouter()

    var body: some View {
        Group {
            // A large iPhone becomes regular-width during landscape playback.
            // Replacing its TabView then destroys the selected tab and each
            // NavigationStack, so dismissing the player loses the file detail.
            // Keep the root hierarchy stable; NavigationSplitView handles its
            // own compact-width adaptation on iPad.
            if UIDevice.current.userInterfaceIdiom == .pad {
                NavigationSplitView {
                    List(AppSection.allCases, selection: $selectedSection) { section in
                        Label(LocalizedStringKey(section.titleKey), systemImage: section.symbolName)
                            .tag(section)
                    }
                    .navigationTitle("Nastart")
                    .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
                } detail: {
                    sectionContent(selectedSection ?? .launchpad)
                        .id(selectedSection ?? .launchpad)
                }
                .navigationSplitViewStyle(.balanced)
                .tint(AppTheme.accent)
            } else {
                phoneTabs
            }
        }
        .environmentObject(mediaLibraryRouter)
        .fullScreenCover(item: $mediaLibraryRouter.presentation) { presentation in
            NavigationStack {
                MediaLibraryView(service: presentation.service)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("action.done") {
                                mediaLibraryRouter.presentation = nil
                            }
                        }
                    }
            }
        }
    }

    private var phoneTabs: some View {
        TabView {
            LaunchpadView()
                .tabItem {
                    Label("tab.launchpad", systemImage: "square.grid.2x2")
                }

            DevicesView()
                .tabItem {
                    Label("tab.devices", systemImage: "server.rack")
                }

            TasksView()
                .tabItem {
                    Label("tab.tasks", systemImage: "checklist")
                }

            MineView()
                .tabItem {
                    Label("tab.mine", systemImage: "person")
                }
        }
        .tint(AppTheme.accent)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .launchpad: LaunchpadView()
        case .devices: DevicesView()
        case .tasks: TasksView()
        case .mine: MineView()
        }
    }
}

@MainActor
final class MediaLibraryRouter: ObservableObject {
    @Published var presentation: MediaLibraryPresentation?

    func open(_ service: LaunchpadService) {
        presentation = MediaLibraryPresentation(service: service)
    }
}

struct MediaLibraryPresentation: Identifiable {
    let id = UUID()
    let service: LaunchpadService
}

private enum AppSection: String, CaseIterable, Identifiable {
    case launchpad
    case devices
    case tasks
    case mine

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .launchpad: return "tab.launchpad"
        case .devices: return "tab.devices"
        case .tasks: return "tab.tasks"
        case .mine: return "tab.mine"
        }
    }

    var symbolName: String {
        switch self {
        case .launchpad: return "square.grid.2x2"
        case .devices: return "server.rack"
        case .tasks: return "checklist"
        case .mine: return "person"
        }
    }
}
