import SwiftUI

enum TaskSegment: String, CaseIterable, Identifiable {
    case watching
    case pending
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
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var segment: TaskSegment = .watching

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

                Section {
                    switch segment {
                    case .pending:
                        if dataStore.tasks.isEmpty {
                            TaskEmptyView(
                                symbol: "checkmark.circle",
                                titleKey: "tasks.empty.pending",
                                descriptionKey: "tasks.empty.pending.description"
                            )
                        } else {
                            ForEach(dataStore.tasks) { task in
                                NavigationLink {
                                    TaskDetailView(task: task)
                                } label: {
                                    TaskRow(task: task)
                                }
                            }
                        }
                    case .watching:
                        NavigationLink {
                            ReminderCreateView(defaultKind: .certificate)
                        } label: {
                            Label("tasks.watch.certificates", systemImage: "lock.shield")
                        }
                        NavigationLink {
                            ReminderCreateView(defaultKind: .domain)
                        } label: {
                            Label("tasks.watch.domains", systemImage: "globe")
                        }
                        NavigationLink {
                            ReminderCreateView(defaultKind: .service)
                        } label: {
                            Label("tasks.watch.agent", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    case .history:
                        TaskEmptyView(
                            symbol: "archivebox",
                            titleKey: "tasks.empty.history",
                            descriptionKey: "tasks.empty.history.description"
                        )
                    }
                } header: {
                    Text(segment.titleKey)
                }
            }
            .listStyle(.insetGrouped)
            .padding(.top, -12)
            .navigationTitle("tab.tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ReminderCreateView(defaultKind: .certificate)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

private struct TaskEmptyView: View {
    let symbol: String
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.secondary)
            Text(titleKey)
                .font(.headline)
            Text(descriptionKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 176)
        .padding(.vertical, 20)
    }
}

enum ReminderKind: String, CaseIterable, Identifiable {
    case certificate
    case domain
    case service
    case subscription

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .certificate: return "reminder.kind.certificate"
        case .domain: return "reminder.kind.domain"
        case .service: return "reminder.kind.service"
        case .subscription: return "reminder.kind.subscription"
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.symbol)
                .font(.subheadline)
                .foregroundStyle(task.isUrgent ? .orange : .primary)
                .frame(width: 34, height: 34)
                .background(AppTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(task.title))
                    .font(.body)
                Text(LocalizedStringKey(task.subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TaskDetailView: View {
    let task: TaskItem
    @State private var isMuted = false
    @State private var actionMessageKey = "tasks.detail.handle_hint"
    @State private var showActionHint = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: task.symbol)
                        .font(.system(size: 42, weight: .regular))
                        .foregroundStyle(task.isUrgent ? .orange : .primary)
                    Text(LocalizedStringKey(task.title))
                        .font(.title2.weight(.bold))
                    Text(LocalizedStringKey(task.subtitle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                Button("tasks.detail.handle") {
                    showAction("tasks.detail.handle_hint")
                }
                Toggle("tasks.detail.mute", isOn: $isMuted)
                Button("tasks.detail.done") {
                    showAction("tasks.detail.done_hint")
                }
            } header: {
                Text("tasks.detail.actions")
            }

            Section {
                LabeledContent("tasks.detail.created") {
                    Text("state.today")
                }
                LabeledContent("tasks.detail.next", value: task.isUrgent ? "19d" : "42d")
            } header: {
                Text("tasks.detail.timeline")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("tasks.detail.title")
        .alert(LocalizedStringKey(actionMessageKey), isPresented: $showActionHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func showAction(_ key: String) {
        actionMessageKey = key
        showActionHint = true
    }
}

private struct ReminderCreateView: View {
    @State private var kind: ReminderKind
    @State private var title = ""
    @State private var target = ""
    @State private var daysBefore = 14
    @State private var enablePush = true
    @State private var showSavedHint = false

    init(defaultKind: ReminderKind) {
        _kind = State(initialValue: defaultKind)
    }

    var body: some View {
        List {
            Section {
                Picker("reminder.kind.title", selection: $kind) {
                    ForEach(ReminderKind.allCases) { kind in
                        Text(kind.titleKey).tag(kind)
                    }
                }
            }

            Section {
                TextField("reminder.title.placeholder", text: $title)
                TextField("reminder.target.placeholder", text: $target)
            } header: {
                Text("reminder.section.basic")
            }

            Section {
                Stepper(value: $daysBefore, in: 1...60) {
                    LabeledContent("reminder.days_before", value: "\(daysBefore)d")
                }
                Toggle("reminder.push", isOn: $enablePush)
            } header: {
                Text("reminder.section.notify")
            }

            Section {
                Button {
                    showSavedHint = true
                } label: {
                    Text("reminder.save")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("reminder.create.title")
        .alert("reminder.saved_hint", isPresented: $showSavedHint) {
            Button("action.ok", role: .cancel) {}
        }
    }
}
