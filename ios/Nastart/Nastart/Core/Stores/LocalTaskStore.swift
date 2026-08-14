import Foundation
import UserNotifications

struct PersistedTaskState: Codable {
    let pending: [TaskItem]
    let history: [TaskItem]
}
enum ReminderNotificationScheduler {
    private static func identifier(for task: TaskItem) -> String {
        "nastart.reminder.\(task.id.uuidString.lowercased())"
    }

    static func schedule(_ task: TaskItem, requestsAuthorization: Bool) {
        let center = UNUserNotificationCenter.current()
        let identifier = identifier(for: task)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard !task.isMuted, let reminderDate = task.nextReminderAt, reminderDate > Date() else {
            return
        }

        Task {
            let settings = await center.notificationSettings()
            var isAuthorized = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            if settings.authorizationStatus == .notDetermined, requestsAuthorization {
                isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
            }
            guard isAuthorized else { return }

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
            try? await center.add(request)
        }
    }

    static func cancel(_ task: TaskItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier(for: task)]
        )
    }
}

final class LocalTaskStore {
    static let maxHistoryCount = 500

    private let storageKey = "tasks.localState.v1"

    func load() -> PersistedTaskState? {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let state = try? JSONDecoder().decode(PersistedTaskState.self, from: data)
        else {
            return nil
        }
        return Self.normalizedState(pending: state.pending, history: state.history)
    }

    func save(pending: [TaskItem], history: [TaskItem]) {
        let state = Self.normalizedState(pending: pending, history: history)
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func normalizedState(pending: [TaskItem], history: [TaskItem]) -> PersistedTaskState {
        let normalizedPending = uniqueTasks(pending).filter { $0.completedAt == nil }
        let normalizedHistory = Array(
            uniqueTasks(history)
                .filter { $0.completedAt != nil }
                .prefix(maxHistoryCount)
        )
        return PersistedTaskState(pending: normalizedPending, history: normalizedHistory)
    }

    private static func uniqueTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        var seen = Set<UUID>()
        return tasks.filter { seen.insert($0.id).inserted }
    }
}
