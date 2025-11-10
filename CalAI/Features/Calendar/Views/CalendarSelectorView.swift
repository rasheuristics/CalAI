//
//  CalendarSelectorView.swift
//  CalAI
//
//  iOS-style calendar selector with visibility toggles
//  Created by Claude Code on 11/9/25.
//

import SwiftUI

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct CalendarSelectorView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // iOS Calendars Section
                if !calendarManager.iosCalendars.isEmpty {
                    Section(header: Text("iOS CALENDAR")) {
                        ForEach(calendarManager.iosCalendars, id: \.calendarIdentifier) { calendar in
                            CalendarRow(
                                name: calendar.title,
                                color: calendar.cgColor != nil ? Color(calendar.cgColor) : .blue,
                                isVisible: calendarManager.isCalendarVisible(calendar.calendarIdentifier),
                                source: .ios,
                                eventCount: calendarManager.getEventCount(for: calendar.calendarIdentifier),
                                fontManager: fontManager,
                                onToggleVisibility: {
                                    calendarManager.toggleCalendarVisibility(calendar.calendarIdentifier)
                                },
                                onShowInfo: {
                                    // Show calendar info sheet
                                    calendarManager.selectedCalendarForInfo = calendar
                                }
                            )
                        }
                    }
                }

                // Google Calendar Section
                if calendarManager.googleCalendarManager?.isSignedIn == true {
                    Section(header: Text("GOOGLE CALENDAR")) {
                        ForEach(calendarManager.googleCalendars, id: \.self) { calendar in
                            CalendarRow(
                                name: calendar.displayName,
                                color: .blue, // Google calendars would have their own colors
                                isVisible: calendarManager.isCalendarVisible(calendar.calendarId),
                                source: .google,
                                eventCount: calendarManager.getEventCount(for: calendar.calendarId),
                                fontManager: fontManager,
                                onToggleVisibility: {
                                    calendarManager.toggleCalendarVisibility(calendar.calendarId)
                                },
                                onShowInfo: {
                                    calendarManager.selectedGoogleCalendarForInfo = calendar
                                }
                            )
                        }
                    }
                }

                // Outlook Calendar Section
                if calendarManager.outlookCalendarManager?.isSignedIn == true,
                   let outlookCalendar = calendarManager.outlookCalendarManager?.selectedCalendar {
                    Section(header: Text("OUTLOOK CALENDAR")) {
                        CalendarRow(
                            name: outlookCalendar.displayName,
                            color: Color(hex: outlookCalendar.color ?? "#0078d4"),
                            isVisible: calendarManager.isCalendarVisible(outlookCalendar.id),
                            source: .outlook,
                            eventCount: calendarManager.getEventCount(for: outlookCalendar.id),
                            fontManager: fontManager,
                            onToggleVisibility: {
                                calendarManager.toggleCalendarVisibility(outlookCalendar.id)
                            },
                            onShowInfo: {
                                calendarManager.selectedOutlookCalendarForInfo = outlookCalendar
                            }
                        )
                    }
                }

                // Show All / Hide All
                Section {
                    Button(action: {
                        calendarManager.showAllCalendars()
                    }) {
                        HStack {
                            Image(systemName: "eye")
                            Text("Show All Calendars")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                        .foregroundColor(.blue)
                    }

                    Button(action: {
                        calendarManager.hideAllCalendars()
                    }) {
                        HStack {
                            Image(systemName: "eye.slash")
                            Text("Hide All Calendars")
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $calendarManager.selectedCalendarForInfo) { calendar in
            CalendarInfoSheet(calendar: calendar, fontManager: fontManager)
        }
    }
}

// MARK: - Calendar Row

struct CalendarRow: View {
    let name: String
    let color: Color
    let isVisible: Bool
    let source: CalendarSource
    let eventCount: Int
    @ObservedObject var fontManager: FontManager
    let onToggleVisibility: () -> Void
    let onShowInfo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Visibility toggle (checkmark)
            Button(action: onToggleVisibility) {
                Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isVisible ? color : .gray)
            }
            .buttonStyle(PlainButtonStyle())

            // Calendar color indicator
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            // Calendar name and event count
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .foregroundColor(.primary)

                if eventCount > 0 {
                    Text("\(eventCount) event\(eventCount == 1 ? "" : "s")")
                        .dynamicFont(size: 13, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Info button
            Button(action: onShowInfo) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Calendar Info Sheet

struct CalendarInfoSheet: View {
    let calendar: Any // Could be EKCalendar, GoogleCalendar, or OutlookCalendar
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("CALENDAR DETAILS")) {
                    // This would be customized based on calendar type
                    // For now, showing basic info
                    LabeledContent("Type", value: "Calendar")
                    LabeledContent("Source", value: "iOS")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Calendar Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CalendarSelectorView(
        calendarManager: CalendarManager(),
        fontManager: FontManager()
    )
}
