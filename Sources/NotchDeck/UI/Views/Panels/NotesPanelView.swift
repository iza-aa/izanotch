import SwiftUI
import AppKit

public struct NotesPanelView: View {
    @ObservedObject public var cardStore: CardDataStore
    @State private var newNoteText: String = ""

    public init(cardStore: CardDataStore = .shared) {
        self.cardStore = cardStore
    }

    private var noteItems: [CardItem] {
        cardStore.items.filter { $0.category == .notes }
    }

    public var body: some View {
        VStack(spacing: 10) {
            // 1. Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Notes & Scratchpad")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                Text("\(noteItems.count) notes")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 28)

            // 2. Notes List (Takes up middle flexible area)
            if noteItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.25))
                    Text("No notes yet")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                    Text("Type below to create a quick note or snippet.")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundColor(.white.opacity(0.28))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(noteItems) { item in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(2)

                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)
                                    }
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

            // 3. Dedicated Bottom Note Input Bar pinned at the bottom
            HStack(spacing: 8) {
                TextField("Write note or paste snippet...", text: $newNoteText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundColor(.white)
                    .onSubmit {
                        addNote()
                    }

                if !newNoteText.isEmpty {
                    Button(action: { addNote() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addNote() {
        let text = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: Date())
        cardStore.addItem(CardItem(title: text, subtitle: "Note", category: .notes, badge: "Note", timestamp: timeStr))
        newNoteText = ""
    }
}
