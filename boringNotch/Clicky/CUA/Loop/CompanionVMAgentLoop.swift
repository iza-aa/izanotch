//
//  CompanionVMAgentLoop.swift
//  boringNotch
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
    private var sessionObservedListItems: [(index: Int, content: String)] = []

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
        sessionObservedListItems.removeAll()
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
        CompanionWindowStreamService.shared.ensureWorkflowAppRunning(appName: appName)
        MascotVirtualDesktopService.shared.ensureVirtualDisplay(slug: slug)
        CompanionWindowStreamService.shared.activeIntentType = taskPlan?.intentType
        CompanionWindowStreamService.shared.activeTargetEntity = taskPlan?.targetEntity
        MascotVirtualDesktopService.shared.assignAppToVirtualDesktop(appName: appName, slug: slug, intentType: taskPlan?.intentType)
        CompanionWindowStreamService.shared.startStreaming(appName: appName, slug: slug, interval: 0.8)

        // Initial snapshot capture from isolated virtual desktop (prioritize real application window)
        let initialSnapPath = await CompanionWindowStreamService.shared.captureTargetWindowAsync(appName: appName, slug: slug) ??
            (MascotVirtualDesktopService.shared.captureSnapshot() != nil ? MascotVirtualDesktopService.shared.activeSnapshotPath : nil)

        // 2b. Human Takeover Check: Only if a blocking system dialog / sheet is detected
        let userLang = taskPlan?.userLanguage ?? TaskIngressGateway.resolveLanguage(prompt: prompt)
        if let blockingDialog = CompanionWindowStreamService.shared.detectBlockingDialog(appName: appName) {
            let reason = await TaskEgressValidator.shared.synthesizeNotice(
                noticeSummary: "System dialog detected on \(appName) (\"\(blockingDialog)\"). Manual takeover required.",
                appName: appName,
                userGoal: prompt,
                userLanguage: userLang
            )
            queueItems.append(ComputerCardQueueItem(name: "Human Intervention Required", statusBadge: "Takeover Needed", isChecked: false))
            let takeoverPayload = finishTask(
                summary: reason,
                slug: slug,
                taskPrompt: prompt,
                appName: appName,
                auditTrail: auditTrail,
                queueItems: queueItems,
                isSuccess: true,
                status: .takeoverNeeded
            )
            onProgress?(takeoverPayload)
            return takeoverPayload
        }

        // 3. Hierarchical Autonomous CUA ReAct Loop (AFM ⇄ Luna)
        // AFM (Apple Foundation Models, On-Device / Cloud Fallback): Task Planner, Reasoner & Validator
        // Luna (6 Luna Medium / gpt-6-luna): High-Resolution Visual Perception & Element Grounder
        
        let candidateWindows = CompanionWindowStreamService.shared.findCandidateWindows(appName: appName)
        let targetPID = candidateWindows.first?.pid ?? NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.localizedCaseInsensitiveContains(appName) == true
        })?.processIdentifier
        
        // Reset scroll position to top (0.0) if inspecting latest item / general inbox (Clean Workspace Anchor)
        let effectiveTargetIdx = taskPlan?.targetIndex ?? (taskPlan?.intentType == "inspect" || taskPlan?.intentType == "read" ? 1 : nil)
        if let pid = targetPID, pid > 0, effectiveTargetIdx == 1 {
            CUAScrollActionTool.resetScrollToTop(pid: pid)
        }

        let maxSteps = 6
        var historySummary: [String] = []
        var finalSystemState = "Task in progress"
        var finalResponseToUser = ""
        var isTaskSuccessful = false
        var lastValidationResult: AFMValidationResult? = nil
        
        for stepIndex in 1...maxSteps {
            if Task.isCancelled { break }
            
            // Step 1: Capture active frame from isolated workspace
            let currentSnap = await CompanionWindowStreamService.shared.captureTargetWindowAsync(appName: appName, slug: slug) ??
                MascotVirtualDesktopService.shared.activeSnapshotPath ?? initialSnapPath
                
            // Check Human Takeover condition if system dialog blocked
            if let blockingDialog = CompanionWindowStreamService.shared.detectBlockingDialog(appName: appName) {
                let reason = await TaskEgressValidator.shared.synthesizeNotice(
                    noticeSummary: "System dialog detected on \(appName) (\"\(blockingDialog)\"). Manual takeover required.",
                    appName: appName,
                    userGoal: prompt,
                    userLanguage: userLang
                )
                queueItems.append(ComputerCardQueueItem(name: "Human Intervention Required", statusBadge: "Takeover Needed", isChecked: false))
                let takeoverPayload = finishTask(
                    summary: reason,
                    responseToUser: reason,
                    slug: slug,
                    taskPrompt: prompt,
                    appName: appName,
                    auditTrail: auditTrail,
                    queueItems: queueItems,
                    isSuccess: true,
                    status: .takeoverNeeded
                )
                onProgress?(takeoverPayload)
                return takeoverPayload
            }
            
            // SEE (Prinsip See ➔ Plan ➔ Act): Amati kondisi layar nyata saat ini dari snapshot terkini
            let rawObs = await readStructuredObservation(appName: appName, pid: targetPID, snapshotPath: currentSnap)
            let currentObservation = rawObs.isEmpty ? "App is open in isolated workspace" : rawObs

            // Step 2: AFM Task Planner determines the next atomic sub-goal
            let decision = await AFMLunaCoordinationBridge.shared.planNextStepWithAFM(
                userGoal: prompt,
                currentStep: stepIndex,
                appName: appName,
                lastObservation: currentObservation,
                historySummary: historySummary,
                taskContract: taskPlan
            )
            
            var activeDecision = decision
            
            // Anti-Spurious Scroll Guard: If target item is already visible in listItems, do not scroll!
            if (activeDecision.actionType == "scroll_down" || activeDecision.actionType == "scroll_up"),
               let tIdx = effectiveTargetIdx,
               sessionObservedListItems.contains(where: { $0.index == tIdx }) {
                ClickyLogger.info("[VM_AGENT_LOOP]", "Prevented spurious scroll: target item index \(tIdx) is already visible on screen! Switching directly to click.")
                let ordinalDesc = tIdx == 1 ? "first item in list" : "item with index \(tIdx) in list"
                activeDecision = AFMStepDecision(
                    thought: "Target item index \(tIdx) is already visible on screen. Opening it directly.",
                    subGoal: "Open \(ordinalDesc) for inspection",
                    targetElement: ordinalDesc,
                    actionType: "click",
                    textToType: nil,
                    isFinished: false
                )
            }

            if activeDecision.isFinished || activeDecision.actionType == "done" {
                ClickyLogger.info("[AUTONOMOUS_LOOP]", "AFM concluded execution at step \(stepIndex). Validating outcome...")
                let validation = await AFMLunaCoordinationBridge.shared.validateWithAFM(
                    userGoal: prompt,
                    appName: appName,
                    performedSteps: historySummary,
                    latestObservation: currentObservation,
                    taskContract: taskPlan
                )
                let hasValidExtraction = !validation.extractedData.isEmpty && validation.extractedData.lowercased() != "none" && validation.extractedData.count > 3
                isTaskSuccessful = validation.isDone || (hasValidExtraction && !validation.requiresTakeover)
                finalSystemState = validation.systemState
                finalResponseToUser = validation.responseToUser
                lastValidationResult = validation
                break
            }
            
            currentActionDescription = "\(activeDecision.subGoal)..."
            
            // Step 3: Luna Vision & AX Perception grounds the UI element coordinate
            let perception = await AFMLunaCoordinationBridge.shared.perceiveElementWithLuna(
                snapshotPath: currentSnap ?? "",
                targetElement: activeDecision.targetElement,
                subGoal: activeDecision.subGoal,
                pid: targetPID
            )
            
            let targetPoint: CGPoint
            let groundingMethod: String
            
            let vBounds = MascotVirtualDesktopService.shared.displayBounds
            let vOriginX = vBounds.origin.x > 0 ? vBounds.origin.x : 1512.0
            let vOriginY = vBounds.origin.y
            let vWidth = vBounds.width > 0 ? vBounds.width : 1920.0
            let vHeight = vBounds.height > 0 ? vBounds.height : 1080.0

            if let perception = perception {
                targetPoint = perception.coordinate
                groundingMethod = perception.sourceMethod
            } else {
                // Fast fallback grounding
                let fallbackGround = await ClickyHybridGroundingEngine.shared.resolveElementCoordinate(
                    targetPrompt: decision.targetElement,
                    pid: targetPID,
                    snapshotPath: currentSnap
                )
                let defaultCenter: CGPoint
                if let winBounds = candidateWindows.first?.bounds {
                    defaultCenter = CGPoint(x: winBounds.midX, y: winBounds.midY)
                } else {
                    defaultCenter = CGPoint(x: vOriginX + (vWidth / 2.0), y: vOriginY + (vHeight / 2.0))
                }
                targetPoint = fallbackGround?.coordinate ?? defaultCenter
                groundingMethod = fallbackGround?.method.rawValue ?? GroundedTargetResult.GroundingMethod.axUIElement.rawValue
            }
            
            let targetWinBounds = candidateWindows.first?.bounds ?? CGRect(x: vOriginX + 40, y: vOriginY + 40, width: 1260, height: 800)
            MascotVirtualDesktopService.shared.currentWindowBounds = targetWinBounds

            var snapWidth = targetWinBounds.width > 0 ? targetWinBounds.width : 1260.0
            var snapHeight = targetWinBounds.height > 0 ? targetWinBounds.height : 800.0
            if let snapPath = currentSnap, let img = NSImage(contentsOfFile: snapPath), img.size.width > 0 && img.size.height > 0 {
                snapWidth = img.size.width
                snapHeight = img.size.height
            }

            let normX: Double
            let normY: Double
            if groundingMethod == GroundedTargetResult.GroundingMethod.axUIElement.rawValue {
                let rawX = Double(targetPoint.x)
                let relX = rawX >= targetWinBounds.origin.x ? (rawX - targetWinBounds.origin.x) : rawX
                let rawY = Double(targetPoint.y)
                let relY = rawY >= targetWinBounds.origin.y ? (rawY - targetWinBounds.origin.y) : rawY
                normX = min(max(relX / snapWidth, 0.02), 0.98)
                normY = min(max(relY / snapHeight, 0.02), 0.98)
            } else {
                // Luna Vision coordinates are already relative to the window snapshot image
                normX = min(max(Double(targetPoint.x) / snapWidth, 0.02), 0.98)
                normY = min(max(Double(targetPoint.y) / snapHeight, 0.02), 0.98)
            }
            
            // Step 4: Dispatch in-chat interactive card progress
            var currentQueue = queueItems
            let activeIdx = stepIndex - 1
            if currentQueue.indices.contains(activeIdx) {
                currentQueue[activeIdx] = ComputerCardQueueItem(
                    name: activeDecision.subGoal.isEmpty ? currentQueue[activeIdx].name : activeDecision.subGoal,
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
                    name: activeDecision.subGoal,
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
                currentActionLabel: "\(stepIndex). \(activeDecision.subGoal) [\(groundingMethod)]"
            )
            onProgress?(stepPayload)
            
            // Step 5: Execute Virtual CUA Action via Pure Physical Mouse Hands (0 Host Screen Intrusion)
            // Visually glide AI cursor smoothly to target element coordinate with human kinematics
            await MascotVirtualDesktopService.shared.glideReticleTo(target: CGPoint(x: normX, y: normY))
            
            // Delegate physical action execution to specialized modular CUA tool
            let actionResult = await CUAPhysicalActionDispatcher.shared.dispatchAction(
                decision: activeDecision,
                normalizedPoint: CGPoint(x: normX, y: normY),
                appName: appName,
                targetPID: targetPID,
                snapshotPath: currentSnap
            )
            var actionObsResult = actionResult.observationResult
            
            try? await Task.sleep(nanoseconds: 600_000_000)
            
            // Capture updated frame
            let updatedSnap = await CompanionWindowStreamService.shared.captureTargetWindowAsync(appName: appName, slug: slug)
            
            // Refresh observation after click/type action so AFM validator & subsequent planner see targeted state delta
            if activeDecision.actionType != "read" && activeDecision.actionType != "inspect" {
                let afterActionObs = await readStructuredObservation(
                    appName: appName,
                    pid: targetPID,
                    snapshotPath: updatedSnap
                )
                if !afterActionObs.isEmpty && afterActionObs != "{}" {
                    let targetedSummary = summarizeTargetedObservation(
                        actionType: activeDecision.actionType,
                        targetElement: activeDecision.targetElement,
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
                actionName: "\(activeDecision.actionType):\(activeDecision.targetElement)",
                targetDescription: activeDecision.subGoal,
                groundingMethod: groundingMethod,
                coordinateX: Int(targetPoint.x),
                coordinateY: Int(targetPoint.y),
                observationResult: actionObsResult
            )
            auditTrail.append(stepRecord)
            let stepIdx = stepIndex - 1
            if queueItems.indices.contains(stepIdx) {
                queueItems[stepIdx] = ComputerCardQueueItem(
                    name: activeDecision.subGoal.isEmpty ? queueItems[stepIdx].name : activeDecision.subGoal,
                    statusBadge: "Done",
                    isChecked: true
                )
            } else {
                queueItems.append(ComputerCardQueueItem(
                    name: activeDecision.subGoal,
                    statusBadge: "Done",
                    isChecked: true
                ))
            }
            historySummary.append("\(activeDecision.subGoal): \(actionObsResult)")
            
            // Step 6: AFM Validates state transition
            let validation = await AFMLunaCoordinationBridge.shared.validateWithAFM(
                userGoal: prompt,
                appName: appName,
                performedSteps: historySummary,
                latestObservation: actionObsResult,
                taskContract: taskPlan
            )
            
            lastValidationResult = validation

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
            if !isScrollStep && !draftNotSentYet && !targetIndexNotReached && (validation.isDone || (hasValidExtraction && !validation.requiresTakeover)) && !effectiveResp.isEmpty {
                isTaskSuccessful = true
                finalSystemState = validation.systemState
                finalResponseToUser = effectiveResp
                ClickyLogger.info("[AUTONOMOUS_LOOP]", "AFM confirmed task completion with extracted data: \(validation.extractedData)")
                break
            }
        }
        
        // Anti-Fake Check: If loop terminated without isTaskSuccessful flag, check if last validation had factual extraction
        if !isTaskSuccessful {
            if let lastVal = lastValidationResult,
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
                    performedSteps: historySummary,
                    latestObservation: "Execution step limit reached (\(maxSteps) steps). Current screen observation: \(currentObs)",
                    taskContract: taskPlan
                )
                finalResponseToUser = conclusionVal.responseToUser
                finalSystemState = conclusionVal.systemState
                ClickyLogger.warning("[AUTONOMOUS_LOOP]", "Task concluded at step limit, synthesized response: \(finalResponseToUser)")
            }
        }
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        _ = await CompanionWindowStreamService.shared.captureTargetWindowAsync(appName: appName, slug: slug)
        CompanionWindowStreamService.shared.stopStreaming()
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

        if let axApp = findTargetAXApplication(appName: appName) {
            detectedElements = extractAXElementTitles(from: axApp)
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
            snapshotPath: snapshotPath
        )

        if let pt = grounded?.coordinate {
            await CuaDriverClient.shared.glideAgentCursor(to: pt)
            await ComputerUsePhysicalExecutor.shared.executeMoveAndClick(at: pt, button: .left, clickCount: 1)
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        ComputerUsePhysicalExecutor.shared.executeTypeText(text, autoSendReturn: false)
        return true
    }

    /// Reads screen contents into a structured, section-based JSON representation
    /// Sections: topBar, sidebar, listItems (with explicit 1-based indexing), previewPane
    public func readStructuredObservation(
        appName: String,
        pid: pid_t? = nil,
        snapshotPath: String? = nil
    ) async -> String {
        guard let snapPath = snapshotPath ?? CompanionWindowStreamService.shared.activeSnapshotPath,
              FileManager.default.fileExists(atPath: snapPath),
              let img = NSImage(contentsOfFile: snapPath),
              let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            // Fallback to AX if snapshot unavailable
            if let pid = pid, pid > 0 {
                let appElement = AXUIElementCreateApplication(pid)
                var windowRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
                   let win = windowRef {
                    let axTexts = extractAXElementTextRecursive(from: win as! AXUIElement, maxDepth: 4)
                    let fallbackDict: [String: Any] = ["content": axTexts]
                    if let data = try? JSONSerialization.data(withJSONObject: fallbackDict, options: [.prettyPrinted]),
                       let str = String(data: data, encoding: .utf8) {
                        return str
                    }
                }
            }
            return "{}"
        }

        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([req])

        guard let results = req.results, !results.isEmpty else {
            return "{}"
        }

        struct DetectedItem {
            let text: String
            let box: CGRect
        }

        var topBarItems: [String] = []
        var sidebarItems: [String] = []
        var previewPaneItems: [String] = []
        var listRawItems: [DetectedItem] = []
        var generalItems: [DetectedItem] = []

        for obs in results {
            guard let str = obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                  str.count >= 2 else { continue }
            let b = obs.boundingBox

            // Top bar / toolbar
            if b.midY >= 0.93 {
                if !topBarItems.contains(str) { topBarItems.append(str) }
            }
            // Sidebar (left column)
            else if b.maxX <= 0.17 {
                if !sidebarItems.contains(str) { sidebarItems.append(str) }
            }
            // Preview / detail pane (right column)
            else if b.minX >= 0.55 {
                if !previewPaneItems.contains(str) { previewPaneItems.append(str) }
            }
            // Middle column: list items
            else if b.minX >= 0.16 && b.maxX <= 0.55 {
                listRawItems.append(DetectedItem(text: str, box: b))
            } else {
                generalItems.append(DetectedItem(text: str, box: b))
            }
        }

        // Group middle column into distinct list item cards
        let sortedList = listRawItems.sorted { $0.box.midY > $1.box.midY }
        var cards: [[DetectedItem]] = []

        for item in sortedList {
            if let idx = cards.firstIndex(where: { card in
                guard let top = card.first else { return false }
                return abs(top.box.midY - item.box.midY) < 0.085
            }) {
                cards[idx].append(item)
            } else {
                cards.append([item])
            }
        }

        var rawSummaries: [String] = []
        for card in cards {
            let sortedCard = card.sorted {
                if abs($0.box.midY - $1.box.midY) < 0.02 {
                    return $0.box.minX < $1.box.minX
                }
                return $0.box.midY > $1.box.midY
            }
            rawSummaries.append(sortedCard.map { $0.text }.joined(separator: " | "))
        }

        let assignedIndices = resolveCardIndices(newCards: rawSummaries, previousItems: sessionObservedListItems)
        var formattedListItems: [[String: Any]] = []
        for (idx, summary) in zip(assignedIndices, rawSummaries) {
            formattedListItems.append([
                "index": idx,
                "content": summary
            ])
            if !sessionObservedListItems.contains(where: { $0.index == idx }) {
                sessionObservedListItems.append((index: idx, content: summary))
            }
        }

        var sectionJSON: [String: Any] = [:]
        if !topBarItems.isEmpty { sectionJSON["topBar"] = topBarItems }
        if !sidebarItems.isEmpty { sectionJSON["sidebar"] = sidebarItems }
        if !formattedListItems.isEmpty { sectionJSON["listItems"] = formattedListItems }
        if !previewPaneItems.isEmpty { sectionJSON["previewPane"] = previewPaneItems }

        // Single-pane fallback: if no columns were detected
        if formattedListItems.isEmpty && !generalItems.isEmpty {
            let genSorted = generalItems.sorted { $0.box.midY > $1.box.midY }
            sectionJSON["content"] = genSorted.map { $0.text }
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: sectionJSON, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            ClickyLogger.info("[VM_AGENT_LOOP]", "Structured observation: \(topBarItems.count) topBar, \(sidebarItems.count) sidebar, \(formattedListItems.count) listItems, \(previewPaneItems.count) preview")
            return jsonString
        }

        return "{}"
    }

    /// Produces a concise, targeted per-item summary of screen state delta following an action.
    /// Eliminates token bloating by focusing strictly on the interacted item and reading pane.
    public func summarizeTargetedObservation(
        actionType: String,
        targetElement: String,
        observationJSON: String,
        targetIndex: Int?
    ) -> String {
        guard let data = observationJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }

        let preview = (dict["previewPane"] as? [String]) ?? []
        let previewSummary = preview.prefix(4).joined(separator: " | ")
        let listItems = (dict["listItems"] as? [[String: Any]]) ?? []

        if actionType == "click" || actionType == "right_click" {
            var itemSummary = ""
            if let tIdx = targetIndex, let match = listItems.first(where: { ($0["index"] as? Int) == tIdx }) {
                let content = (match["content"] as? String) ?? ""
                itemSummary = "Target Item #\(tIdx): '\(content)'"
            } else if let firstItem = listItems.first {
                let idx = (firstItem["index"] as? Int) ?? 1
                let content = (firstItem["content"] as? String) ?? ""
                itemSummary = "Item #\(idx): '\(content)'"
            }

            var components: [String] = []
            if !itemSummary.isEmpty { components.append(itemSummary) }
            if !previewSummary.isEmpty { components.append("Reading Pane: '\(previewSummary)'") }
            return components.joined(separator: " | ")
        } else if actionType.contains("scroll") {
            let indices = listItems.compactMap { $0["index"] as? Int }.sorted()
            if let minIdx = indices.first, let maxIdx = indices.last {
                return "Visible list items now: indices \(minIdx) to \(maxIdx) (count: \(indices.count))"
            }
            return "List scrolled"
        } else if actionType == "type" {
            return "Input field '\(targetElement)' updated"
        } else {
            if !previewSummary.isEmpty {
                return "Display: '\(previewSummary)'"
            }
            return ""
        }
    }

    /// Visual Anchor Chaining: matches overlapping cards from previous observations
    /// to assign continuous, absolute 1-based indices across vertical scroll actions.
    private func resolveCardIndices(newCards: [String], previousItems: [(index: Int, content: String)]) -> [Int] {
        guard !previousItems.isEmpty else { return newCards.indices.map { $0 + 1 } }
        var anchorNewIdx: Int?
        var anchorKnownIndex: Int?
        for (newIdx, newContent) in newCards.enumerated() {
            let cleanNew = newContent.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanNew.count >= 6 else { continue }
            if let match = previousItems.first(where: { prev in
                let cleanPrev = prev.content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard cleanPrev.count >= 6 else { return false }
                let prevPrefix = String(cleanPrev.prefix(30))
                let newPrefix = String(cleanNew.prefix(30))
                return cleanNew.contains(prevPrefix) || cleanPrev.contains(newPrefix)
            }) {
                anchorNewIdx = newIdx
                anchorKnownIndex = match.index
                break
            }
        }
        if let anchorNew = anchorNewIdx, let knownIdx = anchorKnownIndex {
            return newCards.enumerated().map { (idx, _) in
                let offset = idx - anchorNew
                return max(1, knownIdx + offset)
            }
        }
        return newCards.indices.map { $0 + 1 }
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

        // Save deliverable receipt in isolated workspace
        saveDeliverableReceipt(receipt: receipt, slug: slug)

        let finalStatus = status ?? (isSuccess ? .done : .failed)
        let finalizedQueue: [ComputerCardQueueItem]
        if finalStatus == .done {
            finalizedQueue = queueItems.map {
                ComputerCardQueueItem(name: $0.name, statusBadge: "Done", isChecked: true)
            }
        } else {
            finalizedQueue = queueItems
        }

        if finalStatus != .takeoverNeeded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                CompanionWindowStreamService.shared.stopStreaming()
                MascotVirtualDesktopService.shared.stopVirtualDesktop()
            }
        }

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
            updatedAt: Date()
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

    // MARK: - AX Helpers
    private func findTargetAXApplication(appName: String) -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.localizedName?.localizedCaseInsensitiveContains(appName) == true }) {
            return AXUIElementCreateApplication(app.processIdentifier)
        }
        return nil
    }

    private func extractAXElementTitles(from element: AXUIElement) -> [String] {
        return extractAXElementTextRecursive(from: element, maxDepth: 3)
    }

    private func extractAXElementTextRecursive(from element: AXUIElement, depth: Int = 0, maxDepth: Int = 4) -> [String] {
        guard depth <= maxDepth else { return [] }
        var results: [String] = []

        var titleRef: CFTypeRef?
        var valRef: CFTypeRef?
        var descRef: CFTypeRef?

        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success,
           let title = titleRef as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(title.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valRef) == .success,
           let val = valRef as? String, !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(val.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
           let desc = descRef as? String, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(desc.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Traverse rows if table or outline view
        var rowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRowsAttribute as CFString, &rowsRef) == .success,
           let rows = rowsRef as? [AXUIElement] {
            for row in rows.prefix(15) {
                let rowTexts = extractAXElementTextRecursive(from: row, depth: depth + 1, maxDepth: maxDepth)
                if !rowTexts.isEmpty {
                    results.append(rowTexts.joined(separator: " | "))
                }
                if results.count >= 20 { break }
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children.prefix(20) {
                let childTexts = extractAXElementTextRecursive(from: child, depth: depth + 1, maxDepth: maxDepth)
                results.append(contentsOf: childTexts)
                if results.count >= 25 { break }
            }
        }

        var unique: [String] = []
        for text in results {
            if text.count > 2 && !unique.contains(text) {
                unique.append(text)
            }
        }
        return Array(unique.prefix(25))
    }
}
