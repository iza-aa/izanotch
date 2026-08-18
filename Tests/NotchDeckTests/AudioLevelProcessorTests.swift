import Testing
import Foundation
@testable import NotchDeck

@Suite("Audio Level Processor Tests")
struct AudioLevelProcessorTests {
    @Test("Calculate normalized levels for silent buffer")
    func testSilentBufferLevels() {
        let silentSamples: [Float] = Array(repeating: 0.0, count: 512)
        let levels = AudioLevelProcessor.calculateNormalizedLevels(from: silentSamples, barCount: 6)
        
        #expect(levels.count == 6)
        for level in levels {
            #expect(level >= 0.1 && level <= 0.2)
        }
    }

    @Test("Calculate normalized levels for loud buffer")
    func testLoudBufferLevels() {
        let loudSamples: [Float] = Array(repeating: 0.8, count: 512)
        let levels = AudioLevelProcessor.calculateNormalizedLevels(from: loudSamples, barCount: 6)
        
        #expect(levels.count == 6)
        for level in levels {
            #expect(level >= 0.7)
        }
    }
}
