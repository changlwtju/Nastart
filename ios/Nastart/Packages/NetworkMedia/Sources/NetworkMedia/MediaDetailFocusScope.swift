#if os(iOS) || os(tvOS)
import SwiftUI

/// Live controller bindings; no value-view snapshot owns the navigation state.
@MainActor struct MediaDetailFocusContext {
    let focus: FocusState<String?>.Binding
    let requested: Binding<String?>
    let move: (String, MediaDetailFocusMap.Direction) -> Void
    let diagnostic: String
    let canRestore: (String) -> Bool
    var observe: ((String, String?, String?) -> Void)? = nil
    func restore(_ id: String) {
        observe?("target.restore.check", id, focus.wrappedValue)
        guard canRestore(id) else { observe?("target.restore.skip", id, focus.wrappedValue); return }
        DispatchQueue.main.async {
            guard canRestore(id) else { observe?("target.restore.expired", id, focus.wrappedValue); return }
            observe?("target.restore.commit", id, focus.wrappedValue)
            focus.wrappedValue = id
        }
    }
}

/// A nil context leaves mobile interactions and unbound native controls alone.
struct MediaDetailFocusTarget: ViewModifier {
    let context: MediaDetailFocusContext?
    let id: String
    var bindsFocus = true
    @ViewBuilder func body(content: Content) -> some View {
        #if os(tvOS)
        if let context {
            bound(content, context).id(id)
                .onAppear { context.restore(id) }
                .onMoveCommand { direction in
                    context.observe?("move.received.\(direction)", id, context.focus.wrappedValue)
                    // tvOS may move native focus before delivering this source's
                    // command. The attached control identifies the source; an
                    // already-updated binding must not discard its semantic move.
                    switch direction {
                    case .up: context.move(id, .up)
                    case .down: context.move(id, .down)
                    case .left: context.move(id, .left)
                    case .right: context.move(id, .right)
                    default: break
                    }
                }
        } else { content }
        #else
        content
        #endif
    }
    #if os(tvOS)
    @ViewBuilder private func bound(_ content: Content, _ context: MediaDetailFocusContext) -> some View {
        if bindsFocus { content.focused(context.focus, equals: id) }
        else { content }
    }
    #endif
}

struct MediaDetailFocusedPeople<Content: View>: View {
    let context: MediaDetailFocusContext?
    let ids: [String]
    @ViewBuilder let content: () -> Content
    var body: some View {
        #if os(tvOS)
        ScrollViewReader { horizontal in
            if let context {
                MediaDetailPeopleScroller(content: content)
                    .defaultFocus(context.focus, ids.contains(context.requested.wrappedValue ?? "")
                        ? context.requested.wrappedValue : ids.first, priority: .userInitiated)
                    .onChange(of: context.requested.wrappedValue) { target in
                        guard let target, ids.contains(target) else { return }
                        horizontal.scrollTo(target)
                        context.restore(target)
                    }
                    .onChange(of: ids) { updatedIDs in
                        guard let target = context.requested.wrappedValue, updatedIDs.contains(target) else { return }
                        horizontal.scrollTo(target)
                        context.restore(target)
                    }
            } else { MediaDetailPeopleScroller(content: content) }
        }.id("media.detail.cast")
        #else
        MediaDetailPeopleScroller(content: content)
        #endif
    }
}

#if os(tvOS)
/// The reference survives SwiftUI value-view callbacks; all decisions use one
/// independently tested session rather than captured copies of view fields.
@MainActor private final class MediaDetailFocusController: ObservableObject {
    @Published private(set) var session: MediaDetailFocusSession
    @Published private(set) var diagnostic = ""
    private(set) var revision = UUID()
    #if DEBUG
    private let diagnosticID = UUID().uuidString
    private let diagnosticsEnabled: Bool
    #endif
    init(map: MediaDetailFocusMap, nativeIDs: Set<String>, diagnosticsEnabled: Bool) {
        session = MediaDetailFocusSession(map: map, nativeIDs: nativeIDs)
        #if DEBUG
        self.diagnosticsEnabled = diagnosticsEnabled
        #endif
        observe("controller.init")
    }
    func observe(_ event: String, target: String? = nil, binding: @autoclosure () -> String? = nil, render: String? = nil) {
        #if DEBUG
        guard diagnosticsEnabled else { return }
        MediaDetailFocusDiagnostics.record(event, controller: diagnosticID, render: render, revision: revision.uuidString,
            session: session, target: target, binding: binding())
        #endif
    }
    func diagnosticRender() -> String? {
        #if DEBUG
        return diagnosticsEnabled ? UUID().uuidString : nil
        #else
        return nil
        #endif
    }
    func observer(render: String?) -> ((String, String?, String?) -> Void)? {
        #if DEBUG
        guard diagnosticsEnabled else { return nil }
        return { self.observe($0, target: $1, binding: $2, render: render) }
        #else
        return nil
        #endif
    }
    func request(_ target: String?) -> String? {
        observe("request.before", target: target)
        let result = session.request(target)
        observe("request.after", target: result)
        return result
    }
    func move(_ source: String, _ direction: MediaDetailFocusMap.Direction) -> String? {
        observe("session.move.before.\(direction)", target: source)
        let result = session.move(from: source, direction: direction)
        observe("session.move.after.\(direction)", target: result)
        return result
    }
    func recordFocus(_ target: String?) {
        observe("focus.changed.before", target: target)
        session.recordFocus(target)
        observe("focus.changed.after", target: target)
    }
    func update(_ map: MediaDetailFocusMap) -> String? {
        observe("map.changed.before")
        let before = session
        revision = UUID()
        let target = session.update(map)
        #if DEBUG
        diagnostic = "oldFiles=\(before.map.fileChoices.count);newFiles=\(map.fileChoices.count);ownerFile=\(before.owner.map { before.map.fileChoices.contains($0) } ?? false);targetFile=\(target.map { map.fileChoices.contains($0) } ?? false)"
        #endif
        observe("map.changed.after", target: target)
        return target
    }
}

