import SwiftUI

public struct CardCarouselView: View {
    @ObservedObject public var store: CardDataStore

    public init(store: CardDataStore = .shared) {
        self.store = store
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(store.filteredItems()) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        // Card Header: Badge + Timestamp
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: badgeIcon(for: item.category))
                                    .font(.system(size: 9))
                                Text(item.badge)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(badgeGradient(for: item.category))
                            )
                            .foregroundColor(.white)

                            Spacer()

                            Text(item.timestamp)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.45))
                        }

                        // Card Title
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        // Card Body / Subtitle
                        Text(item.subtitle)
                            .font(.system(size: 10.5, weight: .regular, design: item.category == .clipboard ? .monospaced : .default))
                            .foregroundColor(.white.opacity(0.70))
                            .lineLimit(2)
                            .lineSpacing(2)

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(width: 148, height: 112)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.18),
                                                Color.white.opacity(0.04)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private func badgeIcon(for category: CardCategory) -> String {
        switch category {
        case .all: return "square.grid.2x2"
        case .clipboard: return "doc.on.clipboard"
        case .prompts: return "sparkles"
        case .schedule: return "clock.badge.checkmark"
        case .dropzone: return "tray.and.arrow.down"
        }
    }

    private func badgeGradient(for category: CardCategory) -> LinearGradient {
        switch category {
        case .all:
            return LinearGradient(colors: [Color.gray.opacity(0.7), Color.gray.opacity(0.5)], startPoint: .top, endPoint: .bottom)
        case .clipboard:
            return LinearGradient(colors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        case .prompts:
            return LinearGradient(colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        case .schedule:
            return LinearGradient(colors: [Color.green.opacity(0.8), Color.teal.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        case .dropzone:
            return LinearGradient(colors: [Color.orange.opacity(0.8), Color.red.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        }
    }
}
