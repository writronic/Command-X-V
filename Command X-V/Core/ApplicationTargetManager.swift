import Foundation
import AppKit
@preconcurrency import ApplicationServices
import os.log

class ApplicationTargetManager {
    
    private var cachedFrontmostApp: NSRunningApplication?
    private var lastAppCheckTime = Date()
    private let cacheLifetime: TimeInterval = 0.5
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "ApplicationTargetManager")

    var cachedTargetApplications: [String] = []


    nonisolated(unsafe) var cachedIsTextFieldFocused: Bool = false

    private var focusObserver: AXObserver?
    private var observedPid: pid_t = 0

    private static let textEditingRoles: Set<String> = [
        kAXTextFieldRole,
        kAXTextAreaRole,
        kAXComboBoxRole
    ]

    private static let textEditingSubroles: Set<String> = [
        "AXSearchField"
    ]

    init() {}


    func isTargetApplicationActive() -> Bool {
        let frontmostApp = getFrontmostApplication()

        guard let bundleIdentifier = frontmostApp?.bundleIdentifier else {
            logger.debug("No frontmost application bundle identifier")
            return false
        }

        let isTarget = cachedTargetApplications.contains(bundleIdentifier)

        if isTarget {
            logger.info("Target application active: \(bundleIdentifier)")
        } else {
            logger.debug("Non-target application active: \(bundleIdentifier)")
        }

        return isTarget
    }
    
    func getCurrentApplicationInfo() -> ApplicationInfo? {
        guard let app = getFrontmostApplication() else { return nil }
        
        return ApplicationInfo(
            bundleIdentifier: app.bundleIdentifier,
            localizedName: app.localizedName,
            processIdentifier: app.processIdentifier,
            isTarget: isTargetApplicationActive()
        )
    }
    
    private func getFrontmostApplication() -> NSRunningApplication? {
        let now = Date()
        
        if let cachedApp = cachedFrontmostApp,
           now.timeIntervalSince(lastAppCheckTime) < cacheLifetime {
            return cachedApp
        }
        
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        
        cachedFrontmostApp = frontmostApp
        lastAppCheckTime = now
        
        return frontmostApp
    }


    func startFocusTracking() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        if let frontApp = NSWorkspace.shared.frontmostApplication {
            attachFocusObserver(to: frontApp.processIdentifier)
        }

        logger.info("Focus tracking started")
    }

    func stopFocusTracking() {
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        detachCurrentObserver()
        cachedIsTextFieldFocused = false
        logger.info("Focus tracking stopped")
    }


    @objc private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        let pid = app.processIdentifier
        let bundleId = app.bundleIdentifier ?? "unknown"

        if cachedTargetApplications.contains(bundleId) {
            attachFocusObserver(to: pid)
        } else {
            detachCurrentObserver()
            cachedIsTextFieldFocused = false
        }
    }


    private func attachFocusObserver(to pid: pid_t) {
        if observedPid == pid, focusObserver != nil {
            checkFocusedElementRole(for: pid)
            return
        }

        detachCurrentObserver()

        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon = refcon else { return }
            let manager = Unmanaged<ApplicationTargetManager>.fromOpaque(refcon).takeUnretainedValue()
            manager.handleFocusChanged(element: element)
        }

        var newObserver: AXObserver?
        let error = AXObserverCreate(pid, callback, &newObserver)

        guard error == .success, let observer = newObserver else {
            logger.warning("Failed to create AXObserver for PID \(pid): \(error.rawValue)")
            cachedIsTextFieldFocused = false
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        let notificationName = kAXFocusedUIElementChangedNotification as CFString

        let addError = AXObserverAddNotification(
            observer,
            appElement,
            notificationName,
            Unmanaged.passUnretained(self).toOpaque()
        )

        guard addError == .success else {
            logger.warning("Failed to add focus notification for PID \(pid): \(addError.rawValue)")
            cachedIsTextFieldFocused = false
            return
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        self.focusObserver = observer
        self.observedPid = pid

        checkFocusedElementRole(for: pid)

        logger.info("Focus observer attached for PID \(pid)")
    }

    private func detachCurrentObserver() {
        guard let observer = focusObserver else { return }

        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        focusObserver = nil
        observedPid = 0
        logger.debug("Focus observer detached")
    }


    private func handleFocusChanged(element: AXUIElement) {
        var role: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        if error == .success, let roleString = role as? String {
            var isTF = Self.textEditingRoles.contains(roleString)

            if !isTF {
                var subrole: CFTypeRef?
                let subError = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
                if subError == .success, let subroleString = subrole as? String {
                    isTF = Self.textEditingSubroles.contains(subroleString)
                }
            }

            cachedIsTextFieldFocused = isTF
            logger.debug("Focus changed: role=\(roleString), isTextField=\(isTF)")
        } else {
            cachedIsTextFieldFocused = false
            logger.debug("Focus changed: unable to determine role (error=\(error.rawValue))")
        }
    }

    private func checkFocusedElementRole(for pid: pid_t) {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?

        let error = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard error == .success, let element = focusedElement else {
            cachedIsTextFieldFocused = false
            return
        }

        handleFocusChanged(element: (element as! AXUIElement))
    }

    deinit {
        detachCurrentObserver()
    }
}

struct ApplicationInfo: Sendable {
    let bundleIdentifier: String?
    let localizedName: String?
    let processIdentifier: pid_t
    let isTarget: Bool
}
