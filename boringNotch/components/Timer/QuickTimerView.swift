//
//  QuickTimerView.swift
//  boringNotch
//
//  Created for boringNotch Home Tab Dashboard.
//

import SwiftUI
import Combine

struct QuickTimerView: View {
    @State private var totalDurationSeconds: Int = 60
    @State private var remainingSeconds: Int = 60
    @State private var isRunning: Bool = false
    @State private var isCompleted: Bool = false

    private let timerPublisher = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background Card matching Music Album Art geometry
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(
                            isCompleted
                                ? Color.green.opacity(0.8)
                                : (isRunning ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.12)),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 2)

            VStack(spacing: 4) {
                // 1. Header: "Timer"
                Text("Timer")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 7)

                Spacer(minLength: 0)

                // 2. Time Wheel / Counter Display
                VStack(spacing: 2) {
                    if isRunning {
                        Text(formatCountdown(remainingSeconds))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    } else {
                        // Interactive Wheel / Stepper style
                        VStack(spacing: 1.5) {
                            HStack(spacing: 6) {
                                Text("0h").foregroundColor(.white.opacity(0.3))
                                Text("0m").foregroundColor(.white.opacity(0.3))
                                Text("0s").foregroundColor(.white.opacity(0.3))
                            }
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))

                            HStack(spacing: 6) {
                                let h = totalDurationSeconds / 3600
                                let m = (totalDurationSeconds % 3600) / 60
                                let s = totalDurationSeconds % 60
                                Text("\(h)h")
                                Text("\(m)m")
                                Text("\(s)s")
                            }
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.white.opacity(0.1))
                            )

                            HStack(spacing: 6) {
                                Text("2h").foregroundColor(.white.opacity(0.3))
                                Text("2m").foregroundColor(.white.opacity(0.3))
                                Text("2s").foregroundColor(.white.opacity(0.3))
                            }
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        }
                    }
                }

                Spacer(minLength: 0)

                // 3. Action Presets and Start/Stop Button
                HStack(spacing: 4) {
                    Button(action: {
                        setPreset(minutes: 1)
                    }) {
                        Text("1m")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundColor(totalDurationSeconds == 60 ? .black : .white)
                            .padding(.vertical, 3.5)
                            .padding(.horizontal, 5)
                            .background(
                                Capsule()
                                    .fill(totalDurationSeconds == 60 ? Color.white : Color.white.opacity(0.12))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        setPreset(minutes: 5)
                    }) {
                        Text("5m")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundColor(totalDurationSeconds == 300 ? .black : .white)
                            .padding(.vertical, 3.5)
                            .padding(.horizontal, 5)
                            .background(
                                Capsule()
                                    .fill(totalDurationSeconds == 300 ? Color.white : Color.white.opacity(0.12))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        toggleTimer()
                    }) {
                        Text(isRunning ? "Stop" : "Start")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.vertical, 3.5)
                            .padding(.horizontal, 6)
                            .background(
                                Capsule()
                                    .fill(isRunning ? Color.orange : Color.white)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 7)
                .padding(.horizontal, 5)
            }
        }
        .onReceive(timerPublisher) { _ in
            guard isRunning else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                isRunning = false
                isCompleted = true
            }
        }
    }

    private func setPreset(minutes: Int) {
        totalDurationSeconds = minutes * 60
        remainingSeconds = totalDurationSeconds
        isRunning = false
        isCompleted = false
    }

    private func toggleTimer() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            if isRunning {
                isRunning = false
            } else {
                if remainingSeconds <= 0 {
                    remainingSeconds = totalDurationSeconds
                }
                isCompleted = false
                isRunning = true
            }
        }
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
