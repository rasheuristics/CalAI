import Foundation
import GoogleSignIn
// GoogleAPIClientForRESTCore and GoogleAPIClientForREST_Calendar temporarily commented out
// until packages are added to project
// import GoogleAPIClientForRESTCore
// import GoogleAPIClientForREST_Calendar

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
        print("✅ Google Sign-Out successful")
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
            let simulatedEvents = [
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

            self?.googleEvents = simulatedEvents
            self?.isLoading = false
            print("✅ Fetched \(simulatedEvents.count) Google Calendar events")
        }
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