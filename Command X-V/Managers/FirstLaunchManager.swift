import Foundation
import os.log

@MainActor
class FirstLaunchManager {
    
    static let shared = FirstLaunchManager()
    private init() {}
    
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "FirstLaunchManager")
    
    private enum Keys {
        static let hasCompletedOnboarding = "HasCompletedOnboarding"
        static let firstLaunchDate = "FirstLaunchDate"
        static let appVersion = "AppVersion"
        static let launchCount = "LaunchCount"
    }
    
    var isFirstLaunch: Bool {
        return !UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
    }
    
    var hasCompletedOnboarding: Bool {
        return UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
    }
    
    var firstLaunchDate: Date? {
        return UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date
    }
    
    var launchCount: Int {
        return UserDefaults.standard.integer(forKey: Keys.launchCount)
    }
    
    var firstLaunchAppVersion: String? {
        return UserDefaults.standard.string(forKey: Keys.appVersion)
    }
    
    func recordLaunch() {
        let currentLaunchCount = launchCount
        let newLaunchCount = currentLaunchCount + 1
        
        UserDefaults.standard.set(newLaunchCount, forKey: Keys.launchCount)
        
        if currentLaunchCount == 0 {
            UserDefaults.standard.set(Date(), forKey: Keys.firstLaunchDate)
            
            if let appVersion = getCurrentAppVersion() {
                UserDefaults.standard.set(appVersion, forKey: Keys.appVersion)
            }
            
            logger.info("First launch recorded - version: \(self.getCurrentAppVersion() ?? "unknown")")
        }
        
        logger.debug("Launch count updated: \(newLaunchCount)")
    }
    
    func markOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: Keys.hasCompletedOnboarding)
        
        logger.info("Onboarding marked as completed")
    }
    
    func resetOnboardingState() {
        UserDefaults.standard.removeObject(forKey: Keys.hasCompletedOnboarding)
        UserDefaults.standard.removeObject(forKey: Keys.firstLaunchDate)
        UserDefaults.standard.removeObject(forKey: Keys.appVersion)
        UserDefaults.standard.removeObject(forKey: Keys.launchCount)
        
        logger.warning("Onboarding state reset")
    }
    
    func isVersionUpgrade() -> Bool {
        guard let firstVersion = firstLaunchAppVersion,
              let currentVersion = getCurrentAppVersion() else {
            return false
        }
        
        return firstVersion != currentVersion
    }
    
    func getOnboardingSummary() -> String {
        var summary = "Onboarding Summary:\n"
        summary += "- Is First Launch: \(isFirstLaunch)\n"
        summary += "- Has Completed Onboarding: \(hasCompletedOnboarding)\n"
        summary += "- Launch Count: \(launchCount)\n"
        
        if let firstDate = firstLaunchDate {
            summary += "- First Launch Date: \(firstDate.formatted())\n"
        }
        
        if let firstVersion = firstLaunchAppVersion {
            summary += "- First Launch Version: \(firstVersion)\n"
        }
        
        if let currentVersion = getCurrentAppVersion() {
            summary += "- Current Version: \(currentVersion)\n"
        }
        
        summary += "- Is Version Upgrade: \(isVersionUpgrade())"
        
        return summary
    }
    
    private func getCurrentAppVersion() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}

#if DEBUG
extension FirstLaunchManager {
    
    func forceShowOnboarding() {
        UserDefaults.standard.set(false, forKey: Keys.hasCompletedOnboarding)
        logger.debug("Forced onboarding to show")
    }
    
    func simulateFirstLaunch() {
        resetOnboardingState()
        recordLaunch()
        logger.debug("Simulated first launch")
    }
}
#endif
