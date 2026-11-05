import AppKit
import SwiftUI
import Combine

private final class StickyNotePanel: NSPanel {
    var noteID: UUID?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Own once for the app lifetime. Restoration never activates Nino or moves keyboard focus.
@MainActor final class StickyNoteWindows: NSObject, NSWindowDelegate {
    private let store: StickyNotesStore
    private var panels: [UUID: StickyNotePanel] = [:]
    private var subscriptions: Set<AnyCancellable> = []
    private var enabled = false
    private var adjusting: Set<UUID> = []
    var projects: [StickyNoteProject] = [] {
        didSet {
            for (id, panel) in panels {
                (panel.contentView as? NSHostingView<StickyNoteEditor>)?.rootView = StickyNoteEditor(store: store, id: id, projects: projects)
            }
        }
    }

    init(store: StickyNotesStore) {
        self.store = store
        super.init()
        store.$notes.receive(on: RunLoop.main).sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.flush() }.store(in: &subscriptions)
    }

    func restoreVisibleNotes() { enabled = true; reconcile() }

    func show(_ id: UUID, activate: Bool = true) {
        guard store.note(id)?.trashedAt == nil, store.note(id) != nil else { return }
        enabled = true
        store.setVisible(id, true)
        reconcile()
        guard let panel = panels[id] else { return }
        if activate { NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil) }
        else { panel.orderFrontRegardless() }
    }

    func hideAll() { store.hideAll(); reconcile(); store.flush() }
    func flush() { store.flush() }

    private var screens: [StickyNoteFrame] {
        NSScreen.screens.map { let rect = $0.visibleFrame; return .init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height) }
    }
    private func defaultFrame(_ index: Int) -> StickyNoteFrame {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let offset = Double(index % 7) * 26
        return StickyNoteFrame(x: screen.maxX - 380 - offset, y: screen.maxY - 420 - offset, width: 340, height: 360).clamped(to: screens)
    }
    private func reconcile() {
        guard enabled else { return }
        let visible = store.notes.filter { $0.visible && $0.trashedAt == nil }
        let ids = Set(visible.map(\.id))
        for id in Array(panels.keys) where !ids.contains(id) {
            let panel = panels.removeValue(forKey: id)
            panel?.delegate = nil; panel?.orderOut(nil); panel?.close()
        }
        // Copy is intentional: saving a clamped geometry publishes a new store value.
        for (index, note) in visible.enumerated() {
            let panel: StickyNotePanel
            let isNew = panels[note.id] == nil
            if let existing = panels[note.id] { panel = existing }
            else {
                panel = StickyNotePanel(contentRect: .zero, styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
                panel.noteID = note.id
                panel.title = "Nino · \(note.displayTitle)"
                panel.titleVisibility = .hidden
                panel.titlebarAppearsTransparent = true
                panel.titlebarSeparatorStyle = .none
                panel.standardWindowButton(.closeButton)?.isHidden = true
                panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
                panel.standardWindowButton(.zoomButton)?.isHidden = true
                panel.isReleasedWhenClosed = false
                panel.hidesOnDeactivate = false
                panel.isMovableByWindowBackground = true
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.appearance = NSAppearance(named: .aqua)
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hasShadow = true
                panel.minSize = NSSize(width: 280, height: 84)
                panel.maxSize = NSSize(width: 640, height: 900)
                panel.contentView = NSHostingView(rootView: StickyNoteEditor(store: store, id: note.id, projects: projects))
                panel.delegate = self
                panels[note.id] = panel
            }
            adjusting.insert(note.id)
            panel.title = "Nino · \(note.displayTitle)"
            panel.level = note.pinned ? .floating : .normal
            panel.isFloatingPanel = note.pinned
            let mask: NSWindow.StyleMask = note.collapsed ? [.titled, .closable, .nonactivatingPanel, .fullSizeContentView] : [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView]
            if panel.styleMask != mask { panel.styleMask = mask }
            // AppKit can recreate the titlebar controls when resize capability changes.
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            let stored = note.frame ?? defaultFrame(index)
            var expanded = stored.clamped(to: screens)
            expanded.height = max(200, expanded.height)
            expanded = expanded.clamped(to: screens)
            let frame = NSRect(x: expanded.x, y: note.collapsed ? expanded.y + expanded.height - 84 : expanded.y, width: expanded.width, height: note.collapsed ? 84 : expanded.height)
            if panel.frame != frame { panel.setFrame(frame, display: true) }
            adjusting.remove(note.id)
            if note.frame != expanded { store.setFrame(note.id, expanded) }
            if isNew { panel.orderFrontRegardless() }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let panel = sender as? StickyNotePanel, let id = panel.noteID {
            store.setVisible(id, false); store.flush()
            panel.orderOut(nil)
        }
        return false // Native close hides the note; the library and text remain intact.
    }
    func windowDidMove(_ notification: Notification) { saveFrame(notification) }
    func windowDidResize(_ notification: Notification) { saveFrame(notification) }
    private func saveFrame(_ notification: Notification) {
        guard let panel = notification.object as? StickyNotePanel, let id = panel.noteID,
              !adjusting.contains(id), let note = store.note(id) else { return }
        let rect = panel.frame
        let expandedHeight = note.collapsed ? (note.frame?.height ?? 360) : rect.height
        let saved = StickyNoteFrame(x: rect.minX, y: rect.maxY - expandedHeight, width: rect.width, height: expandedHeight)
        if saved != note.frame { store.setFrame(id, saved) }
    }
}
