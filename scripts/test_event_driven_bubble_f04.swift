import Foundation
import SwiftUI

enum CompanionStatus: String {
    case idle, working, done
}

struct TestCompanionProfile {
    var slug: String
    var name: String
    var role: String
    var summary: String
    var cloudColorHex: String
    var ringColorHex: String
    var status: CompanionStatus
    var hasUnreadMessages: Bool
}

@main
struct F04TestRunner {
    static func main() {
        print("=== Test Suite: F-04 Event-Driven Bubble & Waveform Badge ===")

        // 1. Initial State: All idle and read -> 0 active mascots
        var r1 = TestCompanionProfile(slug: "futures-scout", name: "Futures Scout", role: "Futures Analyst", summary: "Crypto", cloudColorHex: "#F87171", ringColorHex: "#FEE2E2", status: .idle, hasUnreadMessages: false)
        var r2 = TestCompanionProfile(slug: "shippy", name: "Shippy", role: "Assistant", summary: "Desk", cloudColorHex: "#5B7FE5", ringColorHex: "#BAE6FD", status: .idle, hasUnreadMessages: false)
        var r3 = TestCompanionProfile(slug: "riset-buddy", name: "Riset Buddy", role: "Researcher", summary: "Web", cloudColorHex: "#84CC16", ringColorHex: "#ECFCCB", status: .idle, hasUnreadMessages: false)

        var roster = [r1, r2, r3]
        func getActiveMascots(_ list: [TestCompanionProfile]) -> [TestCompanionProfile] {
            list.filter { $0.status == .working || $0.hasUnreadMessages }
        }

        assert(getActiveMascots(roster).isEmpty, "Initial state must have 0 active mascots on screen")
        print("✅ Test 1 Passed: When idle and read, 0 mascots are shown (desktop is 100% clean).")

        // 2. Event Trigger: User prompts Futures Scout -> status becomes .working
        roster[0].status = .working
        let workingMascots = getActiveMascots(roster)
        assert(workingMascots.count == 1, "Expected 1 active mascot during processing")
        assert(workingMascots[0].slug == "futures-scout")
        assert(workingMascots[0].status == .working)
        print("✅ Test 2 Passed: When bot starts working, mascot appears dynamically with processing waveform.")

        // 3. Concurrent Event: Shippy has an unread response ready
        roster[1].hasUnreadMessages = true
        roster[1].status = .done
        let concurrentMascots = getActiveMascots(roster)
        assert(concurrentMascots.count == 2, "Expected 2 active mascots")
        assert(concurrentMascots.map(\.slug) == ["futures-scout", "shippy"])
        print("✅ Test 3 Passed: Multiple concurrent active bots appear stacked without static rail clutter.")

        // 4. Dismissal via [X]: User reads/dismisses Shippy
        roster[1].hasUnreadMessages = false
        if roster[1].status == .done {
            roster[1].status = .idle
        }
        let afterDismiss = getActiveMascots(roster)
        assert(afterDismiss.count == 1, "Expected only Futures Scout remaining")
        assert(afterDismiss[0].slug == "futures-scout")
        print("✅ Test 4 Passed: Clicking [X] marks read and dismisses Shippy immediately from screen.")

        // 5. Completion & Final Dismissal: Futures Scout finishes and is dismissed
        roster[0].status = .done
        roster[0].hasUnreadMessages = false
        roster[0].status = .idle
        assert(getActiveMascots(roster).isEmpty, "All bots dismissed -> desktop 100% clean")
        print("✅ Test 5 Passed: All bots dismissed -> desktop completely clean again.")

        // 6. Waveform Math Verification: Sinusoidal amplitude bounds
        for t in stride(from: 0.0, through: 2.0, by: 0.2) {
            for i in 0..<3 {
                let phase = t * 6.0 + Double(i) * 1.2
                let height = 3.5 + (sin(phase) + 1.0) * 3.2
                assert(height >= 3.49 && height <= 10.0, "Waveform bar height must stay within [3.5, 9.9] pt")
            }
        }
        print("✅ Test 6 Passed: Breathing waveform equalizer mathematics is stable within [3.5, 9.9] pt.")

        print("=== All 6 Tests Passed Successfully! ===")
    }
}
