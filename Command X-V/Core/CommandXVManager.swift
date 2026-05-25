import Foundation
import Cocoa
import os.log

@MainActor
class CommandXVManager {

    static let shared = CommandXVManager()

    private let stateManager = StateManager.shared
    private let configurationManager = ConfigurationManager.shared
    private let errorManager = ErrorManager.shared

    private var eventManager: EventManager?
    private let menuBarManager: MenuBarManager
    private let menuBarVisibilityManager = MenuBarVisibilityManager()
    private let permissionManager = PermissionManager.shared

    private(set) var isRunning = false {
        didSet {
            if oldValue != isRunning {
                onRunningStateChanged?(isRunning)
            }
        }
    }

    private(set) var isInitialized = false

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "CommandXVManager")

    var onPermissionDenied: (() -> Void)?
    var onRunningStateChanged: ((Bool) -> Void)?

    private init() {
        self.menuBarManager = MenuBarManager()

        setupManagerDependencies()
        isInitialized = true
        logger.info("CommandXVManager: Initialized")
    }

    func showMenuBar() {
        menuBarManager.show()
        menuBarManager.setIconVisible(menuBarVisibilityManager.isMenuBarVisible)
        updateMenuBarStatus()
    }

    func start() {
        guard !isRunning else {
            logger.info("CommandXVManager: Already running")
            return
        }

        logger.info("CommandXVManager: Starting...")

        if !permissionManager.isMonitoring {
            permissionManager.startMonitoring()
        }

        guard configurationManager.isEnabled else {
            logger.info("CommandXVManager: Application is disabled in configuration")
            return
        }

        permissionManager.checkAndRequestPermissions { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startServices()
                } else {
                    self?.handlePermissionDenied()
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }

        logger.info("CommandXVManager: Stopping...")

        eventManager?.stopMonitoring()
        menuBarManager.hide()
        stateManager.setActiveState(false)

        isRunning = false
        logger.info("CommandXVManager: Stopped")
    }

    func restart() {
        logger.info("CommandXVManager: Restarting...")
        stop()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.start()
        }
    }

    func getStatus() -> AppStatus {
        return AppStatus(
            isRunning: isRunning,
            isActive: stateManager.isActive,
            hasCutFiles: stateManager.hasCutFiles,
            hasPermissions: permissionManager.hasAllRequiredPermissions
        )
    }

    private func setupManagerDependencies() {
        stateManager.onActiveStateChanged = { [weak self] isActive in
            self?.menuBarManager.updateIcon(active: isActive)
            self?.updateMenuBarStatus()
        }

        stateManager.onCutFilesStateChanged = { [weak self] hasCutFiles in
            let state: StatusItemManager.StatusState = hasCutFiles ? .hasCutFiles : .active
            self?.menuBarManager.statusItemManager.updateState(state)
            self?.updateMenuBarStatus()
        }

        configurationManager.onConfigurationChanged = { [weak self] config in
            self?.handleConfigurationChange(config)
            self?.eventManager?.applicationTargetManager.cachedTargetApplications = config.targetApplications
        }

        stateManager.onCutStateChanged = { [weak self] hasCut in
            self?.eventManager?.cachedHasCut = hasCut
        }

        configurationManager.onShortcutConfigurationChanged = { [weak self] shortcutConfig in
            self?.eventManager?.cachedShortcutConfig = shortcutConfig
            self?.logger.info("CommandXVManager: Shortcut configuration updated in EventManager")
        }

        setupMenuBarManagerCallbacks()

        setupPermissionManagerCallbacks()

        logger.info("CommandXVManager: Manager dependencies configured")

        menuBarVisibilityManager.onVisibilityChanged = { [weak self] isVisible in
            if isVisible {
                self?.menuBarManager.show()
            }
            self?.menuBarManager.setIconVisible(isVisible)
            self?.logger.info("CommandXVManager: Menu bar icon visibility changed: \(isVisible)")
        }
    }

    private func setupEventManagerCallbacks() {
        eventManager?.onEventProcessed = { [weak self] commandType in
            MainActor.assumeIsolated {
                self?.handleEventProcessed(commandType)
            }
        }

        eventManager?.onRestoreShortcutDetected = { [weak self] in
            MainActor.assumeIsolated {
                self?.menuBarVisibilityManager.processRestoreShortcut()
            }
        }

        eventManager?.onPermissionRevoked = { [weak self] in
            MainActor.assumeIsolated {
                self?.handlePermissionRevoked()
            }
        }
    }

    private func setupMenuBarManagerCallbacks() {
        menuBarManager.onQuitRequested = { [weak self] in
            self?.handleQuitRequest()
        }

        menuBarManager.onSettingsRequested = { [weak self] in
            self?.handleSettingsRequest()
        }
    }

    private func setupPermissionManagerCallbacks() {
        permissionManager.onPermissionGranted = { [weak self] in
            self?.handlePermissionGranted()
        }

        permissionManager.onPermissionRevoked = { [weak self] in
            self?.handlePermissionRevoked()
        }

        permissionManager.onPermissionStatusChanged = { [weak self] status in
            self?.handlePermissionStatusChanged(status)
        }
    }

    private func startServices() {
        do {
            if eventManager == nil {
                eventManager = try EventManager()
                setupEventManagerCallbacks()

                eventManager?.cachedHasCut = stateManager.hasCut
                eventManager?.cachedShortcutConfig = configurationManager.shortcutConfiguration
                eventManager?.applicationTargetManager.cachedTargetApplications = configurationManager.configuration.targetApplications
            }

            try eventManager?.startMonitoring()

            menuBarManager.show()
            menuBarManager.setIconVisible(menuBarVisibilityManager.isMenuBarVisible)

            isRunning = true

            stateManager.setActiveState(true)

            logger.info("CommandXVManager: All services started successfully")

        } catch {
            logger.error("CommandXVManager: Failed to start services: \(error.localizedDescription)")
            errorManager.handleError(.unknownError("Failed to start services: \(error.localizedDescription)"),
                                   context: "Service startup")
        }
    }

    private func handlePermissionDenied() {
        logger.warning("CommandXVManager: Permissions denied")

        onPermissionDenied?()

        updateMenuBarStatus()
    }

    private func handlePermissionGranted() {
        logger.info("CommandXVManager: Permissions granted")

        if !isRunning && configurationManager.isEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.start()
            }
        }
    }

    private func handlePermissionRevoked() {
        logger.warning("CommandXVManager: Permissions revoked")

        if isRunning {
            eventManager?.stopMonitoring()
            stateManager.setActiveState(false)
            isRunning = false
            logger.info("CommandXVManager: Event monitoring stopped (menu bar kept visible)")
        }

        updateMenuBarStatus()

        onPermissionDenied?()
    }

    private func handlePermissionStatusChanged(_ status: PermissionStatus) {
        logger.debug("CommandXVManager: Permission status changed - \(status.summary)")

        updateMenuBarStatus()
    }

    private func handleConfigurationChange(_ config: AppConfiguration) {
        logger.info("CommandXVManager: Configuration changed")

        if !config.isEnabled && isRunning {
            stop()
        } else if config.isEnabled && !isRunning {
            start()
        }

        if isRunning {
            if config.hideMenuBarIcon {
                menuBarManager.setIconVisible(false)
            } else {
                menuBarManager.setIconVisible(true)
            }
        }
    }

    private func handleEventProcessed(_ commandType: EventCommandType) {
        logger.info("CommandXVManager: Event processed: \(commandType.rawValue)")

        updateMenuBarStatus()

        switch commandType {
        case .cut:
            menuBarManager.showFeedback("Cut operation")
        case .paste:
            menuBarManager.showFeedback("Paste operation")
        default:
            break
        }

        menuBarManager.highlight()
    }

    private func updateMenuBarStatus() {
        if isRunning {
            let status = getStatus()
            menuBarManager.updateFromAppStatus(status)
        }
    }

    private var settingsWindowController: SettingsWindowController?

    private func handleQuitRequest() {
        logger.info("CommandXVManager: Quit requested")
        NSApplication.shared.terminate(nil)
    }

    private func handleSettingsRequest() {
        logger.info("CommandXVManager: Settings requested")

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
            settingsWindowController?.onHideMenuBarRequested = { [weak self] completion in
                self?.menuBarVisibilityManager.showRestoreInstructions(completion: completion)
            }
        }
        settingsWindowController?.showSettings()
    }
}

struct AppStatus: Sendable {
    let isRunning: Bool
    let isActive: Bool
    let hasCutFiles: Bool
    let hasPermissions: Bool

    init(isRunning: Bool, isActive: Bool, hasCutFiles: Bool, hasPermissions: Bool) {
        self.isRunning = isRunning
        self.isActive = isActive
        self.hasCutFiles = hasCutFiles
        self.hasPermissions = hasPermissions
    }
}
