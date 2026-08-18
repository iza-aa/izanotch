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
        VStack(spacing: 10) {
            // 1. Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Schedule & Reminders")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                Text("\(scheduleItems.count) upcoming")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 28)

            // 2. Schedule List (Takes up middle flexible area)
            if scheduleItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.25))
                    Text("No upcoming reminders")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                    Text("Add a reminder below (e.g. 'Meeting with client at 3pm').")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundColor(.white.opacity(0.28))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(scheduleItems) { item in
                            HStack(spacing: 10) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.75))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text(item.subtitle)
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                Spacer()

                                Text(item.badge)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.white.opacity(0.15)))
                                    .foregroundColor(.white)

                                Button(action: {
                                    cardStore.removeItem(id: item.id)
                                }) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))
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

            // 3. Dedicated Bottom Schedule Input Bar pinned at the bottom
            HStack(spacing: 8) {
                TextField("Add reminder (e.g. 'Meeting at 3pm')...", text: $newScheduleText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundColor(.white)
                    .onSubmit {
                        submitSchedule()
                    }

                if !newScheduleText.isEmpty {
                    Button(action: { submitSchedule() }) {
                        Image(systemName: "calendar.badge.plus")
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
