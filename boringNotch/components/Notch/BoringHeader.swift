//
//  BoringHeader.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

struct BoringHeader: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var clickyManager = CompanionManager.shared
    @StateObject var tvm = ShelfStateViewModel.shared
    @State private var showClickyHoverSpace = false
    @State private var isHoveringButton = false
    @State private var isHoveringPopover = false
    @State private var hideHoverSpaceTask: Task<Void, Never>?
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                if (!tvm.isEmpty || coordinator.alwaysShowTabs) && Defaults[.boringShelf] {
                    TabSelectionView()
                } else if vm.notchState == .open {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .allowsHitTesting(vm.notchState == .open)
            .onHover { hovering in
                coordinator.isHoveringTabs = hovering
            }
            .zIndex(2)

            if vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            HStack(spacing: 4) {
                if vm.notchState == .open {
                    if isHUDType(coordinator.sneakPeek.type) && coordinator.sneakPeek.show && Defaults[.showOpenNotchHUD] {
                        OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                vm.toggleCameraPreview()
                            }
                        }) {
                            Capsule()
                                .fill(vm.isCameraExpanded ? Color.accentColor : Color.black)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: "web.camera")
                                        .foregroundColor(.white)
                                        .padding()
                                        .imageScale(.medium)
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // IzaClicky Companion Rail Toggle Button (Master ON/OFF Switch)
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if clickyManager.isClickyCursorEnabled {
                                    clickyManager.disableCursor()
                                    FloatingCompanionRailWindowManager.shared.hideRail()
                                    showClickyHoverSpace = false
                                } else {
                                    clickyManager.enableCursor()
                                    FloatingCompanionRailWindowManager.shared.showRail()
                                }
                            }
                        }) {
                            Capsule()
                                .fill(clickyManager.isClickyCursorEnabled ? Color(red: 0.12, green: 0.52, blue: 0.95) : Color.black)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if clickyManager.isClickyCursorEnabled {
                                        AgentCloudShape()
                                            .fill(Color.white)
                                            .frame(width: 16, height: 13)
                                            .overlay(
                                                HStack(spacing: 2.5) {
                                                    Circle().fill(Color.black).frame(width: 2, height: 2)
                                                    Circle().fill(Color.black).frame(width: 2, height: 2)
                                                }
                                                .offset(y: -0.5)
                                            )
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(clickyManager.isClickyCursorEnabled ? "Clicky Active (Click to turn off)" : "Clicky Inactive (Click to turn on)")
                        .onHover { hovering in
                            isHoveringButton = hovering
                            if hovering {
                                hideHoverSpaceTask?.cancel()
                                hideHoverSpaceTask = nil
                                if clickyManager.isClickyCursorEnabled {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                        showClickyHoverSpace = true
                                    }
                                }
                            } else {
                                scheduleHideClickySpaceIfNeeded()
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if showClickyHoverSpace {
                                NotchClickyHoverSpace(
                                    onExpandToStudio: {
                                        withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                                            showClickyHoverSpace = false
                                        }
                                        vm.close()
                                        HomeSpaceWindowManager.shared.show()
                                    },
                                    onDismiss: {
                                        withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                                            showClickyHoverSpace = false
                                        }
                                    }
                                )
                                .onHover { hovering in
                                    isHoveringPopover = hovering
                                    if hovering {
                                        hideHoverSpaceTask?.cancel()
                                        hideHoverSpaceTask = nil
                                    } else {
                                        scheduleHideClickySpaceIfNeeded()
                                    }
                                }
                                .offset(x: 0, y: 34)
                                .transition(
                                    .asymmetric(
                                        insertion: .scale(scale: 0.05, anchor: UnitPoint(x: 0.94, y: 0.0))
                                            .combined(with: .offset(y: -8))
                                            .combined(with: .opacity),
                                        removal: .scale(scale: 0.05, anchor: UnitPoint(x: 0.94, y: 0.0))
                                            .combined(with: .offset(y: -8))
                                            .combined(with: .opacity)
                                    )
                                )
                            }
                        }
                        .onChange(of: showClickyHoverSpace) {
                            vm.isClickyPopoverActive = showClickyHoverSpace
                        }
                        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowClickyHoverSpace"))) { _ in
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                showClickyHoverSpace = true
                            }
                        }

                        if Defaults[.settingsIconInNotch] {
                            Button(action: {
                                DispatchQueue.main.async {
                                    SettingsWindowController.shared.showWindow()
                                }
                                
                            }) {
                                Capsule()
                                    .fill(.black)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Image(systemName: "gear")
                                            .foregroundColor(.white)
                                            .padding()
                                            .imageScale(.medium)
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if Defaults[.showBatteryIndicator] {
                            BoringBatteryView(
                                batteryWidth: 30,
                                isCharging: batteryModel.isCharging,
                                isInLowPowerMode: batteryModel.isInLowPowerMode,
                                isPluggedIn: batteryModel.isPluggedIn,
                                levelBattery: batteryModel.levelBattery,
                                maxCapacity: batteryModel.maxCapacity,
                                timeToFullCharge: batteryModel.timeToFullCharge,
                                isForNotification: false
                            )
                        }
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }

    func isHUDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return true
        default:
            return false
        }
    }

    private func scheduleHideClickySpaceIfNeeded() {
        if isHoveringButton || isHoveringPopover { return }
        hideHoverSpaceTask?.cancel()
        hideHoverSpaceTask = Task {
            try? await Task.sleep(for: .milliseconds(70))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if isHoveringButton || isHoveringPopover { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                    showClickyHoverSpace = false
                }
            }
        }
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
