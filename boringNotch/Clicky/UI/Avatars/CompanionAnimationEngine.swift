//
//  CompanionAnimationEngine.swift
//  boringNotch
//
//  Engine Sequencer Animasi Autentik dari Bible Strong Avatar Lab (smontlouis/bible-strong-avatar-lab)
//  Memainkan 23 Urutan Animasi (7 Life Cycle + 16 Reactions) dengan Loop Transisi Smooth Hermite & Timer holdMs
//

import SwiftUI
import Combine

@MainActor
public final class CompanionAnimationEngine: ObservableObject {
    public static let shared = CompanionAnimationEngine()

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentSequence: AvatarLabAnimation?
    @Published public private(set) var currentStepIndex: Int = 0
    @Published public private(set) var currentExpressionKey: String = "neutral"

    private var playbackTask: Task<Void, Never>?

    public init() {}

    public var currentStep: AvatarAnimationStep? {
        guard let seq = currentSequence, seq.steps.indices.contains(currentStepIndex) else {
            return nil
        }
        return seq.steps[currentStepIndex]
    }

    public func play(sequence: AvatarLabAnimation, onStep: @escaping (AvatarAnimationStep) -> Void) {
        stop()
        currentSequence = sequence
        currentStepIndex = 0
        isPlaying = true
        if let first = sequence.steps.first {
            currentExpressionKey = first.semanticKey
            onStep(first)
        }

        playbackTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                guard let seq = self.currentSequence, !seq.steps.isEmpty else { break }
                let step = seq.steps[self.currentStepIndex]
                self.currentExpressionKey = step.semanticKey
                onStep(step)

                // Hold duration dari spec resmi Avatar Lab (2300ms s.d. 5200ms)
                let holdNanos = UInt64(max(500, step.holdMs)) * 1_000_000
                do {
                    try await Task.sleep(nanoseconds: holdNanos)
                } catch {
                    break
                }

                if Task.isCancelled { break }

                // Maju ke step berikutnya (Looping perulangan sequence)
                let nextIdx = (self.currentStepIndex + 1) % seq.steps.count
                self.currentStepIndex = nextIdx
            }
        }
    }

    public func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }

    public func advanceStep() {
        guard let seq = currentSequence, !seq.steps.isEmpty else { return }
        currentStepIndex = (currentStepIndex + 1) % seq.steps.count
        currentExpressionKey = seq.steps[currentStepIndex].semanticKey
    }

    public func toggle(sequence: AvatarLabAnimation, onStep: @escaping (AvatarAnimationStep) -> Void) {
        if isPlaying && currentSequence?.id == sequence.id {
            stop()
        } else {
            play(sequence: sequence, onStep: onStep)
        }
    }
}
