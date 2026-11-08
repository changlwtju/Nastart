/// Semantic detail regions. Only targets that exist in the current page are returned.
public struct MediaDetailFocusMap: Equatable, Sendable {
    public enum Direction: Equatable, Sendable { case up, down, left, right }
    public let actions: [String]
    public let fileChoices: [String]
    public let people: [String]
    public let related: [String]
    public let relatedRetry: String?
    public let files: String?
    public init(actions: [String], people: [String], related: [String], relatedRetry: String?, files: String?, fileChoices: [String] = []) {
        self.actions = actions; self.people = people; self.related = related
        self.relatedRetry = relatedRetry; self.files = files; self.fileChoices = fileChoices
    }
    public func target(from source: String, direction: Direction, lastAction: String? = nil,
                       lastPerson: String? = nil, lastRelated: String? = nil, lastFileChoice: String? = nil) -> String? {
        let action = remembered(lastAction, in: actions) ?? actions.first
        let person = remembered(lastPerson, in: people) ?? people.first
        let choice = remembered(lastFileChoice, in: fileChoices) ?? fileChoices.last
        if let index = actions.firstIndex(of: source) {
            switch direction {
            case .down: return fileChoices.first ?? people.first ?? related.first ?? relatedRetry ?? files
            case .left: return actions[max(0, index - 1)]
            case .right: return actions[min(actions.count - 1, index + 1)]
            case .up: return nil
            }
        }
        if let index = fileChoices.firstIndex(of: source) {
            switch direction {
            case .up: return index > 0 ? fileChoices[index - 1] : action
            case .down: return index + 1 < fileChoices.count ? fileChoices[index + 1] : people.first ?? related.first ?? relatedRetry ?? files
            default: return nil
            }
        }
        if let index = people.firstIndex(of: source) {
            switch direction {
            case .up: return choice ?? action
            case .down: return related.first ?? relatedRetry ?? files
            case .left: return people[max(0, index - 1)]
            case .right: return people[min(people.count - 1, index + 1)]
            }
        }
        if let index = related.firstIndex(of: source) {
            switch direction {
            case .up: return person ?? choice ?? action
            case .down: return relatedRetry ?? files
            case .left: return related[max(0, index - 1)]
            case .right: return related[min(related.count - 1, index + 1)]
            }
        }
        if source == relatedRetry {
            switch direction {
            case .up: return remembered(lastRelated, in: related) ?? related.first ?? person ?? choice ?? action
            case .down: return files
            default: return nil
            }
        }
        if source == files, direction == .up { return relatedRetry ?? related.first ?? person ?? choice ?? action }
        return nil
    }
    public func contains(_ target: String) -> Bool {
        actions.contains(target) || fileChoices.contains(target) || people.contains(target)
            || related.contains(target) || target == relatedRetry || target == files
    }
    public func entry(lastAction: String? = nil, lastFileChoice: String? = nil) -> String? {
        preferredAction(lastAction) ?? remembered(lastFileChoice, in: fileChoices) ?? fileChoices.first
            ?? people.first ?? related.first ?? relatedRetry ?? files
    }
    /// Dynamic metadata may replace people or change which file choices are playable.
    /// Repair only the removed owner, never a different live/native control.
    public func recoveryAfterContentChange(previous: Self, focused: String?, requested: String?,
        lastAction: String? = nil, lastFileChoice: String? = nil, lastPerson: String? = nil,
        previousOwner: String? = nil) -> String? {
        // A native auxiliary control can take ownership while an update is pending.
        if let focused, !previous.contains(focused), !contains(focused) { return nil }
        guard let source = previousOwner ?? focused ?? requested, previous.contains(source) else { return nil }
        // A reordered lazy row may briefly have no native focus while its
        // still-valid requested owner is being rebuilt at a different index.
        if contains(source) { return focused == source ? nil : source }
        if previous.fileChoices.contains(source), !fileChoices.isEmpty {
            return remembered(lastFileChoice, in: fileChoices) ?? fileChoices.first
        }
        if previous.people.contains(source), !people.isEmpty {
            return remembered(lastPerson, in: people) ?? people.first
        }
        return entry(lastAction: lastAction, lastFileChoice: lastFileChoice)
    }
    /// Default focus must never retain a button removed by refreshed metadata.
    public func preferredAction(_ lastAction: String? = nil) -> String? {
        remembered(lastAction, in: actions) ?? actions.first
    }
    /// Repair only a removed action that still owns focus (or its pending request).
    /// A metadata update must not pull focus away from another live region.
    public func recoveryAfterActionChange(previousActions: [String], focused: String?,
                                          requested: String?, lastAction: String? = nil) -> String? {
        guard let source = focused ?? requested,
              previousActions.contains(source), !actions.contains(source) else { return nil }
        return preferredAction(lastAction)
    }
    public func fallbackAfterRetry(lastAction: String? = nil, lastPerson: String? = nil,
                                   lastRelated: String? = nil, lastFileChoice: String? = nil) -> String? {
        remembered(lastRelated, in: related) ?? related.first ?? files
            ?? remembered(lastPerson, in: people) ?? people.first
            ?? remembered(lastFileChoice, in: fileChoices) ?? fileChoices.first
            ?? remembered(lastAction, in: actions) ?? actions.first
    }
    /// Artwork IDs are transport details, not the identity of a displayed person.
    /// Occurrence disambiguates identical name/role pairs; lengths avoid delimiter collisions.
    public static func personIDs(for people: [MediaCredit]) -> [String] {
        var occurrences: [String: Int] = [:]
        return people.map { person in
            let key = "\(person.name.utf8.count):" + person.name + "\(person.role.utf8.count):" + person.role
            let occurrence = occurrences[key, default: 0]
            occurrences[key] = occurrence + 1
            return "media.detail.person." + key + "|\(occurrence)"
        }
    }
    private func remembered(_ value: String?, in items: [String]) -> String? {
        value.flatMap { items.contains($0) ? $0 : nil }
    }
}
