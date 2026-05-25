import Foundation
import os.log

@MainActor
class ConfigurationManager {

    static let shared = ConfigurationManager()

    private(set) var configuration: AppConfiguration
    private(set) var shortcutConfiguration: ShortcutConfiguration

    var onConfigurationChanged: ((AppConfiguration) -> Void)?
    var onShortcutConfigurationChanged: ((ShortcutConfiguration) -> Void)?

    private let userDefaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "ConfigurationManager")

    private enum ConfigKeys: String {
        case configuration = "CommandXV_Configuration"
        case isEnabled = "CommandXV_IsEnabled"
        case startAtLogin = "CommandXV_StartAtLogin"
        case hideMenuBarIcon = "CommandXV_HideMenuBarIcon"
        case enableSounds = "CommandXV_EnableSounds"
        case enableVisualFeedback = "CommandXV_EnableVisualFeedback"
        case targetApplications = "CommandXV_TargetApplications"
        case cutTimeout = "CommandXV_CutTimeout"
        case enableNotifications = "CommandXV_EnableNotifications"
        case enableDebugLogging = "CommandXV_EnableDebugLogging"
        case shortcutConfiguration = "CommandXV_ShortcutConfiguration"
    }

    private init() {
        self.configuration = AppConfiguration.default
        self.shortcutConfiguration = ShortcutConfiguration.default
        setupDefaultValues()
        loadConfiguration()
        loadShortcutConfiguration()
        logger.info("ConfigurationManager: Initialized")
    }

    func loadConfiguration() {
        logger.info("ConfigurationManager: Loading configuration...")

        if let data = userDefaults.data(forKey: ConfigKeys.configuration.rawValue),
           let savedConfig = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            self.configuration = savedConfig.validated()
            logger.info("ConfigurationManager: Loaded saved configuration")
            return
        }

        var config = AppConfiguration.default

        config.isEnabled = userDefaults.bool(forKey: ConfigKeys.isEnabled.rawValue)
        config.startAtLogin = userDefaults.bool(forKey: ConfigKeys.startAtLogin.rawValue)
        config.hideMenuBarIcon = userDefaults.bool(forKey: ConfigKeys.hideMenuBarIcon.rawValue)
        config.enableSoundFeedback = userDefaults.bool(forKey: ConfigKeys.enableSounds.rawValue)
        config.enableVisualFeedback = userDefaults.bool(forKey: ConfigKeys.enableVisualFeedback.rawValue)
        config.enableNotifications = userDefaults.bool(forKey: ConfigKeys.enableNotifications.rawValue)
        config.enableDebugLogging = userDefaults.bool(forKey: ConfigKeys.enableDebugLogging.rawValue)

        if let apps = userDefaults.array(forKey: ConfigKeys.targetApplications.rawValue) as? [String] {
            config.targetApplications = apps
        }

        let timeout = userDefaults.double(forKey: ConfigKeys.cutTimeout.rawValue)
        if timeout > 0 {
            config.cutTimeout = timeout
        }

        self.configuration = config.validated()

        saveConfiguration()
        logger.info("ConfigurationManager: Migrated and loaded configuration")
    }

    func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(configuration)
            userDefaults.set(data, forKey: ConfigKeys.configuration.rawValue)
            logger.info("ConfigurationManager: Configuration saved")
        } catch {
            logger.error("ConfigurationManager: Failed to save configuration: \(error)")
        }
    }

    func updateConfiguration(_ newConfiguration: AppConfiguration) {
        let validatedConfig = newConfiguration.validated()
        guard validatedConfig != configuration else { return }

        let oldTimeout = configuration.cutTimeout
        configuration = validatedConfig
        saveConfiguration()

        onConfigurationChanged?(configuration)
        NotificationCenter.default.post(name: .configurationDidChange, object: nil)

        if oldTimeout != configuration.cutTimeout {
            StateManager.shared.handleConfigurationTimeoutChange(configuration.cutTimeout)
        }

        logger.info("ConfigurationManager: Configuration updated")
    }

    func loadShortcutConfiguration() {
        if let data = userDefaults.data(forKey: ConfigKeys.shortcutConfiguration.rawValue),
           let savedConfig = try? JSONDecoder().decode(ShortcutConfiguration.self, from: data) {
            self.shortcutConfiguration = savedConfig
            logger.info("ConfigurationManager: Loaded saved shortcut configuration")
        } else {
            self.shortcutConfiguration = ShortcutConfiguration.default
            logger.info("ConfigurationManager: Using default shortcut configuration")
        }
    }

    func saveShortcutConfiguration() {
        do {
            let data = try JSONEncoder().encode(shortcutConfiguration)
            userDefaults.set(data, forKey: ConfigKeys.shortcutConfiguration.rawValue)
            logger.info("ConfigurationManager: Shortcut configuration saved")
        } catch {
            logger.error("ConfigurationManager: Failed to save shortcut configuration: \(error)")
        }
    }

    func updateShortcutConfiguration(_ newConfiguration: ShortcutConfiguration) {
        guard newConfiguration != shortcutConfiguration else { return }

        shortcutConfiguration = newConfiguration
        saveShortcutConfiguration()
        onShortcutConfigurationChanged?(shortcutConfiguration)

        logger.info("ConfigurationManager: Shortcut configuration updated")
    }

    func resetToDefaults() {
        configuration = AppConfiguration.default
        saveConfiguration()
        logger.info("ConfigurationManager: Configuration reset to defaults")
    }

    var isEnabled: Bool {
        get { configuration.isEnabled }
        set {
            var config = configuration
            config.isEnabled = newValue
            updateConfiguration(config)
        }
    }

    var startAtLogin: Bool {
        get { configuration.startAtLogin }
        set {
            var config = configuration
            config.startAtLogin = newValue
            updateConfiguration(config)
        }
    }

    var hideMenuBarIcon: Bool {
        get { configuration.hideMenuBarIcon }
        set {
            var config = configuration
            config.hideMenuBarIcon = newValue
            updateConfiguration(config)
        }
    }

    private func setupDefaultValues() {
        let defaults: [String: Any] = [
            ConfigKeys.isEnabled.rawValue: AppConfiguration.default.isEnabled,
            ConfigKeys.startAtLogin.rawValue: AppConfiguration.default.startAtLogin,
            ConfigKeys.hideMenuBarIcon.rawValue: AppConfiguration.default.hideMenuBarIcon,
            ConfigKeys.enableSounds.rawValue: AppConfiguration.default.enableSoundFeedback,
            ConfigKeys.enableVisualFeedback.rawValue: AppConfiguration.default.enableVisualFeedback,
            ConfigKeys.targetApplications.rawValue: AppConfiguration.default.targetApplications,
            ConfigKeys.cutTimeout.rawValue: AppConfiguration.default.cutTimeout,
            ConfigKeys.enableNotifications.rawValue: AppConfiguration.default.enableNotifications,
            ConfigKeys.enableDebugLogging.rawValue: AppConfiguration.default.enableDebugLogging
        ]

        userDefaults.register(defaults: defaults)
    }
}

extension Notification.Name {
    static let configurationDidChange = Notification.Name("com.writronic.commandxv.configurationDidChange")
}
