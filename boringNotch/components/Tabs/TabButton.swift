//
//  TabButton.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-24.
//

import SwiftUI

struct TabButton: View {
    let label: String
    let icon: String
    let selected: Bool
    let onClick: () -> Void
    @EnvironmentObject var vm: BoringViewModel

    @State private var hoverTask: Task<Void, Never>? = nil

    var body: some View {
        Image(systemName: icon)
            .padding(.horizontal, 15)
            .contentShape(Capsule())
            .onHover { hovering in
                guard vm.notchState == .open else {
                    hoverTask?.cancel()
                    hoverTask = nil
                    BoringViewCoordinator.shared.isHoveringTabs = false
                    return
                }
                if hovering && !selected {
                    BoringViewCoordinator.shared.isHoveringTabs = true
                    // Short delay so fast mouse movement across tabs doesn't flicker
                    hoverTask = Task {
                        try? await Task.sleep(for: .milliseconds(120))
                        guard !Task.isCancelled, vm.notchState == .open else { return }
                        await MainActor.run {
                            BoringViewCoordinator.shared.isHoveringTabs = false
                            withAnimation(.smooth) { onClick() }
                        }
                    }
                } else {
                    BoringViewCoordinator.shared.isHoveringTabs = false
                    hoverTask?.cancel()
                    hoverTask = nil
                }
            }
    }
}

#Preview {
    TabButton(label: "Home", icon: "tray.fill", selected: true) {
        print("Tapped")
    }
}
