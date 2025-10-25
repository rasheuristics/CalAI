import Foundation
import NaturalLanguage
import SwiftAnthropic
import Contacts
import EventKit

// MARK: - Event Category Classification

enum ParsedEventCategory: String, CaseIterable {
    case meeting = "Meeting"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case coffee = "Coffee"
    case workout = "Workout"
    case interview = "Interview"
    case presentation = "Presentation"
    case conference = "Conference"
    case flight = "Flight"
    case appointment = "Appointment"
    case social = "Social"
    case personal = "Personal"
    case other = "Other"

    var defaultDuration: TimeInterval {
        switch self {
        case .meeting: return 3600 // 1 hour
        case .lunch: return 3600 // 1 hour
        case .dinner: return 5400 // 1.5 hours
        case .coffee: return 1800 // 30 minutes
        case .workout: return 3600 // 1 hour
        case .interview: return 3600 // 1 hour
        case .presentation: return 3600 // 1 hour
        case .conference: return 28800 // 8 hours
        case .flight: return 7200 // 2 hours
        case .appointment: return 1800 // 30 minutes
        case .social: return 7200 // 2 hours
        case .personal: return 3600 // 1 hour
        case .other: return 3600 // 1 hour
        }
    }

    var suggestedLocations: [String] {
        switch self {
        case .lunch, .dinner: return ["Restaurant", "Cafe", "Food Court"]
        case .coffee: return ["Coffee Shop", "Cafe", "Starbucks"]
        case .workout: return ["Gym", "Fitness Center", "Park"]
        case .interview: return ["Office", "Video Call"]
        case .meeting: return ["Conference Room", "Office", "Zoom"]
        case .flight: return ["Airport"]
        default: return []
        }
    }

    static func classify(from title: String) -> ParsedEventCategory {
        let lowercased = title.lowercased()

        for eventType in ParsedEventCategory.allCases {
            if lowercased.contains(eventType.rawValue.lowercased()) {
                return eventType
            }
        }

        // Check for keywords
        if lowercased.contains("lunch") { return .lunch }
        if lowercased.contains("dinner") { return .dinner }
        if lowercased.contains("coffee") { return .coffee }
        if lowercased.contains("workout") || lowercased.contains("gym") { return .workout }
        if lowercased.contains("interview") { return .interview }
        if lowercased.contains("present") { return .presentation }
        if lowercased.contains("conference") { return .conference }
        if lowercased.contains("flight") { return .flight }

        return .other
    }
}

// MARK: - Location History

struct LocationHistory: Codable {
    var locations: [String: Int] // location -> frequency
    var lastUsed: [String: Date] // location -> last used date

    static let userDefaultsKey = "LocationHistory"

    static func load() -> LocationHistory {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let history = try? JSONDecoder().decode(LocationHistory.self, from: data) else {
            return LocationHistory(locations: [:], lastUsed: [:])
        }
        return history
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    mutating func recordLocation(_ location: String) {
        locations[location, default: 0] += 1
        lastUsed[location] = Date()
        save()
    }

    func suggestLocations(limit: Int = 5) -> [String] {
        // Sort by frequency and recency
        let sorted = locations.sorted { lhs, rhs in
            let freqScore1 = Double(lhs.value)
            let freqScore2 = Double(rhs.value)

            let recencyScore1 = lastUsed[lhs.key]?.timeIntervalSinceNow ?? -86400 * 365
            let recencyScore2 = lastUsed[rhs.key]?.timeIntervalSinceNow ?? -86400 * 365

            let score1 = freqScore1 * 0.7 + (recencyScore1 / 86400) * 0.3
            let score2 = freqScore2 * 0.7 + (recencyScore2 / 86400) * 0.3

            return score1 > score2
        }

        return Array(sorted.prefix(limit).map { $0.key })
    }
}

// MARK: - LLM Service Abstraction (Protocol and Generic Types)

/// A generic request structure to pass to any LLM service.
struct LLMRequest {
    let model: String
    let prompt: String
    let maxTokens: Int
}

/// A generic response structure received from any LLM service.
struct LLMResponse {
    let content: String
}

/// A protocol that defines the common interface for any LLM service we want to use.
protocol LLMService {
    func createMessage(request: LLMRequest) async throws -> LLMResponse
}

// MARK: - OpenAI Service Implementation

/// A service class to interact with the OpenAI API.
class OpenAIService: LLMService {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession.shared
    }

    func createMessage(request: LLMRequest) async throws -> LLMResponse {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody = OpenAIRequestBody(model: request.model, messages: [.init(role: "user", content: request.prompt)], max_tokens: request.maxTokens)
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorData = String(data: data, encoding: .utf8) ?? "No error data"
            throw NSError(domain: "OpenAIService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "OpenAI API request failed: \(errorData)"])
        }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices.first?.message.content else {
            throw NSError(domain: "OpenAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response structure from OpenAI API."])
        }
        return LLMResponse(content: content)
    }
}

