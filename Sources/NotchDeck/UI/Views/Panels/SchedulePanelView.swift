import SwiftUI

public struct SchedulePanelView: View {
    @ObservedObject public var cardStore: CardDataStore
    public var onAddSchedule: (@MainActor (String) -> Void)?
    @State private var newScheduleText: String = ""

    public init(
        cardStore: CardDataStore = .shared,
        onAddSchedule: (@MainActor (String) -> Void)? = nil
    ) {
        self.cardStore = cardStore
        self.onAddSchedule = onAddSchedule
    }

    private var scheduleItems: [CardItem] {
        cardStore.items.filter { $0.category == .schedule }
    }

    public var body: some View {
        VStack(spacing: 8) {
            // 1. Header
            HStack {
                Text("Schedule & Reminders")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Text("\(scheduleItems.count) upcoming")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)

            // 2. Schedule List
            if scheduleItems.isEmpty {
                VStack(spacing: 6) {
                    Spacer(minLength: 16)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No upcoming reminders. Add one below.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer(minLength: 16)
                }
                .frame(maxHeight: 120)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(scheduleItems) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text(item.subtitle)
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                Spacer()

                                Text(item.badge)
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.15)))
                                    .foregroundColor(.white)

                                Button(action: {
                                    cardStore.removeItem(id: item.id)
                                }) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
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

            // 3. Dedicated Bottom Schedule Input Bar
            HStack(spacing: 8) {
                TextField("Add reminder (e.g. 'Meeting at 3pm')...", text: $newScheduleText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .onSubmit {
                        submitSchedule()
                    }

                if !newScheduleText.isEmpty {
                    Button(action: { submitSchedule() }) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    private func submitSchedule() {
        let text = newScheduleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let onAdd = onAddSchedule {
            onAdd(text)
        } else {
            cardStore.addItem(CardItem(title: text, subtitle: "Reminder", category: .schedule, badge: "Upcoming"))
        }
        newScheduleText = ""
    }
}
