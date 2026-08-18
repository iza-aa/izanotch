import Foundation

public enum TranscriptEvent: Equatable, Sendable {
    case taskCompleted(summary: String)
    case userClarificationNeeded(question: String, options: [String]?)
    case toolExecuted(name: String, summary: String)
    case streamingContent(text: String)
    case none
}

public final class LiveTranscriptWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var fileHandle: FileHandle?
    private var lastReadOffset: UInt64 = 0
    private let queue = DispatchQueue(label: "com.notchdeck.transcriptwatcher", qos: .utility)

    public init() {}

    deinit {
        stopWatching()
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
        stopWatching()

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
        self.fileHandle = handle

        let fd = handle.fileDescriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: queue
        )

        // Read initial end of file
        self.lastReadOffset = (try? handle.seekToEnd()) ?? 0

        source.setEventHandler { [weak self] in
            guard let self = self, let handle = self.fileHandle else { return }
            do {
                try handle.seek(toOffset: self.lastReadOffset)
                let newData = handle.readDataToEndOfFile()
                self.lastReadOffset = try handle.offset()

                if let string = String(data: newData, encoding: .utf8) {
                    let lines = string.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
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

        self.source = source
        source.resume()
    }

    public func stopWatching() {
        source?.cancel()
        source = nil
        try? fileHandle?.close()
        fileHandle = nil
    }
}
