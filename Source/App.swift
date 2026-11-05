import SwiftUI
import AppKit
import Carbon
import Combine

@main struct NinoApp: App {
    @NSApplicationDelegateAdaptor(NinoDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}
final class NinoPanel: NSPanel { override var canBecomeKey: Bool { true }; override var canBecomeMain: Bool { false } }
@MainActor final class NinoDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = NinoStore()
    var stickyProjectsObservation: AnyCancellable?
    var stickyWindows: StickyNoteWindows?
    var mainWindow: NSWindow!
    var notch: NinoPanel!
    var prompter: NinoPanel?
    var callPanel: NinoPanel?
    let snow = SnowController()
    var snowObservation: AnyCancellable?
    var snowMenuItem: NSMenuItem?
    var callAnswerObservation: AnyCancellable?
    var touchBarBridge: TouchBarBridge?
    var status: NSStatusItem!
    var hotKey: EventHotKeyRef?
    let presentation = NotchPresentation()
    var expanded = false
    var collapseWork: DispatchWorkItem?
    var nativeUpdates: NativeUpdates?
    let terminationGate = TerminationGate()
    var welcomeCompanion: OnboardingCompanionController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = Bundle.main.object(forInfoDictionaryKey:"NinoPreviewSession") as? Bool == true ? "Nino · Découverte" : "Nino"; window.titlebarAppearsTransparent = true; window.isReleasedWhenClosed = false; window.delegate = self
        window.contentView = NSHostingView(rootView: NinoRootView(store: store)); window.setContentSize(fittedWindowSize()); window.center(); mainWindow = window
        stickyWindows = StickyNoteWindows(store: store.notes)
        store.openStickyNote = { [weak self] id in self?.stickyWindows?.show(id, activate: true) }
        store.hideStickyNotes = { [weak self] in self?.stickyWindows?.hideAll() }
        stickyProjectsObservation = store.work.$state.receive(on: RunLoop.main).sink { [weak self] state in
            self?.stickyWindows?.projects = state.projects.map { StickyNoteProject(id: $0.id, title: $0.title) }
        }
        stickyWindows?.restoreVisibleNotes()
        store.analytics.track(.appOpened)
        createMenu()
        nativeUpdates = NativeUpdates(model: store.updates, blockingReason: { [weak self] in
            self?.updateBlockingReason
        }, flushNotes: { [weak self] in
            self?.stickyWindows?.flush()
            self?.store.notes.flush()
        })
        store.updates.start()
        store.onDisplayChange = { [weak self] in self?.screenChanged() }
        if store.showOnboarding { presentation.snowEnabled = false }
        touchBarBridge = TouchBarBridge(store: store)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Nino")
        status.button?.target = self; status.button?.action = #selector(toggleNotch)
        notch = NinoPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        notch.isOpaque = false; notch.backgroundColor = .clear; notch.hasShadow = false; notch.level = .statusBar
        notch.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; notch.hidesOnDeactivate = false; notch.isReleasedWhenClosed = false
        notch.contentView = NSHostingView(rootView: NotchView(store: store, presentation: presentation, work: store.work, agent: store.agent, delivery: store.delivery, hover: { [weak self] in self?.hover($0) }, open: { [weak self] in self?.showMain() }, collapse: { [weak self] in self?.showNotch(expanded: false) }))
        showNotch(expanded: false)
        store.openNotchTimer = { [weak self] in self?.presentation.showTimer = true; self?.showNotch(expanded: true) }
        store.openCallAssistant = { [weak self] in self?.showCallAssistant(focus: true) }
        callAnswerObservation = store.assistant.$answerRevision.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self, self.presentation.automaticCallPrompter, self.store.assistant.running else { return }
            self.showCallAssistant()
        }
        snowObservation = presentation.$snowEnabled.sink { [weak self] enabled in
            UserDefaults.standard.set(enabled, forKey: "snowEnabled"); self?.snow.setEnabled(enabled)
            self?.snowMenuItem?.state = enabled ? .on : .off
        }
        store.openPrompter = { [weak self] in self?.showPrompter() }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            let app = Unmanaged<NinoDelegate>.fromOpaque(data).takeUnretainedValue()
            DispatchQueue.main.async { app.toggleNotch() }; return noErr
        }, 1, &type, pointer, nil)
        RegisterEventHotKey(UInt32(kVK_ANSI_N), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x4e494e4f, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        showMain()
        welcomeCompanion = OnboardingCompanionController(window: mainWindow, store: store)
    }
    @objc func newStickyNote() {
        if let id = store.notes.create(projectID: store.work.current?.id) { stickyWindows?.show(id, activate: true) }
    }
    func createMenu() {
        let menu = NSMenu(); let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "À propos de Nino", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(withTitle: "Rechercher une mise à jour…", action: #selector(checkUpdates), keyEquivalent: "")
        appMenu.addItem(withTitle: "Réglages…", action: #selector(settings), keyEquivalent: ",")
        if Bundle.main.object(forInfoDictionaryKey:"NinoPreviewSession") as? Bool == true {
            appMenu.addItem(withTitle:"Revenir à mon Nino habituel", action:#selector(exitPreview), keyEquivalent:"")
        }
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "Quitter Nino", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        let fileItem = NSMenuItem(); fileItem.title = "Fichier"; let file = NSMenu(title: "Fichier")
        file.addItem(withTitle: "Importer un média…", action: #selector(importMedia), keyEquivalent: "o")
        file.addItem(withTitle: "Nouveau post-it", action: #selector(newStickyNote), keyEquivalent: "n")
        file.addItem(withTitle: "Ouvrir Nino", action: #selector(showMain), keyEquivalent: "1")
        file.addItem(withTitle: "Afficher l’encoche", action: #selector(toggleNotch), keyEquivalent: "")
        fileItem.submenu = file; menu.addItem(fileItem)
        let editItem = NSMenuItem(); editItem.title = "Édition"; let edit = NSMenu(title: "Édition")
        for (name, selector, key) in [("Annuler", "undo:", "z"), ("Couper", "cut:", "x"), ("Copier", "copy:", "c"), ("Coller", "paste:", "v"), ("Tout sélectionner", "selectAll:", "a")] { edit.addItem(withTitle: name, action: Selector(selector), keyEquivalent: key) }
        editItem.submenu = edit; menu.addItem(editItem)
        let viewItem=NSMenuItem();viewItem.title="Affichage";let viewMenu=NSMenu(title:"Affichage")
        viewMenu.addItem(withTitle:"Fenêtre compacte",action:#selector(compactWindow),keyEquivalent:"")
        viewMenu.addItem(withTitle:"Fenêtre confortable",action:#selector(comfortableWindow),keyEquivalent:"")
        let snowItem = NSMenuItem(title: "Neige sur le bureau", action: #selector(toggleSnow), keyEquivalent: "")
        snowItem.state = presentation.snowEnabled ? .on : .off; snowMenuItem = snowItem
        viewMenu.addItem(.separator()); viewMenu.addItem(snowItem)
        viewItem.submenu=viewMenu;menu.addItem(viewItem);NSApp.mainMenu=menu
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        let scheme = Bundle.main.object(forInfoDictionaryKey:"NinoPreviewSession") as? Bool == true ? "nino-discovery" : "nino"
        for url in urls {
        if store.google.handle(url) { continue }
        guard url.scheme == scheme else { continue }
        switch url.host {
        case "delivery": store.page = "delivery"; showMain()
        case "work", "home": store.page = "home"; showMain()
        case "today": store.page = "today"; showMain()
        case "transcript":
            if let doc = store.latestTranscript { store.selected = doc.id }
            store.page = "library"; showMain()
        case "stop", "audio": showNotch(expanded: true)
        default: showNotch(expanded: true)
        }
        }
    }
    @objc func exitPreview() {
        guard store.canCapture else { store.error="Termine la capture ou la transcription avant de quitter le test."; return }
        let backup=store.root.appendingPathComponent("mtmr-before.json")
        let config=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/MTMR/items.json")
        do {
            let original=store.root.deletingLastPathComponent().appendingPathComponent("Nino.app")
            guard FileManager.default.fileExists(atPath:original.path) else { throw NinoError("Nino habituel introuvable. Tes données sont conservées.") }
            if FileManager.default.fileExists(atPath:backup.path) {
                let data=try Data(contentsOf:backup)
                _ = try JSONSerialization.jsonObject(with:data)
                let permissions=try FileManager.default.attributesOfItem(atPath:config.path)[.posixPermissions]
                try data.write(to:config,options:.atomic)
                if let permissions { try FileManager.default.setAttributes([.posixPermissions:permissions],ofItemAtPath:config.path) }
                if let app=NSRunningApplication.runningApplications(withBundleIdentifier:"Toxblh.MTMR").first {
                    let appURL=app.bundleURL
                    var observer:NSObjectProtocol?
                    observer=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didTerminateApplicationNotification,object:nil,queue:.main) { notification in
                        guard let ended=notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, ended.processIdentifier == app.processIdentifier else { return }
                        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
                        if let appURL { NSWorkspace.shared.openApplication(at:appURL,configuration:NSWorkspace.OpenConfiguration()) }
                    }
                    if !app.terminate(), let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
                }
            }
            NSWorkspace.shared.openApplication(at:original,configuration:NSWorkspace.OpenConfiguration()) { _, error in
                Task { @MainActor in if let error { self.store.error=error.localizedDescription } else { DispatchQueue.main.asyncAfter(deadline:.now()+2) { NSApp.terminate(nil) } } }
            }
        } catch { store.error=error.localizedDescription }
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Nino", .applicationVersion: AppUpdates.installedVersion, .credits: NSAttributedString(string: "Compagnon de travail local. SwiftUI · Whisper.cpp · FFmpeg · CodexBar.")]) }
    @objc func compactWindow() { mainWindow.setContentSize(NSSize(width:680,height:540));mainWindow.center();showMain() }
    @objc func comfortableWindow() { mainWindow.setContentSize(fittedWindowSize());mainWindow.center();showMain() }
    @objc func showMain() { mainWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func importMedia() { showMain(); store.chooseFiles() }
    @objc func checkUpdates() { store.page = "settings"; showMain(); if store.updates.installerReady { store.updates.installUpdate() } else { store.updates.requestCheck(manual: true) } }
    @objc func settings() { store.page = "settings"; showMain() }
    @objc func toggleSnow() { presentation.snowEnabled.toggle() }
    @objc func toggleNotch() { showNotch(expanded: !expanded) }
    private func fittedWindowSize() -> NSSize {
        let available=(NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size ?? NSSize(width:1280,height:800)
        return NSSize(width:min(1120,max(680,available.width-32)),height:min(740,max(540,available.height-70)))
    }
    @objc func screenChanged() {
        notch.orderOut(nil); showNotch(expanded:expanded); snow.setEnabled(presentation.snowEnabled)
        guard let screen=mainWindow.screen ?? NSScreen.main else { return }
        var frame=mainWindow.frame
        frame.size.width=min(frame.width,screen.visibleFrame.width)
        frame.size.height=min(frame.height,screen.visibleFrame.height)
        frame.origin.x=max(screen.visibleFrame.minX,min(frame.minX,screen.visibleFrame.maxX-frame.width))
        frame.origin.y=max(screen.visibleFrame.minY,min(frame.minY,screen.visibleFrame.maxY-frame.height))
        mainWindow.setFrame(frame,display:true)
    }
    func hover(_ inside: Bool) {
        collapseWork?.cancel()
        if inside, !expanded { showNotch(expanded: true) }
        else if !inside && !presentation.showCallPrompter { let work = DispatchWorkItem { [weak self] in self?.showNotch(expanded: false) }; collapseWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work) }
    }
    func showNotch(expanded: Bool) {
        collapseWork?.cancel()
        if !expanded { presentation.showCallPrompter = false }
        // Recompute the frame when changing from tools to the call reader, even if expanded.
        self.expanded = expanded
        guard let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue == store.preferredDisplay }) ?? NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let camera = screen.safeAreaInsets.top > 0 ? max(0, screen.frame.width - (screen.auxiliaryTopLeftArea?.width ?? 0) - (screen.auxiliaryTopRightArea?.width ?? 0)) : 0
        presentation.cameraWidth = camera
        presentation.topHeight = max(screen.safeAreaInsets.top, 32)
        presentation.expanded = expanded
        let width = min(screen.frame.width - 16, expanded ? max(presentation.showCallPrompter ? 650 : 500, camera + 220) : max(216, camera + 200))
        let height = min(screen.frame.height - 20, expanded ? presentation.topHeight + 390 : presentation.topHeight)
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        if notch.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                notch.animator().setFrame(frame, display: true)
            }
        } else { notch.setFrame(frame, display: true) }
        notch.orderFrontRegardless()
    }
    func showCallAssistant(focus: Bool = false) {
        callPanel?.close(); callPanel = nil
        presentation.showTimer = false
        presentation.showCallPrompter = true
        showNotch(expanded: true)
        if focus { notch.makeKeyAndOrderFront(nil) }
    }
    func showPrompter() {
        prompter?.close()
        guard let screen = NSScreen.main else { return }
        let panel = NinoPanel(contentRect: NSRect(x: screen.frame.midX - 360, y: screen.visibleFrame.maxY - 400, width: 720, height: 370), styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        panel.isOpaque = true; panel.backgroundColor = .black; panel.level = .floating; panel.isMovableByWindowBackground = true; panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: PrompterView(store: store, close: { [weak self] in self?.prompter?.close(); self?.prompter = nil; self?.presentation.reading = false }))
        presentation.reading = true
        panel.makeKeyAndOrderFront(nil); prompter = panel
    }
    func applicationDidBecomeActive(_ notification: Notification) { VoicePermissions.shared.refresh() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMain(); return true }
    var updateBlockingReason: String? {
        NativeUpdatePolicy.Work(recording: store.recordingID != nil, starting: store.isStarting,
            stopping: store.isStopping, transcribing: store.busyID != nil, importing: store.copying,
            summarizing: store.summaryBusy, generating: store.agent.working || store.assistant.thinking || store.assistant.understanding,
            checkingDelivery: store.delivery.running, connecting: store.google.busy,
            savingWorkspace: store.work.saving, unsavedNotes: store.notes.hasUnsavedChanges).reason
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let decision = terminationGate.request(flush: { [weak self] in
            self?.store.saveSettings()
            self?.stickyWindows?.flush()
            self?.store.notes.flush()
        }, blocker: { [weak self] in self?.updateBlockingReason }, revoke: { [weak self] completion in
            guard let self else { completion(false); return }
            self.store.work.revokeOnExit(completion: completion)
        }, report: { [weak self] issue in
            self?.store.error = issue; self?.showMain()
        }, reply: { sender.reply(toApplicationShouldTerminate: $0) })
        return decision == .cancel ? .terminateCancel : .terminateLater
    }
}
