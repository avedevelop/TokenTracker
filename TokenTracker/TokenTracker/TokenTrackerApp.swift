import SwiftUI
import Combine
import AppKit
import Sparkle

@main
struct TokenTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                // Remove unused default menus
                CommandGroup(replacing: .newItem) { }
                CommandGroup(replacing: .undoRedo) { }
                CommandGroup(replacing: .pasteboard) { }
                CommandGroup(replacing: .help) { }
                CommandGroup(replacing: .textFormatting) { }
                CommandGroup(replacing: .toolbar) { }
                CommandGroup(replacing: .sidebar) { }
                CommandGroup(replacing: .windowSize) { }
            }
    }
}

// MARK: - AppDelegate

class WindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var mainWindow: NSWindow?
    private let windowDelegate = WindowDelegate()
    let orchestrator = AppOrchestrator()
    private var cancellable: AnyCancellable?
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance enforcement: if another copy is already running, bring it to front and exit
        let running = NSWorkspace.shared.runningApplications
        let others = running.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier &&
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        if let existing = others.first {
            existing.activate(options: .activateIgnoringOtherApps)
            NSApp.terminate(nil)
            return
        }

        NSApplication.shared.setActivationPolicy(.regular)
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        setupStatusItem()
        orchestrator.start()
        Task { await NotificationManager.shared.requestPermission() }
        cleanupMenus()

        cancellable = orchestrator.$fiveHourUtilization
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pct in self?.updateStatusTitle(pct) }

        showMainWindow()
    }

    // MARK: Window (single instance)

    func showMainWindow() {
        if mainWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 580),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.title = "TokenTracker"
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.isMovableByWindowBackground = true
            win.styleMask.insert(.fullSizeContentView)
            win.backgroundColor = NSColor(red: 0.09, green: 0.07, blue: 0.14, alpha: 1)
            win.minSize = NSSize(width: 340, height: 400)
            win.maxSize = NSSize(width: 340, height: 900)

            let rootView = ContentView().environmentObject(orchestrator)
            let hostingController = NSHostingController(rootView: rootView)
            hostingController.preferredContentSize = NSSize(width: 340, height: 580)
            win.contentViewController = hostingController
            win.setContentSize(NSSize(width: 340, height: 580))
            win.center()
            win.delegate = windowDelegate
            mainWindow = win
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        orchestrator.stop()
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        "https://raw.githubusercontent.com/avedevelop/TokenTracker/main/appcast.xml"
    }

    // MARK: Status Item (optional menu bar icon)

    func setupStatusItem() {
        let show = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        guard show else { return }
        createStatusItem()
    }

    func createStatusItem() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "◆"
            button.target = self
            button.action = #selector(statusItemClicked)
        }
    }

    func removeStatusItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    @objc func statusItemClicked() {
        showMainWindow()
    }

    func setShowMenuBarIcon(_ show: Bool) {
        UserDefaults.standard.set(show, forKey: "showMenuBarIcon")
        if show { createStatusItem() } else { removeStatusItem() }
    }

    func updateStatusTitle(_ pct: Double) {
        guard let button = statusItem?.button else { return }
        button.title = pct == 0 ? "◆" : "\(Int(pct))%"
    }

    // MARK: Menus

    @objc func checkForUpdatesMenu() {
        updaterController?.checkForUpdates(nil)
    }

    func cleanupMenus() {
        guard let menu = NSApplication.shared.mainMenu else { return }
        // Add "Check for Updates…" to the app menu
        if let appMenu = menu.items.first?.submenu {
            let sep = NSMenuItem.separator()
            let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesMenu), keyEquivalent: "u")
            updateItem.target = self
            if appMenu.items.first(where: { $0.title.contains("Updates") }) == nil {
                appMenu.insertItem(sep, at: 1)
                appMenu.insertItem(updateItem, at: 1)
            }
        }
        let keepTitles = ["TokenTracker", "Window"]
        for item in menu.items where !keepTitles.contains(item.title) {
            menu.removeItem(item)
        }
    }

    // Keep for compatibility with existing SettingsView toggle
    func setMenuBarOnly(_ enabled: Bool) {
        setShowMenuBarIcon(enabled)
    }
}
