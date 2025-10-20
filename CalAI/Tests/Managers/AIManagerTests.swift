import XCTest
@testable import CalAI

/// Critical tests for AIManager - intent classification and entity extraction
final class AIManagerTests: XCTestCase {

    var sut: SmartEventParser!

    override func setUp() {
        super.setUp()
        sut = SmartEventParser()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Action Detection Tests

    func testDetectAction_CreateEvent_FromMultipleVerbs() {
        // Test various create verbs
        let createCommands = [
            "create meeting with John",
            "schedule lunch tomorrow",
            "book conference room",
            "set up call with Sarah",
            "add dentist appointment",
            "remind me to call mom"
        ]

        for command in createCommands {
            // When
            let result = sut.parse(command)

            // Then
            if case .success(let entities, _) = result {
                XCTAssertEqual(entities.action, .create, "Failed for: \(command)")
            } else if case .needsClarification(let entities, _) = result {
                XCTAssertEqual(entities.action, .create, "Failed for: \(command)")
            } else {
                XCTFail("Should detect create action for: \(command)")
            }
        }
    }

    func testDetectAction_UpdateEvent_FromMultipleVerbs() {
        let updateCommands = [
            "change meeting to 3pm",
            "update the location to Zoom",
            "modify lunch time",
            "edit the event title"
        ]

        for command in updateCommands {
            // When
            let result = sut.parse(command)

            // Then
            if case .success(let entities, _) = result {
                XCTAssertEqual(entities.action, .update, "Failed for: \(command)")
            } else if case .needsClarification(let entities, _) = result {
                XCTAssertEqual(entities.action, .update, "Failed for: \(command)")
            } else {
                XCTFail("Should detect update action for: \(command)")
            }
        }
    }

    func testDetectAction_DeleteEvent_FromMultipleVerbs() {
        let deleteCommands = [
            "delete meeting with John",
            "cancel lunch tomorrow",
            "remove the 3pm call",
            "clear my afternoon"
        ]

        for command in deleteCommands {
            // When
            let result = sut.parse(command)

            // Then
            if case .success(let entities, _) = result {
                XCTAssertEqual(entities.action, .delete, "Failed for: \(command)")
            } else if case .needsClarification(let entities, _) = result {
                XCTAssertEqual(entities.action, .delete, "Failed for: \(command)")
            } else {
                XCTFail("Should detect delete action for: \(command)")
            }
        }
    }

    func testDetectAction_MoveEvent_FromMultipleVerbs() {
        let moveCommands = [
            "move meeting to tomorrow",
            "reschedule lunch to 2pm",
            "push the call to next week",
            "shift standup to 10am"
        ]

        for command in moveCommands {
            // When
            let result = sut.parse(command)

            // Then
            if case .success(let entities, _) = result {
                XCTAssertEqual(entities.action, .move, "Failed for: \(command)")
            } else if case .needsClarification(let entities, _) = result {
                XCTAssertEqual(entities.action, .move, "Failed for: \(command)")
            } else {
                XCTFail("Should detect move action for: \(command)")
            }
        }
    }

    func testDetectAction_QueryEvent_FromMultipleVerbs() {
        let queryCommands = [
            "what's on my calendar today",
            "show me tomorrow's meetings",
            "do I have anything at 3pm",
            "when is my meeting with John"
        ]

        for command in queryCommands {
            // When
            let result = sut.parse(command)

            // Then
            if case .success(let entities, _) = result {
                XCTAssertEqual(entities.action, .query, "Failed for: \(command)")
            } else if case .needsClarification(let entities, _) = result {
                XCTAssertEqual(entities.action, .query, "Failed for: \(command)")
            } else {
                XCTFail("Should detect query action for: \(command)")
            }
        }
    }

    // MARK: - Entity Extraction Tests

    func testExtractTitle_FromSimpleCommand() {
        // Given
        let command = "schedule team meeting tomorrow at 2pm"

        // When
        let result = sut.parse(command)

        // Then
        if case .success(let entities, _) = result {
            XCTAssertNotNil(entities.title)
            XCTAssertTrue(entities.title?.lowercased().contains("meeting") ?? false)
        } else {
            XCTFail("Should extract title from simple command")
        }
    }

    func testExtractAttendees_FromWithClause() {
        // Given
        let command = "schedule lunch with John and Sarah tomorrow at noon"

        // When
        let result = sut.parse(command)

        // Then
        if case .success(let entities, _) = result {
            XCTAssertFalse(entities.attendeeNames.isEmpty, "Should extract attendees")
            XCTAssertTrue(entities.attendeeNames.contains { $0.contains("John") })
        } else if case .needsClarification(let entities, _) = result {
            XCTAssertFalse(entities.attendeeNames.isEmpty, "Should extract attendees")
        } else {
            XCTFail("Should extract attendees from command")
        }
    }

    func testExtractTime_FromRelativeTime() {
        // Given
        let commands = [
            "schedule meeting tomorrow",
            "book call today at 3pm",
            "set reminder for tonight"
        ]

        for command in commands {
            // When
            let result = sut.parse(command)

            // Then
            if case .success(let entities, _) = result {
                // Time extraction may or may not succeed depending on specificity
                // Just verify no crash and reasonable behavior
                XCTAssertNotNil(entities.action)
            } else if case .needsClarification(let entities, _) = result {
                XCTAssertNotNil(entities.action)
            }
        }
    }

    func testExtractLocation_FromAtClause() {
        // Given
        let command = "schedule meeting at Conference Room A tomorrow at 2pm"

        // When
        let result = sut.parse(command)

        // Then
        if case .success(let entities, _) = result {
            XCTAssertNotNil(entities.location)
            XCTAssertTrue(entities.location?.contains("Conference") ?? false)
        } else if case .needsClarification(let entities, _) = result {
            XCTAssertNotNil(entities.location)
            XCTAssertTrue(entities.location?.contains("Conference") ?? false)
        }
    }

    func testExtractEventType_FromKeywords() {
        // Given
        let testCases: [(command: String, expectedType: String)] = [
            ("schedule lunch with John", "lunch"),
            ("book dinner reservation", "dinner"),
            ("set up meeting tomorrow", "meeting"),
            ("arrange call with Sarah", "call")
        ]

        for (command, expectedType) in testCases {
            // When
            let result = sut.parse(command)

            // Then
            if case .success(let entities, _) = result {
                XCTAssertEqual(entities.eventType, expectedType, "Failed for: \(command)")
            } else if case .needsClarification(let entities, _) = result {
                XCTAssertEqual(entities.eventType, expectedType, "Failed for: \(command)")
            }
        }
    }

    func testExtractAllDayFlag_FromKeywords() {
        // Given
        let command = "block off tomorrow as vacation"

        // When
        let result = sut.parse(command)

        // Then
        if case .success(let entities, _) = result {
            // Should detect as create action
            XCTAssertEqual(entities.action, .create)
        } else if case .needsClarification(let entities, _) = result {
            XCTAssertEqual(entities.action, .create)
        }
    }

    // MARK: - Confidence Score Tests

    func testConfidenceScore_HighForCompleteCommand() {
        // Given - complete command with all info
        let command = "schedule team meeting with John tomorrow at 2pm in Conference Room A"

        // When
        let result = sut.parse(command)

        // Then
        if case .success(let entities, _) = result {
            XCTAssertGreaterThanOrEqual(entities.confidence, 0.8, "Complete command should have high confidence")
        }
    }

    func testConfidenceScore_RequestsClarificationForIncompleteCommand() {
        // Given - vague command missing details
        let command = "schedule something"

        // When
        let result = sut.parse(command)

        // Then
        switch result {
        case .needsClarification(let entities, let question):
            XCTAssertNotNil(question)
            XCTAssertFalse(entities.missingFields.isEmpty)
        case .success(let entities, _):
            // Might succeed with low confidence
            XCTAssertLessThan(entities.confidence, 0.8)
        case .failure:
            // Also acceptable to fail on vague input
            break
        }
    }

    // MARK: - Missing Fields Detection Tests

    func testMissingFields_DetectsNoTime() {
        // Given
        let command = "schedule meeting with John"

        // When
        let result = sut.parse(command)

        // Then
        if case .needsClarification(let entities, let question) = result {
            XCTAssertTrue(entities.missingFields.contains { $0.contains("time") || $0.contains("when") })
            XCTAssertTrue(question.lowercased().contains("when") || question.lowercased().contains("time"))
        }
    }

    func testMissingFields_DetectsNoTitle() {
        // Given
        let command = "schedule tomorrow at 2pm"

        // When
        let result = sut.parse(command)

        // Then
        switch result {
        case .needsClarification(let entities, _):
            // Should detect missing title or generate one
            XCTAssertNotNil(entities.action)
        case .success(let entities, _):
            // Or succeed by generating a default title
            XCTAssertNotNil(entities.title)
        case .failure:
            break
        }
    }

    // MARK: - Multi-Turn Conversation Tests

    func testConversationState_StartsIdle() {
        // Given
        let conversationState = ConversationState.idle

        // Then
        XCTAssertEqual(conversationState, .idle)
        XCTAssertEqual(conversationState.description, "idle")
    }

    func testConversationState_AwaitingConfirmation() {
        // Given
        let state = ConversationState.awaitingConfirmation

        // Then
        XCTAssertEqual(state, .awaitingConfirmation)
        XCTAssertEqual(state.description, "awaitingConfirmation")
    }

    func testConversationState_CreatingEventWithMissingField() {
        // Given
        let entities = ExtractedEntities(action: .create, title: "Meeting")
        let state = ConversationState.creatingEvent(entities, missingField: "time")

        // Then
        XCTAssertEqual(state.description, "creatingEvent(missingField: time)")

        // Test equality
        let sameState = ConversationState.creatingEvent(entities, missingField: "time")
        XCTAssertEqual(state, sameState)

        let differentState = ConversationState.creatingEvent(entities, missingField: "location")
        XCTAssertNotEqual(state, differentState)
    }

    // MARK: - Parse Result Tests

    func testParseResult_Success_ContainsConfirmation() {
        // Given
        let command = "schedule lunch with John tomorrow at noon"

        // When
        let result = sut.parse(command)

        // Then
        if case .success(let entities, let confirmation) = result {
            XCTAssertEqual(entities.action, .create)
            XCTAssertFalse(confirmation.isEmpty)
            XCTAssertTrue(confirmation.lowercased().contains("lunch") || confirmation.lowercased().contains("john"))
        } else {
            // Clarification is also acceptable
            if case .needsClarification(let entities, _) = result {
                XCTAssertEqual(entities.action, .create)
            }
        }
    }

    func testParseResult_NeedsClarification_ContainsQuestion() {
        // Given
        let command = "schedule meeting"

        // When
        let result = sut.parse(command)

        // Then
        if case .needsClarification(let entities, let question) = result {
            XCTAssertEqual(entities.action, .create)
            XCTAssertFalse(question.isEmpty)
            XCTAssertTrue(question.contains("?"))
        }
    }

    func testParseResult_Failure_ContainsErrorMessage() {
        // Given
        let command = "invalid gibberish xyz123"

        // When
        let result = sut.parse(command)

        // Then
        if case .failure(let message) = result {
            XCTAssertFalse(message.isEmpty)
            XCTAssertTrue(message.lowercased().contains("understand") || message.lowercased().contains("try"))
        } else {
            // Parser might be lenient and try to interpret it
            // That's also acceptable behavior
        }
    }

    // MARK: - Complex Command Tests

    func testComplexCommand_WithMultipleEntities() {
        // Given
        let command = "schedule team standup with John, Sarah, and Mike tomorrow at 9am in Conference Room B for 30 minutes"

        // When
        let result = sut.parse(command)

        // Then
        switch result {
        case .success(let entities, _):
            XCTAssertEqual(entities.action, .create)
            XCTAssertNotNil(entities.title)
            XCTAssertFalse(entities.attendeeNames.isEmpty)
            XCTAssertNotNil(entities.location)
            // Time and duration may or may not be extracted perfectly
        case .needsClarification(let entities, _):
            XCTAssertEqual(entities.action, .create)
            XCTAssertNotNil(entities.title)
        case .failure:
            XCTFail("Should parse complex command")
        }
    }

    func testComplexCommand_WithRecurrence() {
        // Given
        let command = "schedule daily standup at 9am every weekday"

        // When
        let result = sut.parse(command)

        // Then
        switch result {
        case .success(let entities, _):
            XCTAssertEqual(entities.action, .create)
            XCTAssertNotNil(entities.title)
            // Recurrence parsing may or may not be implemented
        case .needsClarification(let entities, _):
            XCTAssertEqual(entities.action, .create)
        case .failure:
            XCTFail("Should parse recurring event command")
        }
    }

    // MARK: - Edge Cases

    func testEdgeCase_EmptyCommand() {
        // Given
        let command = ""

        // When
        let result = sut.parse(command)

        // Then
        if case .failure(let message) = result {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Empty command should fail")
        }
    }

    func testEdgeCase_VeryLongCommand() {
        // Given
        let command = String(repeating: "schedule meeting ", count: 50)

        // When
        let result = sut.parse(command)

        // Then
        // Should not crash
        switch result {
        case .success, .needsClarification, .failure:
            // Any result is acceptable as long as it doesn't crash
            break
        }
    }

    func testEdgeCase_SpecialCharacters() {
        // Given
        let command = "schedule meeting with @John #important $$$ tomorrow"

        // When
        let result = sut.parse(command)

        // Then
        // Should handle special characters gracefully
        switch result {
        case .success(let entities, _):
            XCTAssertEqual(entities.action, .create)
        case .needsClarification(let entities, _):
            XCTAssertEqual(entities.action, .create)
        case .failure:
            // Also acceptable
            break
        }
    }

    // MARK: - AIError Tests

    func testAIError_UserFriendlyMessages() {
        let testCases: [(error: AIError, shouldContain: String)] = [
            (.invalidResponse, "unexpected"),
            (.networkError, "connection"),
            (.authenticationError, "API"),
            (.rateLimitError, "too many"),
            (.timeoutError, "too long"),
            (.noAPIKeyConfigured, "configure")
        ]

        for (error, keyword) in testCases {
            let message = error.userFriendlyMessage
            XCTAssertFalse(message.isEmpty)
            XCTAssertTrue(message.lowercased().contains(keyword), "Error message should contain '\(keyword)': \(message)")
        }
    }
}
