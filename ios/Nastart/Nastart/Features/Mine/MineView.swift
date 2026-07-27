import SwiftUI

struct MineView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text("N")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 54, height: 54)
                            .background(AppTheme.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("mine.profile.name")
                                .font(.headline)
                            Text("mine.profile.subtitle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("mine.plus.title")
                            .font(.headline.weight(.semibold))
                        Text("mine.plus.subtitle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("mine.plus.action") {}
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    NavigationLink {
                        PlaceholderView(titleKey: "mine.launchpad.title", systemImage: "square.grid.2x2", descriptionKey: "mine.launchpad.description")
                    } label: {
                        Label("mine.launchpad.title", systemImage: "square.grid.2x2")
                    }
                    NavigationLink {
                        PlaceholderView(titleKey: "mine.preferences.title", systemImage: "slider.horizontal.3", descriptionKey: "mine.preferences.description")
                    } label: {
                        Label("mine.preferences.title", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink {
                        PlaceholderView(titleKey: "mine.data.title", systemImage: "lock.shield", descriptionKey: "mine.data.description")
                    } label: {
                        Label("mine.data.title", systemImage: "lock.shield")
                    }
                    NavigationLink {
                        PlaceholderView(titleKey: "mine.about.title", systemImage: "questionmark.circle", descriptionKey: "mine.about.description")
                    } label: {
                        Label("mine.about.title", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("tab.mine")
        }
    }
}
