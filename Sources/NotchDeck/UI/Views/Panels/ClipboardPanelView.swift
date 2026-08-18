import SwiftUI
import AppKit

public struct ClipboardPanelView: View {
    @ObservedObject public var cardStore: CardDataStore

    public init(cardStore: CardDataStore = .shared) {
        self.cardStore = cardStore
    }

    private var clipboardItems: [CardItem] {
        cardStore.items.filter { $0.category == .clipboard || $0.category == .dropzone }
    }

    private func iconForCategory(_ category: CardCategory) -> String {
        category == .dropzone ? "folder.fill" : "doc.text.fill"
    }

    public var body: some View {
        VStack(spacing: 10) {
            // 1. Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Clipboard & Staging")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                Text("\(clipboardItems.count) items")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 28)

            // 2. Clipboard Items List (Takes up middle flexible area)
            if clipboardItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.25))
                    Text("Clipboard history is empty")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                    Text("Copy text or files to automatically stage here.")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundColor(.white.opacity(0.28))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(clipboardItems) { item in
                            HStack(spacing: 10) {
                                Image(systemName: iconForCategory(item.category))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.75))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text(item.subtitle)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                Spacer()

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(item.title, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(4)
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    cardStore.removeItem(id: item.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // 3. Dropzone Staging Lip pinned at the bottom
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                Text("Drop files here to stage or drag to other apps")
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
