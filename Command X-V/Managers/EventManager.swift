import Foundation
import Cocoa
import Carbon
import os.log

class EventManager {

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    let applicationTargetManager: ApplicationTargetManager
    private let keyboardEventSynthesizer = KeyboardEventSynthesizer()
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "EventManager")

    private let stateManager: StateManager

    nonisolated(unsafe) var cachedHasCut: Bool = false
    nonisolated(unsafe) var cachedShortcutConfig: ShortcutConfiguration = ShortcutConfiguration.default

    private let maxRecoveryAttempts = 3
    nonisolated(unsafe) private var tapRecoveryAttempts = 0
    private var healthCheckTimer: Timer?

    var onEventProcessed: (@Sendable (EventCommandType) -> Void)?
    var onRestoreShortcutDetected: (@Sendable () -> Void)?
    var onPermissionRevoked: (@Sendable () -> Void)?

    @MainActor
    init() throws {
        self.stateManager = StateManager.shared
        self.applicationTargetManager = ApplicationTargetManager()
        logger.info("Initializing EventManager...")

        guard PermissionChecker.checkAccessibilityPermission() == .granted else {
            throw ErrorManager.CommandXVError.accessibilityNotEnabled
        }
    }

    func startMonitoring() throws {
        logger.info("Starting keyboard event monitoring...")

        guard eventTap == nil else {
            logger.warning("Event monitoring already active")
            return
        }

        try createEventTap()
        enableEventTap()
        setupSystemObservers()
        startHealthCheckTimer()
        applicationTargetManager.startFocusTracking()

        logger.info("Event monitoring started successfully")
    }

    func stopMonitoring() {
        logger.info("Stopping keyboard event monitoring...")

        applicationTargetManager.stopFocusTracking()
        stopHealthCheckTimer()
        removeSystemObservers()
        cleanup()

        logger.info("Event monitoring stopped")
    }

    private func createEventTap() throws {
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                let unmanagedSelf = Unmanaged<EventManager>.fromOpaque(refcon!)
                let eventManager = unmanagedSelf.takeUnretainedValue()

                return eventManager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            throw ErrorManager.CommandXVError.eventProcessingFailed("Failed to create event tap")
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
            throw ErrorManager.CommandXVError.eventProcessingFailed("Failed to create run loop source")
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    }

    private func enableEventTap() {
        guard let eventTap = eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    nonisolated private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            handleTapDisabled(type: type)
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == KeyboardEventSynthesizer.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        logger.debug("Key event: keyCode=\(keyCode), flags=\(flags.rawValue)")

        if KeyCodes.matchesShortcut(CGKeyCode(keyCode), flags, cachedShortcutConfig.hideMenuBarShortcut) {
            logger.info("Menu bar restore shortcut detected")
            let callback = onRestoreShortcutDetected
            DispatchQueue.main.async {
                callback?()
            }
            return nil
        }

        guard shouldProcessEvent() else {
            logger.debug("Event not processed - target application not active")
            return Unmanaged.passUnretained(event)
        }

        if applicationTargetManager.cachedIsTextFieldFocused {
            logger.debug("Text field focused - passing through for native text editing")
            return Unmanaged.passUnretained(event)
        }

        if let command = createEventCommand(keyCode: CGKeyCode(keyCode), flags: flags) {
            logger.info("Processing command: \(String(describing: command.commandType))")
            return processEventCommand(command, originalEvent: event)
        }

        if shouldBlockDefaultShortcut(keyCode: CGKeyCode(keyCode), flags: flags) {
            logger.info("Blocking default shortcut to prevent native paste/cut behavior")
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    nonisolated private func shouldProcessEvent() -> Bool {
        let isTarget = applicationTargetManager.isTargetApplicationActive()
        if !isTarget {
            if let appInfo = applicationTargetManager.getCurrentApplicationInfo() {
                logger.debug("Current app: \(appInfo.bundleIdentifier ?? "unknown") - not a target")
            }
        }
        return isTarget
    }

    nonisolated private func createEventCommand(keyCode: CGKeyCode, flags: CGEventFlags) -> EventCommand? {
        if KeyCodes.matchesShortcut(keyCode, flags, cachedShortcutConfig.cutShortcut) {
            logger.info("Cut key combo detected")
            return CutCommand(stateManager: stateManager, synthesizer: keyboardEventSynthesizer)
        } else if KeyCodes.matchesShortcut(keyCode, flags, cachedShortcutConfig.pasteShortcut) && self.cachedHasCut {
            logger.info("Paste key combo detected (cachedHasCut: \(self.cachedHasCut))")
            let command = PasteCommand(stateManager: stateManager, synthesizer: keyboardEventSynthesizer)
            command.onImmediateCutClear = { [weak self] in
                self?.cachedHasCut = false
            }
            return command
        } else if KeyCodes.matchesShortcut(keyCode, flags, cachedShortcutConfig.pasteShortcut) {
            logger.debug("Paste key combo detected but no cut state")
        }

        return nil
    }

    nonisolated private func shouldBlockDefaultShortcut(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        let modifiers = flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])

        let isDefaultPaste = (keyCode == KeyCodes.v && modifiers == .maskCommand)
        if isDefaultPaste {
            let pasteShortcut = cachedShortcutConfig.pasteShortcut
            let pasteIsRemapped = !(pasteShortcut.cgKeyCode == KeyCodes.v && pasteShortcut.modifierOnlyFlags == .maskCommand)
            if pasteIsRemapped {
                return true
            }
        }

        let isDefaultCut = (keyCode == KeyCodes.x && modifiers == .maskCommand)
        if isDefaultCut {
            let cutShortcut = cachedShortcutConfig.cutShortcut
            let cutIsRemapped = !(cutShortcut.cgKeyCode == KeyCodes.x && cutShortcut.modifierOnlyFlags == .maskCommand)
            if cutIsRemapped {
                return true
            }
        }

        return false
    }

    nonisolated private func processEventCommand(_ command: EventCommand, originalEvent: CGEvent) -> Unmanaged<CGEvent>? {
        let callback = onEventProcessed
        let commandType = command.commandType

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            do {
                _ = try command.execute(originalEvent: originalEvent)
            } catch {
                self?.logger.error("Event command execution failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                callback?(commandType)
            }
        }

        return nil
    }


    nonisolated private func handleTapDisabled(type: CGEventType) {
        let reason = type == .tapDisabledByTimeout ? "timeout" : "user input"
        logger.warning("Event tap disabled by \(reason), attempting re-enable...")

        guard let tap = eventTap else {
            logger.error("Cannot re-enable: eventTap is nil")
            return
        }

        CGEvent.tapEnable(tap: tap, enable: true)

        if CGEvent.tapIsEnabled(tap: tap) {
            logger.info("Event tap re-enabled successfully")
            tapRecoveryAttempts = 0
        } else {
            tapRecoveryAttempts += 1
            logger.error("Event tap re-enable failed (attempt \(self.tapRecoveryAttempts))")

            if tapRecoveryAttempts >= maxRecoveryAttempts {
                logger.critical("Max recovery attempts reached, signaling permission revoked")
                let callback = onPermissionRevoked
                DispatchQueue.main.async {
                    callback?()
                }
            }
        }
    }


    private func setupSystemObservers() {
        let center = NSWorkspace.shared.notificationCenter

        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWake()
        }

        center.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWake()
        }

        logger.info("System wake/session observers registered")
    }

    private func removeSystemObservers() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        logger.info("System observers removed")
    }

    private func handleSystemWake() {
        logger.info("System wake or session activation detected, verifying event tap...")

        guard let tap = eventTap else {
            logger.warning("Event tap is nil after wake, attempting full recreation...")
            recreateEventTap()
            return
        }

        if !CGEvent.tapIsEnabled(tap: tap) {
            logger.warning("Event tap disabled after wake, re-enabling...")
            CGEvent.tapEnable(tap: tap, enable: true)

            if !CGEvent.tapIsEnabled(tap: tap) {
                logger.warning("Re-enable failed after wake, attempting full recreation...")
                recreateEventTap()
            } else {
                logger.info("Event tap re-enabled after wake")
                tapRecoveryAttempts = 0
            }
        } else {
            logger.info("Event tap healthy after wake")
        }
    }

    private func recreateEventTap() {
        logger.info("Recreating event tap...")

        cleanup()

        do {
            try createEventTap()
            enableEventTap()
            tapRecoveryAttempts = 0
            logger.info("Event tap recreated successfully")
        } catch {
            tapRecoveryAttempts += 1
            logger.error("Event tap recreation failed: \(error.localizedDescription)")

            if tapRecoveryAttempts >= maxRecoveryAttempts {
                logger.critical("Max recovery attempts reached during recreation")
                let callback = onPermissionRevoked
                DispatchQueue.main.async {
                    callback?()
                }
            }
        }
    }


    private func startHealthCheckTimer() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkTapHealth()
        }
        logger.info("Event tap health check timer started (5s interval)")
    }

    private func stopHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    private func checkTapHealth() {
        guard let tap = eventTap else { return }

        if !CGEvent.tapIsEnabled(tap: tap) {
            logger.warning("Health check: event tap disabled, re-enabling...")
            CGEvent.tapEnable(tap: tap, enable: true)

            if CGEvent.tapIsEnabled(tap: tap) {
                logger.info("Health check: event tap re-enabled")
                tapRecoveryAttempts = 0
            } else {
                logger.error("Health check: re-enable failed")
            }
        }
    }

    private func cleanup() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        tapRecoveryAttempts = 0
    }

    deinit {
        stopHealthCheckTimer()
        removeSystemObservers()
        cleanup()
    }
}
