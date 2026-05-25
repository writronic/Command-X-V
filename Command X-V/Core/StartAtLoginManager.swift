import Foundation
import Cocoa
import os.log
@preconcurrency import CoreServices

@MainActor
class StartAtLoginManager {

    static let shared = StartAtLoginManager()

    private(set) var isEnabled: Bool = false

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "StartAtLoginManager")

    private static let launchAgentPlist: NSDictionary = [
        "Label": "com.writronic.commandxv",
        "Program": Bundle.main.executablePath ?? "/Applications/Command X-V.app/Contents/MacOS/Command X-V",
        "RunAtLoad": true,
        "KeepAlive": false,
        "LimitLoadToSessionType": "Aqua",
        "AssociatedBundleIdentifiers": "com.writronic.commandxv",
        "ProcessType": "Interactive",
        "LegacyTimers": true,
    ]

    private init() {
        logger.info("StartAtLoginManager initialized")
        updateStatus()
    }

    func toggle() {
        setEnabled(!isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        logger.info("Setting start at login to: \(enabled)")

        if (StartAtLoginManager.self as AvoidDeprecationWarnings.Type).removeLoginItemIfPresent() && !enabled {
            logger.info("Removed legacy login item, enabling LaunchAgent instead")
            do {
                try writePlistToDisk(true)
                updateStatus()
            } catch {
                logger.error("Failed to write plist after removing legacy login item: \(error.localizedDescription)")
            }
            return
        }

        do {
            try writePlistToDisk(enabled)
            updateStatus()
        } catch {
            logger.error("Failed to set start at login: \(error.localizedDescription)")
        }
    }

    func updateStatus() {
        let plistPath = getLaunchAgentPlistPath()
        let newIsEnabled = FileManager.default.fileExists(atPath: plistPath.path)

        isEnabled = newIsEnabled

        logger.info("Start at login status: \(newIsEnabled ? "enabled" : "disabled")")
    }

    private func writePlistToDisk(_ enabled: Bool) throws {
        var launchAgentsPath = (try? FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)) ?? URL(fileURLWithPath: "~/Library", isDirectory: true)
        launchAgentsPath.appendPathComponent("LaunchAgents", isDirectory: true)
        if !FileManager.default.fileExists(atPath: launchAgentsPath.path) {
            try FileManager.default.createDirectory(at: launchAgentsPath, withIntermediateDirectories: false)
            logger.debug("\(launchAgentsPath.absoluteString) created")
        }
        launchAgentsPath.appendPathComponent("com.writronic.commandxv.plist", isDirectory: false)
        if enabled {
            let data = try PropertyListSerialization.data(fromPropertyList: Self.launchAgentPlist, format: .xml, options: 0)
            try data.write(to: launchAgentsPath, options: [.atomic])
            logger.debug("\(launchAgentsPath.absoluteString) written")
        } else {
            if FileManager.default.fileExists(atPath: launchAgentsPath.path) {
                try FileManager.default.removeItem(at: launchAgentsPath)
                logger.debug("\(launchAgentsPath.absoluteString) removed")
            }
        }
    }

    private func getLaunchAgentPlistPath() -> URL {
        var launchAgentsPath = (try? FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)) ?? URL(fileURLWithPath: "~/Library", isDirectory: true)
        launchAgentsPath.appendPathComponent("LaunchAgents", isDirectory: true)
        launchAgentsPath.appendPathComponent("com.writronic.commandxv.plist", isDirectory: false)
        return launchAgentsPath
    }

    @available(OSX, deprecated: 10.11)
    static func removeLoginItemIfPresent() -> Bool {
        if #available(macOS 14.0, *) {
            return false
        }

        var removed = false
        if let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue(),
           let loginItemsSnapshot = LSSharedFileListCopySnapshot(loginItems, nil)?.takeRetainedValue() as? [LSSharedFileListItem] {
            let appUrl = URL(fileURLWithPath: Bundle.main.bundlePath)
            for item in loginItemsSnapshot {
                let itemUrl = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() as? URL
                if (itemUrl?.lastPathComponent == appUrl.lastPathComponent) {
                    LSSharedFileListItemRemove(loginItems, item)
                    removed = true
                }
            }
        }
        return removed
    }
}

@MainActor
private protocol AvoidDeprecationWarnings {
    static func removeLoginItemIfPresent() -> Bool
}

extension StartAtLoginManager: AvoidDeprecationWarnings {}
