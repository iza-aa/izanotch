import Foundation

print("=== Running Test F-12 Task 1: Eliminate Hardcoded Action Pipeline ===")

let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
let pipelinePath = "\(rootPath)/boringNotch/Clicky/Tools/MascotEmailActionPipeline.swift"
let homeSpaceViewPath = "\(rootPath)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
let pbxprojPath = "\(rootPath)/boringNotch.xcodeproj/project.pbxproj"

var passed = 0
var total = 0

// Test 1: MascotEmailActionPipeline.swift must NOT exist on disk
total += 1
if !FileManager.default.fileExists(atPath: pipelinePath) {
    print("  ✅ [PASS] MascotEmailActionPipeline.swift has been completely deleted")
    passed += 1
} else {
    print("  ❌ [FAIL] MascotEmailActionPipeline.swift still exists on disk")
}

// Test 2: HomeSpaceRootView.swift must NOT have hardcoded 'rezkyhaikal2@gmail.com' interceptor
total += 1
if let homeSpaceContent = try? String(contentsOfFile: homeSpaceViewPath, encoding: .utf8) {
    if !homeSpaceContent.contains("MascotEmailActionPipeline") && !homeSpaceContent.contains("rezkyhaikal2@gmail.com") {
        print("  ✅ [PASS] HomeSpaceRootView does not contain hardcoded email interceptors or MascotEmailActionPipeline calls")
        passed += 1
    } else {
        print("  ❌ [FAIL] HomeSpaceRootView still contains hardcoded pipeline interceptor")
    }
} else {
    print("  ❌ [FAIL] Unable to read HomeSpaceRootView.swift")
}

// Test 3: project.pbxproj must NOT reference MascotEmailActionPipeline.swift
total += 1
if let pbxContent = try? String(contentsOfFile: pbxprojPath, encoding: .utf8) {
    if !pbxContent.contains("MascotEmailActionPipeline.swift") {
        print("  ✅ [PASS] project.pbxproj has completely removed MascotEmailActionPipeline.swift")
        passed += 1
    } else {
        print("  ❌ [FAIL] project.pbxproj still references MascotEmailActionPipeline.swift")
    }
} else {
    print("  ❌ [FAIL] Unable to read project.pbxproj")
}

print("=== Results: \(passed)/\(total) tests passed ===")
if passed == total {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("SOME TESTS FAILED (EXPECTED BEFORE CODE CLEANUP)")
    exit(1)
}
