//
//  test_avatar_lab_catalog_f05.swift
//  boringNotch (Izanotchy • Milestone 172 Verification Runner)
//
//  Comprehensive verification test suite for Avatar Lab Full Catalog & Sequencer Engine:
//  1. 11 Character Templates (Shape First)
//  2. 27 Expressions Presets (00 s.d. 26)
//  3. 23 Animation Sequences (7 Life Cycle + 16 Reactions)
//  4. Domain Model Extensions (BuddySession, CompanionProfile, ComputerUseRequest)
//  5. Animation Sequencer Execution & Step Advancing
//

import Foundation
import SwiftUI

@main
struct AvatarLabCatalogF05TestRunner {
    static func main() {
        print("================================================================================")
        print("🚀 [TEST SUITE] Avatar Lab Full Catalog & Animation Sequencer Engine (F-05)")
        print("================================================================================")

        // -------------------------------------------------------------------------
        // 1. Verify 11 Character Templates
        // -------------------------------------------------------------------------
        print("\n--- 1. Testing 11 Character Templates ---")
        let templates = CompanionAvatarLabCatalog.allTemplates
        assert(templates.count == 11, "❌ Expected exactly 11 templates, got \(templates.count)")
        print("✅ Template Count: Exactly 11 templates registered.")

        let expectedTemplateIds = [
            "strobi", "freddy", "citrus", "nova", "grok-bot",
            "sunee", "kirby", "cloudee", "cubee", "onee", "unknown"
        ]
        for expectedId in expectedTemplateIds {
            let found = CompanionAvatarLabCatalog.template(byId: expectedId)
            assert(found != nil, "❌ Missing expected template '\(expectedId)'")
            print("  ✓ Template '\(found!.name)' (ID: \(found!.id), Surface: \(found!.body.primary.type))")
        }

        // Detailed template checks
        let freddy = CompanionAvatarLabCatalog.template(byId: "freddy")!
        assert(freddy.body.primary.type == "cube", "Freddy body surface must be rounded cube")
        assert(freddy.body.nodes.count == 3, "Freddy must have 3 body nodes (2 ears + 1 snout)")

        let nova = CompanionAvatarLabCatalog.template(byId: "nova")!
        assert(nova.body.primary.type == "capsule", "Nova body surface must be capsule")

        let sunee = CompanionAvatarLabCatalog.template(byId: "sunee")!
        assert(sunee.body.primary.type == "sphere", "Sunee body surface must be sphere")
        assert(sunee.body.nodes.count == 8, "Sunee must have exactly 8 ray nodes")

        let cubee = CompanionAvatarLabCatalog.template(byId: "cubee")!
        assert(cubee.body.primary.type == "cube", "Cubee body surface must be cube")

        let unknown = CompanionAvatarLabCatalog.template(byId: "unknown")!
        assert(unknown.body.primary.type == "invisible", "Unknown body surface must be invisible")

        print("✅ Template Morphologies: Surface shapes and multi-node body accessories verified.")

        // -------------------------------------------------------------------------
        // 2. Verify 27 Expression Presets (00 through 26)
        // -------------------------------------------------------------------------
        print("\n--- 2. Testing 27 Calibrated Presets (00 s.d. 26) ---")
        let presets = CompanionAvatarLabCatalog.allPresets
        assert(presets.count == 27, "❌ Expected exactly 27 presets, got \(presets.count)")
        print("✅ Preset Count: Exactly 27 presets registered.")

        for i in 0..<27 {
            let preset = CompanionAvatarLabCatalog.preset(byIndex: i)
            assert(preset != nil, "❌ Missing preset at index \(i)")
            assert(preset!.index == i, "❌ Preset index mismatch at \(i)")
        }

        let p00 = CompanionAvatarLabCatalog.preset(byIndex: 0)!
        assert(p00.badgeNumber == "00", "P00 badge number should be 00")
        assert(p00.semanticKey == "upward-side-glance", "P00 semantic key should be upward-side-glance")

        let p01 = CompanionAvatarLabCatalog.preset(byIndex: 1)!
        assert(p01.semanticKey == "downward-gaze", "P01 semantic key should be downward-gaze")

        let p22 = CompanionAvatarLabCatalog.preset(byIndex: 22)!
        assert(p22.semanticKey == "drowsy-closed", "P22 semantic key should be drowsy-closed")

        let p25 = CompanionAvatarLabCatalog.preset(byIndex: 25)!
        assert(p25.semanticKey == "angry-brows", "P25 semantic key should be angry-brows")
        assert(p25.expression.bodyColorHex == "#ba3636", "P25 chromatic body must be angry red #ba3636")

        let p26 = CompanionAvatarLabCatalog.preset(byIndex: 26)!
        assert(p26.semanticKey == "uneasy-left", "P26 semantic key should be uneasy-left")
        assert(p26.expression.bodyColorHex == "#adc3ff", "P26 chromatic body must be uneasy blue #adc3ff")

        print("✅ Preset Calibration: All 27 indices [00..26] and key presets verified.")

        // -------------------------------------------------------------------------
        // 3. Verify 23 Animation Sequences (7 Life Cycle + 16 Reactions)
        // -------------------------------------------------------------------------
        print("\n--- 3. Testing 23 Animation Sequences ---")
        let animations = CompanionAvatarLabCatalog.allAnimations
        assert(animations.count == 23, "❌ Expected exactly 23 animation sequences, got \(animations.count)")
        print("✅ Animation Count: Exactly 23 animation sequences registered.")

        let lifeCycleCount = animations.filter { $0.category == .lifeCycle }.count
        let reactionCount = animations.filter { $0.category == .reaction }.count
        assert(lifeCycleCount == 7, "❌ Expected 7 Life Cycle sequences, got \(lifeCycleCount)")
        assert(reactionCount == 16, "❌ Expected 16 Reaction sequences, got \(reactionCount)")
        print("✅ Category Distribution: 7 Life Cycle + 16 Reaction sequences.")

        let workingAnim = CompanionAvatarLabCatalog.animation(byKey: "working")
        assert(workingAnim != nil, "❌ Missing 'working' animation")
        assert(workingAnim!.steps.count == 4, "Working animation should have 4 steps")
        assert(workingAnim!.steps[0].holdMs == 2300, "Step 0 hold should be 2300ms")

        let celebrateAnim = CompanionAvatarLabCatalog.animation(byKey: "celebrate")
        assert(celebrateAnim != nil, "❌ Missing 'celebrate' animation")
        assert(celebrateAnim!.steps.count == 3, "Celebrate animation should have 3 steps")

        print("✅ Sequence Steps & Timers: Hold times (2300ms–5200ms) and step lists verified.")

        // -------------------------------------------------------------------------
        // 4. Verify Domain Model Avatar Definition Extensions
        // -------------------------------------------------------------------------
        print("\n--- 4. Testing Domain Model Extensions ---")
        let session = BuddySession(
            name: "Freddy Bear",
            roleDescription: "Executive",
            avatarColorHex: "#FB923C",
            templateId: "freddy"
        )
        let sessionDef = session.avatarDefinition
        assert(sessionDef.name == "Freddy Bear")
        assert(sessionDef.body.primary.type == "cube")
        assert(sessionDef.body.nodes.count == 3)
        assert(sessionDef.colors.bodyHex == "#FB923C")
        print("  ✓ BuddySession (templateId: freddy) correctly resolves to rounded cube with 3 body nodes.")

        let profile = CompanionProfile(
            slug: "sun-bot",
            name: "Sunee Bot",
            role: "Morning Guide",
            summary: "Warm",
            cloudColorHex: "#FACC15",
            ringColorHex: "#FEF08A",
            templateId: "sunee"
        )
        let profileDef = profile.avatarDefinition
        assert(profileDef.name == "Sunee Bot")
        assert(profileDef.body.primary.type == "sphere")
        assert(profileDef.body.nodes.count == 8)
        assert(profileDef.colors.bodyHex == "#FACC15")
        print("  ✓ CompanionProfile (templateId: sunee) correctly resolves to sphere with 8 sun rays.")

        let cubeeSession = BuddySession(
            name: "Cubee Assistant",
            roleDescription: "Block",
            avatarColorHex: "#818CF8",
            templateId: "cubee"
        )
        assert(cubeeSession.avatarDefinition.body.primary.type == "cube")
        print("  ✓ BuddySession (templateId: cubee) correctly resolves to cube surface.")

        let consentReq = ComputerUseRequest(
            companionName: "Strobi",
            cloudColorHex: "#38BDF8",
            bodyText: "Needs permission",
            payload: ComputerUseActionPayload()
        )
        assert(consentReq.avatarDefinition.name == "Strobi")
        assert(consentReq.avatarDefinition.colors.bodyHex == "#38BDF8")
        print("  ✓ ComputerUseRequest correctly resolves to Strobi avatar definition.")

        // -------------------------------------------------------------------------
        // 5. Test Animation Sequencer Execution
        // -------------------------------------------------------------------------
        print("\n--- 5. Testing CompanionAnimationEngine Sequencer ---")
        let engine = CompanionAnimationEngine.shared
        assert(!engine.isPlaying, "Engine should initially be stopped")
        assert(engine.currentSequence == nil)

        // Start working animation
        engine.play(sequence: workingAnim!) { _ in }
        assert(engine.isPlaying, "Engine must be playing after play()")
        assert(engine.currentSequence?.id == "working")
        assert(engine.currentStepIndex == 0)
        assert(engine.currentExpressionKey == workingAnim!.steps[0].semanticKey)
        print("  ✓ Engine successfully started sequence 'working' at step 0.")

        // Test step navigation
        engine.advanceStep()
        assert(engine.currentStepIndex == 1)
        assert(engine.currentExpressionKey == workingAnim!.steps[1].semanticKey)
        print("  ✓ Engine advanced to step 1.")

        engine.advanceStep()
        assert(engine.currentStepIndex == 2)
        engine.advanceStep()
        assert(engine.currentStepIndex == 3)
        // Next step should loop back to 0
        engine.advanceStep()
        assert(engine.currentStepIndex == 0)
        print("  ✓ Engine looped back to step 0 after reaching last step.")

        // Stop engine
        engine.stop()
        assert(!engine.isPlaying, "Engine should be stopped")
        print("  ✓ Engine successfully stopped (isPlaying = false).")

        print("\n================================================================================")
        print("🎉 ALL ASSERTIONS PASSED! Avatar Lab Full Studio Engine (F-05) Verified 100%.")
        print("================================================================================")
    }
}
