import Foundation

struct AppConfiguration: Codable, Equatable, Sendable {
    
    var isEnabled: Bool
    
    var startAtLogin: Bool
    
    var hideMenuBarIcon: Bool
    
    var targetApplications: [String]
    
    var enableVisualFeedback: Bool
    
    var enableSoundFeedback: Bool
    
    var cutTimeout: TimeInterval
    
    var enableNotifications: Bool
    
    var enableDebugLogging: Bool
    
    static let `default` = AppConfiguration(
        isEnabled: true,
        startAtLogin: false,
        hideMenuBarIcon: false,
        targetApplications: [
            "com.apple.finder",
            "com.apple.PathFinder",
            "com.cocoatech.PathFinder"
        ],
        enableVisualFeedback: true,
        enableSoundFeedback: false,
        cutTimeout: 300.0,
        enableNotifications: true,
        enableDebugLogging: false
    )
    
    func isValid() -> Bool {
        return cutTimeout > 0 && cutTimeout <= 3600 && !targetApplications.isEmpty
    }
    
    func validated() -> AppConfiguration {
        var config = self
        
        if config.cutTimeout <= 0 || config.cutTimeout > 3600 {
            config.cutTimeout = AppConfiguration.default.cutTimeout
        }
        
        if config.targetApplications.isEmpty {
            config.targetApplications = AppConfiguration.default.targetApplications
        }
        
        return config
    }
}
