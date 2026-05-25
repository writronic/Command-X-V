import Foundation
import Cocoa
import os.log

@MainActor
class StatusItemManager {
    
    enum StatusState: Equatable {
        case inactive
        case active
        case hasCutFiles
        case disabled
        case error
        
        var icon: NSImage? {
            switch self {
            case .inactive, .active, .hasCutFiles, .disabled:
                return NSImage(named: "MenuBarIcon")
            case .error:
                return NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Command X-V Error")
            }
        }
        
        var toolTip: String {
            switch self {
            case .inactive:
                return "Command X-V - Windows-style Cut & Paste (Inactive)"
            case .active:
                return "Command X-V - Windows-style Cut & Paste (Active)"
            case .hasCutFiles:
                return "Command X-V - Files cut and ready to paste"
            case .disabled:
                return "Command X-V - Disabled (Click to enable)"
            case .error:
                return "Command X-V - Error (Click for details)"
            }
        }
        
        var alphaValue: CGFloat {
            switch self {
            case .inactive, .disabled:
                return 0.6
            case .active, .hasCutFiles, .error:
                return 1.0
            }
        }
        
        var isTemplate: Bool {
            switch self {
            case .inactive, .active, .hasCutFiles, .disabled:
                return true
            case .error:
                return false
            }
        }
    }
    
    private(set) var currentState: StatusState = .inactive
    private(set) var isVisible = false
    
    private var statusItem: NSStatusItem?
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "StatusItemManager")
    
    private var animationTimer: Timer?
    private var isAnimating = false
    
    init() {
        logger.info("StatusItemManager: Initialized")
    }
    
    deinit {
    }
    
    func show() {
        guard statusItem == nil else {
            logger.debug("Status item already visible")
            return
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard statusItem?.button != nil else {
            logger.error("Failed to get status item button")
            return
        }
        
        updateButtonAppearance(for: currentState)
        
        isVisible = true
        logger.info("Status item shown")
    }
    
    func hide() {
        guard let statusItem = statusItem else { return }
        
        stopAnimation()
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        isVisible = false
        
        logger.info("Status item hidden")
    }

    func setVisible(_ visible: Bool) {
        statusItem?.isVisible = visible
        logger.info("Status item visibility set to: \(visible)")
    }
    
    func updateState(_ newState: StatusState, animated: Bool = true) {
        guard currentState != newState else { return }
        
        let oldState = currentState
        currentState = newState
        
        logger.debug("Status state changed: \(String(describing: oldState)) -> \(String(describing: newState))")
        
        if isVisible {
            if animated && shouldAnimateTransition(from: oldState, to: newState) {
                animateStateTransition(to: newState)
            } else {
                updateButtonAppearance(for: newState)
            }
        }
    }
    
    func setMenu(_ menu: NSMenu) {
        statusItem?.menu = menu
    }
    
    func highlight(duration: TimeInterval = 0.5) {
        guard let button = statusItem?.button else { return }
        
        let originalAlpha = button.alphaValue
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration / 2
            button.animator().alphaValue = 1.0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let button = self?.statusItem?.button else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = duration / 2
                    button.animator().alphaValue = originalAlpha
                }
            }
        }
    }
    
    func startPulsing() {
        guard !isAnimating else { return }
        
        isAnimating = true
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated {
                self?.pulseOnce()
            }
        }
        
        logger.debug("Started pulsing animation")
    }
    
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isAnimating = false
        
        if isVisible {
            updateButtonAppearance(for: currentState)
        }
        
        logger.debug("Stopped animation")
    }
    
    private func updateButtonAppearance(for state: StatusState) {
        guard let button = statusItem?.button else { return }
        
        button.image = state.icon
        button.image?.isTemplate = state.isTemplate
        button.alphaValue = state.alphaValue
        button.toolTip = state.toolTip
        
        button.setAccessibilityTitle(state.toolTip)
        button.setAccessibilityRole(.button)
    }
    
    private func shouldAnimateTransition(from oldState: StatusState, to newState: StatusState) -> Bool {
        switch (oldState, newState) {
        case (.inactive, .active), (.active, .hasCutFiles), (.hasCutFiles, .active):
            return true
        case (_, .error), (.error, _):
            return true
        default:
            return false
        }
    }
    
    private func animateStateTransition(to newState: StatusState) {
        guard let button = statusItem?.button else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            button.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                self?.updateButtonAppearance(for: newState)
                
                guard let button = self?.statusItem?.button else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.15
                    button.animator().alphaValue = newState.alphaValue
                }
            }
        }
    }
    
    private func pulseOnce() {
        guard let button = statusItem?.button, isAnimating else { return }
        
        let originalAlpha = currentState.alphaValue
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            button.animator().alphaValue = min(1.0, originalAlpha + 0.4)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let button = self?.statusItem?.button else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.5
                    button.animator().alphaValue = originalAlpha
                }
            }
        }
    }
}

extension StatusItemManager {
    
    func updateFromAppStatus(_ status: AppStatus) {
        let newState: StatusState
        
        if !status.hasPermissions {
            newState = .error
        } else if !status.isRunning {
            newState = .disabled
        } else if status.hasCutFiles {
            newState = .hasCutFiles
        } else if status.isActive {
            newState = .active
        } else {
            newState = .inactive
        }
        
        updateState(newState)
    }
    
    func showSuccess() {
        let originalState = currentState
        updateState(.active, animated: true)
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.updateState(originalState, animated: true)
        }
    }
    
    func showError() {
        let originalState = currentState
        updateState(.error, animated: true)
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.updateState(originalState, animated: true)
        }
    }
}
