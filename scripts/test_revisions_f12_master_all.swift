import Foundation

print("=== STARTING MASTER TEST RUNNER: F-12 AUTONOMOUS VM AGENT LOOP & PROACTIVE WATCHER ===")

let scripts = [
    "scripts/test_revisions_f12_task1_no_hardcoded_pipeline.swift",
    "scripts/test_revisions_f12_task2_persona_sovereignty.swift",
    "scripts/test_revisions_f12_task3_vm_agent_loop.swift",
    "scripts/test_revisions_f12_task4_proactive_watcher.swift"
]

var allPassed = true

for script in scripts {
    print("\n--- Running \(script) ---")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = [script]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        print(output)
        
        if process.terminationStatus != 0 {
            print("❌ FAILED: \(script)")
            allPassed = false
        } else {
            print("✅ PASSED: \(script)")
        }
    } catch {
        print("❌ Error executing \(script): \(error)")
        allPassed = false
    }
}

if allPassed {
    print("\n=======================================================")
    print("🎉 ALL F-12 MASTER SUITE TESTS PASSED (100% SUCCESS) 🎉")
    print("=======================================================")
    exit(0)
} else {
    print("\n❌ SOME TESTS FAILED IN MASTER SUITE")
    exit(1)
}
