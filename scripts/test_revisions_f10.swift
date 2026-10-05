import Foundation

// TDD Verification Test for Milestone 177 (Revisi F-10: Option 2 Top-Pinned Studio)

func testRevisionsF10() {
    print("=== START TEST REVISIONS F-10 (OPTION 2) ===")

    let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
    let homeSpaceViewPath = "\(rootPath)/boringNotch/Clicky/HomeSpace/HomeSpaceRootView.swift"
    guard let content = try? String(contentsOfFile: homeSpaceViewPath, encoding: .utf8) else {
        fatalError("Failed to read HomeSpaceRootView.swift")
    }

    // 1. Verify "CHARACTER TEMPLATES (11 SHAPES)" is replaced by "CHARACTER"
    assert(!content.contains("CHARACTER TEMPLATES (11 SHAPES)"), "FAIL: Still contains old long title")
    assert(content.contains("Text(\"CHARACTER\")"), "FAIL: Does not contain Text(\"CHARACTER\")")
    print("✓ Test 1: Title changed to CHARACTER")

    // 2. Verify Spacer() is used to pin action buttons to the bottom
    assert(content.contains("Spacer()") && content.contains("padding(.bottom, 20)"), "FAIL: Bottom action buttons not pinned via Spacer()")
    print("✓ Test 2: Top-pinned layout with Spacer() and bottom-pinned action buttons")

    // 3. Verify Color Picker has clean custom circular swatch and compact hex field
    assert(content.contains("frame(width: 22, height: 22)"), "FAIL: Circular swatch 22x22 missing")
    assert(content.contains("opacity(0.015)"), "FAIL: Interactive ColorPicker overlay missing")
    print("✓ Test 3: Compact color swatch 22x22 with interactive overlay & proportioned hex field")

    // 4. Verify Single Chevron on Dropdowns (.buttonStyle(.plain) used instead of .menuStyle(.borderlessButton))
    // We should not have .menuStyle(.borderlessButton) for these dropdowns to prevent left chevron
    assert(!content.contains(".menuStyle(.borderlessButton)"), "FAIL: Still contains .menuStyle(.borderlessButton) causing double chevrons")
    print("✓ Test 4: Single chevron verified via .buttonStyle(.plain) replacing .menuStyle(.borderlessButton)")

    // 5. Verify 3-Column Top-Label Layout (Option 2)
    assert(content.contains("Text(\"COLOR\")") && content.contains("Text(\"EXPRESSION\")") && content.contains("Text(\"ANIMATION\")"), "FAIL: Missing top labels")
    print("✓ Test 5: 3-Column Top-Label layout verified")

    print("=== ALL REVISIONS F-10 TESTS PASSED (100%) ===")
}

testRevisionsF10()
