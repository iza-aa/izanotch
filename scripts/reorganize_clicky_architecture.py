#!/usr/bin/env python3
import os
import sys
import shutil

REPO_ROOT = "/Users/heizaaa/Desktop/cdev/iza-3"
PROJECT_FILE = os.path.join(REPO_ROOT, "boringNotch.xcodeproj/project.pbxproj")
BORING_NOTCH = os.path.join(REPO_ROOT, "boringNotch")

FILE_MAPPINGS = {
    # --- REASONING (AI Cognition Layer) ---
    "Clicky/Tools/TaskIngressGateway.swift": "Clicky/Reasoning/Ingress/TaskIngressGateway.swift",
    "Clicky/Tools/CanonicalTaskContract.swift": "Clicky/Reasoning/Ingress/CanonicalTaskContract.swift",
    "Clicky/Tools/TaskStepPlanner.swift": "Clicky/Reasoning/Planner/TaskStepPlanner.swift",
    "Clicky/Tools/TaskEgressValidator.swift": "Clicky/Reasoning/Validator/TaskEgressValidator.swift",
    "Clicky/Tools/AFMLunaCoordinationBridge.swift": "Clicky/Reasoning/Coordination/AFMLunaCoordinationBridge.swift",

    # --- CUA (Computer Use Agent: Loop, Actions, Grounding, Execution) ---
    "Clicky/Tools/CompanionVMAgentLoop.swift": "Clicky/CUA/Loop/CompanionVMAgentLoop.swift",
    "Clicky/Tools/CompanionVMBackgroundWatcher.swift": "Clicky/CUA/Loop/CompanionVMBackgroundWatcher.swift",

    "Clicky/Tools/Actions/CUAPhysicalActionDispatcher.swift": "Clicky/CUA/Actions/CUAPhysicalActionDispatcher.swift",
    "Clicky/Tools/Actions/CUAPhysicalActionTool.swift": "Clicky/CUA/Actions/CUAPhysicalActionTool.swift",
    "Clicky/Tools/Actions/CUAClickActionTool.swift": "Clicky/CUA/Actions/CUAClickActionTool.swift",
    "Clicky/Tools/Actions/CUAScrollActionTool.swift": "Clicky/CUA/Actions/CUAScrollActionTool.swift",
    "Clicky/Tools/Actions/CUATypeActionTool.swift": "Clicky/CUA/Actions/CUATypeActionTool.swift",
    "Clicky/Tools/Actions/CUAReadActionTool.swift": "Clicky/CUA/Actions/CUAReadActionTool.swift",

    "Clicky/Tools/ClickyHybridGroundingEngine.swift": "Clicky/CUA/Grounding/ClickyHybridGroundingEngine.swift",
    "Clicky/Tools/CuaVisualGrounder.swift": "Clicky/CUA/Grounding/CuaVisualGrounder.swift",
    "Clicky/MacOSVisualGroundingEngine.swift": "Clicky/CUA/Grounding/MacOSVisualGroundingEngine.swift",
    "Clicky/MacOSROIGrounding.swift": "Clicky/CUA/Grounding/MacOSROIGrounding.swift",
    "Clicky/MacOSMarkRenderer.swift": "Clicky/CUA/Grounding/MacOSMarkRenderer.swift",
    "Clicky/MacOSCandidacyResolver.swift": "Clicky/CUA/Grounding/MacOSCandidacyResolver.swift",
    "Clicky/ElementLocationDetector.swift": "Clicky/CUA/Grounding/ElementLocationDetector.swift",
    "Clicky/GoogleStudioGrounderClient.swift": "Clicky/CUA/Grounding/GoogleStudioGrounderClient.swift",

    "Clicky/ComputerUsePhysicalExecutor.swift": "Clicky/CUA/Execution/ComputerUsePhysicalExecutor.swift",
    "Clicky/CuaActionCursorManager.swift": "Clicky/CUA/Execution/CuaActionCursorManager.swift",
    "Clicky/CuaDriverClient.swift": "Clicky/CUA/Execution/CuaDriverClient.swift",
    "Clicky/CuaMotionEngine.swift": "Clicky/CUA/Execution/CuaMotionEngine.swift",

    # --- WORKSPACE (Virtual Display & Window Infrastructure) ---
    "Clicky/Tools/MascotVirtualDesktopService.swift": "Clicky/Workspace/VirtualDisplay/MascotVirtualDesktopService.swift",
    "Clicky/Tools/CompanionWindowStreamService.swift": "Clicky/Workspace/Streaming/CompanionWindowStreamService.swift",
    "Clicky/CompanionScreenCaptureUtility.swift": "Clicky/Workspace/Streaming/CompanionScreenCaptureUtility.swift",
    "Clicky/Tools/CompanionVMViewportController.swift": "Clicky/Workspace/Streaming/CompanionVMViewportController.swift",
    "Clicky/Tools/InstalledAppsDiscoveryService.swift": "Clicky/Workspace/Discovery/InstalledAppsDiscoveryService.swift",
    "Clicky/WindowPositionManager.swift": "Clicky/Workspace/WindowManagement/WindowPositionManager.swift",

    # --- UI (Frontend Layer: SwiftUI Views & Windows) ---
    "Clicky/Tools/InteractiveVirtualDesktopView.swift": "Clicky/UI/Viewport/InteractiveVirtualDesktopView.swift",
    "Clicky/Tools/AppSystemIconView.swift": "Clicky/UI/Viewport/AppSystemIconView.swift",

    "Clicky/HomeSpace/HomeSpaceRootView.swift": "Clicky/UI/HomeSpace/HomeSpaceRootView.swift",
    "Clicky/HomeSpace/HomeSpaceComputerCardView.swift": "Clicky/UI/HomeSpace/HomeSpaceComputerCardView.swift",
    "Clicky/HomeSpace/HomeSpaceInteractiveComputerModalView.swift": "Clicky/UI/HomeSpace/HomeSpaceInteractiveComputerModalView.swift",
    "Clicky/HomeSpace/HomeSpaceWindowManager.swift": "Clicky/UI/HomeSpace/HomeSpaceWindowManager.swift",
    "Clicky/HomeSpace/CompanionVMViewportView.swift": "Clicky/UI/HomeSpace/CompanionVMViewportView.swift",

    "Clicky/Rail/FloatingCompanionRailView.swift": "Clicky/UI/Rail/FloatingCompanionRailView.swift",
    "Clicky/Rail/FloatingCompanionRailWindow.swift": "Clicky/UI/Rail/FloatingCompanionRailWindow.swift",
    "Clicky/Rail/CompanionPopoverCardView.swift": "Clicky/UI/Rail/CompanionPopoverCardView.swift",
    "Clicky/Rail/CompanionOverflowSwitcherView.swift": "Clicky/UI/Rail/CompanionOverflowSwitcherView.swift",

    "Clicky/Floating/AquaGlassSphereView.swift": "Clicky/UI/Floating/AquaGlassSphereView.swift",
    "Clicky/Floating/FloatingCompanionWindowManager.swift": "Clicky/UI/Floating/FloatingCompanionWindowManager.swift",

    "Clicky/Avatars/CompanionProceduralAvatarView.swift": "Clicky/UI/Avatars/CompanionProceduralAvatarView.swift",
    "Clicky/Avatars/CompanionAnimationEngine.swift": "Clicky/UI/Avatars/CompanionAnimationEngine.swift",
    "Clicky/Avatars/CompanionAvatarDefinition.swift": "Clicky/UI/Avatars/CompanionAvatarDefinition.swift",
    "Clicky/Avatars/CompanionAvatarLabCatalog.swift": "Clicky/UI/Avatars/CompanionAvatarLabCatalog.swift",
    "Clicky/Avatars/CompanionGazeTracker.swift": "Clicky/UI/Avatars/CompanionGazeTracker.swift",

    "Clicky/OverlayWindow.swift": "Clicky/UI/Common/OverlayWindow.swift",
    "Clicky/ComputerUseConsentCardView.swift": "Clicky/UI/Common/ComputerUseConsentCardView.swift",
    "Clicky/NotchComputerUseConsentWindow.swift": "Clicky/UI/Common/NotchComputerUseConsentWindow.swift",
    "Clicky/CompanionResponseOverlay.swift": "Clicky/UI/Common/CompanionResponseOverlay.swift",
    "Clicky/WorkSettingsViews.swift": "Clicky/UI/Common/WorkSettingsViews.swift",
    "Clicky/DesignSystem.swift": "Clicky/UI/Common/DesignSystem.swift",

    # --- ROSTER & ONBOARDING & CONTEXT ---
    "Clicky/Roster/CompanionProfile.swift": "Clicky/Roster/CompanionProfile.swift",
    "Clicky/Roster/CompanionRosterStore.swift": "Clicky/Roster/CompanionRosterStore.swift",
    "Clicky/Onboarding/CompanionWorkspaceManager.swift": "Clicky/Roster/Onboarding/CompanionWorkspaceManager.swift",
    "Clicky/Onboarding/CompanionInterviewEngine.swift": "Clicky/Roster/Onboarding/CompanionInterviewEngine.swift",
    "Clicky/Context/IntegrationSuggestionMonitor.swift": "Clicky/Roster/Context/IntegrationSuggestionMonitor.swift",

    # --- SERVICES (Audio, Vision, Models, Domain Extensions) ---
    "Clicky/Audio/BuddyDictationManager.swift": "Clicky/Services/Audio/BuddyDictationManager.swift",
    "Clicky/Audio/BuddyAudioConversionSupport.swift": "Clicky/Services/Audio/BuddyAudioConversionSupport.swift",
    "Clicky/Audio/BuddyTranscriptionProvider.swift": "Clicky/Services/Audio/BuddyTranscriptionProvider.swift",
    "Clicky/Audio/AppleSpeechTranscriptionProvider.swift": "Clicky/Services/Audio/AppleSpeechTranscriptionProvider.swift",
    "Clicky/Audio/OpenAIAudioTranscriptionProvider.swift": "Clicky/Services/Audio/OpenAIAudioTranscriptionProvider.swift",
    "Clicky/Audio/AssemblyAIStreamingTranscriptionProvider.swift": "Clicky/Services/Audio/AssemblyAIStreamingTranscriptionProvider.swift",
    "Clicky/ElevenLabsTTSClient.swift": "Clicky/Services/Audio/ElevenLabsTTSClient.swift",
    "Clicky/ClickySoundEngine.swift": "Clicky/Services/Audio/ClickySoundEngine.swift",
    "Clicky/GlobalPushToTalkShortcutMonitor.swift": "Clicky/Services/Audio/GlobalPushToTalkShortcutMonitor.swift",

    "Clicky/Vision/ChatGPTCodexVisionService.swift": "Clicky/Services/Vision/ChatGPTCodexVisionService.swift",
    "Clicky/Vision/ChatGPTAccountPoolManager.swift": "Clicky/Services/Vision/ChatGPTAccountPoolManager.swift",
    "Clicky/Vision/ChatGPTAccountMonitorWidget.swift": "Clicky/Services/Vision/ChatGPTAccountMonitorWidget.swift",

    "Clicky/SiriAIEngine.swift": "Clicky/Services/Models/SiriAIEngine.swift",
    "Clicky/ClaudeAPI.swift": "Clicky/Services/Models/ClaudeAPI.swift",
    "Clicky/OpenAIAPI.swift": "Clicky/Services/Models/OpenAIAPI.swift",
    "Clicky/IntegrationsManager.swift": "Clicky/Services/Models/IntegrationsManager.swift",

    "Clicky/TradingViewActionDispatcher.swift": "Clicky/Services/Domain/TradingView/TradingViewActionDispatcher.swift",
    "Clicky/Tools/TradingViewDrawingTool.swift": "Clicky/Services/Domain/TradingView/TradingViewDrawingTool.swift",
    "Clicky/Tools/TradingViewInputSupport.swift": "Clicky/Services/Domain/TradingView/TradingViewInputSupport.swift",
    "Clicky/Tools/TradingViewLayoutTool.swift": "Clicky/Services/Domain/TradingView/TradingViewLayoutTool.swift",
    "Clicky/Tools/TradingViewNavigationTool.swift": "Clicky/Services/Domain/TradingView/TradingViewNavigationTool.swift",
    "Clicky/Tools/TradingViewTypes.swift": "Clicky/Services/Domain/TradingView/TradingViewTypes.swift",

    "Clicky/AstronacciClusterEngine.swift": "Clicky/Services/Domain/Astronacci/AstronacciClusterEngine.swift",
    "Clicky/AstronacciDeterministicEngine.swift": "Clicky/Services/Domain/Astronacci/AstronacciDeterministicEngine.swift",
    "Clicky/AstronacciDivergenceEngine.swift": "Clicky/Services/Domain/Astronacci/AstronacciDivergenceEngine.swift",
    "Clicky/AstronacciEconomicCalendarEngine.swift": "Clicky/Services/Domain/Astronacci/AstronacciEconomicCalendarEngine.swift",
    "Clicky/AstronacciEphemerisEngine.swift": "Clicky/Services/Domain/Astronacci/AstronacciEphemerisEngine.swift",
    "Clicky/AstronacciPlanetaryAspectEngine.swift": "Clicky/Services/Domain/Astronacci/AstronacciPlanetaryAspectEngine.swift",
    "Clicky/AstronacciQuasimodoEngine.swift": "Clicky/Services/Domain/Astronacci/AstronacciQuasimodoEngine.swift",

    "Clicky/FuturesScoutBackgroundWatcher.swift": "Clicky/Services/Domain/FuturesScout/FuturesScoutBackgroundWatcher.swift",
    "Clicky/FuturesScoutChartAnalyst.swift": "Clicky/Services/Domain/FuturesScout/FuturesScoutChartAnalyst.swift",
    "Clicky/FuturesScoutCoreAnalyst.swift": "Clicky/Services/Domain/FuturesScout/FuturesScoutCoreAnalyst.swift",
    "Clicky/FuturesScoutMarketDataService.swift": "Clicky/Services/Domain/FuturesScout/FuturesScoutMarketDataService.swift",
    "Clicky/BingXMarketDataEngine.swift": "Clicky/Services/Domain/FuturesScout/BingXMarketDataEngine.swift",

    # --- CORE (Application Singleton & Dispatch) ---
    "Clicky/CompanionManager.swift": "Clicky/Core/CompanionManager.swift",
    "Clicky/ClickyLogger.swift": "Clicky/Core/ClickyLogger.swift",
    "Clicky/ClickyEnums.swift": "Clicky/Core/ClickyEnums.swift",
    "Clicky/ClickyAnalytics.swift": "Clicky/Core/ClickyAnalytics.swift",
    "Clicky/ClickyDeterministicPipeline.swift": "Clicky/Core/ClickyDeterministicPipeline.swift",
    "Clicky/Tools/ClickyFunctionTool.swift": "Clicky/Core/ClickyFunctionTool.swift",
    "Clicky/Tools/ClickyFunctionToolRegistry.swift": "Clicky/Core/ClickyFunctionToolRegistry.swift",
    "Clicky/Tools/ClickyToolDispatcher.swift": "Clicky/Core/ClickyToolDispatcher.swift",
    "Clicky/AppBundleConfiguration.swift": "Clicky/Core/AppBundleConfiguration.swift",
    "Clicky/PCCGroundingEscalation.swift": "Clicky/Core/PCCGroundingEscalation.swift",
}

