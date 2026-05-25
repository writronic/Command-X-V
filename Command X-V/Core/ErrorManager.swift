import Foundation
import Cocoa
import os.log

@MainActor
class ErrorManager {

    static let shared = ErrorManager()

    enum CommandXVError: LocalizedError, Equatable {
        case permissionDenied
        case accessibilityNotEnabled
        case eventProcessingFailed(String)
        case fileOperationFailed(String)
        case applicationNotFound(String)
        case configurationError(String)
        case networkError(String)
        case unknownError(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Permission denied"
            case .accessibilityNotEnabled:
                return "Accessibility access not enabled"
            case .eventProcessingFailed(let details):
                return "Event processing failed: \(details)"
            case .fileOperationFailed(let details):
                return "File operation failed: \(details)"
            case .applicationNotFound(let appName):
                return "Application not found: \(appName)"
            case .configurationError(let details):
                return "Configuration error: \(details)"
            case .networkError(let details):
                return "Network error: \(details)"
            case .unknownError(let details):
                return "Unknown error: \(details)"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .permissionDenied, .accessibilityNotEnabled:
                return "Please grant accessibility permission in System Settings > Privacy & Security > Accessibility"
            case .eventProcessingFailed:
                return "Try restarting the application"
            case .fileOperationFailed:
                return "Check file permissions and try again"
            case .applicationNotFound:
                return "Make sure the application is installed and try again"
            case .configurationError:
                return "Reset configuration to defaults or check settings"
            case .networkError:
                return "Check your internet connection and try again"
            case .unknownError:
                return "Please restart the application and try again"
            }
        }
    }

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "ErrorManager")
    private var errorHistory: [ErrorRecord] = []
    private let maxErrorHistory = 100

    private struct ErrorRecord {
        let error: CommandXVError
        let timestamp: Date
        let context: String?
    }

    private init() {
        logger.info("ErrorManager: Initialized")
    }

    func handleError(_ error: CommandXVError, context: String? = nil) {
        logError(error, context: context)

        addToHistory(error, context: context)

        if ConfigurationManager.shared.configuration.enableNotifications {
            showErrorNotification(error)
        }
    }

    func showPermissionError() {
        let error = CommandXVError.accessibilityNotEnabled
        handleError(error, context: "Permission check")

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Command X-V needs accessibility permission to monitor keyboard events and perform file operations.

        Please go to System Settings > Privacy & Security > Accessibility and add Command X-V to the list of allowed applications.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }

    func showError(_ error: CommandXVError, context: String? = nil) {
        handleError(error, context: context)

        let alert = NSAlert()
        alert.messageText = "Command X-V Error"
        alert.informativeText = error.localizedDescription

        if let suggestion = error.recoverySuggestion {
            alert.informativeText += "\n\n\(suggestion)"
        }

        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")

        if case .configurationError = error {
            alert.addButton(withTitle: "Reset Settings")
        }

        let response = alert.runModal()

        if response == .alertSecondButtonReturn, case .configurationError = error {
            ConfigurationManager.shared.resetToDefaults()
        }
    }

    func logError(_ error: Error, context: String? = nil) {
        let contextString = context.map { " [\($0)]" } ?? ""
        logger.error("Error\(contextString): \(error.localizedDescription)")

        if ConfigurationManager.shared.configuration.enableDebugLogging {
            logger.debug("ErrorManager\(contextString): \(error)")
        }
    }

    func getErrorHistory() -> [String] {
        return errorHistory.suffix(10).map { record in
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium

            let contextString = record.context.map { " [\($0)]" } ?? ""
            return "\(formatter.string(from: record.timestamp))\(contextString): \(record.error.localizedDescription)"
        }
    }

    func clearErrorHistory() {
        errorHistory.removeAll()
        logger.info("Error history cleared")
    }

    private func addToHistory(_ error: CommandXVError, context: String?) {
        let record = ErrorRecord(error: error, timestamp: Date(), context: context)
        errorHistory.append(record)

        if errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst(errorHistory.count - maxErrorHistory)
        }
    }

    private func showErrorNotification(_ error: CommandXVError) {
    }

    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
