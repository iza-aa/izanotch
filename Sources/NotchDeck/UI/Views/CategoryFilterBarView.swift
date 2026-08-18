import SwiftUI

public struct CategoryFilterBarView: View {
    @ObservedObject public var store: CardDataStore

    public init(store: CardDataStore = .shared) {
        self.store = store
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CardCategory.allCases) { cat in
                    let isSelected = store.selectedCategory == cat
                    let count = cat == .all ? store.items.count : store.items.filter { $0.category == cat }.count

                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            store.selectedCategory = cat
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: iconName(for: cat))
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .cyan : .white.opacity(0.7))

                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.8))

                            Text("\(count)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                                )
                                .foregroundColor(isSelected ? .cyan : .white.opacity(0.6))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.cyan.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func iconName(for category: CardCategory) -> String {
        switch category {
        case .all: return "square.grid.2x2.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .prompts: return "sparkles"
        case .schedule: return "calendar.badge.clock"
        case .dropzone: return "arrow.down.doc.fill"
        }
    }
}
