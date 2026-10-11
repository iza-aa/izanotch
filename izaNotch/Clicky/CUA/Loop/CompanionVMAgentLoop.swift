//
//  CompanionVMAgentLoop.swift
//  izaNotch
//
//  Autonomous Dynamic Agent Loop for Companion VMs.
//  Executes multi-turn visual & accessibility reasoning driven by persona.md
//  and generic CUA Driver tools without hardcoded per-application pipelines.
//

import Foundation
import CoreGraphics
import AppKit
import Vision

public struct VMAgentStepRecord: Codable, Equatable, Sendable {
    public let stepNumber: Int
    public let actionName: String
    public let targetDescription: String
    public let groundingMethod: String
    public let coordinateX: Int
    public let coordinateY: Int
    public let observationResult: String

    public init(
        stepNumber: Int,
        actionName: String,
        targetDescription: String,
        groundingMethod: String,
        coordinateX: Int,
        coordinateY: Int,
        observationResult: String
    ) {
        self.stepNumber = stepNumber
        self.actionName = actionName
        self.targetDescription = targetDescription
        self.groundingMethod = groundingMethod
        self.coordinateX = coordinateX
        self.coordinateY = coordinateY
        self.observationResult = observationResult
    }
}

public struct VMAgentDeliverableReceipt: Codable, Equatable, Sendable {
    public let id: String
    public let companionSlug: String
    public let taskPrompt: String
    public let status: String
    public let summary: String
    public let responseToUser: String?
    public let timestamp: TimeInterval
    public let auditTrail: [VMAgentStepRecord]

    public init(
        id: String = UUID().uuidString,
        companionSlug: String,
        taskPrompt: String,
        status: String,
        summary: String,
        responseToUser: String? = nil,
        timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate,
        auditTrail: [VMAgentStepRecord]
    ) {
        self.id = id
        self.companionSlug = companionSlug
        self.taskPrompt = taskPrompt
        self.status = status
        self.summary = summary
        self.responseToUser = responseToUser
        self.timestamp = timestamp
        self.auditTrail = auditTrail
    }
}

@MainActor
public final class CompanionVMAgentLoop: ObservableObject {
    public static let shared = CompanionVMAgentLoop()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentActionDescription: String = ""
    private var sessionObservedListItems: [(index: Int, content: String)] {
        ClickyUIObservationService.shared.observedListItems
    }
    private var sessionObservedCardBoxes: [Int: CGRect] {
        ClickyUIObservationService.shared.observedCardBoxes
    }
    private var sessionObservedElements: [(text: String, box: CGRect)] {
        ClickyUIObservationService.shared.observedElements
    }

    private init() {}

    // MARK: - Safe Asynchronous Process Execution (Anti-Hang & Anti-Watchdog)
    public static func runSubprocessAsync(executable: String, arguments: [String], timeoutSeconds: TimeInterval = 4.0) async -> (exitCode: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                var hasResumed = false
                let lock = NSLock()

                let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
                timer.schedule(deadline: .now() + timeoutSeconds)
                timer.setEventHandler {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        if process.isRunning {
                            process.terminate()
                        }
                        continuation.resume(returning: (-1, "TIMEOUT"))
                    }
                }
                timer.resume()

