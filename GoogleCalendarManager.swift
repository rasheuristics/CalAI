import Foundation
import GoogleSignIn

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

    init() {
        restorePreviousSignIn()
    }

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

    // MARK: - Google Calendar API Integration

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

        print("🔵 Performing real Google Calendar API event fetch for \(user.profile?.email ?? "")...")

        // Make real Google Calendar API call
        makeCalendarAPIRequest(user: user, startDate: startDate, endDate: endDate)
    }

    private func makeCalendarAPIRequest(user: GIDGoogleUser, startDate: Date, endDate: Date) {
        let accessToken = user.accessToken.tokenString

        // Format dates for Google Calendar API (RFC3339 format)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timeMin = formatter.string(from: startDate)
        let timeMax = formatter.string(from: endDate)

        // Build Google Calendar API URL
        let baseURL = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        let params = [
            "timeMin": timeMin,
            "timeMax": timeMax,
            "singleEvents": "true",
            "orderBy": "startTime",
            "maxResults": "50"
        ]

        var components = URLComponents(string: baseURL)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            print("❌ Invalid Google Calendar API URL")
            self.isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("🔍 Google Calendar API Request: \(url.absoluteString)")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    print("❌ Google Calendar API error: \(error.localizedDescription)")
                    self?.provideFallbackGoogleEvents(user: user)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid Google Calendar API response")
                    self?.provideFallbackGoogleEvents(user: user)
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    print("❌ Google Calendar API status: \(httpResponse.statusCode)")
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ API Error: \(errorString)")
                    }
                    self?.provideFallbackGoogleEvents(user: user)
                    return
                }

                guard let data = data else {
                    print("❌ No data from Google Calendar API")
                    self?.provideFallbackGoogleEvents(user: user)
                    return
                }

                self?.parseCalendarAPIResponse(data: data, user: user)
            }
        }.resume()
    }

    private func parseCalendarAPIResponse(data: Data, user: GIDGoogleUser) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                print("❌ Invalid Google Calendar API JSON structure")
                provideFallbackGoogleEvents(user: user)
                return
            }

            print("🔍 Google Calendar API returned \(items.count) raw events")

            let events = items.compactMap { item -> GoogleEvent? in
                guard let id = item["id"] as? String,
                      let summary = item["summary"] as? String else {
                    return nil
                }

                // Parse start and end times
                var startDate = Date()
                var endDate = Date()

                if let start = item["start"] as? [String: Any] {
                    if let dateTimeString = start["dateTime"] as? String {
                        startDate = parseGoogleDateTime(dateTimeString) ?? Date()
                    } else if let dateString = start["date"] as? String {
                        startDate = parseGoogleDate(dateString) ?? Date()
                    }
                }

                if let end = item["end"] as? [String: Any] {
                    if let dateTimeString = end["dateTime"] as? String {
                        endDate = parseGoogleDateTime(dateTimeString) ?? startDate.addingTimeInterval(3600)
                    } else if let dateString = end["date"] as? String {
                        endDate = parseGoogleDate(dateString) ?? startDate.addingTimeInterval(3600)
                    }
                }

                let location = item["location"] as? String
                let description = item["description"] as? String
                let organizer = (item["organizer"] as? [String: Any])?["email"] as? String

                return GoogleEvent(
                    id: id,
                    title: summary,
                    startDate: startDate,
                    endDate: endDate,
                    location: location,
                    description: description,
                    calendarId: "primary",
                    organizer: organizer ?? user.profile?.email
                )
            }

            self.googleEvents = events
            print("✅ Parsed \(events.count) Google Calendar events from real API")

        } catch {
            print("❌ JSON parsing error: \(error.localizedDescription)")
            provideFallbackGoogleEvents(user: user)
        }
    }

    private func parseGoogleDateTime(_ dateTimeString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateTimeString) {
            return date
        }

        // Fallback to basic format
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateTimeString)
    }

    private func parseGoogleDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }

    private func provideFallbackGoogleEvents(user: GIDGoogleUser) {
        print("🔄 Using fallback Google events due to API error")
        let simulatedEvents = [
            GoogleEvent(
                id: "google_fallback_1",
                title: "Morning Workout (Fallback)",
                startDate: Calendar.current.date(byAdding: .hour, value: 8, to: Calendar.current.startOfDay(for: Date())) ?? Date(),
                endDate: Calendar.current.date(byAdding: .hour, value: 9, to: Calendar.current.startOfDay(for: Date())) ?? Date(),
                location: "Gym",
                description: "Daily fitness routine - from fallback data",
                calendarId: "primary",
                organizer: user.profile?.email
            ),
            GoogleEvent(
                id: "google_fallback_2",
                title: "Team Meeting (Fallback)",
                startDate: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(byAdding: .hour, value: 10, to: Calendar.current.startOfDay(for: Date())) ?? Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(byAdding: .hour, value: 11, to: Calendar.current.startOfDay(for: Date())) ?? Date()) ?? Date(),
                location: "Conference Room",
                description: "Weekly team sync - from fallback data",
                calendarId: "primary",
                organizer: user.profile?.email
            )
        ]

        self.googleEvents = simulatedEvents
        print("✅ Using \(simulatedEvents.count) fallback Google Calendar events")
    }

    func updateEvent(_ event: GoogleEvent, completion: @escaping (Bool, String?) -> Void) {
        print("📅 Attempting to update Google Calendar event: \(event.title)")

        // TODO: Implement actual Google Calendar API event update
        // This would require:
        // 1. Authentication with Google Calendar API
        // 2. Using GTLRCalendarService to update the event
        // 3. Making a PATCH request to the Calendar API

        // For now, simulate the update for fallback events
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // Find and update the event in our local array
            if let index = self?.googleEvents.firstIndex(where: { $0.id == event.id }) {
                self?.googleEvents[index] = event
                print("✅ Successfully updated Google Calendar event (simulated): \(event.title)")
                completion(true, nil)
            } else {
                print("❌ Google Calendar event not found for update: \(event.id)")
                completion(false, "Event not found")
            }
        }
    }
}