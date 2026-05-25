import Cocoa
import Foundation
import Carbon
import CoreGraphics
import os.log

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private let firstLaunchManager = FirstLaunchManager.shared
    private var welcomeWindowController: WelcomeWindowController?

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "AppDelegate")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        firstLaunchManager.recordLaunch()

        NSApp.setActivationPolicy(.accessory)

        _ = UpdateManager.shared

        CommandXVManager.shared.showMenuBar()

        if firstLaunchManager.isFirstLaunch {
            showWelcomeWindow()
        } else {
            startNormalOperation()
        }

        logger.info("Command X-V started successfully")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        CommandXVManager.shared.stop()
        logger.info("Command X-V terminated")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @objc func quit(_ sender: Any?) {
        NSApplication.shared.terminate(sender)
    }

    func showWelcomeWindow() {
        if welcomeWindowController != nil {
            welcomeWindowController?.showWelcome()
            return
        }

        logger.info("Showing welcome window")

        welcomeWindowController = WelcomeWindowController()
        welcomeWindowController?.onWelcomeComplete = { [weak self] in
            self?.handleWelcomeComplete()
        }

        welcomeWindowController?.showWelcome()
    }

    private func handleWelcomeComplete() {
        logger.info("Welcome flow completed, starting normal operation")

        firstLaunchManager.markOnboardingCompleted()

        welcomeWindowController?.hideWelcome()
        welcomeWindowController = nil

        startNormalOperation()
    }

    private func startNormalOperation() {
        logger.info("Starting normal app operation")

        CommandXVManager.shared.onPermissionDenied = { [weak self] in
            self?.showWelcomeWindow()
        }

        CommandXVManager.shared.start()
    }
}
