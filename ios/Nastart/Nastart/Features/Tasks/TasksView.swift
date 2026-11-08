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
                .listRowInsets(EdgeInsets())

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
                            ForEach(sortedPendingTasks) { task in
                                NavigationLink {
                                    TaskDetailView(task: task, isHistory: false)
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
                        if dataStore.completedTasks.isEmpty {
                            TaskEmptyView(
                                symbol: "archivebox",
                                titleKey: "tasks.empty.history",
                                descriptionKey: "tasks.empty.history.description"
                            )
                        } else {
                            ForEach(sortedHistoryTasks) { task in
                                NavigationLink {
                                    TaskDetailView(task: task, isHistory: true)
                                } label: {
                                    TaskRow(task: task)
                                }
                            }
                        }
                    }
                } footer: {
                    if segment == .watching {
                        Text("tasks.watch.footer")
                    }
                }.nastartListSection()
            }
            .listStyle(.insetGrouped)
            .padding(.top, -12)
            .nastartReadableWidth()
            .nastartPageTheme()
            .navigationTitle("tab.tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ReminderCreateView(defaultKind: .certificate)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("reminder.create.title"))
                }
            }
        }
    }

    private var sortedPendingTasks: [TaskItem] {
        dataStore.tasks.sorted { lhs, rhs in
            if lhs.requiresAttention != rhs.requiresAttention {
                return lhs.requiresAttention && !rhs.requiresAttention
            }
            return (lhs.nextReminderAt ?? .distantFuture) < (rhs.nextReminderAt ?? .distantFuture)
        }
    }

    private var sortedHistoryTasks: [TaskItem] {
        dataStore.completedTasks.sorted { lhs, rhs in
            (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
        }
    }

}

private struct ReminderWatchRow: View {
    let kind: ReminderKind
    let statusKey: LocalizedStringKey
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbolName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.titleKey)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(statusKey)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .padding(.vertical, 7)
        .padding(.horizontal, 5)
        .nastartCard(cornerRadius: 8)
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
                .foregroundStyle(task.requiresAttention ? .orange : .primary)
                .frame(width: 34, height: 34)
                .nastartSurface()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(task.title))
                    .font(.body)
                Text(LocalizedStringKey(task.subtitle))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if task.isMuted {
                Image(systemName: "bell.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("tasks.detail.mute"))
            }

        }
        .padding(.vertical, 4)
    }
}

private struct TaskDetailView: View {
    let task: TaskItem
    let isHistory: Bool
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var isMuted: Bool

    init(task: TaskItem, isHistory: Bool) {
        self.task = task
        self.isHistory = isHistory
        _isMuted = State(initialValue: task.isMuted)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: task.symbol)
                        .font(.system(size: 42, weight: .regular))
                        .foregroundStyle(task.requiresAttention ? .orange : .primary)
                    Text(LocalizedStringKey(task.title))
                        .font(.title2.weight(.bold))
                    Text(LocalizedStringKey(task.subtitle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }.nastartListSection()

            if !isHistory {
                Section {
                    Toggle("tasks.detail.mute", isOn: $isMuted)
                        .onChange(of: isMuted) { newValue in
                            dataStore.setTask(task, muted: newValue)
                        }
                    Button("tasks.detail.done") {
                        dataStore.completeTask(task)
                        dismiss()
                    }
                } header: {
                    Text("tasks.detail.actions")
                }.nastartListSection()
            }

            Section {
                LabeledContent("tasks.detail.created") {
                    Text(task.createdAt, style: .date)
                }
                if let completedAt = task.completedAt {
                    LabeledContent("tasks.detail.completed") {
                        Text(completedAt, style: .date)
                    }
                } else {
                    if let targetDate = task.targetDate {
                        LabeledContent("tasks.detail.target") {
                            Text(targetDate, style: .date)
                        }
                    }
                    if let nextReminderAt = task.nextReminderAt {
                        LabeledContent("tasks.detail.next") {
                            Text(nextReminderAt, style: .date)
                        }
                    }
                }
            } header: {
                Text("tasks.detail.timeline")
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("tasks.detail.title")
    }
}

struct ReminderCreateView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ReminderKind
    @State private var title = ""
    @State private var target = ""
    @State private var daysBefore = 14
    @State private var targetDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var hasAppliedContextDefaults = false

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
            }.nastartListSection()

            Section {
                TextField("reminder.title.placeholder", text: $title)
                TextField("reminder.target.placeholder", text: $target)
            } header: {
                Text("reminder.section.basic")
            }.nastartListSection()

            Section {
                DatePicker(
                    "reminder.target_date",
                    selection: $targetDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                Stepper(value: $daysBefore, in: 1...60) {
                    LabeledContent(
                        "reminder.days_before",
                        value: String.localizedStringWithFormat(
                            NSLocalizedString("reminder.days_value %lld", comment: ""),
                            daysBefore
                        )
                    )
                }
            } header: {
                Text("reminder.section.notify")
            } footer: {
                if !hasFutureReminder {
                    Text("reminder.date_invalid")
                        .foregroundStyle(.red)
                }
            }.nastartListSection()

            Section {
                Button {
                    dataStore.addTask(
                        TaskItem(
                            id: UUID(),
                            title: normalizedTitle,
                            subtitle: normalizedTarget,
                            symbol: kind.symbolName,
                            isUrgent: false,
                            daysBefore: daysBefore,
                            targetDate: targetDate,
                            kindRawValue: kind.rawValue
                        )
                    )
                    dismiss()
                } label: {
                    Text("reminder.save")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(!canSave)
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("reminder.create.title")
        .onAppear {
            applyContextDefaultsIfNeeded()
        }
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedTarget: String {
        target.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedTitle.isEmpty && !normalizedTarget.isEmpty && hasFutureReminder
    }

    private var hasFutureReminder: Bool {
        guard let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBefore,
            to: targetDate
        ) else {
            return false
        }
        return reminderDate > Date()
    }

    private func applyContextDefaultsIfNeeded() {
        guard !hasAppliedContextDefaults else { return }
        hasAppliedContextDefaults = true

        switch kind {
        case .certificate:
            title = NSLocalizedString("reminder.default.certificate.title", comment: "")
            target = dataStore.device.name
            if let validUntil = dataStore.device.certificate?.validUntil,
               validUntil > Date() {
                targetDate = validUntil
                let daysRemaining = Calendar.current.dateComponents(
                    [.day],
                    from: Date(),
                    to: validUntil
                ).day ?? daysBefore
                daysBefore = min(daysBefore, max(1, daysRemaining / 2))
            }
        case .domain:
            title = NSLocalizedString("reminder.default.domain.title", comment: "")
            target = connectionStore.connectionEndpoints?.primaryDomain?.host
                ?? NSLocalizedString("reminder.default.domain.target", comment: "")
        case .service:
            title = NSLocalizedString("reminder.default.agent.title", comment: "")
            target = connectionStore.agentConnection?.hostIdentity
                ?? dataStore.device.name
            targetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? targetDate
        case .subscription:
            break
        }
    }
}

private extension ReminderKind {
    var symbolName: String {
        switch self {
        case .certificate: return "lock.shield"
        case .domain: return "globe"
        case .service: return "antenna.radiowaves.left.and.right"
        case .subscription: return "creditcard"
        }
    }
}
