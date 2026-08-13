import SwiftUI

struct AppTabRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSection: AppSection? = .launchpad
    @State private var showConnectionFlow = false

    var body: some View {
        ZStack(alignment: .top) {
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

            DataOperationFeedbackView(showConnectionFlow: $showConnectionFlow)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .zIndex(10)
        }
        .nastartScreenBackground()
        .sheet(isPresented: $showConnectionFlow) {
            NavigationStack {
                DSMConnectionFlowView {
                    showConnectionFlow = false
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
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
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

private struct DataOperationFeedbackView: View {
    @Binding var showConnectionFlow: Bool
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var visibleEventAt: Date?

    var body: some View {
        if let visibleEventAt,
           visibleEventAt == dataStore.lastRefreshEventAt {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbolName)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                Text(LocalizedStringKey(dataStore.lastRefreshSummaryKey))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                if canRetry {
                    Button {
                        Task {
                            await dataStore.reconnectDSM(using: connectionStore)
                        }
                    } label: {
                        if dataStore.isRefreshing {
                            ProgressView()
                        } else {
                            Text("action.retry")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .disabled(dataStore.isRefreshing)
                    .accessibilityLabel(Text("connect.status.retry"))

                    Button {
                        showConnectionFlow = true
                    } label: {
                        Text("connect.status.edit")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    self.visibleEventAt = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("action.dismiss"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: 520)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .task(id: dataStore.lastRefreshEventAt) {
            guard let eventAt = dataStore.lastRefreshEventAt else { return }
            visibleEventAt = eventAt
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, visibleEventAt == eventAt else { return }
            visibleEventAt = nil
        }
    }

    private var canRetry: Bool {
        [
            "data.refresh.restore_failed",
            "data.refresh.connection_fluctuation",
            "data.refresh.unreachable",
            "data.refresh.disconnected"
        ].contains(dataStore.lastRefreshSummaryKey)
    }

    private var isError: Bool {
        ["data.refresh.restore_failed", "data.refresh.unreachable"].contains(
            dataStore.lastRefreshSummaryKey
        )
    }

    private var symbolName: String {
        isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var tint: Color {
        isError ? .orange : .green
    }
}
