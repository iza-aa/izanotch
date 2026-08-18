import Foundation

public struct ScheduleDetail: Codable, Sendable {
    public let title: String
    public let eventType: String
    public let eventStartISO: String
    public let reminderISO: String
    public let offsetMinutes: Int
    public let confidenceScore: Double

    public var eventStartDate: Date {
        ISO8601DateFormatter().date(from: eventStartISO) ?? Date()
    }

    public var reminderDate: Date {
        ISO8601DateFormatter().date(from: reminderISO) ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case title
        case eventType = "event_type"
        case eventStartISO = "event_start_iso"
        case reminderISO = "reminder_iso"
        case offsetMinutes = "offset_minutes"
        case confidenceScore = "confidence_score"
    }

    public init(title: String, eventType: String, eventStartISO: String, reminderISO: String, offsetMinutes: Int, confidenceScore: Double) {
        self.title = title
        self.eventType = eventType
        self.eventStartISO = eventStartISO
        self.reminderISO = reminderISO
        self.offsetMinutes = offsetMinutes
        self.confidenceScore = confidenceScore
    }
}

public struct NLPScheduleResult: Codable, Sendable {
    public let success: Bool
    public let isAmbiguous: Bool
    public let clarificationQuestion: String?
    public let payload: ScheduleDetail?

    enum CodingKeys: String, CodingKey {
        case success
        case isAmbiguous = "is_ambiguous"
        case clarificationQuestion = "clarification_question"
        case payload
    }

    public init(success: Bool, isAmbiguous: Bool, clarificationQuestion: String?, payload: ScheduleDetail?) {
        self.success = success
        self.isAmbiguous = isAmbiguous
        self.clarificationQuestion = clarificationQuestion
        self.payload = payload
    }
}
