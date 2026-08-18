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
        VStack(spacing: 8) {
            // 1. Header
            HStack {
                Text("Notes & Scratchpad")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Text("\(noteItems.count) notes")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 4)

            // 2. Notes List
            if noteItems.isEmpty {
                VStack(spacing: 6) {
                    Spacer(minLength: 16)
                    Image(systemName: "note.text")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No notes yet. Type below to create one.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer(minLength: 16)
                }
                .frame(maxHeight: 120)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(noteItems) { item in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 11.5, weight: .medium))
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
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.6))
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
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 120)
            }

            // 3. Dedicated Bottom Note Input Bar
            HStack(spacing: 8) {
                TextField("+ Write note or paste snippet...", text: $newNoteText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
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
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
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
