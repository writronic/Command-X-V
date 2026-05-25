import Cocoa
import os.log

class AboutViewController: NSViewController {

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "AboutViewController")

    private var logoImageView: NSImageView!
    private var appNameLabel: NSTextField!
    private var versionLabel: NSTextField!
    private var taglineLabel: NSTextField!
    private var madeWithLabel: NSTextField!
    private var copyrightLabel: NSTextField!
    private var websiteButton: NSButton!
    private var licenseLabel: NSTextField!

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var yearString: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    private class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: SettingsLayout.detailWidth, height: SettingsLayout.contentHeight))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        logger.info("About view loaded")
    }

    private func setupUI() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
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

        logoImageView = NSImageView()
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.image = NSApp.applicationIconImage

        logoImageView.wantsLayer = true
        logoImageView.layer?.cornerRadius = 20
        logoImageView.layer?.masksToBounds = true

        logoImageView.shadow = NSShadow()
        logoImageView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.15).cgColor
        logoImageView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        logoImageView.layer?.shadowRadius = 8
        logoImageView.layer?.shadowOpacity = 1

        contentView.addSubview(logoImageView)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.topAnchor.constraint(equalTo: lastAnchor, constant: 24),
            logoImageView.widthAnchor.constraint(equalToConstant: 96),
            logoImageView.heightAnchor.constraint(equalToConstant: 96)
        ])
        lastAnchor = logoImageView.bottomAnchor

        appNameLabel = NSTextField(labelWithString: "Command X-V")
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        appNameLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold).rounded()
        appNameLabel.alignment = .center
        appNameLabel.textColor = .labelColor
        contentView.addSubview(appNameLabel)

        NSLayoutConstraint.activate([
            appNameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            appNameLabel.topAnchor.constraint(equalTo: lastAnchor, constant: 16)
        ])
        lastAnchor = appNameLabel.bottomAnchor

        versionLabel = NSTextField(labelWithString: "Version \(appVersion)")
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.font = NSFont.systemFont(ofSize: 14)
        versionLabel.alignment = .center
        versionLabel.textColor = .secondaryLabelColor
        contentView.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            versionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            versionLabel.topAnchor.constraint(equalTo: lastAnchor, constant: 10)
        ])
        lastAnchor = versionLabel.bottomAnchor

        taglineLabel = NSTextField(labelWithString: "The missing cut for macOS.")
        taglineLabel.translatesAutoresizingMaskIntoConstraints = false
        taglineLabel.font = NSFont.systemFont(ofSize: 14)
        taglineLabel.alignment = .center
        taglineLabel.textColor = .secondaryLabelColor
        contentView.addSubview(taglineLabel)

        NSLayoutConstraint.activate([
            taglineLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            taglineLabel.topAnchor.constraint(equalTo: lastAnchor, constant: 8)
        ])
        lastAnchor = taglineLabel.bottomAnchor

        madeWithLabel = NSTextField(labelWithString: "Made with ❤️")
        madeWithLabel.translatesAutoresizingMaskIntoConstraints = false
        madeWithLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        madeWithLabel.alignment = .center
        madeWithLabel.textColor = .labelColor
        contentView.addSubview(madeWithLabel)

        NSLayoutConstraint.activate([
            madeWithLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            madeWithLabel.topAnchor.constraint(equalTo: lastAnchor, constant: 40)
        ])
        lastAnchor = madeWithLabel.bottomAnchor

        copyrightLabel = NSTextField(labelWithString: "Copyright © \(yearString) Writronic. All rights reserved.")
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        copyrightLabel.font = NSFont.systemFont(ofSize: 14)
        copyrightLabel.alignment = .center
        copyrightLabel.textColor = .secondaryLabelColor
        contentView.addSubview(copyrightLabel)

        NSLayoutConstraint.activate([
            copyrightLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            copyrightLabel.topAnchor.constraint(equalTo: lastAnchor, constant: 10)
        ])
        lastAnchor = copyrightLabel.bottomAnchor

        websiteButton = NSButton(title: "Visit Website", target: self, action: #selector(openWebsite))
        websiteButton.translatesAutoresizingMaskIntoConstraints = false
        websiteButton.isBordered = false
        websiteButton.font = NSFont.systemFont(ofSize: 14)
        websiteButton.contentTintColor = .linkColor

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: ["target": "websiteButton"]
        )
        websiteButton.addTrackingArea(trackingArea)

        contentView.addSubview(websiteButton)

        NSLayoutConstraint.activate([
            websiteButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            websiteButton.topAnchor.constraint(equalTo: lastAnchor, constant: 5)
        ])
        lastAnchor = websiteButton.bottomAnchor

        licenseLabel = NSTextField(labelWithString: "GPL-3.0")
        licenseLabel.translatesAutoresizingMaskIntoConstraints = false
        licenseLabel.font = NSFont.systemFont(ofSize: 14)
        licenseLabel.alignment = .center
        licenseLabel.textColor = .tertiaryLabelColor
        contentView.addSubview(licenseLabel)

        NSLayoutConstraint.activate([
            licenseLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            licenseLabel.topAnchor.constraint(equalTo: lastAnchor, constant: 40)
        ])
        lastAnchor = licenseLabel.bottomAnchor

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

    @objc private func openWebsite() {
        if let url = URL(string: "https://writronic.com") {
            NSWorkspace.shared.open(url)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if let userData = event.trackingArea?.userInfo as? [String: String],
           userData["target"] == "websiteButton" {
            NSCursor.pointingHand.push()
        }
    }

    override func mouseExited(with event: NSEvent) {
        if let userData = event.trackingArea?.userInfo as? [String: String],
           userData["target"] == "websiteButton" {
            NSCursor.pop()
        }
    }
}

private extension NSFont {
    func rounded() -> NSFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
