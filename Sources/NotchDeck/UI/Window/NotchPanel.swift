import AppKit

public final class NotchPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.hidesOnDeactivate = false
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}
