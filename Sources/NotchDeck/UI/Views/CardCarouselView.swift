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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.badge)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeColor(for: item.category))
                                .cornerRadius(4)
                                .foregroundColor(.white)
                            Spacer()
                            Text(item.timestamp)
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }

                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(item.subtitle)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(2)

                        Spacer()
                    }
                    .padding(10)
                    .frame(width: 140, height: 110)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func badgeColor(for category: CardCategory) -> Color {
        switch category {
        case .all: return .gray
        case .clipboard: return .blue
        case .prompts: return .purple
        case .schedule: return .green
        case .dropzone: return .orange
        }
    }
}
