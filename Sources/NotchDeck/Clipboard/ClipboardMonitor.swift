import AppKit
import Foundation
import Combine

@MainActor
public final class ClipboardMonitor: ObservableObject {
    public static let shared = ClipboardMonitor()

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    public var onNewTextCopied: (@MainActor (String) -> Void)?

    public init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    public func startMonitoring(interval: TimeInterval = 0.5) {
        stopMonitoring()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForChanges()
            }
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    public func checkForChanges() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if let copiedString = pasteboard.string(forType: .string), !copiedString.isEmpty {
            onNewTextCopied?(copiedString)
            CardDataStore.shared.addClipboardItem(text: copiedString)
        }
    }

    public func copyToClipboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    public func clearClipboard() {
        pasteboard.clearContents()
        lastChangeCount = pasteboard.changeCount
    }
}
