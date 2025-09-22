import Foundation
import GoogleSignIn
import GoogleAPIClientForRESTCore
import GoogleAPIClientForREST_Calendar

class GoogleCalendarManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false

    private let calendarService = GTLRCalendarService()

    init() {
        setupService()
        checkSignInStatus()
    }

    private func setupService() {
        calendarService.apiKey = nil // Will use OAuth token
        calendarService.shouldFetchNextPages = true
    }

    private func checkSignInStatus() {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            isSignedIn = true
            calendarService.authorizer = currentUser.authentication.fetcherAuthorizer()
            print("✅ Google user already signed in")
        } else {
            isSignedIn = false
            print("❌ No Google user signed in")
        }
    }

    func signIn() {
        guard let presentingViewController = UIApplication.shared.windows.first?.rootViewController else {
            print("❌ No presenting view controller found")
            return
        }

        isLoading = true

        let scopes = ["https://www.googleapis.com/auth/calendar"]
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, hint: nil, additionalScopes: scopes) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    print("❌ Google Sign-In error: \(error)")
                    return
                }

                guard let user = result?.user else {
                    print("❌ No user returned from Google Sign-In")
                    return
                }

                self?.isSignedIn = true
                self?.calendarService.authorizer = user.authentication.fetcherAuthorizer()
                print("✅ Google Sign-In successful: \(user.profile?.email ?? "")")
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        calendarService.authorizer = nil
        print("✅ Google Sign-Out successful")
    }

    func fetchCalendars(completion: @escaping ([GTLRCalendar_CalendarListEntry]) -> Void) {
        guard isSignedIn else {
            print("❌ Not signed in to Google")
            completion([])
            return
        }

        let query = GTLRCalendarQuery_CalendarListList.query()

        calendarService.executeQuery(query) { (ticket, result, error) in
            if let error = error {
                print("❌ Error fetching calendars: \(error)")
                completion([])
                return
            }

            guard let calendarList = result as? GTLRCalendar_CalendarList,
                  let calendars = calendarList.items else {
                print("❌ No calendars found")
                completion([])
                return
            }

            print("✅ Fetched \(calendars.count) Google calendars")
            completion(calendars)
        }
    }

    func fetchEvents(from calendarId: String, completion: @escaping ([GTLRCalendar_Event]) -> Void) {
        guard isSignedIn else {
            print("❌ Not signed in to Google")
            completion([])
            return
        }

        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: calendarId)
        query.timeMin = GTLRDateTime(date: Date())
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime

        calendarService.executeQuery(query) { (ticket, result, error) in
            if let error = error {
                print("❌ Error fetching events: \(error)")
                completion([])
                return
            }

            guard let eventList = result as? GTLRCalendar_Events,
                  let events = eventList.items else {
                print("❌ No events found")
                completion([])
                return
            }

            print("✅ Fetched \(events.count) Google calendar events")
            completion(events)
        }
    }
}