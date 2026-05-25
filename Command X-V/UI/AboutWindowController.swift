import Cocoa
import os.log

class AboutWindowController: NSWindowController {

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "AboutWindow")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.init(window: window)
        setupWindow()
    }

    private func setupWindow() {
        guard let window = window else { return }

        window.title = "About Command X-V"
        window.isReleasedWhenClosed = false
        window.center()
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        window.styleMask.insert(.fullSizeContentView)

        window.isOpaque = false
        window.backgroundColor = .clear

        window.contentViewController = AboutViewController()

        logger.info("About window configured")
    }

    func showAbout() {
        guard let window = window else { return }

        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    override func cancelOperation(_ sender: Any?) {
        window?.close()
    }
}
