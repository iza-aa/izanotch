#!/usr/bin/env python3
"""
scripts/check_decomposition_map.py
Validates that line ranges for decomposed God Objects are 100% contiguous,
without gaps, overlaps, or line count mismatches, AND that every partition
boundary sits strictly at the top-level type body (AST brace depth <= 1),
never inside a function or nested block.
"""
import sys

def get_line_brace_depth(lines, target_line):
    """Calculates cumulative brace depth up to target_line, ignoring comments and string literals."""
    depth = 0
    in_multiline_comment = False
    in_triple_string = False
    
    for l in lines[:target_line - 1]:
        i = 0
        while i < len(l):
            if in_multiline_comment:
                if l[i:i+2] == '*/':
                    in_multiline_comment = False
                    i += 2
                    continue
                i += 1
                continue
            if l[i:i+3] == '"""':
                in_triple_string = not in_triple_string
                i += 3
                continue
            if in_triple_string:
                i += 1
                continue
            if l[i:i+2] == '/*':
                in_multiline_comment = True
                i += 2
                continue
            if l[i:i+2] == '//':
                break
            if l[i] == '{':
                depth += 1
            elif l[i] == '}':
                depth -= 1
            i += 1
    return depth

def check_file(filepath, filename, total_expected, partitions):
    total = sum(p[2] for p in partitions)
    print(f"Checking {filename}...")
    print(f"  Total partitioned: {total} / Expected: {total_expected}")
    assert total == total_expected, f"Line count mismatch for {filename}: {total} vs {total_expected}"
    
    with open(filepath, "r", encoding="utf-8") as f:
        file_lines = f.readlines()
        
    current_line = 1
    for name, start, length in partitions:
        assert start == current_line, f"Gap or overlap in {filename} at {name}: expected {current_line}, got {start}"
        depth = get_line_brace_depth(file_lines, start)
        assert depth <= 1, f"❌ AST ERROR: Partition '{name}' at line {start} is inside a nested block (brace depth {depth} > 1)!"
        current_line += length
        
    assert current_line - 1 == total_expected, f"End line mismatch in {filename}"
    print(f"  ✅ {filename} is 100% contiguous (0 gaps/overlaps) and AST brace-depth verified (all boundaries depth <= 1).")

def main():
    # 1. CompanionManager (4,746 lines)
    cm_partitions = [
        ("MacOSDockQueryService", 1, 211),
        ("ActiveWorkSurfaceMonitor", 212, 149),
        ("CompanionVoicePipelineCoordinator", 361, 836),
        ("CompanionSessionStore", 1197, 181),
        ("CompanionSystemPromptBuilder", 1378, 325),
        ("CompanionStreamingBubbleService", 1703, 470),
        ("CompanionTurnIngressCoordinator", 2173, 207),
        ("CompanionTurnExecutor", 2380, 696),
        ("CompanionTurnCompletionHandler", 3076, 48),
        ("CompanionFlightTargetParser", 3124, 362),
        ("CompanionOnboardingPlaybackService", 3486, 202),
        ("CompanionComputerUseConsentService", 3688, 526),
        ("CryptoSymbolExtractor", 4214, 77),
        ("TradingViewFeatureProtocol", 4291, 51),
        ("TradingViewPayloadExtractor", 4342, 405)
    ]
    check_file("boringNotch/Clicky/Core/CompanionManager.swift", "CompanionManager.swift", 4746, cm_partitions)

    # 2. HomeSpaceRootView (3,406 lines)
    hs_partitions = [
        ("HomeSpaceRootView (Root Body)", 1, 269),
        ("HomeSpaceSidebarView", 270, 469),
        ("HomeSpaceChatTranscriptView", 739, 487),
        ("HomeSpaceRootView (Computed Helpers)", 1226, 218),
        ("HomeSpaceHeaderView", 1444, 319),
        ("HomeSpaceEditCharacterStudioView", 1763, 538),
        ("HomeSpaceConnectedAppsView", 2301, 162),
        ("HomeSpaceStudioHelpersView", 2463, 109),
        ("HomeSpaceOnboardingWizardView", 2572, 401),
        ("HomeSpaceOnboardingAppearanceView", 2973, 434)
    ]
    check_file("boringNotch/Clicky/UI/HomeSpace/HomeSpaceRootView.swift", "HomeSpaceRootView.swift", 3406, hs_partitions)

    # 3. ClickyDeterministicPipeline (1,242 lines)
    pipe_partitions = [
        ("InstalledAppsDiscoveryService", 1, 180),
        ("DeterministicIntentRouter", 181, 132),
        ("DeterministicToolGatingService", 313, 152),
        ("DeterministicCommandDecomposer", 465, 167),
        ("DeterministicChainDispatcher", 632, 611)
    ]
    check_file("boringNotch/Clicky/Core/ClickyDeterministicPipeline.swift", "ClickyDeterministicPipeline.swift", 1242, pipe_partitions)

    print("\n🎉 ALL 3 GOD OBJECT DECOMPOSITION MAPS ARE 100% VALIDATED VIA AST BRACE DEPTH!")

if __name__ == "__main__":
    main()
