import Foundation
import os.log

@MainActor
class StateManager {

    static let shared = StateManager()

    private(set) var isActive = false {
        didSet {
            if oldValue != isActive {
                onActiveStateChanged?(isActive)
            }
        }
    }

    private(set) var hasCutFiles = false {
        didSet {
            if oldValue != hasCutFiles {
                onCutFilesStateChanged?(hasCutFiles)
            }
        }
    }

    private(set) var hasCut = false {
        didSet {
            if oldValue != hasCut {
                onCutStateChanged?(hasCut)
            }
        }
    }

    var onActiveStateChanged: ((Bool) -> Void)?
    var onCutFilesStateChanged: ((Bool) -> Void)?
    var onCutStateChanged: ((Bool) -> Void)?

    private var cutFiles: [URL] = []
    private var sourceApplication: String?
    private var cutTimestamp: Date?
    private var cutTimeoutTimer: Timer?
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "StateManager")

    private var cutTimeout: TimeInterval {
        return ConfigurationManager.shared.configuration.cutTimeout
    }

    private init() {
        logger.info("StateManager: Initialized")
    }

    func handleConfigurationTimeoutChange(_ newTimeout: TimeInterval) {
        handleTimeoutChange(newTimeout)
    }

    func setActiveState(_ active: Bool) {
        guard isActive != active else { return }

        isActive = active
        logger.info("StateManager: Active state changed to \(active)")

        if !active {
            clearCutFiles()
        }
    }

    func setCutState(_ state: Bool) {
        hasCut = state

        if state {
            cutTimestamp = Date()
            startCutTimeoutTimer()
        } else {
            cutTimestamp = nil
            cutTimeoutTimer?.invalidate()
            cutTimeoutTimer = nil
        }

        logger.info("StateManager: Cut state changed to \(state)")
    }

    func setCutFiles(_ files: [URL], from application: String) {
        cutFiles = files
        sourceApplication = application
        cutTimestamp = Date()
        hasCutFiles = !files.isEmpty

        logger.info("StateManager: Stored \(files.count) cut files from \(application)")

        startCutTimeoutTimer()
    }

    func getCutFiles() -> [URL] {
        return cutFiles
    }

    func clearCutFiles() {
        guard !cutFiles.isEmpty else { return }

        cutFiles.removeAll()
        sourceApplication = nil
        cutTimestamp = nil
        hasCutFiles = false
        hasCut = false

        cutTimeoutTimer?.invalidate()
        cutTimeoutTimer = nil

        logger.info("StateManager: Cleared cut files")
    }

    func getSourceApplication() -> String? {
        return sourceApplication
    }

    func getCutTimestamp() -> Date? {
        return cutTimestamp
    }

    func areCutFilesExpired() -> Bool {
        guard let timestamp = cutTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) > cutTimeout
    }

    func recordPasteOperation() {
        clearCutFiles()
        logger.info("StateManager: Recorded paste operation")
    }

    private func handleTimeoutChange(_ newTimeout: TimeInterval) {
        if hasCutFiles {
            startCutTimeoutTimer()
        }
    }

    private func startCutTimeoutTimer() {
        cutTimeoutTimer?.invalidate()

        cutTimeoutTimer = Timer.scheduledTimer(withTimeInterval: cutTimeout, repeats: false) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleCutTimeout()
            }
        }
    }

    private func handleCutTimeout() {
        logger.info("StateManager: Cut files expired due to timeout")
        clearCutFiles()
    }
}
