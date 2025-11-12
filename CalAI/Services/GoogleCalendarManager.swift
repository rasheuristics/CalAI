import Foundation
import GoogleSignIn
import GoogleAPIClientForRESTCore
import GoogleAPIClientForREST_Calendar

struct GoogleEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let description: String?
    let calendarId: String
    let organizer: String?

    var duration: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

class GoogleCalendarManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var googleEvents: [GoogleEvent] = []
    @Published var availableCalendars: [GoogleCalendarItem] = []

    // Track events with pending API updates to prevent overwriting during fetch
    private var pendingUpdates: [String: GoogleEvent] = [:] // eventId -> updated event
    private let pendingUpdatesQueue = DispatchQueue(label: "com.calai.google.pendingUpdates")

    // Track deleted events to filter them out when fetching from server
    // Now persisted to UserDefaults for reliability across app restarts
    // Note: UserDefaults is already thread-safe, no dispatch queue needed
    private let deletedEventsKey = "com.calai.google.deletedEventIds"
    private var deletedEventIds: Set<String> {
        get {
            guard let array = UserDefaults.standard.array(forKey: deletedEventsKey) as? [String] else {
                return []
            }
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: deletedEventsKey)
            print("💾 Saved \(newValue.count) deleted Google event IDs to UserDefaults")
        }
    }

    // private let calendarService = GTLRCalendarService()

    init() {
        // setupService()
        restorePreviousSignIn()
    }

    // private func setupService() {
    //     calendarService.apiKey = nil // Will use OAuth token
    //     calendarService.shouldFetchNextPages = true
    // }

    private func restorePreviousSignIn() {
        print("🔄 Attempting to restore previous Google Sign-In...")

        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            print("✅ Found current user, refreshing token if needed...")
            currentUser.refreshTokensIfNeeded { [weak self] refreshedUser, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Token refresh failed: \(error.localizedDescription)")
                        self?.isSignedIn = false
                        return
                    }

                    if let user = refreshedUser {
                        self?.isSignedIn = true
                        print("✅ Google user restored with refreshed token: \(user.profile?.email ?? "")")
                        self?.checkCalendarAccess(for: user)
                    } else {
                        print("❌ No user after token refresh")
                        self?.isSignedIn = false
                    }
                }
            }
        } else {
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to restore Google Sign-In: \(error.localizedDescription)")
                        self?.isSignedIn = false
                        return
                    }

                    if let user = user {
                        self?.isSignedIn = true
                        print("✅ Google user restored: \(user.profile?.email ?? "")")
                        self?.checkCalendarAccess(for: user)
                    } else {
                        self?.isSignedIn = false
                        print("❌ No previous Google sign-in found")
                    }
                }
            }
        }
    }

    private func checkCalendarAccess(for user: GIDGoogleUser) {
        let requiredScopes = ["https://www.googleapis.com/auth/calendar"]
        let grantedScopes = user.grantedScopes ?? []

        let hasCalendarAccess = requiredScopes.allSatisfy { grantedScopes.contains($0) }

        if !hasCalendarAccess {
            print("⚠️ User doesn't have calendar access, requesting additional scopes...")
            requestAdditionalScopes(requiredScopes)
        } else {
            print("✅ User has calendar access")
            // Could fetch events here if needed
        }
    }

    private func requestAdditionalScopes(_ scopes: [String]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let presentingViewController = window.rootViewController else {
            print("❌ No presenting view controller for additional scopes")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, hint: nil, additionalScopes: scopes) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to add calendar scope: \(error.localizedDescription)")
                    return
                }

                if let user = result?.user {
                    print("✅ Additional scopes granted for: \(user.profile?.email ?? "")")
                    self?.isSignedIn = true
                    // Store tokens securely
                    self?.storeUserTokensSecurely(user: user)
                    // self?.calendarService.authorizer = user.authentication.fetcherAuthorizer()
                }
            }
        }
    }

    func signIn() {
        print("🔵 Starting Google Sign-In process...")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let presentingViewController = window.rootViewController else {
            print("❌ No presenting view controller found")
            return
        }

        print("✅ Found presenting view controller: \(presentingViewController)")

        isLoading = true

        let scopes = ["https://www.googleapis.com/auth/calendar"]
        print("🔵 Requesting scopes: \(scopes)")

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, hint: nil, additionalScopes: scopes) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    print("❌ Google Sign-In error: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    return
                }

                guard let user = result?.user else {
                    print("❌ No user returned from Google Sign-In")
                    return
                }

                self?.isSignedIn = true
                // Store tokens securely
                self?.storeUserTokensSecurely(user: user)
                // self?.calendarService.authorizer = user.authentication.fetcherAuthorizer()
                print("✅ Google Sign-In successful: \(user.profile?.email ?? "")")
            }
        }
    }

    func refreshTokenIfNeeded(completion: @escaping (Bool) -> Void) {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            print("❌ No user to refresh token for")
            completion(false)
            return
        }

        print("🔄 Refreshing Google access token...")

        user.refreshTokensIfNeeded { [weak self] user, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Token refresh failed: \(error.localizedDescription)")
                    // If token refresh fails, user may need to sign in again
                    self?.isSignedIn = false
                    completion(false)
                    return
                }

                if let refreshedUser = user {
                    print("✅ Token refreshed for: \(refreshedUser.profile?.email ?? "")")
                    // self?.calendarService.authorizer = refreshedUser.authentication.fetcherAuthorizer()
                    completion(true)
                } else {
                    print("❌ No user returned after token refresh")
                    completion(false)
                }
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        // calendarService.authorizer = nil
        googleEvents = [] // Clear events on sign out

        // Clear stored tokens
        clearStoredTokens()
        print("✅ Google Sign-Out successful")
    }

    // MARK: - Secure Storage Methods

    /// Store user tokens securely in Keychain
    private func storeUserTokensSecurely(user: GIDGoogleUser) {
        do {
            let accessToken = user.accessToken.tokenString
            let refreshToken = user.refreshToken.tokenString

            try SecureStorage.storeGoogleTokens(
                accessToken: accessToken,
                refreshToken: refreshToken
            )

            // Store user email for reference
            if let email = user.profile?.email {
                try SecureStorage.store(key: "google_user_email", value: email)
            }

            print("🔒 Google tokens stored securely")
        } catch {
            print("❌ Failed to store Google tokens securely: \(error.localizedDescription)")
        }
    }

    /// Retrieve stored tokens from Keychain
    private func getStoredTokens() -> (accessToken: String, refreshToken: String?)? {
        do {
            let tokens = try SecureStorage.getGoogleTokens()
            return tokens
        } catch SecureStorage.KeychainError.itemNotFound {
            print("📝 No stored Google tokens found")
            return nil
        } catch {
            print("❌ Failed to retrieve Google tokens: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clear stored tokens from Keychain
    private func clearStoredTokens() {
        do {
            try SecureStorage.delete(key: SecureStorage.Keys.googleAccessToken)
            try SecureStorage.delete(key: SecureStorage.Keys.googleRefreshToken)
            try SecureStorage.delete(key: "google_user_email")
            print("🧹 Cleared stored Google tokens")
        } catch {
            print("⚠️ Error clearing stored tokens: \(error.localizedDescription)")
        }
    }

    /// Check if we have valid stored tokens
    private func hasValidStoredTokens() -> Bool {
        return SecureStorage.exists(key: SecureStorage.Keys.googleAccessToken)
    }

    // Calendar API functions temporarily disabled until Google Calendar API packages are added
    // func fetchCalendars(completion: @escaping ([GTLRCalendar_CalendarListEntry]) -> Void) {
    //     print("⚠️ Calendar API not available - Google Calendar API packages need to be added")
    //     completion([])
    // }

    // func fetchEvents(from calendarId: String, completion: @escaping ([GTLRCalendar_Event]) -> Void) {
    //     print("⚠️ Calendar API not available - Google Calendar API packages need to be added")
    //     completion([])
    // }

    func fetchCalendars() {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            print("❌ No Google user signed in for calendar fetching")
            return
        }

        print("🔵 Fetching Google Calendars...")

        // Real Google Calendar API implementation
        let service = GTLRCalendarService()
        service.authorizer = user.fetcherAuthorizer

        let query = GTLRCalendarQuery_CalendarListList.query()

        service.executeQuery(query) { [weak self] (ticket, result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to fetch Google calendars: \(error.localizedDescription)")
                    return
                }

                guard let calendarList = result as? GTLRCalendar_CalendarList,
                      let items = calendarList.items else {
                    print("❌ No calendars found in response")
                    return
                }

                let calendars = items.compactMap { calendar -> GoogleCalendarItem? in
                    guard let id = calendar.identifier,
                          let summary = calendar.summary else { return nil }

                    return GoogleCalendarItem(
                        id: id,
                        name: summary,
                        backgroundColor: calendar.backgroundColor ?? "#4285F4",
                        isPrimary: calendar.primary?.boolValue ?? false
                    )
                }

                self?.availableCalendars = calendars
                print("✅ Fetched \(calendars.count) Google calendars")
            }
        }
    }

    func fetchEvents(from startDate: Date = Date(), to endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()) {
        guard GIDSignIn.sharedInstance.currentUser != nil else {
            print("❌ No Google user signed in for event fetching")
            return
        }

        print("🔵 Fetching Google Calendar events...")
        isLoading = true

        // Refresh token before making API calls
        refreshTokenIfNeeded { [weak self] success in
            guard success else {
                print("❌ Token refresh failed, cannot fetch events")
                self?.isLoading = false
                return
            }

            self?.performEventFetch(from: startDate, to: endDate)
        }
    }

    private func performEventFetch(from startDate: Date, to endDate: Date) {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            print("❌ No Google user after token refresh")
            isLoading = false
            return
        }

        print("🔵 Performing event fetch for \(user.profile?.email ?? "")...")

        // Simulate Google Calendar API call to fetch events
        // In real implementation: GET https://www.googleapis.com/calendar/v3/calendars/primary/events
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            let fetchedEvents = [
                GoogleEvent(
                    id: "google_event_1",
                    title: "Morning Workout",
                    startDate: Calendar.current.date(byAdding: .hour, value: 8, to: Calendar.current.startOfDay(for: Date())) ?? Date(),
                    endDate: Calendar.current.date(byAdding: .hour, value: 9, to: Calendar.current.startOfDay(for: Date())) ?? Date(),
                    location: "Gym",
                    description: "Daily fitness routine",
                    calendarId: "primary",
                    organizer: user.profile?.email
                ),
                GoogleEvent(
                    id: "google_event_2",
                    title: "Doctor Appointment",
                    startDate: Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.date(byAdding: .hour, value: 14, to: Calendar.current.startOfDay(for: Date())) ?? Date()) ?? Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.date(byAdding: .hour, value: 15, to: Calendar.current.startOfDay(for: Date())) ?? Date()) ?? Date(),
                    location: "Medical Center",
                    description: "Annual checkup",
                    calendarId: "primary",
                    organizer: user.profile?.email
                ),
                GoogleEvent(
                    id: "google_event_3",
                    title: "Weekend Trip",
                    startDate: Calendar.current.date(byAdding: .day, value: 5, to: Calendar.current.startOfDay(for: Date())) ?? Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) ?? Date(),
                    location: "Mountain Resort",
                    description: "Family vacation weekend",
                    calendarId: "primary",
                    organizer: user.profile?.email
                )
            ]

            // SMART MERGE: Preserve events with pending updates, use fetched data for others
            let mergedEvents: [GoogleEvent] = self?.pendingUpdatesQueue.sync {
                guard let pending = self?.pendingUpdates, !pending.isEmpty else {
                    // No pending updates, use fetched events as-is
                    print("✅ No pending updates, using fetched events directly")
                    return fetchedEvents
                }

                print("🔄 Merging \(fetchedEvents.count) fetched events with \(pending.count) pending updates")

                var merged = fetchedEvents.map { fetchedEvent -> GoogleEvent in
                    // If this event has a pending update, use the pending version
                    if let pendingEvent = pending[fetchedEvent.id] {
                        print("🔒 Preserving pending update for: \(pendingEvent.title)")
                        return pendingEvent
                    }
                    return fetchedEvent
                }

                // Add any pending events that weren't in the fetched results
                for (eventId, pendingEvent) in pending {
                    if !merged.contains(where: { $0.id == eventId }) {
                        print("➕ Adding pending event not in fetched results: \(pendingEvent.title)")
                        merged.append(pendingEvent)
                    }
                }

                return merged
            } ?? fetchedEvents

            // Filter out deleted events before assigning
            let deletedIds = self?.deletedEventIds ?? []
            let filteredEvents = mergedEvents.filter { !deletedIds.contains($0.id) }

            self?.googleEvents = filteredEvents
            self?.isLoading = false
            print("✅ Fetched \(fetchedEvents.count) Google Calendar events, merged to \(mergedEvents.count), filtered to \(filteredEvents.count) (removed \(mergedEvents.count - filteredEvents.count) deleted)")
        }
    }

    func updateEvent(_ event: GoogleEvent, completion: @escaping (Bool, String?) -> Void) {
        print("📅 Attempting to update Google Calendar event: \(event.title)")

        // Update local array immediately for UI responsiveness
        DispatchQueue.main.async { [weak self] in
            if let index = self?.googleEvents.firstIndex(where: { $0.id == event.id }) {
                self?.googleEvents[index] = event
                print("✅ Local Google event updated: \(event.title)")

                // Track this update as pending
                self?.pendingUpdatesQueue.sync {
                    self?.pendingUpdates[event.id] = event
                }
                print("🔒 Event marked as pending update: \(event.id)")
            } else {
                print("⚠️ Event not found in local array: \(event.id)")
            }
        }

        // Get access token from current user
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            print("⚠️ No Google user signed in - using local update only")
            completion(true, nil)
            return
        }

        let accessToken = user.accessToken.tokenString
        let calendarId = event.calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "primary"

        // Make actual Google Calendar API PATCH request
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events/\(event.id)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for Google event update")
            completion(false, "Invalid URL")
            return
        }

        // Format dates in RFC 3339 format for Google Calendar API
        let rfc3339Formatter = ISO8601DateFormatter()
        rfc3339Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let startString = rfc3339Formatter.string(from: event.startDate)
        let endString = rfc3339Formatter.string(from: event.endDate)

        // Create PATCH request body with all updatable fields
        var requestBody: [String: Any] = [
            "summary": event.title,
            "start": [
                "dateTime": startString,
                "timeZone": TimeZone.current.identifier
            ],
            "end": [
                "dateTime": endString,
                "timeZone": TimeZone.current.identifier
            ]
        ]

        // Add optional fields if present
        if let location = event.location, !location.isEmpty {
            requestBody["location"] = location
        }
        if let description = event.description, !description.isEmpty {
            requestBody["description"] = description
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("❌ Failed to serialize JSON for Google event update")
            completion(false, "JSON serialization failed")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("✅ Google event \(event.id) successfully updated via API")

                        // Parse response to get updated event data
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("📊 Updated event response: \(json)")
                        }

                        // Remove from pending updates - save completed successfully
                        await MainActor.run { [weak self] in
                            self?.pendingUpdatesQueue.sync {
                                self?.pendingUpdates.removeValue(forKey: event.id)
                            }
                            print("🔓 Removed \(event.id) from pending updates")
                        }

                        await MainActor.run {
                            completion(true, nil)
                        }
                    } else {
                        print("❌ Google API returned status \(httpResponse.statusCode)")
                        if let errorString = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(errorString)")
                        }
                        await MainActor.run {
                            completion(false, "Server returned status \(httpResponse.statusCode)")
                        }
                    }
                }
            } catch {
                print("❌ Network error updating Google event: \(error)")
                await MainActor.run {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    public func deleteEvent(eventId: String) async -> Bool {
        print("🗑️ Deleting Google Calendar event: \(eventId)")

        // Track deletion to prevent reappearance when fetching from server
        var currentIds = deletedEventIds
        currentIds.insert(eventId)
        deletedEventIds = currentIds

        print("📍 Google deletedEventIds now contains: \(deletedEventIds.count) events")

        // Find the calendar ID before deleting and remove from local array immediately
        var calendarId: String?
        var eventTitle: String?
        await MainActor.run { [weak self] in
            let countBefore = self?.googleEvents.count ?? 0

            if let index = self?.googleEvents.firstIndex(where: { $0.id == eventId }) {
                let deletedEvent = self?.googleEvents[index]
                calendarId = deletedEvent?.calendarId
                eventTitle = deletedEvent?.title
                print("📍 Found event to delete: \(eventTitle ?? "Unknown")")

                // Remove from local array IMMEDIATELY before attempting server deletion
                // This ensures the event stays deleted even if server deletion fails
                self?.googleEvents.remove(at: index)

                let countAfter = self?.googleEvents.count ?? 0
                print("🗑️ Removed Google event from local array: \(countBefore) -> \(countAfter) (removed \(countBefore - countAfter) events)")
            } else {
                print("⚠️ Google event not found in local array: \(eventId)")
            }

            // Also remove from pending updates if it exists
            self?.pendingUpdatesQueue.sync {
                self?.pendingUpdates.removeValue(forKey: eventId)
            }
        }

        // Get access token from current user
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            print("⚠️ No Google user signed in - cannot delete from server, but removed locally")
            return false
        }

        let accessToken = user.accessToken.tokenString

        // Use the calendar ID we found, or default to primary
        let calId = (calendarId?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)) ?? "primary"

        // Make actual Google Calendar API DELETE request
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calId)/events/\(eventId)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for Google event deletion")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 DELETE response status: \(httpResponse.statusCode)")

                // Log response body for debugging
                if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                    print("📄 Response body: \(responseString)")
                }

                if httpResponse.statusCode == 204 || httpResponse.statusCode == 200 {
                    print("✅ Google event '\(eventTitle ?? eventId)' successfully deleted from server (status: \(httpResponse.statusCode))")
                    // Event was already removed from local array earlier
                    return true
                } else {
                    print("⚠️ Google event deletion returned status code: \(httpResponse.statusCode)")
                    // Event was already removed from local array, but server deletion failed
                    return false
                }
            }
            return false
        } catch {
            print("❌ Failed to delete Google event: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            return false
        }
    }

    func updateEventTime(eventId: String, newStart: Date, newEnd: Date) async {
        print("📅 Updating Google Calendar event time: \(eventId)")

        // Update local array immediately for UI responsiveness
        await MainActor.run { [weak self] in
            if let index = self?.googleEvents.firstIndex(where: { $0.id == eventId }) {
                let oldEvent = self?.googleEvents[index]
                if let old = oldEvent {
                    // Create new event with updated times (struct properties are immutable)
                    let newEvent = GoogleEvent(
                        id: old.id,
                        title: old.title,
                        startDate: newStart,
                        endDate: newEnd,
                        location: old.location,
                        description: old.description,
                        calendarId: old.calendarId,
                        organizer: old.organizer
                    )
                    self?.googleEvents[index] = newEvent

                    // Track this update as pending
                    self?.pendingUpdatesQueue.sync {
                        self?.pendingUpdates[eventId] = newEvent
                    }
                    print("✅ Local Google event updated: \(newEvent.title)")
                    print("🔒 Event marked as pending update: \(eventId)")
                }
            }
        }

        // Get access token from current user
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            print("⚠️ No Google user signed in - using local update only")
            return
        }

        let accessToken = user.accessToken.tokenString

        // Find the calendar ID for this event
        guard let event = googleEvents.first(where: { $0.id == eventId }) else {
            print("❌ Could not find event to get calendar ID")
            return
        }

        let calendarId = event.calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "primary"

        // Make actual Google Calendar API PATCH request
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events/\(eventId)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for Google event update")
            return
        }

        // Format dates in RFC 3339 format for Google Calendar API
        let rfc3339Formatter = ISO8601DateFormatter()
        rfc3339Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let startString = rfc3339Formatter.string(from: newStart)
        let endString = rfc3339Formatter.string(from: newEnd)

        // Create PATCH request body
        let requestBody: [String: Any] = [
            "start": [
                "dateTime": startString,
                "timeZone": TimeZone.current.identifier
            ],
            "end": [
                "dateTime": endString,
                "timeZone": TimeZone.current.identifier
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("❌ Failed to serialize JSON for Google event update")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Google event \(eventId) successfully updated to \(newStart) - \(newEnd)")

                    // Parse response to get updated event data
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📊 Updated event response: \(json)")
                    }

                    // Remove from pending updates - save completed successfully
                    pendingUpdatesQueue.sync {
                        pendingUpdates.removeValue(forKey: eventId)
                    }
                    print("🔓 Event removed from pending updates: \(eventId)")
                } else {
                    print("⚠️ Google event update returned status code: \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                    // Keep in pending updates on failure
                }
            }
        } catch {
            print("❌ Failed to update Google event: \(error.localizedDescription)")
            // Keep in pending updates on error
        }
    }
}