private struct OpenAIRequestBody: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let max_tokens: Int
}
private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}
private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}
private struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

// MARK: - Anthropic Service Implementation

/// A wrapper class to make the external AnthropicService conform to our internal LLMService protocol.
class AnthropicServiceWrapper: LLMService {
    private let anthropicService: AnthropicService

    init(apiKey: String) {
        self.anthropicService = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)
    }

    func createMessage(request: LLMRequest) async throws -> LLMResponse {
        let message = MessageParameter.Message(role: .user, content: .text(request.prompt))
        let parameters = MessageParameter(model: .claude35Sonnet, messages: [message], maxTokens: request.maxTokens)
        let response = try await anthropicService.createMessage(parameters)
        guard let content = response.content.first, case .text(let text) = content else {
            throw NSError(domain: "AnthropicServiceWrapper", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Anthropic API."])
        }
        return LLMResponse(content: text)
    }
}


// MARK: - Main Natural Language Parser

/// Parses natural language input into structured event data.
class NaturalLanguageParser {
    private let llmService: LLMService
    private let calendar = Calendar.current
    private var locationHistory = LocationHistory.load()
    private let contactStore = CNContactStore()

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    convenience init() {
        let selectedProvider = Config.aiProvider
        let service: LLMService
        switch selectedProvider {
        case .openai:
            print("🤖 Using OpenAI Service")
            service = OpenAIService(apiKey: Config.openaiAPIKey)
        case .anthropic:
            print("🤖 Using Anthropic Service")
            service = AnthropicServiceWrapper(apiKey: Config.anthropicAPIKey)
        case .onDevice:
            print("🤖 On-Device AI not supported in NaturalLanguageParser, falling back to OpenAI")
            service = OpenAIService(apiKey: Config.openaiAPIKey)
        }
        self.init(llmService: service)
    }

    // ... (rest of the NaturalLanguageParser class as it was)
    func parseEvent(from text: String, referenceDate: Date = Date()) async throws -> ParsedEvent {
        if let localEvent = parseLocally(from: text, referenceDate: referenceDate) {
            print("✅ Parsed event locally.")
            return localEvent
        }

        print("ℹ️ Local parsing insufficient. Falling back to remote LLM (\(Config.aiProvider.displayName)).")
        let prompt = buildParsePrompt(text: text, referenceDate: referenceDate)
        
        let model: String
        switch Config.aiProvider {
        case .openai:
            model = "gpt-4o"
        case .anthropic:
            model = "claude-3-5-sonnet-20240620"
        case .onDevice:
            model = "gpt-4o"  // Fallback to OpenAI
        }

        let request = LLMRequest(model: model, prompt: prompt, maxTokens: 500)
        let response = try await llmService.createMessage(request: request)
        return try parseResponse(response, referenceDate: referenceDate)
    }

    func parseMultipleEvents(from text: String, referenceDate: Date = Date()) async throws -> [ParsedEvent] {
        print("ℹ️ Parsing multiple events using remote LLM (\(Config.aiProvider.displayName)).")
        let prompt = buildMultiEventParsePrompt(text: text, referenceDate: referenceDate)

        let model: String
        switch Config.aiProvider {
        case .openai:
            model = "gpt-4o"
        case .anthropic:
            model = "claude-3-5-sonnet-20240620"
        case .onDevice:
            model = "gpt-4o"  // Fallback to OpenAI
        }

        let request = LLMRequest(model: model, prompt: prompt, maxTokens: 800)
        let response = try await llmService.createMessage(request: request)
        return try parseMultipleResponse(response, referenceDate: referenceDate)
    }

    /// Generates freeform text from a prompt using the configured LLM service.
    public func generateText(prompt: String, maxTokens: Int = 500) async throws -> String {
        let model: String
        switch Config.aiProvider {
        case .openai:
            model = Config.openAIModel
        case .anthropic:
            model = Config.anthropicModel
        case .onDevice:
            model = Config.openAIModel  // Fallback to OpenAI
        }
        
        let request = LLMRequest(model: model, prompt: prompt, maxTokens: maxTokens)
        let response = try await llmService.createMessage(request: request)
        return response.content
    }
    
