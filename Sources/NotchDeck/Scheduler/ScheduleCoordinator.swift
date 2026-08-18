import Foundation

public final class ScheduleCoordinator: Sendable {
    public static let shared = ScheduleCoordinator()
    private let aiClient: NotchDeckAIClient
    private let eventKitService: EventKitServiceProtocol

    public init(
        aiClient: NotchDeckAIClient = .shared,
        eventKitService: EventKitServiceProtocol = EventKitService.shared
    ) {
        self.aiClient = aiClient
        self.eventKitService = eventKitService
    }

    public func processUtterance(
        _ utterance: String,
        currentDate: Date = Date(),
        apiKey: String? = nil
    ) async -> ScheduleDetail? {
        let cleanUtterance = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUtterance.isEmpty else { return nil }

        // 1. Try Cloud AI if API Key is available
        if let apiKey = apiKey, !apiKey.isEmpty {
            do {
                let aiResult = try await aiClient.parseSchedule(
                    userUtterance: cleanUtterance,
                    currentDate: currentDate,
                    apiKey: apiKey
                )
                if aiResult.success, let detail = aiResult.payload {
                    _ = try? await eventKitService.createCalendarEvent(detail: detail)
                    _ = try? await eventKitService.createReminder(detail: detail)
                    return detail
                }
            } catch {
                // Fallback to local parsing on network/decoding error
            }
        }

        // 2. Fallback to Local Regex Parser
        if let localDetail = LocalScheduleParser.parse(utterance: cleanUtterance, referenceDate: currentDate) {
            _ = try? await eventKitService.createCalendarEvent(detail: localDetail)
            _ = try? await eventKitService.createReminder(detail: localDetail)
            return localDetail
        }

        return nil
    }
}
