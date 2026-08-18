import Foundation

public final class OutputAccumulator: @unchecked Sendable {
    private var lock = NSLock()
    private var text = ""

    public init() {}

    public func append(_ chunk: String) {
        lock.lock()
        defer { lock.unlock() }
        text += chunk
    }

    public func get() -> String {
        lock.lock()
        defer { lock.unlock() }
        return text
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        text = ""
    }
}
