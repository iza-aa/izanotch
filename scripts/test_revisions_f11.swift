import Foundation

// TDD Verification Test for Milestone 178 (Revisi F-11: Sidebar Top Alignment & Zero Sidebar Aura)

func testRevisionsF11() {
    print("=== START TEST REVISIONS F-11 ===")

    let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
    let homeSpaceViewPath = "\(rootPath)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
    guard let content = try? String(contentsOfFile: homeSpaceViewPath, encoding: .utf8) else {
        fatalError("Failed to read HomeSpaceRootView.swift")
    }

    // Extract sidebarView section
    guard let sidebarStart = content.range(of: "private var sidebarView: some View"),
          let sidebarEnd = content.range(of: "// MARK: - Section 2: Active Chat Workspace View") else {
        fatalError("Failed to locate sidebarView in HomeSpaceRootView.swift")
    }
    let sidebarContent = String(content[sidebarStart.lowerBound..<sidebarEnd.lowerBound])

    // 1. Verify sidebar top padding is reduced to 14 (raised to align with Back to Chat)
    assert(sidebarContent.contains(".padding(.top, 14)"), "FAIL: sidebarView top padding is not 14")
    assert(!sidebarContent.contains(".padding(.top, 36)"), "FAIL: sidebarView still has old top padding 36")
    print("✓ Test 1: Sidebar top padding raised from 36 to 14 to align with Back to Chat")

    // 2. Verify iza logo container has aligned height
    assert(sidebarContent.contains(".frame(height: 24)"), "FAIL: iza logo header row does not have height 24")
    print("✓ Test 2: iza logo header row has height 24 matching Back to Chat")

    // 3. Verify avatar blur circle aura is removed
    assert(!sidebarContent.contains(".blur(radius: 6)"), "FAIL: sidebarView still contains avatar blur aura")
    print("✓ Test 3: Avatar blur aura (.blur(radius: 6)) completely removed")

    // 4. Verify colored aura shadows (#60A5FA) are removed from sidebarView
    assert(!sidebarContent.contains(".shadow(color: Color(hex: \"#60A5FA\")"), "FAIL: sidebarView still contains #60A5FA aura shadow")
    print("✓ Test 4: All blue aura shadows (#60A5FA) completely removed from sidebarView")

    print("=== ALL REVISIONS F-11 TESTS PASSED (100%) ===")
}

testRevisionsF11()
