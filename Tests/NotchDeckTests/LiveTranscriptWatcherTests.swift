import Testing
import Foundation
@testable import NotchDeck

@Suite("Live Transcript Watcher Tests")
struct LiveTranscriptWatcherTests {
    @Test("Parse transcript JSONL line for ask_question event")
    func testParseClarificationQuestion() throws {
        let jsonLine = """
        {"step_index":5,"type":"PLANNER_RESPONSE","status":"WAITING_FOR_INPUT","content":"Pertanyaan untuk user","tool_calls":[{"tool_name":"ask_question","tool_arguments":{"questions":[{"question":"Pilih database?","options":["Postgres","SQLite"]}]}}]}
        """
        
        let event = LiveTranscriptWatcher.parseTranscriptLine(jsonLine)
        
        switch event {
        case .userClarificationNeeded(let question, let options):
            #expect(question.contains("Pilih database?"))
            #expect(options?.count == 2)
            #expect(options?.first == "Postgres")
        default:
            #expect(Bool(false), "Event should be userClarificationNeeded, got \(String(describing: event))")
        }
    }

    @Test("Parse transcript JSONL line for DONE task completed event")
    func testParseTaskDoneEvent() throws {
        let jsonLine = """
        {"step_index":12,"type":"PLANNER_RESPONSE","status":"DONE","content":"Refactoring auth module selesai dengan 15 test passing."}
        """
        
        let event = LiveTranscriptWatcher.parseTranscriptLine(jsonLine)
        
        switch event {
        case .taskCompleted(let summary):
            #expect(summary.contains("Refactoring auth module"))
        default:
            #expect(Bool(false), "Event should be taskCompleted, got \(String(describing: event))")
        }
    }

    @Test("Parse tool execution event")
    func testParseToolExecution() throws {
        let jsonLine = """
        {"step_index":8,"type":"PLANNER_RESPONSE","status":"RUNNING","tool_calls":[{"tool_name":"run_command","tool_summary":"Run Swift Tests"}]}
        """
        
        let event = LiveTranscriptWatcher.parseTranscriptLine(jsonLine)
        
        switch event {
        case .toolExecuted(let name, let summary):
            #expect(name == "run_command")
            #expect(summary == "Run Swift Tests")
        default:
            #expect(Bool(false), "Event should be toolExecuted, got \(String(describing: event))")
        }
    }
}
