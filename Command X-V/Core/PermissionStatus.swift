import Foundation
import Cocoa
@preconcurrency import ApplicationServices

struct PermissionStatus: Equatable, Sendable {
    let accessibility: PermissionState
    let fullDiskAccess: PermissionState
    let notifications: PermissionState
    let lastChecked: Date
    
    init(accessibility: PermissionState = .unknown,
         fullDiskAccess: PermissionState = .unknown,
         notifications: PermissionState = .unknown,
         lastChecked: Date = Date()) {
        self.accessibility = accessibility
        self.fullDiskAccess = fullDiskAccess
        self.notifications = notifications
        self.lastChecked = lastChecked
    }
    
    var allRequiredGranted: Bool {
        return accessibility == .granted
    }
    
    var hasAnyDenied: Bool {
        return accessibility == .denied || fullDiskAccess == .denied || notifications == .denied
    }
    
    var summary: String {
        var components: [String] = []
        
        if accessibility != .granted {
            components.append("Accessibility: \(accessibility.displayName)")
        }
        if fullDiskAccess == .denied {
            components.append("Full Disk Access: \(fullDiskAccess.displayName)")
        }
        if notifications == .denied {
            components.append("Notifications: \(notifications.displayName)")
        }
        
        return components.isEmpty ? "All permissions granted" : components.joined(separator: ", ")
    }
}

enum PermissionState: String, CaseIterable, Sendable {
    case unknown = "unknown"
    case granted = "granted"
    case denied = "denied"
    case restricted = "restricted"
    
    var displayName: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        }
    }
    
    var isGranted: Bool {
        return self == .granted
    }
    
    var needsUserAction: Bool {
        return self == .denied || self == .unknown
    }
}

struct PermissionInfo: Sendable {
    let type: PermissionType
    let title: String
    let description: String
    let reason: String
    let systemPreferencesPane: String?
    let isRequired: Bool
    
    static let accessibility = PermissionInfo(
        type: .accessibility,
        title: "Accessibility",
        description: "Allows Command X-V to monitor keyboard shortcuts and interact with other applications",
        reason: "Required to detect Cmd+X and Cmd+V shortcuts and perform file operations in Finder",
        systemPreferencesPane: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        isRequired: true
    )
    
    static let fullDiskAccess = PermissionInfo(
        type: .fullDiskAccess,
        title: "Full Disk Access",
        description: "Allows Command X-V to access files in protected locations",
        reason: "Optional: Enables cut/paste operations for files in protected system directories",
        systemPreferencesPane: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
        isRequired: false
    )
    
    static let notifications = PermissionInfo(
        type: .notifications,
        title: "Notifications",
        description: "Allows Command X-V to show operation feedback notifications",
        reason: "Optional: Provides visual feedback for cut and paste operations",
        systemPreferencesPane: nil,
        isRequired: false
    )
}

enum PermissionType: String, CaseIterable, Sendable {
    case accessibility = "accessibility"
    case fullDiskAccess = "fullDiskAccess"
    case notifications = "notifications"
    
    var info: PermissionInfo {
        switch self {
        case .accessibility:
            return .accessibility
        case .fullDiskAccess:
            return .fullDiskAccess
        case .notifications:
            return .notifications
        }
    }
}

class PermissionChecker {
    
    static func checkAllPermissions() -> PermissionStatus {
        return PermissionStatus(
            accessibility: checkAccessibilityPermission(),
            fullDiskAccess: .unknown,
            notifications: .unknown,
            lastChecked: Date()
        )
    }
    
    static func checkAccessibilityPermission() -> PermissionState {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: false]
        let isGranted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return isGranted ? .granted : .denied
    }
    
    static func checkFullDiskAccessPermission() -> PermissionState {
        let protectedPath = "/Library/Application Support"
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: protectedPath)
            return contents.isEmpty ? .unknown : .granted
        } catch {
            return .denied
        }
    }
    
    static func checkNotificationPermission() -> PermissionState {
        return .unknown
    }
    
    static func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    static func openSystemPreferences(for permissionType: PermissionType) {
        guard let urlString = permissionType.info.systemPreferencesPane,
              let url = URL(string: urlString) else {
            let fallbackURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
            NSWorkspace.shared.open(fallbackURL)
            return
        }
        
        NSWorkspace.shared.open(url)
    }
}
