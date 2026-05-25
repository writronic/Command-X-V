import Cocoa
import os.log

class WelcomeWindowController: NSWindowController {
    
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "WelcomeWindow")
    private var welcomeViewController: WelcomeViewController?
    
    var onWelcomeComplete: (() -> Void)?
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        setupWindow()
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "Welcome to Command X-V"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        window.styleMask.insert(.fullSizeContentView)
        
        window.isOpaque = false
        window.backgroundColor = .clear
        
        welcomeViewController = WelcomeViewController()
        welcomeViewController?.onWelcomeComplete = { [weak self] in
            self?.handleWelcomeComplete()
        }
        
        window.contentViewController = welcomeViewController
        
        logger.info("Welcome window configured")
    }
    
    func showWelcome() {
        guard let window = window else { return }
        
        logger.info("Showing welcome window")
        
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideWelcome() {
        logger.info("Hiding welcome window")
        window?.orderOut(nil)
    }
    
    private func handleWelcomeComplete() {
        logger.info("Welcome flow completed")
        
        hideWelcome()
        
        UserDefaults.standard.set(true, forKey: "HasCompletedOnboarding")
        
        onWelcomeComplete?()
    }
}

extension WelcomeWindowController: NSWindowDelegate {
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        logger.warning("User attempted to close welcome window")
        
        let alert = NSAlert()
        alert.messageText = "Complete Setup Required"
        alert.informativeText = "Please complete the setup process to use Command X-V, or quit the application."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue Setup")
        alert.addButton(withTitle: "Quit App")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSApplication.shared.terminate(nil)
        }
        
        return false
    }
}