    private func parseLocally(from text: String, referenceDate: Date) -> ParsedEvent? {
        let lowercasedText = text.lowercased()
        let triggerWords = ["schedule", "create", "add", "book", "make an event"]
        
        // Only proceed if the text contains a clear intent to create an event
        guard triggerWords.contains(where: lowercasedText.contains) else {
            print("ℹ️ Local parser skipping query: no creation trigger words found.")
            return nil
        }

        let tagger = NLTagger(tagSchemes: [.nameType, .lemma])
        tagger.string = text
        var attendees: [String] = []
        var location: String?
        var date: Date?
        var titleCandidateRange: Range<String.Index>?
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            if let firstMatch = matches.first(where: { $0.resultType == .date }) {
                date = firstMatch.date
                let dateRange = Range(firstMatch.range, in: text)!
                titleCandidateRange = text.startIndex..<dateRange.lowerBound
            }
        } catch {
            print("❌ Local parse error: NSDataDetector failed: \(error)")
            return nil
        }
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            guard let tag = tag else { return true }
            let tokenText = String(text[tokenRange])
            switch tag {
            case .personalName: attendees.append(tokenText)
            case .placeName, .organizationName: location = tokenText
            default: break
            }
            return true
        }
        var titleComponents: [String] = []
        if let range = titleCandidateRange {
            let potentialTitle = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !potentialTitle.isEmpty {
                let titleWords = potentialTitle.split(separator: " ").map { String($0) }
                let cleanTitle = titleWords.filter { !["with", "at", "and"].contains($0.lowercased()) }.joined(separator: " ")
                titleComponents.append(cleanTitle)
            }
        }
        let finalTitle = titleComponents.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !finalTitle.isEmpty, let foundDate = date else {
            print("❌ Local parse failed: Could not determine a title or date.")
            return nil
        }
        return ParsedEvent(title: finalTitle.capitalized, startDate: foundDate, duration: 60 * 60, location: location, attendees: attendees, isAllDay: false, recurrence: .none)
    }

    private func buildParsePrompt(text: String, referenceDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return """
        Parse this natural language event into structured JSON:
        "\(text)"

        Reference date/time: \(formatter.string(from: referenceDate))

        Extract:
        - title: Event name
        - startTime: ISO8601 datetime
        - duration: Minutes (default 60 if not specified)
        - location: Location if mentioned
        - attendees: Array of people if mentioned
        - isAllDay: Boolean
        - recurrence: "none", "daily", "weekly", "monthly" if mentioned

        Return ONLY valid JSON:
        {
          "title": "string",
          "startTime": "ISO8601",
          "duration": number,
          "location": "string or null",
          "attendees": ["array or empty"],
          "isAllDay": boolean,
          "recurrence": "string"
        }
        """
    }

    private func buildMultiEventParsePrompt(text: String, referenceDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return """
        Parse ALL events from this text into structured JSON array:
        "\(text)"

        Reference date/time: \(formatter.string(from: referenceDate))

        Return ONLY a JSON array of events:
        [
          {
            "title": "string",
            "startTime": "ISO8601",
            "duration": number,
            "location": "string or null",
            "attendees": ["array"],
            "isAllDay": boolean,
            "recurrence": "none|daily|weekly|monthly"
          }
        ]
        """
    }

    private func parseResponse(_ response: LLMResponse, referenceDate: Date) throws -> ParsedEvent {
        guard let jsonData = extractJSON(from: response.content)?.data(using: .utf8) else {
            throw ParserError.noJSONFound
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(ParsedEventDTO.self, from: jsonData)
        return ParsedEvent(title: parsed.title, startDate: parsed.startTime, duration: TimeInterval(parsed.duration * 60), location: parsed.location, attendees: parsed.attendees, isAllDay: parsed.isAllDay, recurrence: RecurrencePattern(rawValue: parsed.recurrence) ?? .none)
    }

    private func parseMultipleResponse(_ response: LLMResponse, referenceDate: Date) throws -> [ParsedEvent] {
        guard let jsonData = extractJSON(from: response.content)?.data(using: .utf8) else {
            throw ParserError.noJSONFound
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsedArray = try decoder.decode([ParsedEventDTO].self, from: jsonData)
        return parsedArray.map { dto in
            ParsedEvent(title: dto.title, startDate: dto.startTime, duration: TimeInterval(dto.duration * 60), location: dto.location, attendees: dto.attendees, isAllDay: dto.isAllDay, recurrence: RecurrencePattern(rawValue: dto.recurrence) ?? .none)
        }
    }

    private func extractJSON(from text: String) -> String? {
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        } else if let start = text.range(of: "["), let end = text.range(of: "]", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return nil
    }

    // MARK: - Location Suggestions

    /// Get location suggestions based on history and event type
    func getLocationSuggestions(for eventCategory: ParsedEventCategory? = nil, limit: Int = 5) -> [String] {
        var suggestions: [String] = []

        // Add type-specific suggestions first
        if let eventCategory = eventCategory {
            suggestions.append(contentsOf: eventCategory.suggestedLocations)
        }

        // Add historical locations
        let historicalSuggestions = locationHistory.suggestLocations(limit: limit)
        suggestions.append(contentsOf: historicalSuggestions)

        // Remove duplicates while preserving order
        var seen = Set<String>()
        suggestions = suggestions.filter { seen.insert($0).inserted }

        return Array(suggestions.prefix(limit))
    }

    /// Record a location for future suggestions
    func recordLocationUsage(_ location: String) {
        guard !location.isEmpty else { return }
        locationHistory.recordLocation(location)
    }

    // MARK: - Contact Search

    /// Search contacts by name
    func searchContacts(query: String, limit: Int = 10) async -> [ContactSuggestion] {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        guard status == .authorized else {
            print("⚠️ Contacts access not authorized")
            return []
        }

        let predicate = CNContact.predicateForContacts(matchingName: query)
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        do {
            let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)

            return contacts.prefix(limit).map { contact in
                let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                let email = contact.emailAddresses.first?.value as String?
                let phone = contact.phoneNumbers.first?.value.stringValue

                return ContactSuggestion(
                    name: fullName,
                    email: email,
                    phone: phone
                )
            }
        } catch {
            print("❌ Contact search error: \(error)")
            return []
        }
    }

    /// Request contacts permission
    func requestContactsPermission() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            do {
                return try await contactStore.requestAccess(for: .contacts)
            } catch {
                print("❌ Contacts permission error: \(error)")
                return false
            }
        default:
            return false
        }
    }

    // MARK: - Duration Prediction

    /// Predict duration for an event based on its title
    func predictDuration(for title: String) -> TimeInterval {
        let eventCategory = ParsedEventCategory.classify(from: title)
        return eventCategory.defaultDuration
    }

    /// Get suggested duration options for an event type
    func getDurationOptions(for title: String) -> [TimeInterval] {
        let eventCategory = ParsedEventCategory.classify(from: title)
        let defaultDuration = eventCategory.defaultDuration

        // Provide common duration options around the default
        let options: [TimeInterval]
        switch eventCategory {
        case .coffee:
            options = [900, 1800, 2700] // 15, 30, 45 minutes
        case .meeting, .appointment:
            options = [1800, 3600, 5400, 7200] // 30m, 1h, 1.5h, 2h
        case .lunch, .dinner:
            options = [3600, 5400, 7200] // 1h, 1.5h, 2h
        case .workout:
            options = [2700, 3600, 5400] // 45m, 1h, 1.5h
        default:
            options = [1800, 3600, 7200] // 30m, 1h, 2h
        }

        return options
    }
}

