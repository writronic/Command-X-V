import Foundation
import Carbon

struct KeyCodes {
    static let x: CGKeyCode = 7
    static let c: CGKeyCode = 8
    static let v: CGKeyCode = 9
    
    static let command = CGEventFlags.maskCommand
    static let option = CGEventFlags.maskAlternate
    static let shift = CGEventFlags.maskShift
    static let control = CGEventFlags.maskControl
    
    static func isCommandKey(_ flags: CGEventFlags) -> Bool {
        return flags.contains(.maskCommand)
    }
    
    static func isCutKeyCombo(_ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Bool {
        let modifiers = flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        return keyCode == x && modifiers == .maskCommand
    }

    static func isPasteKeyCombo(_ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Bool {
        let modifiers = flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        return keyCode == v && modifiers == .maskCommand
    }

    static func isMenuBarRestoreShortcut(_ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Bool {
        return keyCode == x &&
               flags.contains(.maskControl) &&
               flags.contains(.maskAlternate) &&
               flags.contains(.maskShift)
    }

    static func matchesShortcut(_ keyCode: CGKeyCode, _ flags: CGEventFlags, _ shortcut: ShortcutEntry) -> Bool {
        let modifiers = flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        return keyCode == shortcut.cgKeyCode && modifiers == shortcut.modifierOnlyFlags
    }
}
