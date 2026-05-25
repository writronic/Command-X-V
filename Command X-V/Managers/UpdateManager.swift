import Foundation
import Sparkle
import os.log

@MainActor
final class UpdateManager {

    static let shared = UpdateManager()

    private let updaterController: SPUStandardUpdaterController
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "UpdateManager")

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        if !UserDefaults.standard.bool(forKey: "CommandXV_AutoCheckUpdatesConfigured") {
            updaterController.updater.automaticallyChecksForUpdates = false
            UserDefaults.standard.set(true, forKey: "CommandXV_AutoCheckUpdatesConfigured")
        }

        logger.info("UpdateManager: Initialized with Sparkle updater")
    }

    var updater: SPUStandardUpdaterController {
        return updaterController
    }

    var canCheckForUpdates: Bool {
        return updaterController.updater.canCheckForUpdates
    }
}
