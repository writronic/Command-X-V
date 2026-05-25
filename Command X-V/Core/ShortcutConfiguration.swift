import Foundation
import CoreGraphics

struct ShortcutEntry: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifierFlagsRaw: UInt64
    var keyCharacter: String?

    var cgKeyCode: CGKeyCode { CGKeyCode(keyCode) }

    var cgEventFlags: CGEventFlags { CGEventFlags(rawValue: modifierFlagsRaw) }

    var modifierOnlyFlags: CGEventFlags {
        cgEventFlags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    }

    var displayString: String {
        var parts: [String] = []
        if cgEventFlags.contains(.maskControl) { parts.append("⌃") }
        if cgEventFlags.contains(.maskAlternate) { parts.append("⌥") }
        if cgEventFlags.contains(.maskShift) { parts.append("⇧") }
        if cgEventFlags.contains(.maskCommand) { parts.append("⌘") }

        let keyStr: String
        if let char = keyCharacter, !char.isEmpty {
            keyStr = char == " " ? "Space" : char.uppercased()
        } else {
            keyStr = keyNameForCode(keyCode)
        }

        parts.append(keyStr)
        return parts.joined()
    }

    private func keyNameForCode(_ code: UInt16) -> String {
        switch code {
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 49: return "Space"
        case 36: return "↩"
        case 48: return "⇥"
        case 51: return "⌫"
        case 53: return "⎋"
        case 117: return "⌦"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "?"
        }
    }
}

struct ShortcutConfiguration: Codable, Equatable, Sendable {
    var cutShortcut: ShortcutEntry
    var pasteShortcut: ShortcutEntry
    var hideMenuBarShortcut: ShortcutEntry

    static let `default` = ShortcutConfiguration(
        cutShortcut: ShortcutEntry(
            keyCode: 7,
            modifierFlagsRaw: CGEventFlags.maskCommand.rawValue,
            keyCharacter: "x"
        ),
        pasteShortcut: ShortcutEntry(
            keyCode: 9,
            modifierFlagsRaw: CGEventFlags.maskCommand.rawValue,
            keyCharacter: "v"
        ),
        hideMenuBarShortcut: ShortcutEntry(
            keyCode: 46,
            modifierFlagsRaw: [CGEventFlags.maskControl, .maskAlternate, .maskCommand].reduce(CGEventFlags()) { $0.union($1) }.rawValue,
            keyCharacter: "m"
        )
    )

    func conflictingAction(for entry: ShortcutEntry, excluding action: ShortcutAction) -> ShortcutAction? {
        if action != .cut && cutShortcut == entry { return .cut }
        if action != .paste && pasteShortcut == entry { return .paste }
        if action != .hideMenuBar && hideMenuBarShortcut == entry { return .hideMenuBar }
        return nil
    }
}

enum ShortcutAction: String, Sendable {
    case cut = "Cut"
    case paste = "Paste"
    case hideMenuBar = "Hide Menu Bar"
}
