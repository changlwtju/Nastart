import SwiftUI

enum TaskSegment: String, CaseIterable, Identifiable {
    case pending
    case watching
    case history

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .pending: return "tasks.segment.pending"
        case .watching: return "tasks.segment.watching"
        case .history: return "tasks.segment.history"
        }
    }
}

struct TasksView: View {
    @State private var segment: TaskSegment = .pending
    private let tasks = SampleData.tasks

    var body: some View {
        NavigationStack {
            List {
                Picker("tasks.segment.title", selection: $segment) {
                    ForEach(TaskSegment.allCases) { segment in
                        Text(segment.titleKey).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if segment == .pending {
                    Section("tasks.section.pending") {
                        ForEach(tasks) { task in
                            TaskRow(task: task)
                        }
                    }
                } else if segment == .watching {
                    Section("tasks.section.watching") {
                        Label("tasks.watch.certificates", systemImage: "lock.shield")
                        Label("tasks.watch.domains", systemImage: "globe")
                        Label("tasks.watch.agent", systemImage: "antenna.radiowaves.left.and.right")
                    }
                } else {
                    Section {
                        PlaceholderView(titleKey: "tasks.empty.history", systemImage: "archivebox", descriptionKey: "tasks.empty.history.description")
                            .frame(minHeight: 260)
                    }
                }
            }
            .navigationTitle("tab.tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.symbol)
                .font(.headline)
                .foregroundStyle(task.isUrgent ? .orange : .primary)
                .frame(width: 34, height: 34)
                .background(AppTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(task.title))
                    .font(.body.weight(.semibold))
                Text(LocalizedStringKey(task.subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
