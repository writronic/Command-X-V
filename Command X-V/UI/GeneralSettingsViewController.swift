import Cocoa
import Sparkle
import os.log

@MainActor
class GeneralSettingsViewController: NSViewController {

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "GeneralSettings")

    private var startAtLoginSwitch: NSSwitch!
    private var autoCheckUpdatesSwitch: NSSwitch!

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
        logger.info("General settings loaded")
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

        let loginRow = createToggleRow(
            title: "Start at Login",
            subtitle: "Automatically launch Command X-V when you log in.",
            switchAction: #selector(startAtLoginToggled(_:)),
            switchView: &startAtLoginSwitch
        )
        contentView.addSubview(loginRow)

        NSLayoutConstraint.activate([
            loginRow.topAnchor.constraint(equalTo: lastAnchor, constant: 20),
            loginRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            loginRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
        lastAnchor = loginRow.bottomAnchor

        let sep1 = createSeparator()
        contentView.addSubview(sep1)
        NSLayoutConstraint.activate([
            sep1.topAnchor.constraint(equalTo: lastAnchor, constant: 16),
            sep1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            sep1.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            sep1.heightAnchor.constraint(equalToConstant: 1)
        ])
        lastAnchor = sep1.bottomAnchor

        let autoUpdateRow = createToggleRow(
            title: "Automatically Check for Updates",
            subtitle: "Periodically check for new versions in the background.",
            switchAction: #selector(autoCheckUpdatesToggled(_:)),
            switchView: &autoCheckUpdatesSwitch
        )
        contentView.addSubview(autoUpdateRow)

        NSLayoutConstraint.activate([
            autoUpdateRow.topAnchor.constraint(equalTo: lastAnchor, constant: 16),
            autoUpdateRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            autoUpdateRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
        lastAnchor = autoUpdateRow.bottomAnchor

        let checkButton = NSButton(title: "Check for Updates…", target: UpdateManager.shared.updater, action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)))
        checkButton.translatesAutoresizingMaskIntoConstraints = false
        checkButton.bezelStyle = .rounded
        checkButton.controlSize = .regular
        contentView.addSubview(checkButton)

        NSLayoutConstraint.activate([
            checkButton.topAnchor.constraint(equalTo: lastAnchor, constant: 12),
            checkButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24)
        ])
        lastAnchor = checkButton.bottomAnchor

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


    private func loadCurrentValues() {
        let config = ConfigurationManager.shared.configuration

        startAtLoginSwitch.state = config.startAtLogin ? .on : .off

        let autoCheck = UpdateManager.shared.updater.updater.automaticallyChecksForUpdates
        autoCheckUpdatesSwitch.state = autoCheck ? .on : .off
    }


    @objc private func startAtLoginToggled(_ sender: NSSwitch) {
        let enabled = sender.state == .on

        var config = ConfigurationManager.shared.configuration
        config.startAtLogin = enabled
        ConfigurationManager.shared.updateConfiguration(config)

        StartAtLoginManager.shared.setEnabled(enabled)

        logger.info("Start at login toggled: \(enabled)")
    }

    @objc private func autoCheckUpdatesToggled(_ sender: NSSwitch) {
        let enabled = sender.state == .on
        UpdateManager.shared.updater.updater.automaticallyChecksForUpdates = enabled
        logger.info("Automatically check for updates toggled: \(enabled)")
    }

}
