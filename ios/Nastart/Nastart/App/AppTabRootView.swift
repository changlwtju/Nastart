import SwiftUI

struct AppTabRootView: View {
    var body: some View {
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
}
