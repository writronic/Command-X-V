import Foundation
import CoreGraphics
import os.log

class KeyboardEventSynthesizer {

    static let syntheticEventMarker: Int64 = 0x434D445856

    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "KeyboardEventSynthesizer")
    
    func sendCopyCommand() throws {
        logger.debug("Sending copy command (Cmd+C)")
        try sendKeyCombo(key: KeyCodes.c, flags: KeyCodes.command)
    }
    
    func sendMoveCommand() throws {
        logger.debug("Sending move command (Option+Cmd+V)")
        try sendKeyCombo(key: KeyCodes.v, flags: [KeyCodes.command, KeyCodes.option])
    }
    
    func sendPasteCommand() throws {
        logger.debug("Sending paste command (Cmd+V)")
        try sendKeyCombo(key: KeyCodes.v, flags: KeyCodes.command)
    }
    
    private func sendKeyCombo(key: CGKeyCode, flags: CGEventFlags) throws {
        guard let eventSource = CGEventSource(stateID: .combinedSessionState) else {
            throw ErrorManager.CommandXVError.eventProcessingFailed("Failed to create event source for keyboard synthesis")
        }
        eventSource.userData = Self.syntheticEventMarker

        guard let keyDownEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: true) else {
            throw ErrorManager.CommandXVError.eventProcessingFailed("Failed to create keyboard event")
        }

        guard let keyUpEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: false) else {
            throw ErrorManager.CommandXVError.eventProcessingFailed("Failed to create keyboard event")
        }

        keyDownEvent.flags = flags
        keyUpEvent.flags = flags

        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)

        logger.debug("Key combo sent successfully: key=\(key), flags=\(flags.rawValue)")
    }
}