def main():
    print(f"=== Reorganizing Clicky Architecture ({len(FILE_MAPPINGS)} files) ===")

    # 1. Read project.pbxproj
    with open(PROJECT_FILE, "r", encoding="utf-8") as f:
        pbx_content = f.read()

    moved_count = 0
    pbx_replacements = 0

    for old_rel, new_rel in FILE_MAPPINGS.items():
        old_abs = os.path.join(BORING_NOTCH, old_rel)
        new_abs = os.path.join(BORING_NOTCH, new_rel)

        if old_rel == new_rel:
            # No path change needed
            continue

        if not os.path.exists(old_abs):
            if os.path.exists(new_abs):
                print(f"ℹ️ File already at new location: {new_rel}")
            else:
                print(f"⚠️ Source file not found: {old_abs}")
        else:
            # Ensure target directory exists
            os.makedirs(os.path.dirname(new_abs), exist_ok=True)
            # Move file
            shutil.move(old_abs, new_abs)
            moved_count += 1
            print(f"✅ Moved: {old_rel} -> {new_rel}")

        # Update project.pbxproj
        old_pattern = f'path = "{old_rel}";'
        new_pattern = f'path = "{new_rel}";'
        if old_pattern in pbx_content:
            pbx_content = pbx_content.replace(old_pattern, new_pattern)
            pbx_replacements += 1
        else:
            # Try without quotes if any
            old_pattern_noquotes = f'path = {old_rel};'
            new_pattern_noquotes = f'path = {new_rel};'
            if old_pattern_noquotes in pbx_content:
                pbx_content = pbx_content.replace(old_pattern_noquotes, new_pattern_noquotes)
                pbx_replacements += 1

    # 2. Write updated project.pbxproj
    with open(PROJECT_FILE, "w", encoding="utf-8") as f:
        f.write(pbx_content)

    print(f"=== File Move Summary: {moved_count} moved, {pbx_replacements} pbxproj references updated ===")

    # 3. Clean up empty old directories
    old_dirs_to_clean = [
        "Clicky/Tools/Actions",
        "Clicky/Tools",
        "Clicky/HomeSpace",
        "Clicky/Rail",
        "Clicky/Floating",
        "Clicky/Avatars",
        "Clicky/Audio",
        "Clicky/Vision",
        "Clicky/Onboarding",
        "Clicky/Context",
    ]
    for d in old_dirs_to_clean:
        d_abs = os.path.join(BORING_NOTCH, d)
        if os.path.exists(d_abs) and os.path.isdir(d_abs):
            try:
                # Only remove if empty
                if not os.listdir(d_abs):
                    os.rmdir(d_abs)
                    print(f"🧹 Removed empty directory: {d}")
            except Exception as e:
                print(f"ℹ️ Directory not empty or could not remove {d}: {e}")

    # 4. Verification assertion
    missing = []
    for _, new_rel in FILE_MAPPINGS.items():
        new_abs = os.path.join(BORING_NOTCH, new_rel)
        if not os.path.exists(new_abs):
            missing.append(new_rel)

    if missing:
        print(f"❌ ERROR: {len(missing)} files missing after reorganization:")
        for m in missing:
            print(f"   - {m}")
        sys.exit(1)
    else:
        print(f"🎉 SUCCESS! All {len(FILE_MAPPINGS)} files confirmed at their clean target paths.")

if __name__ == "__main__":
    main()