/// Shared by the source-backed network page and the client-free UI fixture.
@MainActor struct MediaDetailFocusScope<Content: View>: View {
    let map: MediaDetailFocusMap
    @ViewBuilder let content: (MediaDetailFocusContext) -> Content
    @StateObject private var controller: MediaDetailFocusController
    @FocusState private var focused: String?
    init(map: MediaDetailFocusMap, nativeIDs: Set<String> = [], diagnosticsEnabled: Bool = false,
         @ViewBuilder content: @escaping (MediaDetailFocusContext) -> Content) {
        self.map = map; self.content = content
        _controller = StateObject(wrappedValue: MediaDetailFocusController(map: map, nativeIDs: nativeIDs, diagnosticsEnabled: diagnosticsEnabled))
    }
    var body: some View {
        ScrollViewReader { vertical in
            let live = controller
            let binding = $focused
            let expected = live.revision
            let render = live.diagnosticRender()
            let _ = live.observe("scope.body", binding: binding.wrappedValue, render: render)
            let context = MediaDetailFocusContext(focus: binding,
                requested: Binding(get: { live.session.requested }, set: { _ = live.request($0) }),
                move: { source, direction in
                    live.observe("context.move.\(direction)", target: source, binding: binding.wrappedValue, render: render)
                    if let target = live.move(source, direction) { binding.wrappedValue = target }
                }, diagnostic: live.diagnostic,
                canRestore: { live.revision == expected && live.session.canRestore($0)
                    && !live.session.nativeIDs.contains(binding.wrappedValue ?? "") },
                observe: live.observer(render: render))
            content(context)
                .defaultFocus(binding, live.session.preferredFocus, priority: .userInitiated)
                .onAppear {
                    live.observe("scope.appear", binding: binding.wrappedValue, render: render)
                    guard live.session.requested == nil,
                          let target = live.request(live.session.preferredFocus) else { return }
                    binding.wrappedValue = target
                }
                .onDisappear { live.observe("scope.disappear", binding: binding.wrappedValue, render: render) }
                .onChange(of: live.session.requested) { target in
                    live.observe("request.observed", target: target, binding: binding.wrappedValue, render: render)
                    guard let target, live.session.map.contains(target) else { return }
                    vertical.scrollTo(live.session.map.people.contains(target) ? "media.detail.cast" : target)
                    restore(target, controller: live, binding: binding)
                }
                .onChange(of: focused) { target in live.recordFocus(target) }
                .onChange(of: map) { updated in
                    live.observe("map.observed", binding: binding.wrappedValue, render: render)
                    guard let target = live.update(updated) else { return }
                    vertical.scrollTo(live.session.map.people.contains(target) ? "media.detail.cast" : target)
                    binding.wrappedValue = target
                    restore(target, controller: live, binding: binding)
                }
        }
    }
    private func restore(_ target: String, controller: MediaDetailFocusController,
                         binding: FocusState<String?>.Binding) {
        let revision = controller.revision
        controller.observe("scope.restore.queued", target: target, binding: binding.wrappedValue)
        DispatchQueue.main.async {
            guard controller.revision == revision, controller.session.canRestore(target),
                  !controller.session.nativeIDs.contains(binding.wrappedValue ?? "") else {
                controller.observe("scope.restore.expired", target: target, binding: binding.wrappedValue); return
            }
            controller.observe("scope.restore.commit", target: target, binding: binding.wrappedValue)
            binding.wrappedValue = target
        }
    }
}
#endif
#endif
