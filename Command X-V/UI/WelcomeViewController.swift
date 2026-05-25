import Cocoa
import os.log

class WelcomeViewController: NSViewController {
    
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "WelcomeViewController")
    private let permissionManager = PermissionManager.shared
    private var permissionMonitoringTimer: Timer?
    
    var onWelcomeComplete: (() -> Void)?
    
    private var logoImageView: NSImageView!
    private var welcomeLabel: NSTextField!
    private var descriptionLabel: NSTextField!
    private var accessibilityButton: NSButton!
    private var letsGoButton: NSButton!
    private var statusLabel: NSTextField!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 500))
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialState()
        setupPermissionObserver()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        checkInitialPermissionStatus()
    }
    
    private func setupUI() {
        let visualEffectView = NSVisualEffectView(frame: view.bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        
        if #available(macOS 26.0, *) {
            visualEffectView.material = .underWindowBackground
        } else {
            visualEffectView.material = .windowBackground
        }
        
        view.addSubview(visualEffectView, positioned: .below, relativeTo: nil)
        
        createLogoImageView()
        createWelcomeLabel()
        createDescriptionLabel()
        createAccessibilityButton()
        createLetsGoButton()
        createStatusLabel()
        configureButtonStyles()
        
        setupConstraints()
    }
    
    private func createLogoImageView() {
        logoImageView = NSImageView()
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.image = NSApp.applicationIconImage
        view.addSubview(logoImageView)
    }
    
    private func createWelcomeLabel() {
        welcomeLabel = NSTextField(labelWithString: "Welcome to Command X-V")
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        welcomeLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        welcomeLabel.alignment = .center
        welcomeLabel.textColor = .labelColor
        welcomeLabel.isSelectable = false
        view.addSubview(welcomeLabel)
    }
    
    private func createDescriptionLabel() {
        let description = """
        Cut files with ⌘X, move them with ⌘V — the way it should have always worked.
        
        Command X-V plugs the missing shortcut into macOS Finder. 
        No more ⌘C → ⌘⌥V gymnastics.
        
        To get started, we need accessibility permission to monitor 
        keyboard shortcuts and interact with Finder.
        """
        
        descriptionLabel = NSTextField(wrappingLabelWithString: description)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = NSFont.systemFont(ofSize: 14)
        descriptionLabel.alignment = .center
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.isSelectable = false
        descriptionLabel.maximumNumberOfLines = 0
        view.addSubview(descriptionLabel)
    }
    
    private func createAccessibilityButton() {
        accessibilityButton = NSButton(title: "Allow for Accessibility", target: self, action: #selector(requestAccessibilityPermission))
        accessibilityButton.translatesAutoresizingMaskIntoConstraints = false
        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.controlSize = .large
        accessibilityButton.keyEquivalent = "\r"
        view.addSubview(accessibilityButton)
    }
    
    private func createLetsGoButton() {
        letsGoButton = NSButton(title: "Let's Go!", target: self, action: #selector(completeWelcome))
        letsGoButton.translatesAutoresizingMaskIntoConstraints = false
        letsGoButton.bezelStyle = .rounded
        letsGoButton.controlSize = .large
        letsGoButton.keyEquivalent = "\r"
        letsGoButton.isHidden = true
        view.addSubview(letsGoButton)
    }
    
    private func createStatusLabel() {
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.alignment = .center
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isHidden = true
        view.addSubview(statusLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 90),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            
            welcomeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            welcomeLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            welcomeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            welcomeLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            
            descriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 30),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            
            accessibilityButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            accessibilityButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
            accessibilityButton.widthAnchor.constraint(equalToConstant: 200),
            accessibilityButton.heightAnchor.constraint(equalToConstant: 32),
            
            letsGoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            letsGoButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
            letsGoButton.widthAnchor.constraint(equalToConstant: 200),
            letsGoButton.heightAnchor.constraint(equalToConstant: 32),
            
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: accessibilityButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func configureButtonStyles() {
        if #available(macOS 26.0, *) {
            accessibilityButton.hasDestructiveAction = false
            letsGoButton.hasDestructiveAction = false
        }
    }

    private func setupInitialState() {
        accessibilityButton.isHidden = false
        letsGoButton.isHidden = true
        statusLabel.isHidden = true
    }

    private func setupPermissionObserver() {
    }

    private func checkInitialPermissionStatus() {
        permissionManager.updatePermissionStatus()
        let status = permissionManager.currentStatus
        handlePermissionStatusChange(status)
    }

    private func handlePermissionStatusChange(_ status: PermissionStatus) {
        logger.debug("Permission status changed: \(status.summary)")

        if status.allRequiredGranted {
            showPermissionGranted()
        } else {
            showPermissionRequired()
        }
    }

    private func showPermissionRequired() {
        accessibilityButton.isHidden = false
        letsGoButton.isHidden = true
        statusLabel.isHidden = true

        let status = permissionManager.currentStatus
        if status.accessibility == .denied {
            accessibilityButton.title = "Open System Settings"
            statusLabel.stringValue = "Please enable accessibility access in System Settings"
            statusLabel.textColor = .systemOrange
            statusLabel.isHidden = false
        } else {
            accessibilityButton.title = "Allow for Accessibility"
            statusLabel.isHidden = true
        }
    }

    private func showPermissionGranted() {
        accessibilityButton.isHidden = true
        letsGoButton.isHidden = false
        statusLabel.stringValue = "✅ Accessibility permission granted!"
        statusLabel.textColor = .systemGreen
        statusLabel.isHidden = false

        letsGoButton.keyEquivalent = "\r"
        view.window?.defaultButtonCell = letsGoButton.cell as? NSButtonCell
    }

    @objc private func requestAccessibilityPermission() {
        logger.info("User requested accessibility permission")

        PermissionChecker.openSystemPreferences(for: .accessibility)

        statusLabel.stringValue = "Please enable Command X-V in System Settings > Privacy & Security > Accessibility"
        statusLabel.textColor = .systemBlue
        statusLabel.isHidden = false

        startPermissionMonitoring()
    }

    @objc private func completeWelcome() {
        logger.info("User completed welcome flow")
        onWelcomeComplete?()
    }

    private func showPermissionDeniedMessage() {
        statusLabel.stringValue = "Accessibility permission is required for Command X-V to function"
        statusLabel.textColor = .systemRed
        statusLabel.isHidden = false
    }

    private func startPermissionMonitoring() {
        permissionMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.view.window?.isVisible == true else {
                    self?.permissionMonitoringTimer?.invalidate()
                    self?.permissionMonitoringTimer = nil
                    return
                }

                self.permissionManager.updatePermissionStatus()
                self.handlePermissionStatusChange(self.permissionManager.currentStatus)
            }
        }
    }
}
