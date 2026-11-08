import Foundation

struct LaunchpadVisibilityStore {
    private let storageKey = "nastart.launchpadServiceVisibility.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> [String: Bool] {
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    func save(_ overrides: [String: Bool]) {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
struct LaunchpadOrderStore {
    private let storageKey = "nastart.launchpadServiceOrder.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> [String: [String]] {
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: [String]].self, from: data)) ?? [:]
    }

    func save(_ order: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(order) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

struct StoredManualLaunchpadService: Codable, Identifiable {
    let id: UUID
    let name: String
    let endpointString: String
    let categoryRawValue: String
    let iconText: String
    let createdAt: Date

    var launchpadService: LaunchpadService? {
        guard
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            name.count <= 80,
            let endpoint = URL(string: endpointString),
            UserConfiguredServiceURLPolicy.allows(endpoint),
            let category = ServiceCategory(rawValue: categoryRawValue)
        else {
            return nil
        }
        return LaunchpadService(
            id: id,
            name: name,
            iconText: iconText,
            category: category,
            status: .online,
            subtitle: endpoint.host ?? endpoint.absoluteString,
            detail: "manual.service.detail",
            isMedia: category == .media,
            cpu: nil,
            memoryText: nil,
            ports: endpoint.port.map { ["\($0)"] } ?? [],
            endpoint: endpoint,
            source: .manual
        )
    }
}

struct ManualLaunchpadServiceStore {
    private let storageKey = "nastart.manualLaunchpadServices.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> [LaunchpadService] {
        loadStoredServices().compactMap(\.launchpadService)
    }

    func add(name: String, endpoint: URL, category: ServiceCategory, iconText: String) -> LaunchpadService {
        let stored = StoredManualLaunchpadService(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            endpointString: endpoint.absoluteString,
            categoryRawValue: category.rawValue,
            iconText: Self.normalizedIconText(iconText, fallbackName: name),
            createdAt: Date()
        )
        var services = loadStoredServices()
        services.append(stored)
        save(services)
        return stored.launchpadService ?? LaunchpadService(
            id: stored.id,
            name: stored.name,
            iconText: stored.iconText,
            category: category,
            status: .online,
            subtitle: endpoint.host ?? endpoint.absoluteString,
            detail: "manual.service.detail",
            isMedia: category == .media,
            cpu: nil,
            memoryText: nil,
            endpoint: endpoint,
            source: .manual
        )
    }

    func delete(id: UUID) {
        save(loadStoredServices().filter { $0.id != id })
    }

    func exportForSync() -> [StoredManualLaunchpadService] {
        loadStoredServices().compactMap { service in
            guard var components = URLComponents(string: service.endpointString) else {
                return nil
            }
            // A manually entered URL may contain Basic Auth credentials or
            // token-bearing query values. They are useful locally, but must
            // never be serialized into the CloudKit snapshot.
            components.user = nil
            components.password = nil
            components.query = nil
            components.fragment = nil
            guard
                let sanitizedURL = components.url,
                UserConfiguredServiceURLPolicy.allows(sanitizedURL)
            else {
                return nil
            }
            return StoredManualLaunchpadService(
                id: service.id,
                name: service.name,
                endpointString: sanitizedURL.absoluteString,
                categoryRawValue: service.categoryRawValue,
                iconText: service.iconText,
                createdAt: service.createdAt
            )
        }
    }

    func replaceFromSync(_ services: [StoredManualLaunchpadService]) {
        let safeServices = services.filter { $0.launchpadService != nil }
        save(safeServices)
    }

    private func loadStoredServices() -> [StoredManualLaunchpadService] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([StoredManualLaunchpadService].self, from: data)) ?? []
    }

    private func save(_ services: [StoredManualLaunchpadService]) {
        guard let data = try? JSONEncoder().encode(services) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func normalizedIconText(_ value: String, fallbackName: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.prefix(3)).uppercased()
        }
        let letters = fallbackName
            .split(separator: " ")
            .compactMap(\.first)
            .map { String($0) }
            .joined()
        if !letters.isEmpty {
            return String(letters.prefix(3)).uppercased()
        }
        return "APP"
    }
}