// MARK: - Supporting Types

struct ParsedEvent {
    let title: String
    let startDate: Date
    let duration: TimeInterval
    let location: String?
    let attendees: [String]
    let isAllDay: Bool
    let recurrence: RecurrencePattern

    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }
}

private struct ParsedEventDTO: Codable {
    let title: String
    let startTime: Date
    let duration: Int // minutes
    let location: String?
    let attendees: [String]
    let isAllDay: Bool
    let recurrence: String
}

enum RecurrencePattern: String, Codable, Equatable {
    case none
    case daily
    case weekly
    case monthly
    case yearly
}

enum ParserError: Error, LocalizedError {
    case invalidResponse
    case noJSONFound
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "AI returned an invalid response"
        case .noJSONFound: return "Could not find valid JSON in response"
        case .parsingFailed: return "Failed to parse event data"
        }
    }
}

struct ContactSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let email: String?
    let phone: String?

    var displayName: String {
        if let email = email {
            return "\(name) (\(email))"
        } else if let phone = phone {
            return "\(name) (\(phone))"
        } else {
            return name
        }
    }
}

// MARK: - Quick Event Templates

extension NaturalLanguageParser {
    static var quickTemplates: [EventTemplate] {
        [
            EventTemplate(id: "meeting-30", title: "Meeting", duration: 30 * 60, icon: "person.2.fill"),
            EventTemplate(id: "meeting-60", title: "1 Hour Meeting", duration: 60 * 60, icon: "person.3.fill"),
            EventTemplate(id: "lunch", title: "Lunch", duration: 60 * 60, icon: "fork.knife"),
            EventTemplate(id: "coffee", title: "Coffee Break", duration: 15 * 60, icon: "cup.and.saucer.fill"),
            EventTemplate(id: "focus", title: "Focus Time", duration: 90 * 60, icon: "brain.head.profile"),
            EventTemplate(id: "workout", title: "Workout", duration: 45 * 60, icon: "figure.run")
        ]
    }
}

struct EventTemplate: Identifiable {
    let id: String
    let title: String
    let duration: TimeInterval
    let icon: String
}