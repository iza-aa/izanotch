//
//  LayaDecisionEngine.swift
//  izaNotch (Izanotchy)
//
//  Non-Autoregressive System 1 Decision Client (Port 1978)
//  Ultra-low latency (~20ms) discrete UI action classification via Laya Multilingual.
//  Zero Linguistic Prompt Injections — Single Responsibility Architecture.
//

import AppKit
import Foundation

public struct LayaDecisionResult: Sendable {
    public let action: String
    public let confidence: Double
    public let probabilities: [String: Double]
    public let latencyMs: Double
    
    public init(action: String, confidence: Double, probabilities: [String: Double], latencyMs: Double) {
        self.action = action
        self.confidence = confidence
        self.probabilities = probabilities
        self.latencyMs = latencyMs
    }
}

public final class LayaDecisionEngine: @unchecked Sendable {
    public static let shared = LayaDecisionEngine()
    
    public static let defaultPort = 1978
    private let session: URLSession
    private let daemonLock = NSLock()
    private var localDaemonProcess: Process?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 3.0
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopDaemon()
        }
    }
    
    deinit {
        stopDaemon()
    }
    
    // MARK: - Daemon Lifecycle
    
    public var isDaemonRunning: Bool {
        guard let url = URL(string: "http://127.0.0.1:\(Self.defaultPort)/health") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0.5
        
        let semaphore = DispatchSemaphore(value: 0)
        var isHealthy = false
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                isHealthy = true
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 0.6)
        return isHealthy
    }
    
    public func warmUp() {
        Task.detached(priority: .utility) { [weak self] in
            self?.ensureDaemonRunning()
        }
    }
    
    public func ensureDaemonRunning() {
        daemonLock.lock()
        defer { daemonLock.unlock() }
        
        if isDaemonRunning { return }
        
        let scriptCandidates = [
            "/Users/heizaaa/Desktop/cdev/iza-3/scripts/laya_daemon.py",
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("scripts/laya_daemon.py").path,
            NSString(string: "~/.izanotchy/scripts/laya_daemon.py").expandingTildeInPath
        ]
        let pythonCandidates = [
            "/Users/heizaaa/Desktop/cdev/iza-3/scripts/laya_env/bin/python",
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("scripts/laya_env/bin/python").path,
            NSString(string: "~/.izanotchy/laya_env/bin/python").expandingTildeInPath
        ]
        
        guard let scriptPath = scriptCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }),
              let pythonPath = pythonCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            ClickyLogger.warning("[LAYA_ENGINE]", "Laya script or virtualenv not found on disk")
            return
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [scriptPath]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        
        do {
            try proc.run()
            self.localDaemonProcess = proc
            ClickyLogger.info("[LAYA_ENGINE]", "Launched Laya decision daemon in background (PID: \(proc.processIdentifier))")
            
            // Wait briefly for daemon readiness on port 1978
            for _ in 0..<25 {
                if isDaemonRunning {
                    ClickyLogger.success("[LAYA_ENGINE]", "Laya decision daemon is ready and responding at port \(Self.defaultPort)")
                    return
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
        } catch {
            ClickyLogger.warning("[LAYA_ENGINE]", "Failed to launch Laya daemon: \(error.localizedDescription)")
        }
    }
    
    public func stopDaemon() {
        daemonLock.lock()
        defer { daemonLock.unlock() }
        if let proc = localDaemonProcess, proc.isRunning {
            proc.terminate()
            ClickyLogger.info("[LAYA_ENGINE]", "Terminated local Laya daemon process (PID: \(proc.processIdentifier))")
        }
        localDaemonProcess = nil
    }
    
    // MARK: - Decision Inference
    
    /// Requests Laya Multilingual for a discrete System 1 UI action decision in ~20-30 ms
    public func decideStep(
        userGoal: String,
        activeContainer: String,
        targetContainer: String?,
        isAtTop: Bool,
        scrollOffset: Float?,
        visibleItemCount: Int,
        targetIndex: Int?,
        hasActiveForm: Bool = false,
        formFields: [String: String]? = nil,
        hasModalOrError: Bool = false
    ) async -> LayaDecisionResult? {
        guard let url = URL(string: "http://127.0.0.1:\(Self.defaultPort)/decide") else { return nil }
        
        let hasSpecificContainer = targetContainer != nil && !targetContainer!.isEmpty && targetContainer!.lowercased() != "unspecified"
        let tIdx = targetIndex ?? 1
        
        // Dynamically tailor the choices: align semantic descriptions with empirical MPS embeddings
        let stateStr: String
        var choices: [String: String] = [:]
        
        if hasModalOrError {
            stateStr = "An alert dialog or error popout is currently active on screen."
            choices = [
                "handle_alert": "Dismiss or confirm the active alert or error dialog",
                "conclude_task": "Form or action is complete"
            ]
        } else if hasActiveForm || visibleItemCount == 0 {
            let priorityOrder = ["to", "subject", "body"]
            var rawEmpty: [String] = []
            if let fields = formFields {
                for (k, v) in fields {
                    if v == "[empty]" || v.isEmpty {
                        rawEmpty.append(k)
                    }
                }
            }
            let emptyFields = rawEmpty.sorted { (a: String, b: String) -> Bool in
                let idxA = priorityOrder.firstIndex(of: a.lowercased()) ?? 99
                let idxB = priorityOrder.firstIndex(of: b.lowercased()) ?? 99
                if idxA != idxB {
                    return idxA < idxB
                }
                return a < b
            }
            if !emptyFields.isEmpty {
                stateStr = "Active window is a form with empty fields: \(emptyFields.joined(separator: ", "))."
                choices = [
                    "type_field": "Type text into an empty input field (\(emptyFields.joined(separator: ", ")))",
                    "click_control": "Click a button, menu, or control"
                ]
            } else if hasActiveForm && formFields != nil && !formFields!.isEmpty {
                stateStr = "All required form fields are filled. Form is ready to verify and submit."
                choices = [
                    "verify_and_send": "Verify visual truth and submit the form",
                    "click_control": "Click a button, menu, or control"
                ]
            } else {
                stateStr = "Active window has interactive form fields and action controls."
                choices = [
                    "type_field": "Type text into an input field or text area",
                    "click_control": "Click a button, menu, or control",
                    "conclude_task": "Form is complete and action is confirmed"
                ]
            }
        } else {
            choices = [
                "scroll_up": "Scroll up to the top of the list because the list is offset away from the top",
                "scroll_down": "Scroll down to reveal items further down the list",
                "click_item": "Click to select the visible row in the list"
            ]
            
            if hasSpecificContainer && !activeContainer.lowercased().contains(targetContainer!.lowercased()) {
                choices["switch_container"] = "Switch container to match target folder"
                stateStr = "Target container is '\(targetContainer!)' while active container is '\(activeContainer)'."
            } else if !isAtTop && tIdx <= 5 {
                stateStr = "Viewport is offset below and not at the top. Target is at the beginning of the list, requiring navigation back to the top."
            } else if isAtTop {
                stateStr = "List is at the top. Target is visible row in the list."
            } else {
                stateStr = "Target item is further down past the currently visible items."
            }
        }
        
        let payload: [String: Any] = [
            "state": stateStr,
            "choices": choices,
            "model": "multilingual"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 1.0
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
                return nil
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let action = json["action"] as? String,
                  let conf = json["confidence"] as? Double else {
                return nil
            }
            
            let latency = (json["latency_ms"] as? Double) ?? 0.0
            let rawProbs = (json["probabilities"] as? [String: Double]) ?? [:]
            
            ClickyLogger.info("[LAYA_ENGINE]", "Laya decided action: '\(action)' in \(String(format: "%.1f", latency))ms (confidence: \(String(format: "%.2f", conf)))")
            return LayaDecisionResult(action: action, confidence: conf, probabilities: rawProbs, latencyMs: latency)
        } catch {
            return nil
        }
    }
    
    // MARK: - Semantic Element Selection Grounding
    
    /// Requests Laya Multilingual to ground and select the best matching UI element candidate (~20-25ms)
    /// from a dictionary of [candidateId: candidateDescription] for a target goal or query
    public func selectElement(
        targetQuery: String,
        candidates: [String: String]
    ) async -> (id: String, confidence: Double)? {
        guard !candidates.isEmpty else { return nil }
        guard let url = URL(string: "http://127.0.0.1:\(Self.defaultPort)/decide") else { return nil }
        
        let payload: [String: Any] = [
            "state": "Find and select target UI element matching: \(targetQuery)",
            "choices": candidates,
            "model": "multilingual"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 1.0
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chosenId = json["action"] as? String,
                  let conf = json["confidence"] as? Double else {
                return nil
            }
            let latency = (json["latency_ms"] as? Double) ?? 0.0
            ClickyLogger.info("[LAYA_ENGINE]", "Laya selected element: '\(chosenId)' in \(String(format: "%.1f", latency))ms (confidence: \(String(format: "%.2f", conf)))")
            return (chosenId, conf)
        } catch {
            return nil
        }
    }

    // MARK: - Instruction Intent Classification

    /// Classifies user instruction intent into canonical task type via Laya Multilingual (~20ms)
    /// without hardcoded word dictionaries.
    public func classifyInstructionIntent(prompt: String) async -> (intent: String, confidence: Double)? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: "http://127.0.0.1:\(Self.defaultPort)/decide") else { return nil }

        let choices = [
            "inspect_latest": "Inspect, read, or check the user's latest inbox messages or recent items",
            "search_filtered": "Search, query, or filter for a specific topic, keyword, or third-party sender",
            "compose_new": "Compose, write, create, or send a new message or document",
            "conversational": "General conversational chit-chat, greetings, or questions not operating an application"
        ]

        let payload: [String: Any] = [
            "state": "Classify user instruction intent: \(trimmed)",
            "choices": choices,
            "model": "multilingual"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 1.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chosenIntent = json["action"] as? String,
                  let conf = json["confidence"] as? Double else {
                return nil
            }
            let latency = (json["latency_ms"] as? Double) ?? 0.0
            ClickyLogger.info("[LAYA_ENGINE]", "Laya classified instruction intent: '\(chosenIntent)' in \(String(format: "%.1f", latency))ms (confidence: \(String(format: "%.2f", conf)))")
            return (chosenIntent, conf)
        } catch {
            return nil
        }
    }
}
