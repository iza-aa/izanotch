import Foundation

print("==================================================================")
print("🧪 Test Task H: Eliminate Residual Hardcoding Across Tools")
print("==================================================================")

let rootDir = FileManager.default.currentDirectoryPath
let groundingPath = "\(rootDir)/boringNotch/Clicky/Tools/ClickyHybridGroundingEngine.swift"
let ingressPath = "\(rootDir)/boringNotch/Clicky/Tools/TaskIngressGateway.swift"
let iconViewPath = "\(rootDir)/boringNotch/Clicky/Tools/AppSystemIconView.swift"
let streamPath = "\(rootDir)/boringNotch/Clicky/Tools/CompanionWindowStreamService.swift"

guard let groundingCode = try? String(contentsOfFile: groundingPath),
      let ingressCode = try? String(contentsOfFile: ingressPath),
      let iconViewCode = try? String(contentsOfFile: iconViewPath),
      let streamCode = try? String(contentsOfFile: streamPath) else {
    print("❌ Failed to read required source files.")
    exit(1)
}

// 1. Assert ClickyHybridGroundingEngine does NOT hardcode email keywords
print("Asserting ClickyHybridGroundingEngine no hardcoded email keywords...")
let hasHardcodedEmailKeywords = groundingCode.contains("query.contains(\"to\") && (title == \"to\"") ||
                                groundingCode.contains("query.contains(\"compose\") && (title.contains(\"compose\")")
assert(!hasHardcodedEmailKeywords, "ClickyHybridGroundingEngine must NOT contain hardcoded email keywords!")

// 2. Assert TaskIngressGateway has no hardcoded Mail/Safari fallback
print("Asserting TaskIngressGateway no hardcoded Mail/Safari fallback...")
let hasHardcodedAppFallback = ingressCode.contains("(lower.contains(\"mail\") || lower.contains(\"email\") ? \"Mail\" : (lower.contains(\"safari\")")
assert(!hasHardcodedAppFallback, "TaskIngressGateway must NOT contain hardcoded Mail/Safari fallback!")

// 3. Assert AppSystemIconView does not hardcode com.apple.mail or envelope.fill
print("Asserting AppSystemIconView dynamic icon resolution...")
let hasHardcodedBundleId = iconViewCode.contains("bundleId = \"com.apple.mail\"")
let hasHardcodedEnvelope = iconViewCode.contains("envelope.fill")
assert(!hasHardcodedBundleId, "AppSystemIconView must NOT hardcode com.apple.mail bundle ID!")
assert(!hasHardcodedEnvelope, "AppSystemIconView must NOT hardcode envelope.fill fallback symbol!")

// 4. Assert CompanionWindowStreamService launches with persistence ignore
print("Asserting CompanionWindowStreamService launches with persistence ignore...")
let hasPersistenceIgnore = streamCode.contains("-ApplePersistenceIgnoreState")
assert(hasPersistenceIgnore, "CompanionWindowStreamService must pass -ApplePersistenceIgnoreState YES!")

print("✅ Test Task H assertions defined successfully!")
