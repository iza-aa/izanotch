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

                    Button(action: { store.selectedCategory = cat }) {
                        HStack(spacing: 4) {
                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            Text("\(count)")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
