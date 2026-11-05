import AppKit
import SwiftUI
import Combine

private final class WelcomeCompanionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor private final class WelcomeCompanionPose: ObservableObject {
    @Published var time = 0.0
    @Published var walk = CompanionWalkPose()
}

private struct WalkingWelcomeCompanion: View {
    @ObservedObject var pose: WelcomeCompanionPose
    var body: some View {
        CompanionView(mood: .idle, sampleTime: pose.time, energy: .lively, walkPose: pose.walk)
            .frame(width: CompanionWalkRoute.panelSize.width, height: CompanionWalkRoute.panelSize.height)
            .accessibilityHidden(true)
    }
}

/// Decorative only: no click interception, screen capture or global input monitoring.
/// The panel lives with the onboarding window, on that window's current screen.
@MainActor final class OnboardingCompanionController {
    private weak var window: NSWindow?
    private weak var store: NinoStore?
    private let panel: WelcomeCompanionPanel
    private let pose = WelcomeCompanionPose()
    private var subscriptions = Set<AnyCancellable>()
    private var timer: Timer?
    private var elapsed = 0.0
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var route: CompanionWalkRoute?
    private var geometry = CGRect.zero
    private var screenGeometry = CGRect.zero
    private var variation = 0

    init(window: NSWindow, store: NinoStore) {
        self.window = window; self.store = store
        panel = WelcomeCompanionPanel(contentRect: NSRect(origin: .zero, size: CompanionWalkRoute.panelSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false; panel.collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: WalkingWelcomeCompanion(pose: pose))
        Publishers.CombineLatest4(store.$showOnboarding, store.$welcomeEnergy, store.$welcomeWalkEnabled, store.$welcomeStep)
            .receive(on: RunLoop.main).sink { [weak self] _, _, _, _ in self?.updateVisibility() }.store(in: &subscriptions)
        let center = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.didChangeScreenNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification, NSWindow.didBecomeKeyNotification, NSWindow.willCloseNotification] {
            center.publisher(for: name, object: window).sink { [weak self] note in
                if note.name == NSWindow.willCloseNotification { self?.stop() } else { self?.updateVisibility() }
            }.store(in: &subscriptions)
        }
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification, NSApplication.didChangeScreenParametersNotification] {
            center.publisher(for: name).sink { [weak self] _ in self?.updateVisibility() }.store(in: &subscriptions)
        }
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
            .sink { [weak self] _ in self?.updateVisibility() }.store(in: &subscriptions)
        updateVisibility()
    }
    func updateVisibility() {
        guard let window, let store, store.showOnboarding, store.welcomeWalkEnabled,
              store.welcomeEnergy == .lively, NSApp.isActive, window.isVisible, !window.isMiniaturized,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { stop(); return }
        guard timer == nil else { tick(); return }
        lastTick = ProcessInfo.processInfo.systemUptime
        window.addChildWindow(panel, ordered: .above)
        tick(); panel.orderFront(nil)
        let next = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        next.tolerance = 0.002; RunLoop.main.add(next, forMode: .common); timer = next
    }
    private func tick() {
        guard let window, let screen = window.screen ?? NSScreen.main else { stop(); return }
        let now = ProcessInfo.processInfo.systemUptime
        elapsed += min(0.1, max(0, now - lastTick)); lastTick = now
        if geometry != window.frame || screenGeometry != screen.visibleFrame || route == nil {
            geometry = window.frame; screenGeometry = screen.visibleFrame
            route = CompanionWalkRoute(window: geometry, screen: screenGeometry, variation: variation)
            elapsed = 0
        }
        guard let route else { return }
        if elapsed >= route.duration {
            elapsed -= route.duration; variation += 1
            self.route = CompanionWalkRoute(window: geometry, screen: screenGeometry, variation: variation)
        }
        let sample = (self.route ?? route).sample(at: elapsed)
        pose.walk = sample; pose.time = now
        panel.setFrameOrigin(CGPoint(x: sample.position.x - 62, y: sample.position.y - 18))
    }
    private func stop() {
        timer?.invalidate(); timer = nil
        window?.removeChildWindow(panel); panel.orderOut(nil)
    }
}
