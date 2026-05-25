import Cocoa
import os.log

enum SettingsLayout {
    static let windowWidth: CGFloat = 540
    static let windowHeight: CGFloat = 430
    static let sidebarWidth: CGFloat = 140
    static let detailWidth: CGFloat = windowWidth - sidebarWidth
    static let windowSize = NSSize(width: windowWidth, height: windowHeight)
    static let contentHeight: CGFloat = windowHeight - 28 // title bar offset
}

@MainActor
class SettingsWindowController: NSWindowController {

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "SettingsWindow")

    var onHideMenuBarRequested: ((@escaping (Bool) -> Void) -> Void)? {
        didSet {
            (contentViewController as? SettingsViewController)?.onHideMenuBarRequested = onHideMenuBarRequested
        }
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: SettingsLayout.windowWidth, height: SettingsLayout.windowHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        self.init(window: window)
        setupWindow()
    }

    private func setupWindow() {
        guard let window = window else { return }

        window.title = "Settings"
        window.isReleasedWhenClosed = false

        let settingsVC = SettingsViewController()
        settingsVC.onHideMenuBarRequested = onHideMenuBarRequested
        window.contentViewController = settingsVC

        NSWindow.removeFrame(usingName: "CommandXV_SettingsWindow")

        window.contentMinSize = SettingsLayout.windowSize
        window.contentMaxSize = SettingsLayout.windowSize

        window.setFrame(NSRect(x: 0, y: 0, width: SettingsLayout.windowWidth, height: SettingsLayout.windowHeight), display: true)
        window.setFrameAutosaveName("CommandXV_SettingsWindow")
        window.center()

        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible

        logger.info("Settings window configured")
    }

    func showSettings() {
        guard let window = window else { return }

        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        logger.info("Settings window shown")
    }

    override func cancelOperation(_ sender: Any?) {
        window?.close()
    }
}
