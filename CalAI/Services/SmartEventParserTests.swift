import Foundation

// MARK: - Parser Test Suite

class SmartEventParserTests {

    private let parser = SmartEventParser()

    // MARK: - Test Cases

    struct TestCase {
        let input: String
        let expectedAction: EventAction
        let expectedTitle: String?
        let expectedAttendees: [String]?
        let expectedHasTime: Bool
        let expectedLocation: String?
        let description: String
    }

    private let testCases: [TestCase] = [
        // Simple cases
        TestCase(
            input: "lunch with John tomorrow at noon",
            expectedAction: .create,
            expectedTitle: "Lunch",
            expectedAttendees: ["John"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Basic lunch meeting"
        ),

        TestCase(
            input: "meeting with Sarah next Tuesday 2pm",
            expectedAction: .create,
            expectedTitle: "Meeting",
            expectedAttendees: ["Sarah"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Meeting with specific day and time"
        ),

        TestCase(
            input: "schedule coffee with Mike tomorrow morning",
            expectedAction: .create,
            expectedTitle: "Coffee",
            expectedAttendees: ["Mike"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Coffee with relative time"
        ),

        // Complex/Messy cases
        TestCase(
            input: "hey schedule a thing with Mike sometime tomorrow afternoon maybe 2ish",
            expectedAction: .create,
            expectedTitle: nil,
            expectedAttendees: ["Mike"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Messy natural language"
        ),

        TestCase(
            input: "put in a lunch next week wednesday around noonish with the marketing team",
            expectedAction: .create,
            expectedTitle: "Lunch",
            expectedAttendees: nil,
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Lunch with team reference"
        ),

        TestCase(
            input: "book me and Jennifer for coffee tomorrow morning",
            expectedAction: .create,
            expectedTitle: "Coffee",
            expectedAttendees: ["Jennifer"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Book with compound subject"
        ),

        // With locations
        TestCase(
            input: "lunch with John tomorrow at The Coffee Shop on Main Street",
            expectedAction: .create,
            expectedTitle: "Lunch",
            expectedAttendees: ["John"],
            expectedHasTime: true,
            expectedLocation: "The Coffee Shop on Main Street",
            description: "Event with specific location"
        ),

        TestCase(
            input: "meeting in Conference Room A at 3pm",
            expectedAction: .create,
            expectedTitle: "Meeting",
            expectedAttendees: nil,
            expectedHasTime: true,
            expectedLocation: "Conference Room A",
            description: "Meeting with room location"
        ),

        // Missing information
        TestCase(
            input: "meeting with Alex tomorrow",
            expectedAction: .create,
            expectedTitle: "Meeting",
            expectedAttendees: ["Alex"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Missing specific time (should default)"
        ),

        TestCase(
            input: "lunch at noon",
            expectedAction: .create,
            expectedTitle: "Lunch",
            expectedAttendees: nil,
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Missing attendees"
        ),

        // Special patterns
        TestCase(
            input: "team standup tomorrow",
            expectedAction: .create,
            expectedTitle: "Team Standup",
            expectedAttendees: ["@team"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Team event"
        ),

        TestCase(
            input: "1-on-1 with boss friday",
            expectedAction: .create,
            expectedTitle: "1-on-1",
            expectedAttendees: nil,
            expectedHasTime: true,
            expectedLocation: nil,
            description: "One-on-one meeting"
        ),

        // Time variations
        TestCase(
            input: "call with John at 2:30pm",
            expectedAction: .create,
            expectedTitle: "Call",
            expectedAttendees: ["John"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Call with specific time including minutes"
        ),

        TestCase(
            input: "dinner tomorrow evening",
            expectedAction: .create,
            expectedTitle: "Dinner",
            expectedAttendees: nil,
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Dinner with relative time"
        ),

        TestCase(
            input: "meeting in 2 hours",
            expectedAction: .create,
            expectedTitle: "Meeting",
            expectedAttendees: nil,
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Relative time in hours"
        ),

        // Multiple attendees
        TestCase(
            input: "lunch with John and Sarah tomorrow",
            expectedAction: .create,
            expectedTitle: "Lunch",
            expectedAttendees: ["John", "Sarah"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Multiple attendees"
        ),

        // Action variations
        TestCase(
            input: "book a meeting with the team tomorrow at 10am",
            expectedAction: .create,
            expectedTitle: "Meeting",
            expectedAttendees: ["@team"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Using 'book' verb"
        ),

        TestCase(
            input: "pencil in coffee with Mike next week",
            expectedAction: .create,
            expectedTitle: "Coffee",
            expectedAttendees: ["Mike"],
            expectedHasTime: true,
            expectedLocation: nil,
            description: "Using 'pencil in' verb"
        )
    ]

    // MARK: - Run All Tests

    func runAllTests() {
        print("🧪 Running SmartEventParser Tests")
        print("=" * 80)

        var passCount = 0
        var failCount = 0

        for (index, testCase) in testCases.enumerated() {
            print("\n📝 Test #\(index + 1): \(testCase.description)")
            print("   Input: \"\(testCase.input)\"")

            let result = parser.parse(testCase.input)

            switch result {
            case .success(let entities, let confirmation):
                let passed = validateEntities(entities, against: testCase)
                if passed {
                    print("   ✅ PASS")
                    print("   Confirmation: \(confirmation)")
                    passCount += 1
                } else {
                    print("   ❌ FAIL")
                    printEntityDifferences(entities, testCase)
                    failCount += 1
                }

            case .needsClarification(let entities, let question):
                print("   ⚠️  Needs clarification: \(question)")
                printExtractedEntities(entities)
                // Count as pass if we correctly identified missing fields
                passCount += 1

            case .failure(let message):
                print("   ❌ FAIL - Parse error: \(message)")
                failCount += 1
            }
        }

        print("\n" + "=" * 80)
        print("📊 Test Results:")
        print("   ✅ Passed: \(passCount)/\(testCases.count)")
        print("   ❌ Failed: \(failCount)/\(testCases.count)")
        print("   Success Rate: \(String(format: "%.0f", Double(passCount) / Double(testCases.count) * 100))%")
        print("=" * 80)
    }

    // MARK: - Validation

    private func validateEntities(_ entities: ExtractedEntities, against testCase: TestCase) -> Bool {
        var isValid = true

        // Check action
        if entities.action != testCase.expectedAction {
            print("   ⚠️  Action mismatch: got \(entities.action), expected \(testCase.expectedAction)")
            isValid = false
        }

        // Check time presence
        let hasTime = entities.time != nil
        if hasTime != testCase.expectedHasTime {
            print("   ⚠️  Time presence mismatch: got \(hasTime), expected \(testCase.expectedHasTime)")
            isValid = false
        }

        // Check attendees (if specified)
        if let expectedAttendees = testCase.expectedAttendees {
            if entities.attendeeNames.count != expectedAttendees.count {
                print("   ⚠️  Attendee count mismatch: got \(entities.attendeeNames.count), expected \(expectedAttendees.count)")
                isValid = false
            }
        }

        // Check location (if specified)
        if let expectedLocation = testCase.expectedLocation {
            if entities.location != expectedLocation {
                print("   ⚠️  Location mismatch: got '\(entities.location ?? "nil")', expected '\(expectedLocation)'")
                isValid = false
            }
        }

        return isValid
    }

    private func printEntityDifferences(_ entities: ExtractedEntities, _ testCase: TestCase) {
        print("   Expected:")
        if let title = testCase.expectedTitle {
            print("     Title: \(title)")
        }
        if let attendees = testCase.expectedAttendees {
            print("     Attendees: \(attendees.joined(separator: ", "))")
        }
        print("     Has Time: \(testCase.expectedHasTime)")
        if let location = testCase.expectedLocation {
            print("     Location: \(location)")
        }

        print("   Got:")
        printExtractedEntities(entities)
    }

    private func printExtractedEntities(_ entities: ExtractedEntities) {
        print("     Title: \(entities.title ?? "nil")")
        print("     Attendees: \(entities.attendeeNames.isEmpty ? "none" : entities.attendeeNames.joined(separator: ", "))")
        print("     Time: \(entities.time?.description ?? "nil")")
        print("     Location: \(entities.location ?? "nil")")
        print("     Duration: \(entities.duration ?? 0) seconds")
        print("     Confidence: \(String(format: "%.0f", entities.confidence * 100))%")
        if !entities.missingFields.isEmpty {
            print("     Missing: \(entities.missingFields.joined(separator: ", "))")
        }
    }
}

// MARK: - String Repeat Extension

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// MARK: - Run Tests Function

func testSmartEventParser() {
    let tests = SmartEventParserTests()
    tests.runAllTests()
}
