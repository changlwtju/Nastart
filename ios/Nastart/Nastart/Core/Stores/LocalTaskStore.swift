import Foundation
import UserNotifications

struct PersistedTaskState {
    let pending: [TaskItem]
    let history: [TaskItem]
    let deletedTasks: [DeletedTask]
}

@MainActor
enum ReminderNotificationScheduler {
    private static var schedulingTasks: [String: Task<Void, Never>] = [:]

    private static func identifier(for task: TaskItem) -> String {
        "nastart.reminder.\(task.id.uuidString.lowercased())"
    }

    static func schedule(_ task: TaskItem, requestsAuthorization: Bool) {
        let center = UNUserNotificationCenter.current()
        let identifier = identifier(for: task)
        cancel(task)
        guard !task.isMuted, let reminderDate = task.nextReminderAt, reminderDate > Date() else {
            return
        }

        schedulingTasks[identifier] = Task {
            defer {
                if !Task.isCancelled { schedulingTasks.removeValue(forKey: identifier) }
            }
            let settings = await center.notificationSettings()
            guard !Task.isCancelled else { return }
            var isAuthorized = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            if settings.authorizationStatus == .notDetermined, requestsAuthorization {
                isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
            }
            guard isAuthorized, !Task.isCancelled else { return }

            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = task.subtitle
            content.sound = .default
            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            submit(request, to: center)
        }
    }

    private static func submit(_ request: UNNotificationRequest, to center: UNUserNotificationCenter) {
        // Submit on the same actor as cancellation without suspending before enqueueing.
        center.add(request, withCompletionHandler: nil)
    }

    static func cancel(_ task: TaskItem) {
        let identifier = identifier(for: task)
        schedulingTasks.removeValue(forKey: identifier)?.cancel()
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }
}

final class LocalTaskStore {
    static let maxHistoryCount = 500

    private struct StoredTaskLists: Codable {
        let pending: [TaskItem]
        let history: [TaskItem]
    }

    private let storageKey = "tasks.localState.v1"
    private let deletedTasksKey = "tasks.deleted.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> PersistedTaskState? {
        let decoder = JSONDecoder()
        let lists = defaults.data(forKey: storageKey)
            .flatMap { try? decoder.decode(StoredTaskLists.self, from: $0) }
        let deletedTasks = defaults.data(forKey: deletedTasksKey)
            .flatMap { try? decoder.decode([DeletedTask].self, from: $0) } ?? []
        guard lists != nil || !deletedTasks.isEmpty else { return nil }
        return Self.normalizedState(
            pending: lists?.pending ?? [], history: lists?.history ?? [], deletedTasks: deletedTasks
        )
    }

    func save(pending: [TaskItem], history: [TaskItem], deletedTasks: [DeletedTask]) -> PersistedTaskState {
        let state = Self.normalizedState(pending: pending, history: history, deletedTasks: deletedTasks)
        let encoder = JSONEncoder()
        if let lists = try? encoder.encode(StoredTaskLists(pending: state.pending, history: state.history)),
           let deletions = try? encoder.encode(state.deletedTasks) {
            // A reader can filter an older copy of the lists using the saved deletions.
            defaults.set(deletions, forKey: deletedTasksKey)
            defaults.set(lists, forKey: storageKey)
        }
        return state
    }

    static func normalizedState(
        pending: [TaskItem], history: [TaskItem], deletedTasks: [DeletedTask] = []
    ) -> PersistedTaskState {
        let retainedDeletions = CloudSyncStore.retainedTaskDeletions(deletedTasks)
        let deletedIDs = Set(retainedDeletions.map(\.id))
        let normalizedPending = uniqueTasks(pending).filter { $0.completedAt == nil && !deletedIDs.contains($0.id) }
        let normalizedHistory = Array(
            uniqueTasks(history)
                .filter { $0.completedAt != nil && !deletedIDs.contains($0.id) }
                .prefix(maxHistoryCount)
        )
        return PersistedTaskState(pending: normalizedPending, history: normalizedHistory, deletedTasks: retainedDeletions)
    }

    private static func uniqueTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        var seen = Set<UUID>()
        return tasks.filter { seen.insert($0.id).inserted }
    }
}
