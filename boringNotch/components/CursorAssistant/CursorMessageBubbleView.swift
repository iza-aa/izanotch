import SwiftUI

// MARK: - CursorMessageBubbleSizePreferenceKey
// Binary-confirmed: CursorMessageBubbleSizePreferenceKey
struct CursorMessageBubbleSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - NavigationBubbleSizePreferenceKey
// Binary-confirmed: NavigationBubbleSizePreferenceKey
struct NavigationBubbleSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - CursorMessageBubbleWordRevealModifier
// Binary-confirmed: CursorMessageBubbleWordRevealModifier
struct CursorMessageBubbleWordRevealModifier: ViewModifier {
    var revealedWordCount: Int

    func body(content: Content) -> some View {
        content
            .animation(.easeOut(duration: 0.2), value: revealedWordCount)
    }
}

// MARK: - CursorMessageBubbleView
// Binary-confirmed: CursorMessageBubbleView
struct CursorMessageBubbleView: View {
    var message: String
    var maxBubbleWidth: CGFloat = 280

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
            )
            .frame(maxWidth: maxBubbleWidth, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: CursorMessageBubbleSizePreferenceKey.self,
                        value: geo.size
                    )
                }
            )
    }
}
