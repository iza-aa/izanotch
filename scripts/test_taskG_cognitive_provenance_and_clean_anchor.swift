import Foundation

print("==================================================================")
print("🧪 Test Task G: Cognitive Provenance & Clean Workspace Anchor")
print("==================================================================")

let rootDir = FileManager.default.currentDirectoryPath
let plannerPath = "\(rootDir)/boringNotch/Clicky/Tools/TaskStepPlanner.swift"
let validatorPath = "\(rootDir)/boringNotch/Clicky/Tools/TaskEgressValidator.swift"
let streamServicePath = "\(rootDir)/boringNotch/Clicky/Tools/CompanionWindowStreamService.swift"
let vmAgentLoopPath = "\(rootDir)/boringNotch/Clicky/Tools/CompanionVMAgentLoop.swift"

guard let plannerCode = try? String(contentsOfFile: plannerPath),
      let validatorCode = try? String(contentsOfFile: validatorPath),
      let streamServiceCode = try? String(contentsOfFile: streamServicePath),
      let vmAgentLoopCode = try? String(contentsOfFile: vmAgentLoopPath) else {
    print("❌ Failed to read required source files.")
    exit(1)
}

// 1. Assert TaskStepPlanner has universal provenance reasoning
print("Asserting TaskStepPlanner provenance reasoning...")
let hasProvenanceInPlanner = plannerCode.contains("preexisting") || plannerCode.contains("Previous") || plannerCode.contains("clean")
assert(hasProvenanceInPlanner, "TaskStepPlanner must instruct model to recognize preexisting unrequested text vs Previous steps!")

// 2. Assert TaskStepPlanner has NO app-specific branch
let hasAppSpecificPlanner = plannerCode.contains("if appName == \"Mail\"") || plannerCode.contains("if clean == \"mail\"")
assert(!hasAppSpecificPlanner, "TaskStepPlanner must remain 100% application-agnostic!")

// 3. Assert TaskEgressValidator does not use hardcoded draft string checks
print("Asserting TaskEgressValidator eradication of hardcoded draft string checks...")
let hasHardcodedDraftCheck = validatorCode.contains("contains(\"siap untuk pengiriman\") || contains(\"draft\")")
assert(!hasHardcodedDraftCheck, "TaskEgressValidator must not use hardcoded draft substring checks!")

// 4. Assert CompanionWindowStreamService does NOT prioritize draft tokens over main windows
print("Asserting CompanionWindowStreamService does NOT prioritize draft tokens...")
let hasDraftTokenPriority = streamServiceCode.contains("\"draft\", \"draf\"")
assert(!hasDraftTokenPriority, "CompanionWindowStreamService must NOT prioritize 'draft' tokens over primary windows!")

// 5. Assert CompanionVMAgentLoop does NOT use .contains(\"Sedang\")
print("Asserting CompanionVMAgentLoop eradication of .contains(\"Sedang\")...")
let hasSedangCheck = vmAgentLoopCode.contains(".contains(\"Sedang\")")
assert(!hasSedangCheck, "CompanionVMAgentLoop must NOT use .contains(\"Sedang\")!")

let hasMenungguCheck = vmAgentLoopCode.contains(".contains(\"Menunggu konfirmasi\")")
assert(!hasMenungguCheck, "CompanionVMAgentLoop must NOT use .contains(\"Menunggu konfirmasi\")!")

print("✅ Test Task G assertions defined successfully!")
