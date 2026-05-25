import Foundation
import Cocoa
import os.log

@MainActor
class MenuBarManager {

    private(set) var isVisible = false {
        didSet {
            if oldValue != isVisible {
                onVisibilityChanged?(isVisible)
            }
        }
    }

    private(set) var currentStatus: String = "Inactive" {
        didSet {
            if oldValue != currentStatus {
                onStatusChanged?(currentStatus)
            }
        }
    }

    let statusItemManager = StatusItemManager()

    private var menu: NSMenu?
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "MenuBarManager")

    private weak var statusMenuItem: NSMenuItem?

    var onQuitRequested: (() -> Void)?
    var onSettingsRequested: (() -> Void)?
    var onVisibilityChanged: ((Bool) -> Void)?
    var onStatusChanged: ((String) -> Void)?

    init() {
        logger.info("MenuBarManager: Initialized")
    }

    func show() {
        if isVisible {
            statusItemManager.setVisible(true)
            return
        }

        statusItemManager.show()

        setupMenu()
        statusItemManager.setMenu(menu!)

        isVisible = true

        logger.info("Menu bar shown")
    }

    func hide() {
        guard isVisible else { return }

        statusItemManager.hide()
        menu = nil
        isVisible = false

        logger.info("Menu bar hidden")
    }

    func updateIcon(active: Bool) {
        let state: StatusItemManager.StatusState = active ? .active : .inactive
        statusItemManager.updateState(state)
    }

    func updateFromAppStatus(_ status: AppStatus) {
        statusItemManager.updateFromAppStatus(status)
        updateStatusText(from: status)
    }

    func showFeedback(_ message: String) {
        logger.info("MenuBarManager: \(message)")
    }

    func highlight() {
        statusItemManager.highlight()
    }

    private func setupMenu() {
        menu = NSMenu()
        menu?.autoenablesItems = false

        let statusItem = NSMenuItem(title: currentStatus, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        statusMenuItem = statusItem
        menu?.addItem(statusItem)

        menu?.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu?.addItem(settingsItem)

        let exitItem = NSMenuItem(title: "Exit", action: #selector(quit), keyEquivalent: "q")
        exitItem.target = self
        menu?.addItem(exitItem)
    }

    private func updateStatusText(from status: AppStatus) {
        let newStatus: String

        if !status.hasPermissions {
            newStatus = "Status: Permission Required"
        } else if !status.isRunning {
            newStatus = "Status: Disabled"
        } else if status.hasCutFiles {
            newStatus = "Status: Files Cut (\(StateManager.shared.getCutFiles().count))"
        } else if status.isActive {
            newStatus = "Status: Active"
        } else {
            newStatus = "Status: Inactive"
        }

        currentStatus = newStatus
        statusMenuItem?.title = newStatus
    }

    @objc private func showSettings() {
        onSettingsRequested?()
    }

    @objc private func quit() {
        onQuitRequested?()
    }

    func setIconVisible(_ visible: Bool) {
        statusItemManager.setVisible(visible)
    }
}
