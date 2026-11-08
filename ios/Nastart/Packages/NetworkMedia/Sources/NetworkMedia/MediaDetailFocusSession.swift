/// One semantic focus session, independent of SwiftUI value-view lifetimes.
public struct MediaDetailFocusSession: Equatable, Sendable {
    public private(set) var map: MediaDetailFocusMap
    public let nativeIDs: Set<String>
    public private(set) var requested: String?
    public private(set) var focused: String?
    public private(set) var owner: String?
    private var lastAction: String?
    private var lastFileChoice: String?
    private var lastPerson: String?
    public init(map: MediaDetailFocusMap, nativeIDs: Set<String> = []) {
        self.map = map; self.nativeIDs = nativeIDs
    }
    public var preferredFocus: String? {
        if let focused, nativeIDs.contains(focused) { return focused }
        if focused == nil, let owner, nativeIDs.contains(owner) { return owner }
        if let requested, map.contains(requested) { return requested }
        return map.entry(lastAction: lastAction, lastFileChoice: lastFileChoice)
    }
    @discardableResult public mutating func request(_ target: String?) -> String? {
        guard let target else { requested = nil; owner = nil; return nil }
        guard map.contains(target) else { return nil }
        owner = target; requested = target
        // Native focus can arrive before its source command is delivered. The
        // destination is already confirmed, so no later onChange will remember it.
        if focused == target { remember(target) }
        return target
    }
    public mutating func recordFocus(_ target: String?) {
        focused = target
        if let target, nativeIDs.contains(target) { owner = target; return }
        guard let target, requested == target else { return }
        remember(target)
    }
    public mutating func move(from source: String, direction: MediaDetailFocusMap.Direction) -> String? {
        remember(source)
        guard let target = map.target(from: source, direction: direction, lastAction: lastAction,
            lastPerson: lastPerson, lastFileChoice: lastFileChoice) else { return nil }
        return request(target)
    }
    public mutating func update(_ updated: MediaDetailFocusMap) -> String? {
        let previous = map
        map = updated
        guard let target = updated.recoveryAfterContentChange(previous: previous, focused: focused,
            requested: requested, lastAction: lastAction, lastFileChoice: lastFileChoice,
            lastPerson: lastPerson, previousOwner: owner) else { return nil }
        return request(target)
    }
    public func canRestore(_ target: String) -> Bool {
        guard requested == target, map.contains(target), !nativeIDs.contains(focused ?? "") else { return false }
        return focused != nil || !nativeIDs.contains(owner ?? "")
    }
    private mutating func remember(_ target: String) {
        guard map.contains(target) else { return }
        owner = target
        if map.actions.contains(target) { lastAction = target }
        if map.fileChoices.contains(target) { lastFileChoice = target }
        if map.people.contains(target) { lastPerson = target }
    }
}
