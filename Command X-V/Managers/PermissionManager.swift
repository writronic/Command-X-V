import Foundation
import Cocoa
import os.log

@MainActor
class PermissionManager {

    static let shared = PermissionManager()

    private(set) var currentStatus = PermissionStatus() {
        didSet {
            if oldValue != currentStatus {
                onPermissionStatusChanged?(currentStatus)
            }
        }
    }

    private(set) var isMonitoring = false {
        didSet {
            if oldValue != isMonitoring {
                onMonitoringStateChanged?(isMonitoring)
            }
        }
    }

    private(set) var lastPermissionCheck: Date? {
        didSet {
            if oldValue != lastPermissionCheck {
                onPermissionCheckTimeChanged?(lastPermissionCheck)
            }
        }
    }

    private var monitoringTimer: Timer?
    private var permissionCheckTimer: Timer?
    private var monitoringCheckCount: Int = 0
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "PermissionManager")

    var onPermissionGranted: (() -> Void)?
    var onPermissionRevoked: (() -> Void)?
    var onPermissionStatusChanged: ((PermissionStatus) -> Void)?
    var onMonitoringStateChanged: ((Bool) -> Void)?
    var onPermissionCheckTimeChanged: ((Date?) -> Void)?

    private init() {
        updatePermissionStatus()
        logger.info("PermissionManager: Initialized")
    }

    deinit {
    }

    func hasAccessibilityPermission() -> Bool {
        return currentStatus.accessibility.isGranted
    }

    func getPermissionStatus() -> PermissionStatus {
        return currentStatus
    }

    func updatePermissionStatus() {
        let newStatus = PermissionChecker.checkAllPermissions()
        let oldStatus = currentStatus
        currentStatus = newStatus
        lastPermissionCheck = Date()

        if oldStatus.accessibility != newStatus.accessibility {
            handleAccessibilityPermissionChange(from: oldStatus.accessibility, to: newStatus.accessibility)
        }

        logger.debug("Permission status updated: \(newStatus.summary)")
    }

    func startMonitoring() {
        guard !isMonitoring else {
            logger.debug("Permission monitoring already active")
            return
        }

        isMonitoring = true

        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.updatePermissionStatus()
            }
        }

        logger.info("Started permission monitoring")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        monitoringTimer?.invalidate()
        monitoringTimer = nil

        isMonitoring = false
        logger.info("Stopped permission monitoring")
    }

    func checkAndRequestPermissions(completion: @escaping @Sendable (Bool) -> Void) {
        updatePermissionStatus()

        if currentStatus.allRequiredGranted {
            logger.info("All required permissions granted")
            completion(true)
        } else {
            logger.info("Required permissions missing")
            completion(false)
        }
    }

    func requestAccessibilityPermission() {
        logger.info("Requesting accessibility permission")
        PermissionChecker.requestAccessibilityPermission()
    }

    func handlePermissionRevoked() {
        logger.warning("Permission revoked during runtime")
        onPermissionRevoked?()
    }

    private func requestAccessibilityPermissionAndMonitor(completion: @escaping @Sendable (Bool) -> Void) {
        requestAccessibilityPermission()

        monitorPermissionChanges(timeout: 60.0, completion: completion)
    }

    private func monitorPermissionChanges(timeout: TimeInterval, completion: @escaping @Sendable (Bool) -> Void) {
        let maxChecks = Int(timeout)
        monitoringCheckCount = 0

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }

                self.monitoringCheckCount += 1

                self.updatePermissionStatus()

                if self.currentStatus.allRequiredGranted == true {
                    self.monitoringTimer?.invalidate()
                    self.monitoringTimer = nil
                    self.logger.info("Permission granted during monitoring")
                    completion(true)
                } else if self.monitoringCheckCount >= maxChecks {
                    self.monitoringTimer?.invalidate()
                    self.monitoringTimer = nil
                    self.logger.warning("Permission monitoring timeout")
                    completion(false)
                }
            }
        }

        if let timer = monitoringTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func handleAccessibilityPermissionChange(from oldState: PermissionState, to newState: PermissionState) {
        switch (oldState, newState) {
        case (_, .granted):
            logger.info("Accessibility permission granted")
            onPermissionGranted?()

        case (.granted, .denied), (.granted, .unknown):
            logger.warning("Accessibility permission revoked")
            onPermissionRevoked?()

        default:
            logger.debug("Accessibility permission state changed: \(oldState.rawValue) -> \(newState.rawValue)")
        }
    }
}

extension PermissionManager {

    var hasAllRequiredPermissions: Bool {
        return currentStatus.allRequiredGranted
    }

    var missingPermissionsSummary: String {
        if currentStatus.allRequiredGranted {
            return "All permissions granted"
        }

        var missing: [String] = []

        if !currentStatus.accessibility.isGranted {
            missing.append("Accessibility")
        }

        return "Missing: " + missing.joined(separator: ", ")
    }

    func quickAccessibilityCheck() -> Bool {
        return PermissionChecker.checkAccessibilityPermission().isGranted
    }
}
