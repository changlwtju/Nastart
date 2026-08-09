import SwiftUI

struct AppTabRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSection: AppSection? = .launchpad

    var body: some View {
        if horizontalSizeClass == .regular {
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
