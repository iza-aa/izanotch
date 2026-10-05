#!/usr/bin/env python3
"""
scripts/check_file_map.py
Validates that every single Swift file in boringNotch/Clicky
is mapped to exactly one target in Packages/ClickyKit.
"""
import os
import sys

def get_all_clicky_files():
    files = []
    for root, dirs, fnames in os.walk("boringNotch/Clicky"):
        for f in fnames:
            if f.endswith(".swift"):
                files.append(os.path.join(root, f))
    files.sort()
    return files

def get_file_mapping(files):
    mapping = {}
    for p in files:
        # L0: Foundation
        if p in [
            "boringNotch/Clicky/Core/ClickyLogger.swift",
            "boringNotch/Clicky/Core/ClickyAnalytics.swift",
            "boringNotch/Clicky/Core/ClickyEnums.swift",
            "boringNotch/Clicky/Core/AppBundleConfiguration.swift",
            "boringNotch/Clicky/Core/ClickyFunctionTool.swift",
            "boringNotch/Clicky/Reasoning/Ingress/CanonicalTaskContract.swift"
        ] or p.startswith("boringNotch/Clicky/Core/Contracts/"):
            mapping[p] = "ClickyFoundation"
        # L1: Platform
        elif p in [
            "boringNotch/Clicky/Workspace/Streaming/CompanionScreenCaptureUtility.swift",
            "boringNotch/Clicky/Workspace/Streaming/CompanionWindowStreamService.swift",
            "boringNotch/Clicky/Workspace/WindowManagement/WindowPositionManager.swift",
            "boringNotch/Clicky/Workspace/Discovery/InstalledAppsDiscoveryService.swift",
            "boringNotch/Clicky/Workspace/VirtualDisplay/MascotVirtualDesktopService.swift",
            "boringNotch/Clicky/Services/Audio/GlobalPushToTalkShortcutMonitor.swift",
            "boringNotch/Clicky/Roster/Context/IntegrationSuggestionMonitor.swift",
            "boringNotch/Clicky/Core/ActiveWorkSurfaceManager.swift",
            "boringNotch/Clicky/Core/MacOSDockManager.swift",
            "boringNotch/Clicky/Core/InstalledApplicationsResolver.swift"
        ]:
            mapping[p] = "ClickyPlatform"
        # L2: Speech
        elif p.startswith("boringNotch/Clicky/Services/Audio/"):
            mapping[p] = "ClickySpeech"
        # L2: AIProviders
        elif p.startswith("boringNotch/Clicky/Services/Models/") or p.startswith("boringNotch/Clicky/Services/Vision/") or p == "boringNotch/Clicky/Core/PCCGroundingEscalation.swift":
            if p == "boringNotch/Clicky/Services/Vision/ChatGPTAccountMonitorWidget.swift":
                mapping[p] = "ClickyUI"
            else:
                mapping[p] = "ClickyAIProviders"
        # L2: CUA
        elif p.startswith("boringNotch/Clicky/CUA/"):
            if p in ["boringNotch/Clicky/CUA/Loop/CompanionVMAgentLoop.swift", "boringNotch/Clicky/CUA/Loop/CompanionVMBackgroundWatcher.swift"]:
                mapping[p] = "ClickyAgent" # Fixed layering: Loop orchestrator belongs in L5 ClickyAgent
            else:
                mapping[p] = "ClickyCUA"
        # L3: Reasoning
        elif p.startswith("boringNotch/Clicky/Reasoning/"):
            mapping[p] = "ClickyReasoning"
        # L4: Domain
        elif p.startswith("boringNotch/Clicky/Services/Domain/Astronacci/"):
            mapping[p] = "ClickyAstronacci"
        elif p.startswith("boringNotch/Clicky/Services/Domain/TradingView/"):
            mapping[p] = "ClickyTradingView"
        elif p.startswith("boringNotch/Clicky/Services/Domain/FuturesScout/"):
            mapping[p] = "ClickyFuturesScout"
        # L4: Roster
        elif p.startswith("boringNotch/Clicky/Roster/"):
            mapping[p] = "ClickyRoster"
        # L5: DesignSystem
        elif p in ["boringNotch/Clicky/UI/Common/DesignSystem.swift"]:
            mapping[p] = "ClickyDesignSystem"
        # L5: Agent
        elif p in [
            "boringNotch/Clicky/Core/CompanionManager.swift",
            "boringNotch/Clicky/Core/ClickyDeterministicPipeline.swift",
            "boringNotch/Clicky/Core/ClickyFunctionToolRegistry.swift",
            "boringNotch/Clicky/Core/ClickyToolDispatcher.swift"
        ] or p.startswith("boringNotch/Clicky/Core/CompanionManager+") or p.startswith("boringNotch/Clicky/Core/ClickyDeterministicPipeline+"):
            mapping[p] = "ClickyAgent"
        # L6: UI
        elif p.startswith("boringNotch/Clicky/UI/") or p in [
            "boringNotch/Clicky/Workspace/Streaming/CompanionVMViewportController.swift"
        ]:
            mapping[p] = "ClickyUI"
        else:
            print(f"❌ UNMAPPED FILE: {p}")
    return mapping

def main():
    files = get_all_clicky_files()
    total_files = len(files)
    print(f"Auditing file mapping for {total_files} Swift files in boringNotch/Clicky...")
    
    mapping = get_file_mapping(files)
    unmapped = [p for p in files if p not in mapping]
    assert len(unmapped) == 0, f"Unmapped files: {unmapped}"
    assert len(mapping) == total_files, f"Count mismatch: mapped {len(mapping)} vs total {total_files}"

    counts = {}
    for p, t in mapping.items():
        counts[t] = counts.get(t, 0) + 1

    print(f"✅ All {total_files} files mapped successfully:")
    for t in sorted(counts.keys()):
        print(f"   - {t}: {counts[t]} files")
    print("\n🎉 FILE MAP IS 100% COMPLETE AND DETERMINISTIC!")

if __name__ == "__main__":
    main()
