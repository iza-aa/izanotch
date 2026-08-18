import Foundation

public enum AISubprocessError: Error, LocalizedError, Sendable {
    case stdinNotAvailable
    case processNotRunning
    case dataEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .stdinNotAvailable:
            return "Standard input pipe is not available or has been closed."
        case .processNotRunning:
            return "Subprocess is not currently running."
        case .dataEncodingFailed:
            return "Failed to encode input string to UTF-8."
        }
    }
}

public final class AISubprocessBridge: @unchecked Sendable {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    public var isRunning: Bool {
        process?.isRunning == true
    }

    public init() {}

    deinit {
        terminate()
    }

    public func execute(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) async throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments

        if let env = environment {
            p.environment = env
        }

        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = outPipe

        let handle = outPipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            onOutput?(str)
        }

        self.process = p
        self.stdoutPipe = outPipe

        try p.run()
        p.waitUntilExit()

        handle.readabilityHandler = nil
        return p.terminationStatus
    }

    public func startInteractive(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        onOutput: @escaping @Sendable (String) -> Void
    ) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments

        if let env = environment {
            p.environment = env
        }

        let inPipe = Pipe()
        let outPipe = Pipe()

        p.standardInput = inPipe
        p.standardOutput = outPipe
        p.standardError = outPipe

        let handle = outPipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            onOutput(str)
        }

        self.process = p
        self.stdinPipe = inPipe
        self.stdoutPipe = outPipe

        try p.run()
    }

    public func sendInput(_ text: String) throws {
        guard let inPipe = stdinPipe else {
            throw AISubprocessError.stdinNotAvailable
        }
        guard let data = text.data(using: .utf8) else {
            throw AISubprocessError.dataEncodingFailed
        }
        try inPipe.fileHandleForWriting.write(contentsOf: data)
    }

    public func closeInput() {
        try? stdinPipe?.fileHandleForWriting.close()
        stdinPipe = nil
    }

    public func waitForExit() async throws -> Int32 {
        guard let p = process else { return -1 }
        p.waitUntilExit()
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        return p.terminationStatus
    }

    public func terminate() {
        if process?.isRunning == true {
            process?.terminate()
        }
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
    }
}
