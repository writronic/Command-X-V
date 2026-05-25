import Cocoa
import os.log

@MainActor
class MenuBarVisibilityManager {

    private(set) var isMenuBarVisible: Bool = true

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "MenuBarVisibilityManager")
    private let userDefaults = UserDefaults.standard
    private var customDialogWindow: NSWindow?

    var onVisibilityChanged: ((Bool) -> Void)?

    private struct Constants {
        static let menuBarVisibleKey = "ShowMenuBarIcon"
        static let terminalCommand = "defaults write com.writronic.commandxv ShowMenuBarIcon -bool true"
    }

    static let restoreTerminalCommand = Constants.terminalCommand

    private var restoreShortcutDisplayString: String {
        ConfigurationManager.shared.shortcutConfiguration.hideMenuBarShortcut.displayString
    }

    init() {
        loadSavedPreference()
        syncConfigurationState()
        logger.info("MenuBarVisibilityManager: Initialized with visibility: \(self.isMenuBarVisible)")
    }

    func toggleVisibility() {
        isMenuBarVisible.toggle()
        savePreference()
        onVisibilityChanged?(isMenuBarVisible)

        logger.info("Menu bar visibility toggled to: \(self.isMenuBarVisible)")
    }

    func showMenuBar() {
        guard !isMenuBarVisible else { return }

        isMenuBarVisible = true
        savePreference()
        ConfigurationManager.shared.hideMenuBarIcon = false
        onVisibilityChanged?(isMenuBarVisible)

        logger.info("Menu bar restored via shortcut/terminal command")
    }

    func hideMenuBar() {
        guard isMenuBarVisible else { return }

        isMenuBarVisible = false
        savePreference()
        ConfigurationManager.shared.hideMenuBarIcon = true
        onVisibilityChanged?(isMenuBarVisible)

        logger.info("Menu bar hidden")
    }

    func showRestoreInstructions(completion: @escaping (Bool) -> Void) {
        showCustomRestoreDialog(completion: completion)
        logger.info("Restore instructions dialog shown")
    }

    private func showCustomRestoreDialog(completion: @escaping (Bool) -> Void) {
        let dialogWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        dialogWindow.title = ""
        dialogWindow.isReleasedWhenClosed = false

        let contentView = NSView(frame: dialogWindow.contentRect(forFrameRect: dialogWindow.frame))
        dialogWindow.contentView = contentView

        let iconImageView = NSImageView(frame: NSRect(x: 175, y: 250, width: 70, height: 70))
        if let logoImage = NSApp.applicationIconImage {
            logoImage.size = NSSize(width: 100, height: 100)
            iconImageView.image = logoImage
        }
        contentView.addSubview(iconImageView)

        let titleLabel = NSTextField(labelWithString: "Restore Menu Bar Icon")
        titleLabel.frame = NSRect(x: 20, y: 210, width: 380, height: 25)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)

        let methodsLabel = NSTextField(labelWithString: "Use one of these methods:")
        methodsLabel.frame = NSRect(x: 20, y: 185, width: 380, height: 20)
        methodsLabel.font = NSFont.systemFont(ofSize: 13)
        methodsLabel.alignment = .center
        contentView.addSubview(methodsLabel)

        let textView = NSTextView(frame: NSRect(x: 30, y: 90, width: 360, height: 90))
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor.clear
        textView.textContainer?.lineFragmentPadding = 0

        let attributedText = NSMutableAttributedString()

        let shortcutPrefix = NSAttributedString(
            string: "• Shortcut: ",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )
        attributedText.append(shortcutPrefix)

        let shortcutKeys = NSAttributedString(
            string: restoreShortcutDisplayString,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        attributedText.append(shortcutKeys)

        attributedText.append(NSAttributedString(string: "\n\n"))

        let terminalPrefix = NSAttributedString(
            string: "• Terminal: ",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )
        attributedText.append(terminalPrefix)

        let terminalCommand = NSAttributedString(
            string: Constants.terminalCommand,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        attributedText.append(terminalCommand)

        attributedText.append(NSAttributedString(string: "\n"))

        let italicFont = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 14),
            toHaveTrait: .italicFontMask
        )
        let restartNote = NSAttributedString(
            string: "(Restart app after running)",
            attributes: [.font: italicFont]
        )
        attributedText.append(restartNote)

        textView.textStorage?.setAttributedString(attributedText)
        contentView.addSubview(textView)

        let buttonWidth: CGFloat = 140
        let buttonSpacing: CGFloat = 20
        let totalButtonWidth = (buttonWidth * 2) + buttonSpacing
        let buttonStartX = (420 - totalButtonWidth) / 2

        let cancelButton = NSButton(frame: NSRect(x: buttonStartX, y: 20, width: buttonWidth, height: 32))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        let hideButton = NSButton(frame: NSRect(x: buttonStartX + buttonWidth + buttonSpacing, y: 20, width: buttonWidth, height: 32))
        hideButton.title = "Hide the icon"
        hideButton.bezelStyle = .rounded
        contentView.addSubview(hideButton)

        self.customDialogWindow = dialogWindow

        guard let parentWindow = NSApp.windows.first(where: { $0.title == "Settings" && $0.isVisible }) else {
            dialogWindow.center()
            dialogWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            cancelButton.target = self
            cancelButton.action = #selector(cancelButtonClicked(_:))
            hideButton.target = self
            hideButton.action = #selector(hideButtonClicked(_:))
            self.dialogCompletion = completion
            return
        }

        self.dialogCompletion = completion

        cancelButton.target = self
        cancelButton.action = #selector(sheetCancelClicked(_:))
        hideButton.target = self
        hideButton.action = #selector(sheetHideClicked(_:))

        parentWindow.beginSheet(dialogWindow)
    }

    private var dialogCompletion: ((Bool) -> Void)?

    @objc private func sheetHideClicked(_ sender: NSButton) {
        guard let dialogWindow = customDialogWindow,
              let parentWindow = dialogWindow.sheetParent else { return }
        parentWindow.endSheet(dialogWindow)
        customDialogWindow = nil
        hideMenuBar()
        dialogCompletion?(true)
        dialogCompletion = nil
    }

    @objc private func sheetCancelClicked(_ sender: NSButton) {
        guard let dialogWindow = customDialogWindow,
              let parentWindow = dialogWindow.sheetParent else { return }
        parentWindow.endSheet(dialogWindow)
        customDialogWindow = nil
        dialogCompletion?(false)
        dialogCompletion = nil
    }

    @objc private func hideButtonClicked(_ sender: NSButton) {
        customDialogWindow?.close()
        customDialogWindow = nil
        hideMenuBar()
        dialogCompletion?(true)
        dialogCompletion = nil
    }

    @objc private func cancelButtonClicked(_ sender: NSButton) {
        customDialogWindow?.close()
        customDialogWindow = nil
        dialogCompletion?(false)
        dialogCompletion = nil
    }

    private func loadSavedPreference() {
        isMenuBarVisible = userDefaults.object(forKey: Constants.menuBarVisibleKey) as? Bool ?? true
    }

    private func syncConfigurationState() {
        let configHidden = ConfigurationManager.shared.configuration.hideMenuBarIcon
        if isMenuBarVisible && configHidden {
            ConfigurationManager.shared.hideMenuBarIcon = false
        } else if !isMenuBarVisible && !configHidden {
            ConfigurationManager.shared.hideMenuBarIcon = true
        }
    }

    private func savePreference() {
        userDefaults.set(isMenuBarVisible, forKey: Constants.menuBarVisibleKey)
    }
}

extension MenuBarVisibilityManager {

    func processRestoreShortcut() {
        showMenuBar()
    }
}
