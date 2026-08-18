import Foundation

public enum TranscriptEvent: Equatable, Sendable {
    case taskCompleted(summary: String)
    case userClarificationNeeded(question: String, options: [String]?)
    case toolExecuted(name: String, summary: String)
    case streamingContent(text: String)
    case none
}

public final class LiveTranscriptWatcher: @unchecked Sendable {
    private var fileSource: DispatchSourceFileSystemObject?
    private var dirSource: DispatchSourceFileSystemObject?
    private var fileHandle: FileHandle?
    private var dirHandle: FileHandle?
    private var lastReadOffset: UInt64 = 0
    private var lineRemainderBuffer: String = ""
    private let queue = DispatchQueue(label: "com.notchdeck.transcriptwatcher", qos: .utility)
    private var currentWatchedURL: URL?
    private var onEventCallback: (@Sendable (TranscriptEvent) -> Void)?

    public var isDirectoryWatchingActive: Bool {
        dirSource != nil
    }

    public var isFileWatchingActive: Bool {
        fileSource != nil
    }

    public init() {}

    deinit {
        stopAllWatching()
    }

    public static func parseTranscriptLine(_ line: String) -> TranscriptEvent {
        let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let data = clean.data(using: .utf8) else { return .none }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .none
        }

        let status = json["status"] as? String ?? ""
        let content = json["content"] as? String ?? ""
        let toolCalls = json["tool_calls"] as? [[String: Any]] ?? []

        // 1. Check for ask_question or user confirmation
        for call in toolCalls {
            let toolName = (call["tool_name"] as? String) ?? (call["name"] as? String) ?? ""
            let toolSummary = (call["tool_summary"] as? String) ?? ""

            if toolName == "ask_question" {
                var extractedQuestion = "Agent butuh klarifikasi"
                var extractedOptions: [String] = []

                if let args = call["tool_arguments"] as? [String: Any],
                   let questions = args["questions"] as? [[String: Any]],
                   let firstQ = questions.first {
                    extractedQuestion = firstQ["question"] as? String ?? extractedQuestion
                    extractedOptions = firstQ["options"] as? [String] ?? []
                }

                return .userClarificationNeeded(question: extractedQuestion, options: extractedOptions.isEmpty ? nil : extractedOptions)
            }

            if !toolName.isEmpty {
                return .toolExecuted(name: toolName, summary: toolSummary)
            }
        }

        if status == "WAITING_FOR_INPUT" {
            return .userClarificationNeeded(question: content.isEmpty ? "Agent menunggu konfirmasi" : content, options: nil)
        }

        // 2. Check for task DONE
        if status == "DONE" {
            return .taskCompleted(summary: content.isEmpty ? "Task AI selesai." : content)
        }

        // 3. Streaming content
        if !content.isEmpty && status == "PLANNER_RESPONSE" {
            return .streamingContent(text: content)
        }

        return .none
    }

    public func startWatching(fileURL: URL, onEvent: @escaping @Sendable (TranscriptEvent) -> Void) {
        stopFileWatching()
        self.currentWatchedURL = fileURL
        self.onEventCallback = onEvent
        self.lineRemainderBuffer = ""

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
        self.fileHandle = handle

        let fd = handle.fileDescriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: queue
        )

        self.lastReadOffset = (try? handle.seekToEnd()) ?? 0

        source.setEventHandler { [weak self] in
            guard let self = self, let handle = self.fileHandle else { return }
            do {
                try handle.seek(toOffset: self.lastReadOffset)
                let newData = handle.readDataToEndOfFile()
                self.lastReadOffset = try handle.offset()

                if let string = String(data: newData, encoding: .utf8) {
                    let combined = self.lineRemainderBuffer + string
                    let lines = combined.components(separatedBy: "\n")

                    if let last = lines.last, !combined.hasSuffix("\n") {
                        self.lineRemainderBuffer = last
                    } else {
                        self.lineRemainderBuffer = ""
                    }

                    let completeLines = combined.hasSuffix("\n") ? lines : Array(lines.dropLast())
                    for line in completeLines where !line.isEmpty {
                        let event = Self.parseTranscriptLine(line)
                        if event != .none {
                            onEvent(event)
                        }
                    }
                }
            } catch {
                // handle read error
            }
        }

        source.setCancelHandler {
            try? handle.close()
        }

        self.fileSource = source
        source.resume()
    }

    public func startWatchingBrainDirectory(brainDirectory: URL, onEvent: @escaping @Sendable (TranscriptEvent) -> Void) {
        self.onEventCallback = onEvent

        findAndWatchLatestSession(in: brainDirectory)

        guard let dirHandle = try? FileHandle(forReadingFrom: brainDirectory) else { return }
        self.dirHandle = dirHandle

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirHandle.fileDescriptor,
            eventMask: [.write, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.findAndWatchLatestSession(in: brainDirectory)
        }

        self.dirSource = source
        source.resume()
    }

    public func findAndWatchLatestSession(in brainDirectory: URL) {
        guard let onEvent = self.onEventCallback else { return }
        if let contents = try? FileManager.default.contentsOfDirectory(at: brainDirectory, includingPropertiesForKeys: [.contentModificationDateKey]),
           let latestSession = contents.filter({ $0.hasDirectoryPath && !$0.lastPathComponent.hasPrefix(".") }).sorted(by: {
               let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
               let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
               return d1 > d2
           }).first {
            let logFile = latestSession.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            if currentWatchedURL != logFile && FileManager.default.fileExists(atPath: logFile.path) {
                startWatching(fileURL: logFile, onEvent: onEvent)
            }
        }
    }

    public func stopFileWatching() {
        fileSource?.cancel()
        fileSource = nil
        try? fileHandle?.close()
        fileHandle = nil
        lineRemainderBuffer = ""
        currentWatchedURL = nil
    }

    public func stopDirWatching() {
        dirSource?.cancel()
        dirSource = nil
        try? dirHandle?.close()
        dirHandle = nil
    }

    public func stopAllWatching() {
        stopFileWatching()
        stopDirWatching()
    }
}
