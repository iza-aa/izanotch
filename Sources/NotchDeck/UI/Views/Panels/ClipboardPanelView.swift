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
        VStack(spacing: 8) {
            // 1. Header
            HStack {
                Text("Clipboard & File Staging")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Text("\(clipboardItems.count) items")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 24)   // page inset per design reference

            // 2. Clipboard Items List
            if clipboardItems.isEmpty {
                VStack(spacing: 6) {
                    Spacer(minLength: 16)
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.2))
                    Text("Clipboard history is empty")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Copy text or files to stage here.")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.28))
                    Spacer(minLength: 16)
                }
                .frame(maxHeight: 120)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(clipboardItems) { item in
                            HStack(spacing: 8) {
                                Image(systemName: iconForCategory(item.category))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.7))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text(item.subtitle)
                                        .font(.system(size: 9.5, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                Spacer()

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(item.title, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    cardStore.removeItem(id: item.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(16)   // card inset per design reference
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 24)   // page inset for cards
                }
                .frame(maxHeight: 120)
            }

            // 3. Dropzone Staging Lip
            HStack {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                Text("Drop files here to stage or drag to other apps")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 16)   // matches input horizontal inset
            .padding(.vertical, 12)      // matches input vertical inset
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
            .padding(.horizontal, 8)
        }
    }
}
