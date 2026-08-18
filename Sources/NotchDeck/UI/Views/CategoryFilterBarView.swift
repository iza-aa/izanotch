import SwiftUI

public struct CategoryFilterBarView: View {
    @ObservedObject public var store: CardDataStore

    public init(store: CardDataStore = .shared) {
        self.store = store
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(CardCategory.allCases) { cat in
                    let isSelected = store.selectedCategory == cat
                    let count = cat == .all ? store.items.count : store.items.filter { $0.category == cat }.count

                    Button(action: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                            store.selectedCategory = cat
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: iconName(for: cat))
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.45))

                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.6))

                            Text("\(count)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                                )
                                .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.04))
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
        case .all: return "square.grid.2x2"
        case .notes: return "note.text"
        case .clipboard: return "doc.on.clipboard"
        case .prompts: return "sparkles"
        case .schedule: return "calendar"
        case .dropzone: return "arrow.down.doc"
        }
    }
}
