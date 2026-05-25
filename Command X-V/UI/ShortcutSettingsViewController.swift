import Cocoa
import os.log

@MainActor
class ShortcutSettingsViewController: NSViewController {

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "ShortcutSettings")

    private var cutRecorderButton: NSButton!
    private var pasteRecorderButton: NSButton!
    private var hideMenuBarRecorderButton: NSButton!

    private var cutResetButton: NSButton!
    private var pasteResetButton: NSButton!
    private var hideMenuBarResetButton: NSButton!

    private var hideMenuBarSwitch: NSSwitch!
    private var restoreInfoContainer: NSView!
    private var restoreInfoLabel: NSTextField!

    private var activeRecorder: ShortcutAction?
    private var eventMonitor: Any?

    var onHideMenuBarRequested: ((@escaping (Bool) -> Void) -> Void)?

    private class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: SettingsLayout.detailWidth, height: SettingsLayout.contentHeight))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCurrentValues()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationDidChange),
            name: .configurationDidChange,
            object: nil
        )
        logger.info("Shortcut settings loaded")
    }

    private func setupUI() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let contentView = FlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor)
        ])

        var lastAnchor = contentView.topAnchor


        let headerLabel = NSTextField(labelWithString: "Keyboard Shortcuts")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        headerLabel.textColor = .secondaryLabelColor
        contentView.addSubview(headerLabel)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: lastAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
        lastAnchor = headerLabel.bottomAnchor

        let cutRow = createShortcutRow(
            title: "Cut",
            subtitle: "Intercepts this shortcut to mark files for moving.",
            action: .cut,
            recorderButton: &cutRecorderButton,
            resetButton: &cutResetButton
        )
        contentView.addSubview(cutRow)

        NSLayoutConstraint.activate([
            cutRow.topAnchor.constraint(equalTo: lastAnchor, constant: 12),
            cutRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            cutRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
        lastAnchor = cutRow.bottomAnchor

        let sep1 = createSeparator()
        contentView.addSubview(sep1)
        NSLayoutConstraint.activate([
            sep1.topAnchor.constraint(equalTo: lastAnchor, constant: 12),
            sep1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            sep1.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            sep1.heightAnchor.constraint(equalToConstant: 1)
        ])
        lastAnchor = sep1.bottomAnchor

        let pasteRow = createShortcutRow(
            title: "Paste",
            subtitle: "Intercepts this shortcut to move the cut files.",
            action: .paste,
            recorderButton: &pasteRecorderButton,
            resetButton: &pasteResetButton
        )
        contentView.addSubview(pasteRow)

        NSLayoutConstraint.activate([
            pasteRow.topAnchor.constraint(equalTo: lastAnchor, constant: 12),
            pasteRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            pasteRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
        lastAnchor = pasteRow.bottomAnchor

        let sep2 = createSeparator()
        contentView.addSubview(sep2)
        NSLayoutConstraint.activate([
            sep2.topAnchor.constraint(equalTo: lastAnchor, constant: 12),
            sep2.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            sep2.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            sep2.heightAnchor.constraint(equalToConstant: 1)
        ])
        lastAnchor = sep2.bottomAnchor

        let hideRow = createShortcutRow(
            title: "Restore Menu Bar Icon",
            subtitle: "Global shortcut to restore the hidden menu bar icon.",
            action: .hideMenuBar,
            recorderButton: &hideMenuBarRecorderButton,
            resetButton: &hideMenuBarResetButton
        )
        contentView.addSubview(hideRow)

        NSLayoutConstraint.activate([
            hideRow.topAnchor.constraint(equalTo: lastAnchor, constant: 12),
            hideRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            hideRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
        lastAnchor = hideRow.bottomAnchor

        let sep3 = createSeparator()
        contentView.addSubview(sep3)
        NSLayoutConstraint.activate([
            sep3.topAnchor.constraint(equalTo: lastAnchor, constant: 16),
            sep3.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            sep3.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            sep3.heightAnchor.constraint(equalToConstant: 1)
        ])
        lastAnchor = sep3.bottomAnchor

        let hideToggleRow = createToggleRow(
            title: "Hide Menu Bar Icon",
            subtitle: "Remove the Command X-V icon from the menu bar.",
            switchAction: #selector(hideMenuBarToggled(_:)),
            switchView: &hideMenuBarSwitch
        )
        contentView.addSubview(hideToggleRow)

        NSLayoutConstraint.activate([
            hideToggleRow.topAnchor.constraint(equalTo: lastAnchor, constant: 16),
            hideToggleRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            hideToggleRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
        lastAnchor = hideToggleRow.bottomAnchor

        restoreInfoContainer = createRestoreInfoView()
        restoreInfoContainer.isHidden = true
        contentView.addSubview(restoreInfoContainer)

        NSLayoutConstraint.activate([
            restoreInfoContainer.topAnchor.constraint(equalTo: lastAnchor, constant: 8),
            restoreInfoContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            restoreInfoContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
        lastAnchor = restoreInfoContainer.bottomAnchor

        let bottomSpacer = NSView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bottomSpacer)
        NSLayoutConstraint.activate([
            bottomSpacer.topAnchor.constraint(equalTo: lastAnchor, constant: 20),
            bottomSpacer.heightAnchor.constraint(equalToConstant: 0),
            bottomSpacer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomSpacer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        ])
    }


    private func createShortcutRow(
        title: String,
        subtitle: String,
        action: ShortcutAction,
        recorderButton: inout NSButton!,
        resetButton: inout NSButton!
    ) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        container.addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.preferredMaxLayoutWidth = 200
        container.addSubview(subtitleLabel)

        let recorder = NSButton(title: "", target: self, action: #selector(recorderClicked(_:)))
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.bezelStyle = .rounded
        recorder.isBordered = true
        recorder.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        recorder.tag = actionToTag(action)
        recorder.setContentHuggingPriority(.required, for: .horizontal)
        container.addSubview(recorder)
        recorderButton = recorder

        let reset = NSButton(image: NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "Reset to default")!, target: self, action: #selector(resetClicked(_:)))
        reset.translatesAutoresizingMaskIntoConstraints = false
        reset.bezelStyle = .circular
        reset.isBordered = false
        reset.tag = actionToTag(action)
        reset.setContentHuggingPriority(.required, for: .horizontal)
        container.addSubview(reset)
        resetButton = reset

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: recorder.leadingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: recorder.leadingAnchor, constant: -12),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            reset.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            reset.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            reset.widthAnchor.constraint(equalToConstant: 20),
            reset.heightAnchor.constraint(equalToConstant: 20),

            recorder.trailingAnchor.constraint(equalTo: reset.leadingAnchor, constant: -4),
            recorder.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            recorder.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])

        return container
    }


    private func createToggleRow(
        title: String,
        subtitle: String,
        switchAction: Selector,
        switchView: inout NSSwitch!
    ) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        container.addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.preferredMaxLayoutWidth = 260
        container.addSubview(subtitleLabel)

        let toggle = NSSwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.target = self
        toggle.action = switchAction
        toggle.controlSize = .regular
        container.addSubview(toggle)
        switchView = toggle

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        return container
    }


    private func createSeparator() -> NSView {
        let sep = NSView()
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        return sep
    }


    private func createRestoreInfoView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.6).cgColor
        container.layer?.cornerRadius = 8

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Info")
        icon.contentTintColor = .secondaryLabelColor
        icon.setContentHuggingPriority(.required, for: .horizontal)
        container.addSubview(icon)

        let shortcutDisplay = ConfigurationManager.shared.shortcutConfiguration.hideMenuBarShortcut.displayString
        let terminalCommand = MenuBarVisibilityManager.restoreTerminalCommand

        restoreInfoLabel = NSTextField(wrappingLabelWithString: "To restore the icon, press \(shortcutDisplay) or run:\n\(terminalCommand)")
        restoreInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        restoreInfoLabel.font = NSFont.systemFont(ofSize: 11)
        restoreInfoLabel.textColor = .secondaryLabelColor
        restoreInfoLabel.isSelectable = true
        container.addSubview(restoreInfoLabel)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),

            restoreInfoLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            restoreInfoLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            restoreInfoLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            restoreInfoLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        return container
    }


    private func loadCurrentValues() {
        let shortcutConfig = ConfigurationManager.shared.shortcutConfiguration
        let appConfig = ConfigurationManager.shared.configuration

        updateRecorderButton(cutRecorderButton, with: shortcutConfig.cutShortcut)
        updateRecorderButton(pasteRecorderButton, with: shortcutConfig.pasteShortcut)
        updateRecorderButton(hideMenuBarRecorderButton, with: shortcutConfig.hideMenuBarShortcut)

        hideMenuBarSwitch.state = appConfig.hideMenuBarIcon ? .on : .off
        restoreInfoContainer.isHidden = !appConfig.hideMenuBarIcon
    }

    private func updateRecorderButton(_ button: NSButton, with entry: ShortcutEntry) {
        button.title = entry.displayString
        button.contentTintColor = nil
    }

    private func updateRestoreInfoText() {
        let shortcutDisplay = ConfigurationManager.shared.shortcutConfiguration.hideMenuBarShortcut.displayString
        let terminalCommand = MenuBarVisibilityManager.restoreTerminalCommand
        restoreInfoLabel.stringValue = "To restore the icon, press \(shortcutDisplay) or run:\n\(terminalCommand)"
    }


    private func actionToTag(_ action: ShortcutAction) -> Int {
        switch action {
        case .cut: return 100
        case .paste: return 101
        case .hideMenuBar: return 102
        }
    }

    private func tagToAction(_ tag: Int) -> ShortcutAction? {
        switch tag {
        case 100: return .cut
        case 101: return .paste
        case 102: return .hideMenuBar
        default: return nil
        }
    }

    private func recorderButton(for action: ShortcutAction) -> NSButton? {
        switch action {
        case .cut: return cutRecorderButton
        case .paste: return pasteRecorderButton
        case .hideMenuBar: return hideMenuBarRecorderButton
        }
    }


    @objc private func recorderClicked(_ sender: NSButton) {
        guard let action = tagToAction(sender.tag) else { return }

        if activeRecorder == action {
            stopRecording()
            return
        }

        if activeRecorder != nil {
            stopRecording()
        }

        startRecording(for: action)
    }

    private func startRecording(for action: ShortcutAction) {
        activeRecorder = action

        guard let button = recorderButton(for: action) else { return }
        button.title = "Press shortcut…"
        button.contentTintColor = .controlAccentColor

        logger.info("Started recording shortcut for: \(action.rawValue)")

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }

            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = flags.contains(.command) || flags.contains(.control) || flags.contains(.option) || flags.contains(.shift)

            guard hasModifier else {
                return nil
            }

            let cgFlags: CGEventFlags = {
                var f = CGEventFlags()
                if flags.contains(.command) { f.insert(.maskCommand) }
                if flags.contains(.control) { f.insert(.maskControl) }
                if flags.contains(.option) { f.insert(.maskAlternate) }
                if flags.contains(.shift) { f.insert(.maskShift) }
                return f
            }()

            let newEntry = ShortcutEntry(
                keyCode: event.keyCode,
                modifierFlagsRaw: cgFlags.rawValue,
                keyCharacter: event.charactersIgnoringModifiers
            )

            self.applyShortcut(newEntry, for: action)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        if let action = activeRecorder, let button = recorderButton(for: action) {
            let config = ConfigurationManager.shared.shortcutConfiguration
            let entry: ShortcutEntry
            switch action {
            case .cut: entry = config.cutShortcut
            case .paste: entry = config.pasteShortcut
            case .hideMenuBar: entry = config.hideMenuBarShortcut
            }
            updateRecorderButton(button, with: entry)
        }

        activeRecorder = nil
        logger.info("Stopped recording shortcut")
    }

    private func applyShortcut(_ entry: ShortcutEntry, for action: ShortcutAction) {
        var config = ConfigurationManager.shared.shortcutConfiguration

        if let conflict = config.conflictingAction(for: entry, excluding: action) {
            showConflictAlert(entry: entry, conflictingAction: conflict)
            logger.warning("Shortcut conflict: \(entry.displayString) already used by \(conflict.rawValue)")
            return
        }

        switch action {
        case .cut: config.cutShortcut = entry
        case .paste: config.pasteShortcut = entry
        case .hideMenuBar: config.hideMenuBarShortcut = entry
        }

        ConfigurationManager.shared.updateShortcutConfiguration(config)

        if let button = recorderButton(for: action) {
            updateRecorderButton(button, with: entry)
        }

        if action == .hideMenuBar {
            updateRestoreInfoText()
        }

        logger.info("Shortcut updated for \(action.rawValue): \(entry.displayString)")
    }

    private func showConflictAlert(entry: ShortcutEntry, conflictingAction: ShortcutAction) {
        let alert = NSAlert()
        alert.messageText = "Shortcut Conflict"
        alert.informativeText = "\(entry.displayString) is already assigned to \"\(conflictingAction.rawValue)\". Please choose a different shortcut."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }


    @objc private func resetClicked(_ sender: NSButton) {
        guard let action = tagToAction(sender.tag) else { return }

        var config = ConfigurationManager.shared.shortcutConfiguration
        let defaultConfig = ShortcutConfiguration.default

        let defaultEntry: ShortcutEntry
        switch action {
        case .cut:
            defaultEntry = defaultConfig.cutShortcut
            config.cutShortcut = defaultEntry
        case .paste:
            defaultEntry = defaultConfig.pasteShortcut
            config.pasteShortcut = defaultEntry
        case .hideMenuBar:
            defaultEntry = defaultConfig.hideMenuBarShortcut
            config.hideMenuBarShortcut = defaultEntry
        }

        if let conflict = config.conflictingAction(for: defaultEntry, excluding: action) {
            showConflictAlert(entry: defaultEntry, conflictingAction: conflict)
            return
        }

        ConfigurationManager.shared.updateShortcutConfiguration(config)

        if let button = recorderButton(for: action) {
            updateRecorderButton(button, with: defaultEntry)
        }

        if action == .hideMenuBar {
            updateRestoreInfoText()
        }

        logger.info("Shortcut reset to default for \(action.rawValue)")
    }


    @objc private func hideMenuBarToggled(_ sender: NSSwitch) {
        let enabled = sender.state == .on

        if enabled {
            sender.isEnabled = false
            onHideMenuBarRequested? { [weak self] confirmed in
                guard let self else { return }
                sender.isEnabled = true
                if confirmed {
                    self.restoreInfoContainer.isHidden = false
                } else {
                    sender.state = .off
                    self.restoreInfoContainer.isHidden = true
                }
            }
        } else {
            restoreInfoContainer.isHidden = true
            var config = ConfigurationManager.shared.configuration
            config.hideMenuBarIcon = false
            ConfigurationManager.shared.updateConfiguration(config)
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        stopRecording()
    }

    @objc private func configurationDidChange() {
        let appConfig = ConfigurationManager.shared.configuration
        hideMenuBarSwitch.state = appConfig.hideMenuBarIcon ? .on : .off
        restoreInfoContainer.isHidden = !appConfig.hideMenuBarIcon
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
