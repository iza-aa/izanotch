import SwiftUI

public struct AudioWaveformView: View {
    public var levels: [CGFloat]

    public init(levels: [CGFloat] = [0.2, 0.5, 0.8, 0.6, 0.3, 0.7]) {
        self.levels = levels
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: max(6, levels[index] * 24))
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: levels[index])
            }
        }
        .frame(height: 26)
    }
}
