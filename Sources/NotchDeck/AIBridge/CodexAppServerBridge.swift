import Foundation

/// A small client for the supported Codex App Server protocol.
///
/// It only talks to Codex threads discovered for the current workspace. It
/// never reuses the Antigravity conversation id or writes to Antigravity
/// transcript files.
public actor CodexAppServerBridge {
    public static let shared = CodexAppServerBridge()

    public struct Response: Sendable {
        public let text: String
        public let threadID: String

        public init(text: String, threadID: String) {
            self.text = text
            self.threadID = threadID
        }
    }

    public struct HistoryMessage: Sendable, Equatable {
        public let id: String
        public let sender: String
        public let text: String
        public let isUser: Bool
        public let timestamp: String

        public init(id: String, sender: String, text: String, isUser: Bool, timestamp: String) {
            self.id = id
            self.sender = sender
            self.text = text
            self.isUser = isUser
            self.timestamp = timestamp
        }
    }

    public struct SessionSnapshot: Sendable {
        public let threadID: String
        public let title: String
        public let messages: [HistoryMessage]

        public init(threadID: String, title: String, messages: [HistoryMessage]) {
            self.threadID = threadID
            self.title = title
            self.messages = messages
        }
    }

    public struct ActivitySnapshot: Sendable {
        public let threadID: String
        public let title: String
        public let isWorking: Bool

        public init(threadID: String, title: String, isWorking: Bool) {
            self.threadID = threadID
            self.title = title
            self.isWorking = isWorking
        }
    }

    public enum BridgeError: Error, LocalizedError, Sendable {
        case executableNotFound
        case processFailed(String)
        case rpcError(code: Int, message: String)
        case malformedResponse(String)
        case noThread
        case turnFailed(String)
        case turnInProgress

        public var errorDescription: String? {
            switch self {
            case .executableNotFound:
                return "Codex App Server tidak ditemukan. Pastikan Codex CLI sudah terpasang."
            case .processFailed(let message):
                return "Codex App Server gagal dijalankan: \(message)"
            case .rpcError(_, let message):
                return "Codex App Server error: \(message)"
            case .malformedResponse(let message):
                return "Respons Codex tidak valid: \(message)"
            case .noThread:
                return "Tidak ada percakapan Codex yang bisa disambungkan."
            case .turnFailed(let message):
                return "Codex turn gagal: \(message)"
            case .turnInProgress:
                return "Codex masih memproses pesan sebelumnya."
            }
        }
    }

    private enum JSONValue: Codable, Sendable {
        case object([String: JSONValue])
        case array([JSONValue])
        case string(String)
        case number(Double)
        case bool(Bool)
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Double.self) {
                self = .number(value)
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else if let value = try? container.decode([String: JSONValue].self) {
                self = .object(value)
            } else if let value = try? container.decode([JSONValue].self) {
                self = .array(value)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unsupported JSON value"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .object(let value): try container.encode(value)
            case .array(let value): try container.encode(value)
            case .string(let value): try container.encode(value)
            case .number(let value): try container.encode(value)
            case .bool(let value): try container.encode(value)
            case .null: try container.encodeNil()
            }
        }

        var stringValue: String? {
            if case .string(let value) = self { return value }
            return nil
        }

        var intValue: Int? {
            if case .number(let value) = self { return Int(value) }
            return nil
        }

        var doubleValue: Double? {
            if case .number(let value) = self { return value }
            return nil
        }

        var objectValue: [String: JSONValue]? {
            if case .object(let value) = self { return value }
            return nil
        }

        var arrayValue: [JSONValue]? {
            if case .array(let value) = self { return value }
            return nil
        }
    }

    private struct RPCError: Sendable {
        let code: Int
        let message: String
    }

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var outputBuffer = Data()
    private var nextRequestID = 1
    private var pendingRequests: [Int: CheckedContinuation<JSONValue, Error>] = [:]
    private var turnWaiters: [String: CheckedContinuation<String, Error>] = [:]
    private var completedTurns: [String: Result<String, Error>] = [:]
    private var turnBuffers: [String: String] = [:]
    private var activeTurnID: String?
    private var connectedThreadID: String?
    private var usesQueueTransport = false
    private var observedCodexThreadPath: String?
    private var observedCodexThreadModificationDate: Date?

    private let storedThreadKey = "notchdeck.codex.appserver.thread-id"

    public init() {}

    // MARK: - Public API

    public func sendMessage(_ text: String) async throws -> Response {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BridgeError.malformedResponse("Pesan kosong")
        }

        // Re-discover immediately before sending so a stale id from an older
        // NotchDeck run cannot hijack the user's currently open Codex session.
        let threadID = try await ensureThread(forceRefresh: true)
        guard activeTurnID == nil else { throw BridgeError.turnInProgress }

        if usesQueueTransport {
            return try await sendMessageThroughQueue(text, threadID: threadID)
        }

        let result = try await request(
            method: "turn/start",
            params: [
                "threadId": threadID,
                "input": [["type": "text", "text": text]]
            ]
        )

        guard let turnID = result.objectValue?["turn"]?.objectValue?["id"]?.stringValue else {
            throw BridgeError.malformedResponse("turn/start tidak mengembalikan turn id")
        }

        activeTurnID = turnID
        turnBuffers[turnID] = ""

        let responseText: String
        if let completed = completedTurns.removeValue(forKey: turnID) {
            responseText = try completed.get()
        } else {
            responseText = try await withCheckedThrowingContinuation { continuation in
                turnWaiters[turnID] = continuation
            }
        }

        activeTurnID = nil
        turnBuffers[turnID] = nil
        return Response(text: responseText, threadID: threadID)
    }

    public func connectToCurrentThread() async throws -> SessionSnapshot {
        let threadID = try await ensureThread(forceRefresh: true)
        return try await readSessionSnapshot(threadID: threadID)
    }

    public func currentActivitySnapshot() async throws -> ActivitySnapshot? {
        try await ensureConnection()
        guard let thread = try await listWorkspaceThreads().first,
              let threadObject = thread.objectValue,
              let threadID = threadObject["id"]?.stringValue else {
            return nil
        }

        let title = threadObject["name"]?.stringValue ?? "Codex ChatGPT"
        guard let rolloutPath = threadObject["path"]?.stringValue,
              let attributes = try? FileManager.default.attributesOfItem(atPath: rolloutPath),
              let modifiedAt = attributes[.modificationDate] as? Date else {
            return ActivitySnapshot(threadID: threadID, title: title, isWorking: false)
        }

        let pathChanged = observedCodexThreadPath != rolloutPath
        let fileChanged = observedCodexThreadModificationDate.map { modifiedAt > $0 } ?? false
        observedCodexThreadPath = rolloutPath
        observedCodexThreadModificationDate = modifiedAt

        // Codex appends rollout events while a turn is running. The short
        // recency window also catches the first poll after the user starts a
        // turn, before the next file event arrives.
        let recentlyModified = Date().timeIntervalSince(modifiedAt) < 1.8
        return ActivitySnapshot(
            threadID: threadID,
            title: title,
            isWorking: pathChanged || fileChanged || recentlyModified
        )
    }

    private func readSessionSnapshot(threadID: String) async throws -> SessionSnapshot {
        let result = try await request(
            method: "thread/read",
            params: [
                "threadId": threadID,
                "includeTurns": true
            ]
        )

        guard let thread = result.objectValue?["thread"]?.objectValue else {
            throw BridgeError.malformedResponse("thread/read tidak mengembalikan thread")
        }

        return SessionSnapshot(
            threadID: threadID,
            title: thread["name"]?.stringValue ?? "Codex ChatGPT",
            messages: historyMessages(from: thread)
        )
    }

    public func connectedThread() -> String? {
        connectedThreadID
    }

    public func disconnect() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        inputPipe = nil
        outputPipe = nil
        process?.terminate()
        process = nil
        connectedThreadID = nil
        activeTurnID = nil
        usesQueueTransport = false

        let error = BridgeError.processFailed("Koneksi ditutup")
        for continuation in pendingRequests.values {
            continuation.resume(throwing: error)
        }
        for continuation in turnWaiters.values {
            continuation.resume(throwing: error)
        }
        pendingRequests.removeAll()
        turnWaiters.removeAll()
        completedTurns.removeAll()
        turnBuffers.removeAll()
    }

    // MARK: - Connection and thread selection

    private func ensureConnection() async throws {
        guard process?.isRunning != true else { return }

        guard let executable = Self.findCodexExecutable() else {
            throw BridgeError.executableNotFound
        }

        let appServer = Process()
        appServer.executableURL = URL(fileURLWithPath: executable)
        appServer.arguments = ["app-server", "--listen", "stdio://"]

        let input = Pipe()
        let output = Pipe()
        appServer.standardInput = input
        appServer.standardOutput = output
        appServer.standardError = FileHandle.standardError

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { [weak self] in
                await self?.receive(data: data)
            }
        }

        appServer.terminationHandler = { [weak self] terminatedProcess in
            let status = terminatedProcess.terminationStatus
            Task { [weak self] in
                await self?.processTerminated(status: status)
            }
        }

        do {
            try appServer.run()
        } catch {
            throw BridgeError.processFailed(error.localizedDescription)
        }

        process = appServer
        inputPipe = input
        outputPipe = output
        outputBuffer.removeAll(keepingCapacity: true)

        _ = try await request(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "notchdeck",
                    "title": "NotchDeck",
                    "version": "1.0"
                ],
                "capabilities": [
                    "experimentalApi": true
                ]
            ]
        )
        try sendNotification(method: "initialized", params: [:])
    }

    private func ensureThread(forceRefresh: Bool = false) async throws -> String {
        try await ensureConnection()
        if !forceRefresh, let connectedThreadID { return connectedThreadID }

        // The server returns newest threads first. Scope discovery to the
        // workspace that launched NotchDeck so an unrelated Codex project
        // cannot receive a message. The persisted id is deliberately not used
        // as the source of truth because an earlier NotchDeck run may have
        // stored a different thread.
        let candidates = try await listWorkspaceThreads()
        for candidate in candidates {
            guard let candidateID = candidate.objectValue?["id"]?.stringValue else {
                continue
            }

            do {
                _ = try await request(method: "thread/resume", params: ["threadId": candidateID])
                connectedThreadID = candidateID
                usesQueueTransport = false
                // Keep this for diagnostics/migration only. It is never trusted
                // to select a future session without a fresh thread/list call.
                UserDefaults.standard.set(candidateID, forKey: storedThreadKey)
                return candidateID
            } catch let error as BridgeError {
                if case .rpcError(_, let message) = error,
                   message.localizedCaseInsensitiveContains("active writer") {
                    // Codex Desktop owns the writer for its currently open
                    // thread. Queue input into that writer instead of trying
                    // to resume it from a second app-server process.
                    connectedThreadID = candidateID
                    usesQueueTransport = true
                    UserDefaults.standard.set(candidateID, forKey: storedThreadKey)
                    return candidateID
                }
            } catch {
                // Try the next workspace thread before reporting no session.
            }
        }

        // Do not silently create a second Codex conversation. The user asked
        // to reply in the session already open in Codex ChatGPT.
        throw BridgeError.noThread
    }

    private func listWorkspaceThreads() async throws -> [JSONValue] {
        let workspacePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .standardizedFileURL
            .path
        let listed = try await request(
            method: "thread/list",
            params: [
                "limit": 50,
                "sortKey": "recency_at",
                "sortDirection": "desc",
                "cwd": workspacePath,
                "archived": false,
                "sourceKinds": ["vscode", "appServer", "cli"]
            ]
        )
        return listed.objectValue?["data"]?.arrayValue ?? []
    }

    private func sendMessageThroughQueue(_ text: String, threadID: String) async throws -> Response {
        let before = try await readSessionSnapshot(threadID: threadID)
        let clientMessageID = UUID().uuidString
        _ = try await request(
            method: "thread/queue/add",
            params: [
                "threadId": threadID,
                "clientUserMessageId": clientMessageID,
                "input": [["type": "text", "text": text]]
            ]
        )

        let baselineIDs = Set(before.messages.map(\.id))
        for _ in 0..<120 {
            try await Task.sleep(nanoseconds: 500_000_000)
            let current = try await readSessionSnapshot(threadID: threadID)
            guard let userIndex = current.messages.lastIndex(where: {
                $0.isUser && $0.text == text && !baselineIDs.contains($0.id)
            }) else {
                continue
            }

            if let response = current.messages.dropFirst(userIndex + 1).first(where: { !$0.isUser }) {
                return Response(text: response.text, threadID: threadID)
            }
        }

        throw BridgeError.turnFailed("Waktu tunggu respons Codex habis setelah pesan masuk ke session aktif.")
    }

    // MARK: - JSON-RPC transport

    private func request(method: String, params: [String: Any]) async throws -> JSONValue {
        let requestID = nextRequestID
        nextRequestID += 1

        var envelope: [String: Any] = [
            "method": method,
            "id": requestID
        ]
        if !params.isEmpty { envelope["params"] = params }
        let data = try JSONSerialization.data(withJSONObject: envelope)
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestID] = continuation
            do {
                try write(data)
            } catch {
                pendingRequests.removeValue(forKey: requestID)
                continuation.resume(throwing: error)
            }
        }
    }

    private func sendNotification(method: String, params: [String: Any]) throws {
        let envelope: [String: Any] = [
            "method": method,
            "params": params
        ]
        try write(JSONSerialization.data(withJSONObject: envelope))
    }

    private func write(_ data: Data) throws {
        guard let inputPipe else {
            throw BridgeError.processFailed("stdin Codex App Server tidak tersedia")
        }
        var line = data
        line.append(10)
        do {
            try inputPipe.fileHandleForWriting.write(contentsOf: line)
        } catch {
            throw BridgeError.processFailed(error.localizedDescription)
        }
    }

    private func receive(data: Data) {
        outputBuffer.append(data)

        while let newline = outputBuffer.firstIndex(of: 10) {
            let lineData = outputBuffer.subdata(in: outputBuffer.startIndex..<newline)
            outputBuffer.removeSubrange(outputBuffer.startIndex...newline)
            guard !lineData.isEmpty else { continue }

            guard let message = try? JSONDecoder().decode(JSONValue.self, from: lineData) else {
                continue
            }
            handle(message: message)
        }
    }

    private func handle(message: JSONValue) {
        guard let object = message.objectValue else { return }

        if let responseID = object["id"]?.intValue {
            if let continuation = pendingRequests.removeValue(forKey: responseID) {
                if let error = parseRPCError(object["error"]) {
                    continuation.resume(throwing: BridgeError.rpcError(code: error.code, message: error.message))
                } else {
                    continuation.resume(returning: object["result"] ?? .null)
                }
            } else if let method = object["method"]?.stringValue {
                // Server-initiated requests (for example approval prompts)
                // must be answered so the app-server transport stays alive.
                handleServerRequest(method: method, id: responseID)
            }
            return
        }

        guard let method = object["method"]?.stringValue else { return }
        let params = object["params"]?.objectValue ?? [:]

        switch method {
        case "item/agentMessage/delta":
            guard let turnID = params["turnId"]?.stringValue,
                  let delta = params["delta"]?.stringValue else { return }
            turnBuffers[turnID, default: ""].append(delta)

        case "item/completed":
            guard let item = params["item"]?.objectValue,
                  item["type"]?.stringValue == "agentMessage",
                  let turnID = params["turnId"]?.stringValue else { return }
            let finalText = text(from: item)
            if !finalText.isEmpty && (turnBuffers[turnID] ?? "").isEmpty {
                turnBuffers[turnID] = finalText
            }

        case "turn/completed":
            guard let turn = params["turn"]?.objectValue,
                  let turnID = turn["id"]?.stringValue else { return }
            let status = turn["status"]?.stringValue ?? "failed"
            if status == "completed" {
                let text = turnBuffers[turnID] ?? "Codex menyelesaikan turn tanpa teks respons."
                resolveTurn(turnID, result: .success(text))
            } else {
                let message = turn["error"]?.objectValue?["message"]?.stringValue ?? status
                resolveTurn(turnID, result: .failure(BridgeError.turnFailed(message)))
            }

        default:
            break
        }
    }

    private func handleServerRequest(method: String, id: Int) {
        // The notch is not an approval surface. Decline rather than silently
        // granting shell/file permissions from a compact status bar.
        guard method.contains("approval") || method.contains("requestUserInput") else { return }
        try? sendResponse(id: id, result: ["decision": "decline"])
    }

    private func sendResponse(id: Int, result: [String: Any]) throws {
        let envelope: [String: Any] = ["id": id, "result": result]
        try write(JSONSerialization.data(withJSONObject: envelope))
    }

    private func parseRPCError(_ value: JSONValue?) -> RPCError? {
        guard let object = value?.objectValue,
              let code = object["code"]?.intValue,
              let message = object["message"]?.stringValue else { return nil }
        return RPCError(code: code, message: message)
    }

    private func text(from item: [String: JSONValue]) -> String {
        if let text = item["text"]?.stringValue { return text }
        guard let content = item["content"]?.arrayValue else { return "" }
        return content.compactMap { block in
            block.objectValue?["text"]?.stringValue
        }.joined()
    }

    private func historyMessages(from thread: [String: JSONValue]) -> [HistoryMessage] {
        guard let turns = thread["turns"]?.arrayValue else { return [] }

        var messages: [HistoryMessage] = []
        for turn in turns {
            guard let turnObject = turn.objectValue,
                  let items = turnObject["items"]?.arrayValue else {
                continue
            }

            let timestamp = historyTimestamp(from: turnObject)
            for item in items {
                guard let itemObject = item.objectValue,
                      let type = itemObject["type"]?.stringValue else {
                    continue
                }

                switch type {
                case "userMessage":
                    let text = text(from: itemObject)
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        messages.append(
                            HistoryMessage(
                                id: itemObject["id"]?.stringValue ?? UUID().uuidString,
                                sender: "You",
                                text: text,
                                isUser: true,
                                timestamp: timestamp
                            )
                        )
                    }

                case "agentMessage":
                    let text = text(from: itemObject)
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        messages.append(
                            HistoryMessage(
                                id: itemObject["id"]?.stringValue ?? UUID().uuidString,
                                sender: "Codex ChatGPT",
                                text: text,
                                isUser: false,
                                timestamp: timestamp
                            )
                        )
                    }

                default:
                    continue
                }
            }
        }

        // Tool items can make a rollout very large. Keep the latest
        // conversational context readable in the compact notch panel.
        return Array(messages.suffix(80))
    }

    private func historyTimestamp(from turn: [String: JSONValue]) -> String {
        guard let seconds = turn["createdAt"]?.doubleValue else { return "History" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: seconds))
    }

    private func resolveTurn(_ turnID: String, result: Result<String, Error>) {
        if let continuation = turnWaiters.removeValue(forKey: turnID) {
            continuation.resume(with: result)
        } else {
            completedTurns[turnID] = result
        }
    }

    private func processTerminated(status: Int32) {
        guard process != nil else { return }
        process = nil
        connectedThreadID = nil
        let error = BridgeError.processFailed("App Server berhenti dengan status \(status)")
        for continuation in pendingRequests.values {
            continuation.resume(throwing: error)
        }
        for continuation in turnWaiters.values {
            continuation.resume(throwing: error)
        }
        pendingRequests.removeAll()
        turnWaiters.removeAll()
        activeTurnID = nil
        usesQueueTransport = false
    }

    private static func findCodexExecutable() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex"
        ]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }
}
