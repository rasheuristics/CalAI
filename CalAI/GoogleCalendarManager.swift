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
        checkSignInStatus()
    }

    // private func setupService() {
    //     calendarService.apiKey = nil // Will use OAuth token
    //     calendarService.shouldFetchNextPages = true
    // }

    private func checkSignInStatus() {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            isSignedIn = true
            // calendarService.authorizer = currentUser.authentication.fetcherAuthorizer()
            print("✅ Google user already signed in: \(currentUser.profile?.email ?? "")")
        } else {
            isSignedIn = false
            print("❌ No Google user signed in")
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

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        // calendarService.authorizer = nil
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
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            print("❌ No Google user signed in for event fetching")
            return
        }

        print("🔵 Fetching Google Calendar events for \(user.profile?.email ?? "")...")
        isLoading = true

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
}