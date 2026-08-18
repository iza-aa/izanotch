import SwiftUI

public struct FeatureNavigationDock: View {
    @ObservedObject public var stateController: NotchStateController

    public init(stateController: NotchStateController) {
        self.stateController = stateController
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(NotchFeatureTab.allCases) { tab in
                Button(action: {
                    stateController.selectTab(tab)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 10.5, weight: stateController.activeTab == tab ? .semibold : .regular))

                        if stateController.activeTab == tab {
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(stateController.activeTab == tab ? Color.white.opacity(0.18) : Color.clear)
                    )
                    .foregroundColor(stateController.activeTab == tab ? .white : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .padding(.horizontal, 12)   // ensure dock tabs clear the window edge
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
    }
}