                do {
                    try process.run()
                    process.waitUntilExit()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let outStr = String(data: outData, encoding: .utf8) ?? ""
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    let combined = outStr + (errStr.isEmpty ? "" : " [stderr: \(errStr)]")

                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        timer.cancel()
                        continuation.resume(returning: (process.terminationStatus, combined))
                    }
                } catch {
                    lock.lock()
                    defer { lock.unlock() }
                    if !hasResumed {
                        hasResumed = true
                        timer.cancel()
                        continuation.resume(returning: (-1, error.localizedDescription))
                    }
                }
            }
        }
    }

    // MARK: - Autonomous Execution Loop
    /// Executes an open-ended autonomous agent task inside the companion's isolated VM workspace.
    /// The agent uses persona.md as its sovereign identity and chooses tools dynamically.
    public func executeAutonomousTask(
        prompt: String,
        slug: String,
        appName: String = "Mail",
        taskPlan: AFMTaskDecomposition? = nil,
        onProgress: (@MainActor (ComputerCardPayload) -> Void)? = nil
    ) async throws -> ComputerCardPayload {
        isRunning = true
        ClickyUIObservationService.shared.resetSession()
        currentActionDescription = "Reading persona.md and connecting to \(appName)..."
        defer {
            isRunning = false
            currentActionDescription = ""
        }

        ClickyLogger.info("[VM_AGENT_LOOP]", "Starting autonomous dynamic agent loop for companion: \(slug) with prompt: \"\(prompt)\"")

        // 1. Verify Persona Sovereignty
        let persona = CompanionWorkspaceManager.shared.readCompanionSpec(slug: slug) ?? ""
        ClickyLogger.info("[VM_AGENT_LOOP]", "Loaded sovereign persona (\(persona.count) chars) for \(slug)")

        var auditTrail: [VMAgentStepRecord] = []
        var queueItems: [ComputerCardQueueItem] = []
        if let subGoals = taskPlan?.plannedSubGoals, !subGoals.isEmpty {
            queueItems = subGoals.map { ComputerCardQueueItem(name: $0, statusBadge: "Planned", isChecked: false) }
        } else {
            let target = (taskPlan?.targetEntity.isEmpty == false && taskPlan?.targetEntity != "main_window" && taskPlan?.targetEntity != "user") ? taskPlan!.targetEntity : appName
            let goalDesc = taskPlan?.normalizedGoal.isEmpty == false ? taskPlan!.normalizedGoal : prompt
            queueItems = [
                ComputerCardQueueItem(name: "Connect to \(appName) in workspace", statusBadge: "Planned", isChecked: false),
                ComputerCardQueueItem(name: "Locate & inspect \(target)", statusBadge: "Planned", isChecked: false),
                ComputerCardQueueItem(name: "Execute: \(goalDesc)", statusBadge: "Planned", isChecked: false)
            ]
        }

        // 1b. Policy Enforcement (Connected Apps & Safari Domain Whitelist)
        let session = CompanionManager.shared.sessions.first(where: { $0.slug == slug })
        let allowedApps = session?.workflowAppNames ?? CompanionManager.shared.activeBuddy.workflowAppNames

        // Check Desktop App Permission
        if !allowedApps.contains(where: { $0.lowercased() == appName.lowercased() }) {
            let userLang = taskPlan?.userLanguage ?? TaskIngressGateway.resolveLanguage(prompt: prompt)
            let errorMsg = await TaskEgressValidator.shared.synthesizeNotice(
                noticeSummary: "Access denied: Bot '\(slug)' does not have permission to access '\(appName)'. Please add '\(appName)' in Edit Character.",
                appName: appName,
                userGoal: prompt,
                userLanguage: userLang
            )
            ClickyLogger.warning("[VM_POLICY]", errorMsg)
            return finishTask(
                summary: errorMsg,
                slug: slug,
                taskPrompt: prompt,
                appName: appName,
                auditTrail: auditTrail,
                queueItems: [ComputerCardQueueItem(name: "Check App Access (\(appName))", statusBadge: "Denied", isChecked: false)],
                isSuccess: false
            )
        }

        // 2. Launch / Connect to Real Native macOS App & Assign to Virtual Desktop Space
        // Zero Host Screen Intrusion: Ensure virtual display is ready FIRST so windows never flash on host desktop
        MascotVirtualDesktopService.shared.ensureVirtualDisplay(slug: slug)
        CompanionWindowStreamService.shared.activeIntentType = taskPlan?.intentType
        CompanionWindowStreamService.shared.activeTargetEntity = taskPlan?.targetEntity
        CompanionWindowStreamService.shared.ensureWorkflowAppRunning(appName: appName)
        MascotVirtualDesktopService.shared.assignAppToVirtualDesktop(appName: appName, slug: slug, intentType: taskPlan?.intentType)
        CompanionWindowStreamService.shared.startStreaming(appName: appName, slug: slug, interval: 0.8)

        // Initial snapshot capture from isolated virtual desktop (prioritize real application window)
        let initialSnapPath = await CompanionWindowStreamService.shared.captureTargetWindowAsync(appName: appName, slug: slug) ??
            (MascotVirtualDesktopService.shared.captureSnapshot() != nil ? MascotVirtualDesktopService.shared.activeSnapshotPath : nil)

        // 2b. Initial Visual Snapshot & Workspace Telemetry Ready
        let userLang = taskPlan?.userLanguage ?? TaskIngressGateway.resolveLanguage(prompt: prompt)

        // 3. Hierarchical Autonomous CUA ReAct Loop (AFM ⇄ Luna)
        // AFM (Apple Foundation Models, On-Device / Cloud Fallback): Task Planner, Reasoner & Validator
        // Luna (6 Luna Medium / gpt-6-luna): High-Resolution Visual Perception & Element Grounder
        
        var candidateWindows = CompanionWindowStreamService.shared.findCandidateWindows(appName: appName)
        var targetPID = candidateWindows.first?.pid ?? NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.localizedCaseInsensitiveContains(appName) == true
        })?.processIdentifier
        
        // Ensure Laya System 1 Decision daemon is ready in background
        LayaDecisionEngine.shared.ensureDaemonRunning()
        
        // Reset scroll position to top (0.0) if inspecting latest item / general list without custom container (Clean Workspace Anchor)
        let effectiveTargetIdx = taskPlan?.targetIndex ?? ((taskPlan?.intentType == "inspect" || taskPlan?.intentType == "read") && taskPlan?.targetContainer == nil ? 1 : nil)
        if let pid = targetPID, pid > 0, effectiveTargetIdx == 1 {
            CUAScrollActionTool.resetScrollToTop(pid: pid)
        }

        let isComposeTask = ["compose", "send", "create", "write"].contains(taskPlan?.intentType ?? "")
        let maxSteps = isComposeTask ? 8 : 6
        var historySummary: [String] = []
        var finalSystemState = "Task in progress"
        var finalResponseToUser = ""
        var isTaskSuccessful = false
        var lastValidationResult: AFMValidationResult? = nil
        
        for stepIndex in 1...maxSteps {
            if Task.isCancelled { break }
            ClickyLogger.info("[HEARTBEAT]", "Step \(stepIndex)/\(maxSteps): Starting cycle for '\(appName)' (PID: \(targetPID ?? 0))")
            
            // Refresh candidate windows on every step iteration so active window bounds and newly opened windows are tracked
            let activeWindows = CompanionWindowStreamService.shared.findCandidateWindows(appName: appName)
            if !activeWindows.isEmpty {
                candidateWindows = activeWindows
                if let freshPid = activeWindows.first?.pid, freshPid > 0 {
                    targetPID = freshPid
                }
            }
            
            // Step 1: Capture active frame from isolated workspace
            let currentSnap = await CompanionWindowStreamService.shared.captureTargetWindowAsync(appName: appName, slug: slug) ??
                MascotVirtualDesktopService.shared.activeSnapshotPath ?? initialSnapPath
                
            // Step 1b: Zero Host Screen Intrusion - Continuously relocate displaced/new windows (in background)
            Task.detached(priority: .userInitiated) {
                await MascotVirtualDesktopService.shared.relocateAppWindowsToVirtualDesktop(appName: appName)
            }
            
            // SEE (Prinsip See ➔ Plan ➔ Act): Amati kondisi layar nyata saat ini dari snapshot terkini
            let rawObs = await readStructuredObservation(
                appName: appName,
                pid: targetPID,
                snapshotPath: currentSnap,
                targetSection: taskPlan?.targetSection,
                intentType: taskPlan?.intentType
            )
            let currentObservation = rawObs.isEmpty ? "App is open in isolated workspace" : rawObs
            ClickyLogger.info("[HEARTBEAT]", "Step \(stepIndex): Structured observation parsed (\(currentObservation.count) bytes)")
            let currentScrollState = targetPID != nil ? CUAScrollActionTool.getScrollState(pid: targetPID!) : CUAScrollState(isAtTop: true)
            
            // Step 2a: System 1 Non-Autoregressive Decision Engine (Laya Multilingual ~20ms)
            var candidateDecision: AFMStepDecision? = nil
            if LayaDecisionEngine.shared.isDaemonRunning {
                let winTitle = candidateWindows.first?.title ?? appName
                let intent = taskPlan?.intentType.lowercased() ?? ""
                let obsService = ClickyUIObservationService.shared
                let isCollectionList = obsService.latestWindowType == "collection_list"
                let isComposeIntent = ["compose", "send", "create", "write"].contains(intent)
                let isFormActive = isComposeIntent && (!isCollectionList || obsService.latestWindowType == "draft_composer")
                if obsService.latestHasModalOrError {
                    // Priority 1: Dismiss active modal dialog / alert before taking any further actions!
                    let alertBtn: String
                    if let primaryConfirm = obsService.observedElements.first(where: {
                        let t = $0.text.lowercased()
                        return t.contains("ok") || t.contains("don't save") || t.contains("dont save") || t.contains("close") || t.contains("discard")
                    }) {
                        alertBtn = primaryConfirm.text
                    } else if let cancelBtn = obsService.observedElements.first(where: {
                        let t = $0.text.lowercased()
                        return t.contains("cancel") || t.contains("batal") || t.contains("dismiss")
                    }) {
                        alertBtn = cancelBtn.text
                    } else {
                        alertBtn = "OK"
                    }
                    candidateDecision = AFMStepDecision(
                        thought: "Active modal alert detected on screen: dismissing via '\(alertBtn)' before proceeding.",
                        subGoal: "Dismiss active modal dialog",
                        targetElement: alertBtn,
                        actionType: "click",
                        textToType: nil,
                        isFinished: false
                    )
                } else if isCollectionList && isComposeIntent {
                    // Window is still at collection list; click toolbar compose/new action button to open editor
                    let topBarCandidate = obsService.latestTopBarItems.first(where: {
                        let l = $0.lowercased()
                        return l.contains("new") || l.contains("compose") || l.contains("create")
                    }) ?? "New Message"
                    candidateDecision = AFMStepDecision(
                        thought: "Active window is collection list for a compose/send intent. Click create action on toolbar to open draft editor.",
                        subGoal: "Click create action on toolbar",
                        targetElement: topBarCandidate,
                        actionType: "click",
                        textToType: nil,
                        isFinished: false
                    )
                } else if let layaRes = await LayaDecisionEngine.shared.decideStep(
                    userGoal: prompt,
                    activeContainer: winTitle,
                    targetContainer: taskPlan?.targetContainer,
                    isAtTop: currentScrollState.isAtTop,
                    scrollOffset: currentScrollState.scrollValue,
                    visibleItemCount: sessionObservedListItems.count,
                    targetIndex: effectiveTargetIdx,
                    hasActiveForm: isFormActive,
                    formFields: obsService.latestFormFields,
                    hasModalOrError: obsService.latestHasModalOrError
                ), layaRes.confidence >= 0.20 {
                    switch layaRes.action {
                    case "scroll_up":
                        if !currentScrollState.isAtTop {
                            candidateDecision = AFMStepDecision(
                                thought: "Laya decided scroll_up in \(Int(layaRes.latencyMs))ms: list is scrolled down.",
                                subGoal: "Scroll up to reach top of list",
                                targetElement: "item list",
                                actionType: "scroll_up",
                                textToType: nil,
                                isFinished: false
                            )
                        }
                    case "scroll_down":
                        candidateDecision = AFMStepDecision(
                            thought: "Laya decided scroll_down in \(Int(layaRes.latencyMs))ms: target beyond visible items.",
                            subGoal: "Scroll down to reveal target item",
                            targetElement: "item list",
                            actionType: "scroll_down",
                            textToType: nil,
                            isFinished: false
                        )
                    case "click_item":
                        if let tIdx = effectiveTargetIdx,
                           sessionObservedListItems.contains(where: { $0.index == tIdx }) {
                            let matchContent = sessionObservedListItems.first(where: { $0.index == tIdx })?.content ?? "item \(tIdx)"
                            candidateDecision = AFMStepDecision(
                                thought: "Laya decided click_item for item #\(tIdx) in \(Int(layaRes.latencyMs))ms.",
                                subGoal: "Open item #\(tIdx) for inspection",
                                targetElement: matchContent,
                                actionType: "click",
                                textToType: nil,
                                isFinished: false
                            )
                        }
                    case "handle_alert":
                        let alertBtn: String
                        if let primaryConfirm = obsService.observedElements.first(where: {
                            let t = $0.text.lowercased()
                            return t.contains("ok") || t.contains("don't save") || t.contains("dont save") || t.contains("close") || t.contains("discard")
                        }) {
                            alertBtn = primaryConfirm.text
                        } else if let cancelBtn = obsService.observedElements.first(where: {
                            let t = $0.text.lowercased()
                            return t.contains("cancel") || t.contains("batal") || t.contains("dismiss")
                        }) {
                            alertBtn = cancelBtn.text
                        } else {
                            alertBtn = "OK"
                        }
                        candidateDecision = AFMStepDecision(
                            thought: "Laya detected modal alert in \(Int(layaRes.latencyMs))ms: dismissing via '\(alertBtn)'.",
                            subGoal: "Acknowledge or dismiss alert dialog",
                            targetElement: alertBtn,
                            actionType: "click",
                            textToType: nil,
                            isFinished: false
                        )
                    case "verify_and_send":
                        candidateDecision = AFMStepDecision(
                            thought: "Laya decided verify_and_send in \(Int(layaRes.latencyMs))ms: all fields populated.",
                            subGoal: "Send completed message",
                            targetElement: "Send",
                            actionType: "click",
                            textToType: nil,
                            isFinished: false
                        )
                    case "done", "read_pane", "conclude_task":
                        if historySummary.contains(where: { $0.lowercased().contains("click") }) {
                            candidateDecision = AFMStepDecision(
                                thought: "Laya decided conclusion in \(Int(layaRes.latencyMs))ms.",
                                subGoal: "Conclude task",
                                targetElement: "preview",
                                actionType: "done",
                                textToType: nil,
                                isFinished: true
                            )
                        }
                    default:
                        // For type_field and click_control, delegate element-level planning to System 2 AFM Task Planner
                        break
                    }
                }
            }

            // Step 2b: Fallback to System 2 AFM Task Planner if Laya did not decide
            var decision: AFMStepDecision
            if let candidate = candidateDecision {
                decision = candidate
            } else {
                decision = await AFMLunaCoordinationBridge.shared.planNextStepWithAFM(
                    userGoal: prompt,
                    currentStep: stepIndex,
                    appName: appName,
                    lastObservation: currentObservation,
                    historySummary: historySummary,
                    taskContract: taskPlan
                )
            }

            // Filled-Field Re-Target Guard (P5 Mandate):
            let obsService = ClickyUIObservationService.shared
            let isFormActive = obsService.latestWindowType == "draft_composer" || ["compose", "send", "create", "write"].contains(taskPlan?.intentType.lowercased() ?? "")
            if isFormActive, (decision.actionType == "type" || decision.actionType == "click") {
                let targetLower = decision.targetElement.lowercased()
                let currentFields = obsService.latestFormFields
                let fieldVal = currentFields.first(where: { $0.key.lowercased() == targetLower || targetLower.contains($0.key.lowercased()) })?.value ?? ""
                let isAlreadyFilled = !fieldVal.isEmpty && fieldVal != "[empty]"

                if isAlreadyFilled {
                    let requiredOrder = ["to", "subject", "body"]
                    if let nextEmptyKey = requiredOrder.first(where: { req in
                        let val = currentFields.first(where: { $0.key.lowercased() == req })?.value ?? "[empty]"
                        return val == "[empty]" || val.isEmpty
                    }) {
                        let capitalKey = nextEmptyKey == "to" ? "To" : (nextEmptyKey == "subject" ? "Subject" : "Body")
                        ClickyLogger.info("[VM_AGENT_LOOP]", "Filled-Field Re-Target Guard: Field '\(decision.targetElement)' is already populated ('\(fieldVal)'). Redirecting to empty required field '\(capitalKey)'.")
                        decision = AFMStepDecision(
                            thought: "Field \(decision.targetElement) is already populated. Redirecting focus to empty field \(capitalKey).",
                            subGoal: "Type text into \(capitalKey) field",
                            targetElement: capitalKey,
                            actionType: "type",
                            textToType: decision.textToType,
                            isFinished: false
                        )
                    }
                }
            }

            // Anti-Spurious Scroll Guard: If target item is already visible in listItems, do not scroll!
            // Exemption: If planner explicitly requests "scroll_up" because viewport is not at the top (!isAtTop), allow autonomous upward recovery!
            if (decision.actionType == "scroll_down" || (decision.actionType == "scroll_up" && currentScrollState.isAtTop)),
               let tIdx = effectiveTargetIdx,
               sessionObservedListItems.contains(where: { $0.index == tIdx }) {
                let hasAlreadyClickedTarget = historySummary.contains(where: {
                    $0.lowercased().contains("click") && ($0.contains("\(tIdx)") || $0.lowercased().contains("item \(tIdx)"))
                })
                if hasAlreadyClickedTarget {
                    ClickyLogger.info("[VM_AGENT_LOOP]", "Target item index \(tIdx) was already clicked and opened. Concluding step to validation.")
                    decision = AFMStepDecision(
                        thought: "Target item index \(tIdx) has already been clicked and preview pane is loaded.",
                        subGoal: "Conclude inspection of target item",
                        targetElement: "preview",
                        actionType: "done",
                        textToType: nil,
                        isFinished: true
                    )
                } else {
                    ClickyLogger.info("[VM_AGENT_LOOP]", "Prevented spurious scroll: target item index \(tIdx) is already visible on screen! Switching directly to click.")
                    let matchSnippet = sessionObservedListItems.first(where: { $0.index == tIdx })?.content ?? (tIdx == 1 ? "first item in list" : "item with index \(tIdx) in list")
                    decision = AFMStepDecision(
                        thought: "Target item index \(tIdx) is already visible on screen. Opening it directly.",
                        subGoal: "Open item #\(tIdx) for inspection",
                        targetElement: matchSnippet,
                        actionType: "click",
                        textToType: nil,
                        isFinished: false
                    )
                }
            }

            if decision.isFinished || decision.actionType == "done" {
                ClickyLogger.info("[AUTONOMOUS_LOOP]", "AFM concluded execution at step \(stepIndex). Validating outcome...")
                let validation = await AFMLunaCoordinationBridge.shared.validateWithAFM(
                    userGoal: prompt,
                    appName: appName,
                    performedSteps: historySummary,
                    latestObservation: currentObservation,
                    taskContract: taskPlan
                )
                let hasValidExtraction = !validation.extractedData.isEmpty && validation.extractedData.lowercased() != "none" && validation.extractedData.count > 3
                let isActionTask = taskPlan?.intentType == "compose" || taskPlan?.intentType == "send" || taskPlan?.intentType == "interact"
                if isActionTask {
                    isTaskSuccessful = validation.isDone && !validation.requiresTakeover
                } else {
                    isTaskSuccessful = validation.isDone || (hasValidExtraction && !validation.requiresTakeover)
                }
                finalSystemState = validation.systemState
                finalResponseToUser = validation.responseToUser
                lastValidationResult = validation
                break
            }
            currentActionDescription = "\(decision.subGoal)..."
            ClickyLogger.info("[HEARTBEAT]", "Step \(stepIndex): Plan determined: [\(decision.actionType)] -> '\(decision.targetElement)' (subGoal: '\(decision.subGoal)')")
            
            // Step 3: Luna Vision & AX Perception grounds the UI element coordinate
            let perception = await AFMLunaCoordinationBridge.shared.perceiveElementWithLuna(
                snapshotPath: currentSnap ?? "",
                targetElement: decision.targetElement,
                subGoal: decision.subGoal,
                pid: targetPID,
                actionType: decision.actionType
            )
            
            let targetPoint: CGPoint?
            let groundingMethod: String
            
            let vBounds = MascotVirtualDesktopService.shared.displayBounds
            let vOriginX = vBounds.origin.x > 0 ? vBounds.origin.x : 1512.0
            let vOriginY = vBounds.origin.y
            let vWidth = vBounds.width > 0 ? vBounds.width : 1920.0
            let vHeight = vBounds.height > 0 ? vBounds.height : 1080.0

            guard let primaryWin = candidateWindows.first else {
                ClickyLogger.warning("[VM_AGENT_LOOP]", "No candidate windows found for '\(appName)'. Suppressing blind interaction.")
                continue
            }
            let targetWinBounds = primaryWin.bounds
            MascotVirtualDesktopService.shared.currentWindowBounds = targetWinBounds

            var snapWidth = targetWinBounds.width > 0 ? targetWinBounds.width : vWidth
            var snapHeight = targetWinBounds.height > 0 ? targetWinBounds.height : vHeight
            if let snapPath = currentSnap, let img = NSImage(contentsOfFile: snapPath), img.size.width > 0 && img.size.height > 0 {
                snapWidth = img.size.width
                snapHeight = img.size.height
            }

            let targetLower = decision.targetElement.lowercased()
            let subGoalLower = decision.subGoal.lowercased()
            let isInspectIntent = taskPlan?.intentType == "inspect" || taskPlan?.intentType == "read"
            
            // Item selection is dynamic: only active when target index is designated AND the target matches an item in observed list
            let isTargetInListItems = sessionObservedListItems.contains { item in
                let itemLower = item.content.lowercased()
                return itemLower.contains(targetLower) || targetLower.contains(itemLower.prefix(20))
            }
            let isButtonControl = targetLower.contains("button") || targetLower.contains("save") || targetLower.contains("cancel") || targetLower.contains("close") || targetLower.contains("ok") || targetLower.contains("dismiss")
            let isItemClick = (decision.actionType == "click_item" || (decision.actionType == "click" && isTargetInListItems && !isButtonControl)) &&
                              isInspectIntent &&
                              effectiveTargetIdx != nil &&
                              !subGoalLower.contains("navigation") &&
                              !subGoalLower.contains("folder")
            if isItemClick, let tIdx = effectiveTargetIdx, let box = sessionObservedCardBoxes[tIdx] {
                let winOrigin = candidateWindows.first?.bounds.origin ?? CGPoint(x: vOriginX + 40, y: vOriginY + 40)
                let visualRelX = box.midX * snapWidth
                let visualRelY = (1.0 - box.midY) * snapHeight
                targetPoint = CGPoint(x: winOrigin.x + visualRelX, y: winOrigin.y + visualRelY)
                groundingMethod = "Visual OCR Card"
                ClickyLogger.info("[VM_AGENT_LOOP]", "Grounded target item \(tIdx) directly via Visual OCR Card at (\(Int(targetPoint?.x ?? 0)), \(Int(targetPoint?.y ?? 0)))")
            } else if isInspectIntent, effectiveTargetIdx != nil, !isTargetInListItems,
                      (decision.actionType == "click" || decision.actionType == "click_item"),
                      taskPlan?.targetSection?.lowercased() != "sidebar",
                      !subGoalLower.contains("navigation"),
                      !subGoalLower.contains("sidebar"),
                      !subGoalLower.contains("folder") {
                // Strict Item Target Guard (Universal & Zero Hardcoding):
                // When an inspect task targets an item ordinal (e.g. item 1), NEVER blindly click arbitrary
                // controls or popups outside the collection list if the item is not visible.
                targetPoint = nil
                groundingMethod = "Ungrounded (Strict Item Target Guard)"
                ClickyLogger.warning("[VM_AGENT_LOOP]", "Strict Item Target Guard: Suppressed clicking arbitrary element '\(decision.targetElement)' because target item index \(effectiveTargetIdx ?? 0) is not visible in collection list items.")
            } else if isFormActive, let fieldBox = obsService.latestFormFieldBoxes.first(where: {
                let k = $0.key.lowercased()
                let t = targetLower
                return k == t || t.contains(k) || k.contains(t)
            })?.value {
                let winOrigin = candidateWindows.first?.bounds.origin ?? CGPoint(x: vOriginX + 40, y: vOriginY + 40)
                let visualRelX = fieldBox.midX * snapWidth
                let visualRelY = (1.0 - fieldBox.midY) * snapHeight
                targetPoint = CGPoint(x: winOrigin.x + visualRelX, y: winOrigin.y + visualRelY)
                groundingMethod = "Form Field Box"
                ClickyLogger.info("[VM_AGENT_LOOP]", "Grounded target '\(decision.targetElement)' via Form Field Box at (\(Int(targetPoint?.x ?? 0)), \(Int(targetPoint?.y ?? 0)))")
            } else if let perception = perception {
                targetPoint = perception.coordinate
                groundingMethod = perception.sourceMethod
            } else {
                // Fast fallback grounding
                let fallbackGround = await ClickyHybridGroundingEngine.shared.resolveElementCoordinate(
                    targetPrompt: decision.targetElement,
                    pid: targetPID,
                    snapshotPath: currentSnap,
                    actionType: decision.actionType
                )
                if let fallback = fallbackGround {
                    targetPoint = fallback.coordinate
                    groundingMethod = fallback.method.rawValue
                } else if let ocrMatch = await findMatchingOcrElement(query: decision.targetElement) {
                    let winOrigin = candidateWindows.first?.bounds.origin ?? CGPoint(x: vOriginX + 40, y: vOriginY + 40)
                    let visualRelX = ocrMatch.box.midX * snapWidth
                    let visualRelY = (1.0 - ocrMatch.box.midY) * snapHeight
                    targetPoint = CGPoint(x: winOrigin.x + visualRelX, y: winOrigin.y + visualRelY)
                    groundingMethod = "Visual OCR Token"
                    ClickyLogger.info("[VM_AGENT_LOOP]", "Grounded target '\(decision.targetElement)' via Visual OCR Token '\(ocrMatch.text)' at (\(Int(targetPoint?.x ?? 0)), \(Int(targetPoint?.y ?? 0)))")
                } else {
                    targetPoint = nil
                    groundingMethod = "Ungrounded"
                    ClickyLogger.warning("[VM_AGENT_LOOP]", "Target '\(decision.targetElement)' could not be grounded in any visible UI element. Blind center click suppressed to preserve screen state.")
                }
            }

            let normX: Double
            let normY: Double
            if let tp = targetPoint {
                var effectiveWinBounds = targetWinBounds
                if effectiveWinBounds.origin.x < (vOriginX - 100) || effectiveWinBounds.width < 100 {
                    if let freshWin = candidateWindows.first(where: { $0.bounds.origin.x >= (vOriginX - 100) }) {
                        effectiveWinBounds = freshWin.bounds
                        ClickyLogger.info("[CUA_NORM]", "Re-resolved targetWinBounds to active virtual window bounds: \(effectiveWinBounds)")
                    } else {
                        effectiveWinBounds = CGRect(x: vOriginX + 40, y: vOriginY + 40, width: snapWidth, height: snapHeight)
                    }
                }

                let isScreenSpace = groundingMethod.contains("AX") ||
                                    groundingMethod.contains("Fast-Path") ||
                                    groundingMethod.contains("Form Field Box") ||
                                    groundingMethod == GroundedTargetResult.GroundingMethod.axUIElement.rawValue ||
                                    groundingMethod == "AXUIElement" ||
                                    groundingMethod == "Visual OCR Card" ||
                                    groundingMethod == "Visual OCR Token" ||
                                    groundingMethod == "Toolbar Action Heuristic"

                let rawX = Double(tp.x)
                let rawY = Double(tp.y)
                let winX = Double(effectiveWinBounds.origin.x)
                let winY = Double(effectiveWinBounds.origin.y)

                if isScreenSpace {
                    let relX = rawX - winX
                    let relY = rawY - winY
                    normX = min(max(relX / snapWidth, 0.02), 0.98)
                    normY = min(max(relY / snapHeight, 0.02), 0.98)
                } else {
                    normX = min(max(rawX / snapWidth, 0.02), 0.98)
                    normY = min(max(rawY / snapHeight, 0.02), 0.98)
                }

                let clickPos = MascotVirtualDesktopService.shared.targetDisplayCoordinate(for: CGPoint(x: normX, y: normY))
                let deltaX = Int(clickPos.x) - Int(rawX)
                let deltaY = Int(clickPos.y) - Int(rawY)
                ClickyLogger.info("[CUA_NORM]", "raw=(\(Int(rawX)), \(Int(rawY))), origin=(\(Int(winX)), \(Int(winY))), snap=(\(Int(snapWidth)), \(Int(snapHeight))) -> norm=(\(String(format: "%.3f", normX)), \(String(format: "%.3f", normY))) -> clickPos=(\(Int(clickPos.x)), \(Int(clickPos.y))) [delta: (\(deltaX), \(deltaY))]")
                ClickyLogger.info("[HEARTBEAT]", "Step \(stepIndex): Normalized coordinate resolved: (\(String(format: "%.3f", normX)), \(String(format: "%.3f", normY))) via [\(groundingMethod)]")
            } else {
                normX = 0.5
                normY = 0.5
            }
            // Step 4: Dispatch in-chat interactive card progress
            var currentQueue = queueItems
            let activeIdx = stepIndex - 1
            if currentQueue.indices.contains(activeIdx) {
                currentQueue[activeIdx] = ComputerCardQueueItem(
                    name: decision.subGoal.isEmpty ? currentQueue[activeIdx].name : decision.subGoal,
                    statusBadge: "Active (\(groundingMethod))",
                    isChecked: false
                )
                for prev in 0..<activeIdx {
                    currentQueue[prev] = ComputerCardQueueItem(
                        name: currentQueue[prev].name,
                        statusBadge: "Done",
                        isChecked: true
                    )
                }
            } else {
                currentQueue.append(ComputerCardQueueItem(
                    name: decision.subGoal,
                    statusBadge: "Active (\(groundingMethod))",
                    isChecked: false
                ))
            }
            
            var stepPayload = ComputerCardPayload(
                cardTitle: "Computer",
                status: .working,
                instructionText: prompt,
                snapshotImagePath: currentSnap,
                targetAppName: appName,
                activeWorkflowApp: appName,
                queueSummary: "\(stepIndex) of \(maxSteps) steps in progress",
                queueItems: currentQueue,
                targetCoordinateX: normX,
                targetCoordinateY: normY,
                currentActionLabel: "\(stepIndex). \(decision.subGoal) [\(groundingMethod)]"
            )
            onProgress?(stepPayload)
            
            // Pre-Terminal Vision Gate (Luna Truth Vision)
            // Before clicking irreversible external mutation actions ("Send", "Submit", "Kirim"),
            // verify holistic visual reality of the screen via Luna Truth Vision (gpt-6-luna)
            let isSendClick = decision.actionType == "click" && (
                targetLower.contains("send") || targetLower.contains("submit") || targetLower.contains("kirim")
            )
            if isSendClick, let snapPath = currentSnap, FileManager.default.fileExists(atPath: snapPath) {
                ClickyLogger.info("[VM_AGENT_LOOP]", "Pre-Terminal Vision Gate: Verifying holistic screen truth before executing '\(decision.targetElement)'...")
                if let truth = try? await ChatGPTCodexVisionService.shared.queryScreenState(imagePath: snapPath, appName: appName) {
                    ClickyLogger.info("[VM_AGENT_LOOP]", "Luna Truth Vision: windowType=\(truth.windowType), hasModalOrError=\(truth.hasModalOrError), summary='\(truth.visualSummary)'")
                    if truth.hasModalOrError {
                        let alertText = truth.errorOrAlertMessage ?? "Active alert dialog detected"
                        ClickyLogger.warning("[VM_AGENT_LOOP]", "Pre-Terminal Vision Gate BLOCKED '\(decision.targetElement)': Active modal alert/error detected: '\(alertText)'")
                        decision = AFMStepDecision(
                            thought: "Luna Truth Vision detected an active alert/error: '\(alertText)'. Dismissing or acknowledging it first.",
                            subGoal: "Acknowledge or dismiss alert dialog",
                            targetElement: "OK",
                            actionType: "click",
                            textToType: nil,
                            isFinished: false
                        )
                    } else {
                        let emptyRequired = truth.formFields.filter { (k, v) in
                            let lowerKey = k.lowercased()
                            let isEmptyVal = v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || v == "[empty]"
                            return isEmptyVal && (lowerKey.contains("subject") || lowerKey.contains("subjek") || lowerKey.contains("to") || lowerKey.contains("penerima"))
                        }
                        if !emptyRequired.isEmpty {
                            let missingName = emptyRequired.keys.first ?? "Subject"
                            ClickyLogger.warning("[VM_AGENT_LOOP]", "Pre-Terminal Vision Gate BLOCKED '\(decision.targetElement)': Required field '\(missingName)' is visually empty on screen.")
                            decision = AFMStepDecision(
                                thought: "Luna Truth Vision verified that '\(missingName)' is visually empty. Focusing and typing into \(missingName) field before sending.",
                                subGoal: "Type text into \(missingName) field",
                                targetElement: "\(missingName) field",
                                actionType: "type",
                                textToType: prompt,
                                isFinished: false
                            )
                        }
                    }
                }
            }
            var actionObsResult: String
            if targetPoint != nil {
                // Step 5: Execute Virtual CUA Action via Pure Physical Mouse Hands (0 Host Screen Intrusion)
                // Visually glide AI cursor smoothly to target element coordinate with human kinematics
                await MascotVirtualDesktopService.shared.glideReticleTo(target: CGPoint(x: normX, y: normY))

                if decision.actionType == "type" && (decision.textToType == nil || decision.textToType?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) {
                    let targetEl = decision.targetElement.lowercased()
                    let extracted = CUATypeActionTool.extractPayloadFromPrompt(prompt)
                    let text = !extracted.isEmpty ? extracted : (targetEl.contains("to") ? (taskPlan?.searchQuery ?? prompt) : prompt)
                    decision = AFMStepDecision(
                        thought: decision.thought,
                        subGoal: decision.subGoal,
                        targetElement: decision.targetElement,
                        actionType: decision.actionType,
                        textToType: text,
                        isFinished: decision.isFinished
                    )
                    ClickyLogger.info("[VM_AGENT_LOOP]", "Populated missing textToType dynamically for '\(decision.targetElement)': '\(text)'")
                }

                // Delegate physical action execution to specialized modular CUA tool
                let actionResult = await CUAPhysicalActionDispatcher.shared.dispatchAction(
                    decision: decision,
                    normalizedPoint: CGPoint(x: normX, y: normY),
                    appName: appName,
                    targetPID: targetPID,
                    snapshotPath: currentSnap
                )
                actionObsResult = actionResult.observationResult
                ClickyLogger.info("[HEARTBEAT]", "Step \(stepIndex): Dispatched action [\(decision.actionType)] -> '\(decision.targetElement)' successfully.")
            } else {
                ClickyLogger.warning("[VM_AGENT_LOOP]", "Suppressed blind interaction: target '\(decision.targetElement)' was not grounded.")
                actionObsResult = "Target '\(decision.targetElement)' not visible on screen. Re-observing..."
            }
            
            if decision.actionType == "click" && (decision.targetElement.lowercased().contains("new") || decision.targetElement.lowercased().contains("compose") || decision.targetElement.lowercased().contains("create")) {
                try? await Task.sleep(nanoseconds: 800_000_000)
            } else {
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            // Zero Host Screen Intrusion: Immediately pull any newly spawned windows (e.g. "New Message") into Virtual Display (in background)
            Task.detached(priority: .userInitiated) {
                await MascotVirtualDesktopService.shared.relocateAppWindowsToVirtualDesktop(appName: appName)
            }
            // Capture updated frame
            let updatedSnap = await CompanionWindowStreamService.shared.captureTargetWindowAsync(appName: appName, slug: slug)
            ClickyLogger.info("[HEARTBEAT]", "Step \(stepIndex): Post-action frame capture completed: \(updatedSnap ?? "none")")
            if decision.actionType != "read" && decision.actionType != "inspect" {
                let afterActionObs = await readStructuredObservation(
                    appName: appName,
                    pid: targetPID,
                    snapshotPath: updatedSnap
                )
                if !afterActionObs.isEmpty && afterActionObs != "{}" {
                    let targetedSummary = summarizeTargetedObservation(
                        actionType: decision.actionType,
                        targetElement: decision.targetElement,
                        observationJSON: afterActionObs,
                        targetIndex: effectiveTargetIdx
                    )
                    if !targetedSummary.isEmpty {
                        actionObsResult += " -> " + targetedSummary
                    }
                }
            }
            
            // Record audit trail and queue item
            let stepRecord = VMAgentStepRecord(
                stepNumber: stepIndex,
                actionName: "\(decision.actionType):\(decision.targetElement)",
                targetDescription: decision.subGoal,
                groundingMethod: groundingMethod,
                coordinateX: Int(targetPoint?.x ?? 0),
                coordinateY: Int(targetPoint?.y ?? 0),
                observationResult: actionObsResult
            )
            auditTrail.append(stepRecord)
            let stepIdx = stepIndex - 1
            if targetPoint != nil {
                if queueItems.indices.contains(stepIdx) {
                    queueItems[stepIdx] = ComputerCardQueueItem(
                        name: decision.subGoal.isEmpty ? queueItems[stepIdx].name : decision.subGoal,
                        statusBadge: "Done",
                        isChecked: true
                    )
                } else {
                    queueItems.append(ComputerCardQueueItem(
                        name: decision.subGoal,
                        statusBadge: "Done",
                        isChecked: true
                    ))
                }
                historySummary.append("\(decision.subGoal): \(actionObsResult)")
            } else {
                if queueItems.indices.contains(stepIdx) {
                    queueItems[stepIdx] = ComputerCardQueueItem(
                        name: decision.subGoal.isEmpty ? queueItems[stepIdx].name : decision.subGoal,
                        statusBadge: "Failed",
                        isChecked: false
                    )
                } else {
                    queueItems.append(ComputerCardQueueItem(
                        name: decision.subGoal,
                        statusBadge: "Failed",
                        isChecked: false
                    ))
                }
                historySummary.append("Failed to execute \(decision.subGoal): \(actionObsResult)")
            }
            
            // Step 6: AFM Validates state transition
            let validation = await AFMLunaCoordinationBridge.shared.validateWithAFM(
                userGoal: prompt,
                appName: appName,
                performedSteps: historySummary,
                latestObservation: actionObsResult,
                taskContract: taskPlan
            )
            lastValidationResult = validation
            ClickyLogger.info("[HEARTBEAT]", "Step \(stepIndex): Egress evaluation completed: isDone=\(validation.isDone), takeover=\(validation.requiresTakeover), state='\(validation.systemState)'")
            // If validation requires human confirmation / takeover to proceed (e.g. review & send draft)
            if validation.requiresTakeover {
                ClickyLogger.info("[AUTONOMOUS_LOOP]", "AFM requested human takeover: \(validation.systemState)")
                queueItems.append(ComputerCardQueueItem(name: "Human Takeover Required to Send", statusBadge: "Takeover Needed", isChecked: false))
                let takeoverPayload = finishTask(
                    summary: validation.systemState,
                    responseToUser: validation.responseToUser,
                    slug: slug,
                    taskPrompt: prompt,
                    appName: appName,
                    auditTrail: auditTrail,
                    queueItems: queueItems,
                    isSuccess: true,
                    status: .takeoverNeeded
                )
                onProgress?(takeoverPayload)
                MascotVirtualDesktopService.shared.hideReticle(afterDwell: false)
                reportFinding(message: validation.responseToUser, slug: slug)
                return takeoverPayload
            }

            let isSendTask = taskPlan?.requiresTakeoverOnCompletion == true
            let draftNotSentYet = isSendTask && stepIndex < 3 && !validation.requiresTakeover
            let isScrollStep = decision.actionType.lowercased().contains("scroll")
            let targetIdx = taskPlan?.targetIndex
            let targetIndexNotReached: Bool
            if let tIdx = targetIdx, tIdx > 1 {
                let hasClickedTarget = historySummary.contains(where: {
                    $0.lowercased().contains("click") && ($0.contains("\(tIdx)") || $0.lowercased().contains("item \(tIdx)"))
                })
                targetIndexNotReached = !hasClickedTarget
            } else {
                targetIndexNotReached = false
            }

            let effectiveResp = validation.responseToUser.isEmpty ? validation.systemState : validation.responseToUser
            let hasValidExtraction = !validation.extractedData.isEmpty && validation.extractedData.lowercased() != "none" && validation.extractedData.count > 3
            let isActionTask = taskPlan?.intentType == "compose" || taskPlan?.intentType == "send" || taskPlan?.intentType == "interact"

            if isActionTask {
                // Action/Composition tasks MUST have validation.isDone == true to complete!
                // Factual extraction alone NEVER bypasses completion for an action task.
                if !isScrollStep && validation.isDone && !effectiveResp.isEmpty {
                    isTaskSuccessful = true
                    finalSystemState = validation.systemState
                    finalResponseToUser = effectiveResp
                    ClickyLogger.info("[AUTONOMOUS_LOOP]", "AFM confirmed action task completion: \(validation.systemState)")
                    break
                }
            } else {
                if !isScrollStep && !draftNotSentYet && !targetIndexNotReached && (validation.isDone || (hasValidExtraction && !validation.requiresTakeover)) && !effectiveResp.isEmpty {
                    isTaskSuccessful = true
                    finalSystemState = validation.systemState
                    finalResponseToUser = effectiveResp
                    ClickyLogger.info("[AUTONOMOUS_LOOP]", "AFM confirmed task completion with extracted data: \(validation.extractedData)")
                    break
                }
            }
        }
        
        // Anti-Fake Check: If loop terminated without isTaskSuccessful flag, check if last validation had factual extraction
        if !isTaskSuccessful {
            let isActionTask = taskPlan?.intentType == "compose" || taskPlan?.intentType == "send" || taskPlan?.intentType == "interact"
            if !isActionTask,
               let lastVal = lastValidationResult,
               !lastVal.extractedData.isEmpty,
               lastVal.extractedData.lowercased() != "none",
               lastVal.isDone,
               !lastVal.requiresTakeover {
                isTaskSuccessful = true
                finalResponseToUser = lastVal.responseToUser.isEmpty ? lastVal.systemState : lastVal.responseToUser
                finalSystemState = lastVal.systemState
                ClickyLogger.info("[AUTONOMOUS_LOOP]", "Reconciled task success from last validation extracted data: \(lastVal.extractedData)")
            } else if let lastVal = lastValidationResult, (!lastVal.responseToUser.isEmpty || !lastVal.systemState.isEmpty), !lastVal.requiresTakeover {
                finalResponseToUser = lastVal.responseToUser.isEmpty ? lastVal.systemState : lastVal.responseToUser
                finalSystemState = lastVal.systemState
                ClickyLogger.warning("[AUTONOMOUS_LOOP]", "Task concluded without validation confirmation: \(finalSystemState)")
            } else {
                let latestSnap = MascotVirtualDesktopService.shared.activeSnapshotPath ?? initialSnapPath
                let currentObs = await readStructuredObservation(appName: appName, pid: targetPID, snapshotPath: latestSnap)
                let conclusionVal = await TaskEgressValidator.shared.validate(
                    userGoal: prompt,
                    appName: appName,
                    performedSteps: historySummary + ["Execution step limit reached (\(maxSteps) steps)"],
                    latestObservation: currentObs,
                    taskContract: taskPlan
                )
                finalResponseToUser = conclusionVal.responseToUser
                finalSystemState = conclusionVal.systemState
                if conclusionVal.isDone && (!conclusionVal.requiresTakeover || taskPlan?.requiresTakeoverOnCompletion == true) {
                    isTaskSuccessful = true
                    ClickyLogger.info("[AUTONOMOUS_LOOP]", "Conclusion validation confirmed task success: \(conclusionVal.systemState)")
                } else {
                    ClickyLogger.warning("[AUTONOMOUS_LOOP]", "Conclusion validation indicated task not accomplished: \(conclusionVal.systemState)")
                }
            }
        }
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        _ = await CompanionWindowStreamService.shared.captureTargetWindowAsync(appName: appName, slug: slug)
        CompanionWindowStreamService.shared.stopStreaming()
        MascotVirtualDesktopService.shared.hideReticle(afterDwell: true)
        finalResponseToUser = finalResponseToUser
            .replacingOccurrences(of: #"^<[^>]+>\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if finalResponseToUser.isEmpty {
            finalResponseToUser = finalSystemState
        }

        reportFinding(message: finalResponseToUser, slug: slug)
        return finishTask(
            summary: finalSystemState,
            responseToUser: finalResponseToUser,
            slug: slug,
            taskPrompt: prompt,
            appName: appName,
            auditTrail: auditTrail,
            queueItems: queueItems,
            isSuccess: isTaskSuccessful
        )
    }

    // MARK: - Generic Visual & Accessibility CUA Tools

    /// Inspects the companion's VM workspace, captures snapshot, and lists active elements
    public func inspectWorkspace(slug: String, appName: String) async -> (snapshotPath: String?, elements: [String]) {
        let snapshot = await CompanionWindowStreamService.shared.captureTargetWindowAsync(appName: appName, slug: slug)
        var detectedElements: [String] = []

        if let axApp = ClickyUIObservationService.shared.findTargetAXApplication(appName: appName) {
            detectedElements = ClickyUIObservationService.shared.extractAXElementTitles(from: axApp)
        }

        return (snapshot, detectedElements)
    }

    /// Resolves target element using AXUIElement-first with 6 Luna Vision fallback, then clicks via CUA Driver
    public func groundAndClick(
        targetDescription: String,
        pid: pid_t? = nil,
        snapshotPath: String? = nil,
        isSandboxed: Bool = true
    ) async -> (success: Bool, point: CGPoint, method: GroundedTargetResult.GroundingMethod) {
        if isSandboxed {
            // Virtual VM Viewport Click: 0 host mouse movement
            let grounded = await ClickyHybridGroundingEngine.shared.resolveElementCoordinate(
                targetPrompt: targetDescription,
                pid: pid,
                snapshotPath: snapshotPath
            )
            let virtualPt = grounded?.coordinate ?? CGPoint(x: 240, y: 150)
            await CompanionVMViewportController.shared.simulateVMClick(at: virtualPt)
            return (true, virtualPt, grounded?.method ?? .axUIElement)
        }

        let grounded = await ClickyHybridGroundingEngine.shared.resolveElementCoordinate(
            targetPrompt: targetDescription,
            pid: pid,
            snapshotPath: snapshotPath
        )

        let targetPt = grounded?.coordinate ?? CGPoint(x: 100, y: 100)
        let method = grounded?.method ?? .axUIElement

        // Perform GUI Mouse Click via CUA Driver
        await CuaDriverClient.shared.glideAgentCursor(to: targetPt)
        try? await Task.sleep(nanoseconds: 30_000_000)
        await ComputerUsePhysicalExecutor.shared.executeMoveAndClick(at: targetPt, button: .left, clickCount: 1)

        return (true, targetPt, method)
    }

    /// Focuses target input element and types text via CUA Driver
    public func typeText(
        targetDescription: String,
        text: String,
        pid: pid_t? = nil,
        snapshotPath: String? = nil,
        isSandboxed: Bool = true
    ) async -> Bool {
        if isSandboxed {
            // Virtual VM Viewport Type: 0 host keyboard typing
            await CompanionVMViewportController.shared.simulateVMType(text: text)
            return true
        }

        let grounded = await ClickyHybridGroundingEngine.shared.resolveElementCoordinate(
            targetPrompt: targetDescription,
            pid: pid,
            snapshotPath: snapshotPath,
            actionType: "type"
        )

        if let pt = grounded?.coordinate {
            await CuaDriverClient.shared.glideAgentCursor(to: pt)
            await ComputerUsePhysicalExecutor.shared.executeMoveAndClick(at: pt, button: .left, clickCount: 1)
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        ComputerUsePhysicalExecutor.shared.executeTypeText(text, autoSendReturn: false)
        return true
    }

    private func findMatchingOcrElement(query: String) async -> (text: String, box: CGRect)? {
        await ClickyUIObservationService.shared.findMatchingOcrElement(query: query)
    }

    /// Reads screen contents into a structured, section-based JSON representation
    /// Sections: topBar, sidebar, listItems (with explicit 1-based indexing), previewPane, content, "viewport": {"isAtTop": Bool}
    public func readStructuredObservation(
        appName: String,
        pid: pid_t? = nil,
        snapshotPath: String? = nil,
        targetSection: String? = nil,
        intentType: String? = nil
    ) async -> String {
        // Injects viewport section ("viewport": {"isAtTop": Bool}) via ClickyUIObservationService
        await ClickyUIObservationService.shared.readStructuredObservation(
            appName: appName,
            pid: pid,
            snapshotPath: snapshotPath,
            targetSection: targetSection,
            intentType: intentType
        )
    }

    /// Produces a concise, targeted per-item summary of screen state delta following an action.
    /// Eliminates token bloating by focusing strictly on the interacted item and reading pane.
    public func summarizeTargetedObservation(
        actionType: String,
        targetElement: String,
        observationJSON: String,
        targetIndex: Int?
    ) -> String {
        ClickyUIObservationService.shared.summarizeTargetedObservation(
            actionType: actionType,
            targetElement: targetElement,
            observationJSON: observationJSON,
            targetIndex: targetIndex
        )
    }

    private func resolveCardIndices(newCards: [String], previousItems: [(index: Int, content: String)], isAtTop: Bool = true) -> [Int] {
        ClickyUIObservationService.shared.resolveCardIndices(newCards: newCards, previousItems: previousItems, isAtTop: isAtTop)
    }

    /// Reads text contents from application via universal accessibility hierarchy (AXUIElement)
    /// and visual OCR from window screenshot — 100% universal across ANY macOS application (Mail, Safari, Notes, TradingView, etc.)
    public func readElements(targetDescription: String, pid: pid_t? = nil, appName: String, snapshotPath: String? = nil) async -> [String] {
        let structuredJSON = await readStructuredObservation(appName: appName, pid: pid, snapshotPath: snapshotPath)
        return [structuredJSON]
    }

    /// Reports an intermediate finding to the companion chat
    public func reportFinding(message: String, slug: String) {
        ClickyLogger.info("[VM_AGENT_LOOP]", "Report finding [\(slug)]: \(message)")
    }

    /// Concludes the autonomous task, writes audit deliverable receipt, and returns ComputerCardPayload
    public func finishTask(
        summary: String,
        responseToUser: String? = nil,
        slug: String,
        taskPrompt: String,
        appName: String = "Workspace",
        auditTrail: [VMAgentStepRecord],
        queueItems: [ComputerCardQueueItem],
        isSuccess: Bool,
        status: ComputerCardStatus? = nil
    ) -> ComputerCardPayload {
        let cleanResponse = responseToUser?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeResponse: String = (cleanResponse?.isEmpty == false) ? cleanResponse! : (!cleanSummary.isEmpty ? cleanSummary : "\(appName) task completed.")

        let receipt = VMAgentDeliverableReceipt(
            companionSlug: slug,
            taskPrompt: taskPrompt,
            status: status?.rawValue ?? (isSuccess ? "Completed" : "Failed"),
            summary: cleanSummary.isEmpty ? safeResponse : cleanSummary,
            responseToUser: safeResponse,
            auditTrail: auditTrail
        )
        #if DEBUG
        let isE2ERun = CompanionManager.shared.activeE2ERunId != nil
        let teardownDelay: TimeInterval = isE2ERun ? 10.0 : 1.2
        #else
        let teardownDelay: TimeInterval = 1.2
        #endif

        let finalStatus = status ?? (isSuccess ? .done : .failed)
        let shouldSaveReceipt = isSuccess && finalStatus != .failed

        if shouldSaveReceipt {
            saveDeliverableReceipt(receipt: receipt, slug: slug)
        } else {
            ClickyLogger.warning("[VM_AGENT_LOOP]", "Task was not validated as successful; suppressed saving deliverable receipt.")
        }

        #if DEBUG
        CompanionManager.postE2EDone(
            runId: nil,
            concluded: true,
            validatorIsDone: isSuccess,
            deliverableSaved: shouldSaveReceipt
        )
        #endif
        let finalizedQueue: [ComputerCardQueueItem]
        if finalStatus == .done {
            finalizedQueue = queueItems.map {
                ComputerCardQueueItem(name: $0.name, statusBadge: "Done", isChecked: true)
            }
        } else {
            finalizedQueue = queueItems
        }

        if finalStatus != .takeoverNeeded {
            DispatchQueue.main.asyncAfter(deadline: .now() + teardownDelay) {
                CompanionWindowStreamService.shared.stopStreaming()
                MascotVirtualDesktopService.shared.stopVirtualDesktop()
            }
        }

        let activeRunId = CompanionManager.shared.activeE2ERunId ?? UUID().uuidString
        let evidenceDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".izanotchy/companions/\(slug)/workspace/evidence/\(activeRunId)", isDirectory: true)

        let performedActions = auditTrail.map { "\($0.actionName): \($0.targetDescription)" }
        let facts: [String] = [
            cleanSummary.isEmpty ? safeResponse : cleanSummary,
            "Tugas diselesaikan pada aplikasi \(appName) melalui CUA terisolasi."
        ]
        let egressReport = EgressReport(
            facts: facts,
            assumptions: [
                "Lingkungan virtual display terisolasi beroperasi tanpa gangguan layar utama."
            ],
            completedActions: performedActions.isEmpty ? ["Eksekusi alur tugas selesai."] : performedActions,
            awaitingApproval: [],
            openQuestions: []
        )
        let snapPath = CompanionWindowStreamService.shared.activeSnapshotPath ?? CompanionVMViewportController.shared.activeSnapshotPath
        let egressEvidence = EvidencePreservationService.shared.preserveRunEvidence(
            runId: activeRunId,
            slug: slug,
            sourceLinks: [],
            snapshotPath: snapPath,
            performedSteps: performedActions,
            filesCreated: ["\(evidenceDir.path)/egress.json"],
            unverifiedItems: [],
            report: egressReport
        )
        let egressRes = EgressResult(
            runId: activeRunId,
            concluded: true,
            isDone: isSuccess,
            report: egressReport,
            evidence: egressEvidence,
            deliverables: [
                EgressDeliverable(type: "card", artifact: "\(evidenceDir.path)/egress.json", title: "\(appName) Task Receipt", summary: safeResponse)
            ]
        )

        return ComputerCardPayload(
            cardTitle: "Computer",
            status: finalStatus,
            instructionText: taskPrompt,
            snapshotImagePath: CompanionWindowStreamService.shared.activeSnapshotPath ?? CompanionVMViewportController.shared.activeSnapshotPath,
            targetAppName: appName,
            activeWorkflowApp: appName,
            queueSummary: "\(finalizedQueue.count) actions executed",
            queueItems: finalizedQueue,
            targetCoordinateX: nil,
            targetCoordinateY: nil,
            currentActionLabel: nil,
            deliverableSummary: safeResponse,
            responseToUser: safeResponse,
            updatedAt: Date(),
            egressResult: egressRes
        )
    }

    // MARK: - Internal Deliverable Persistence
    private func saveDeliverableReceipt(receipt: VMAgentDeliverableReceipt, slug: String) {
        let deliverablesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".izanotchy/companions/\(slug)/workspace/deliverables", isDirectory: true)
        try? FileManager.default.createDirectory(at: deliverablesDir, withIntermediateDirectories: true)

        let fileURL = deliverablesDir.appendingPathComponent("task_\(receipt.id.prefix(8)).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(receipt) {
            try? data.write(to: fileURL)
            ClickyLogger.info("[VM_AGENT_LOOP]", "Saved deliverable receipt to: \(fileURL.path)")
        }
    }

    private func extractAXToolbarControls(
        from element: AXUIElement,
        winPos: CGPoint,
        winSize: CGSize,
        into topBarItems: inout [String],
        depth: Int = 0
    ) {
        ClickyUIObservationService.shared.extractAXToolbarControls(
            from: element,
            winPos: winPos,
            winSize: winSize,
            into: &topBarItems,
            depth: depth
        )
    }
}
