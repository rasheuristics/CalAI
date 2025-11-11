import SwiftUI

struct CalendarAutoRoutingView: View {
    @ObservedObject var fontManager: FontManager
    @State private var defaultWorkCalendar: String = UserDefaults.standard.string(forKey: "defaultWorkCalendar") ?? "iOS"
    @State private var defaultPersonalCalendar: String = UserDefaults.standard.string(forKey: "defaultPersonalCalendar") ?? "iOS"
    @State private var defaultFallbackCalendar: String = UserDefaults.standard.string(forKey: "defaultFallbackCalendar") ?? "iOS"

    var body: some View {
        Form {
            Section(header: Text("Work Events"),
                   footer: Text("For meetings, standups, reviews, clients, presentations")) {

                RoutingCalendarSelectorRow(
                    title: "iOS Calendar",
                    isSelected: defaultWorkCalendar == "iOS",
                    action: {
                        defaultWorkCalendar = "iOS"
                        UserDefaults.standard.set("iOS", forKey: "defaultWorkCalendar")
                    }
                )

                RoutingCalendarSelectorRow(
                    title: "Google Calendar",
                    isSelected: defaultWorkCalendar == "Google",
                    action: {
                        defaultWorkCalendar = "Google"
                        UserDefaults.standard.set("Google", forKey: "defaultWorkCalendar")
                    }
                )

                RoutingCalendarSelectorRow(
                    title: "Outlook Calendar",
                    isSelected: defaultWorkCalendar == "Outlook",
                    action: {
                        defaultWorkCalendar = "Outlook"
                        UserDefaults.standard.set("Outlook", forKey: "defaultWorkCalendar")
                    }
                )
            }

            Section(header: Text("Personal Events"),
                   footer: Text("For gym, doctor, dentist, birthdays, personal appointments")) {

                RoutingCalendarSelectorRow(
                    title: "iOS Calendar",
                    isSelected: defaultPersonalCalendar == "iOS",
                    action: {
                        defaultPersonalCalendar = "iOS"
                        UserDefaults.standard.set("iOS", forKey: "defaultPersonalCalendar")
                    }
                )

                RoutingCalendarSelectorRow(
                    title: "Google Calendar",
                    isSelected: defaultPersonalCalendar == "Google",
                    action: {
                        defaultPersonalCalendar = "Google"
                        UserDefaults.standard.set("Google", forKey: "defaultPersonalCalendar")
                    }
                )

                RoutingCalendarSelectorRow(
                    title: "Outlook Calendar",
                    isSelected: defaultPersonalCalendar == "Outlook",
                    action: {
                        defaultPersonalCalendar = "Outlook"
                        UserDefaults.standard.set("Outlook", forKey: "defaultPersonalCalendar")
                    }
                )
            }

            Section(header: Text("Default Calendar"),
                   footer: Text("Used when event context is unclear or ambiguous")) {

                RoutingCalendarSelectorRow(
                    title: "iOS Calendar",
                    isSelected: defaultFallbackCalendar == "iOS",
                    action: {
                        defaultFallbackCalendar = "iOS"
                        UserDefaults.standard.set("iOS", forKey: "defaultFallbackCalendar")
                    }
                )

                RoutingCalendarSelectorRow(
                    title: "Google Calendar",
                    isSelected: defaultFallbackCalendar == "Google",
                    action: {
                        defaultFallbackCalendar = "Google"
                        UserDefaults.standard.set("Google", forKey: "defaultFallbackCalendar")
                    }
                )

                RoutingCalendarSelectorRow(
                    title: "Outlook Calendar",
                    isSelected: defaultFallbackCalendar == "Outlook",
                    action: {
                        defaultFallbackCalendar = "Outlook"
                        UserDefaults.standard.set("Outlook", forKey: "defaultFallbackCalendar")
                    }
                )
            }

            Section(header: Text("How Auto-Routing Works")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("Smart Calendar Detection")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("• CalAI analyzes your event title and description")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Work keywords: meeting, standup, review, client, presentation")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Personal keywords: gym, doctor, dentist, birthday, appointment")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Events are automatically routed to the appropriate calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Ambiguous events use your default calendar preference")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Calendar Auto-Routing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Calendar Selector Row

struct RoutingCalendarSelectorRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.headline)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        CalendarAutoRoutingView(fontManager: FontManager())
    }
}