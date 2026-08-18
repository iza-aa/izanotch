import AppKit

public enum HotkeyAction: Equatable, Sendable {
    case toggleExpand
    case pushToTalk
    case dismiss
    case none
}

public struct HotkeyManager: Sendable {
    public static func resolveAction(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> HotkeyAction {
        let relevantFlags = flags.intersection([.command, .shift, .option, .control])

        // Spacebar is keyCode 49
        if keyCode == 49 {
            if relevantFlags.contains(.command) && relevantFlags.contains(.shift) {
                return .toggleExpand
            }
            if relevantFlags.contains(.option) {
                return .pushToTalk
            }
        }

        // Escape is keyCode 53
        if keyCode == 53 {
            return .dismiss
        }

        return .none
    }
}
