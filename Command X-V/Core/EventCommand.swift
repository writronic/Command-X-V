import Foundation
import CoreGraphics
import AppKit
import os.log

protocol EventCommand {
    var commandType: EventCommandType { get }
    func execute(originalEvent: CGEvent) throws -> Bool
}

enum EventCommandType: String, CaseIterable, Sendable {
    case cut
    case paste
    case copy
    case selectAll
    case undo
    case redo

    var keyCode: CGKeyCode {
        switch self {
        case .cut: return KeyCodes.x
        case .paste, .redo: return KeyCodes.v
        case .copy: return KeyCodes.c
        case .selectAll: return 0
        case .undo: return 6
        }
    }

    var requiresShift: Bool {
        switch self {
        case .redo: return true
        default: return false
        }
    }
}

class CutCommand: EventCommand {
    let commandType: EventCommandType = .cut

    private weak var stateManager: StateManager?
    private let synthesizer: KeyboardEventSynthesizer
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "CutCommand")

    init(stateManager: StateManager, synthesizer: KeyboardEventSynthesizer) {
        self.stateManager = stateManager
        self.synthesizer = synthesizer
    }

    func execute(originalEvent: CGEvent) throws -> Bool {
        logger.info("Executing cut command")

        let sm = stateManager
        DispatchQueue.main.async {
            sm?.setCutState(true)
        }

        try synthesizer.sendCopyCommand()

        logger.info("Cut command executed successfully")
        return true
    }
}

class PasteCommand: EventCommand {
    let commandType: EventCommandType = .paste

    private weak var stateManager: StateManager?
    private let synthesizer: KeyboardEventSynthesizer
    private let logger = Logger(subsystem: "com.writronic.commandxv", category: "PasteCommand")

    var onImmediateCutClear: (() -> Void)?

    init(stateManager: StateManager, synthesizer: KeyboardEventSynthesizer) {
        self.stateManager = stateManager
        self.synthesizer = synthesizer
    }

    func execute(originalEvent: CGEvent) throws -> Bool {
        logger.info("Executing paste command")

        onImmediateCutClear?()

        let sm = stateManager
        DispatchQueue.main.async {
            sm?.setCutState(false)
        }

        try synthesizer.sendMoveCommand()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSPasteboard.general.clearContents()
        }

        logger.info("Paste command executed successfully")
        return true
    }
}

