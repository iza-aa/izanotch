import SwiftUI

public struct CardCarouselView: View {
    @ObservedObject public var store: CardDataStore

    public init(store: CardDataStore = .shared) {
        self.store = store
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(store.filteredItems()) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        // Card Header: Monochrome Badge + Timestamp
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: badgeIcon(for: item.category))
                                    .font(.system(size: 8.5))
                                Text(item.badge)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                            )
                            .foregroundColor(.white.opacity(0.9))

                            Spacer()

                            Text(item.timestamp)
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(.white.opacity(0.35))
                        }

                        // Card Title
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        // Card Subtitle
                        Text(item.subtitle)
                            .font(.system(size: 10.5, weight: .regular, design: item.category == .clipboard ? .monospaced : .default))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(2)
                            .lineSpacing(2)

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(width: 146, height: 108)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func badgeIcon(for category: CardCategory) -> String {
        switch category {
        case .all: return "square.grid.2x2"
        case .clipboard: return "doc.on.clipboard"
        case .prompts: return "sparkles"
        case .schedule: return "clock"
        case .dropzone: return "tray.and.arrow.down"
        }
    }
}
