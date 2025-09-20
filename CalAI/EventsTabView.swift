import SwiftUI
import EventKit

struct EventsTabView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @State private var showingUpcoming = true
    @State private var selectedTimeRange: TimeRange = .week

    var body: some View {
        VStack(spacing: 0) {
            Picker("Time Range", selection: $selectedTimeRange) {
                Text("This Week").tag(TimeRange.week)
                Text("This Month").tag(TimeRange.month)
                Text("All Events").tag(TimeRange.all)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.top, 8)
            .padding(.horizontal)

            if filteredEvents.isEmpty {
                VStack {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No events found")
                        .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.gray)
                    Text("Events will appear here when you create them")
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(groupedEvents.keys.sorted(), id: \.self) { date in
                        Section(header: Text(formatSectionHeader(date))) {
                            ForEach(groupedEvents[date] ?? [], id: \.eventIdentifier) { event in
                                EventDetailRow(event: event, fontManager: fontManager)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            }
            .onAppear {
                calendarManager.loadEvents()
            }
    }

    private var filteredEvents: [EKEvent] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedTimeRange {
        case .week:
            let weekFromNow = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            return calendarManager.events.filter { event in
                event.startDate >= now && event.startDate <= weekFromNow
            }
        case .month:
            let monthFromNow = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            return calendarManager.events.filter { event in
                event.startDate >= now && event.startDate <= monthFromNow
            }
        case .all:
            return calendarManager.events.sorted { $0.startDate < $1.startDate }
        }
    }

    private var groupedEvents: [Date: [EKEvent]] {
        let calendar = Calendar.current
        return Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.startDate)
        }
    }

    private func formatSectionHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

enum TimeRange {
    case week, month, all
}

struct EventDetailRow: View {
    let event: EKEvent
    let fontManager: FontManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)

                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(formatTime(event.startDate))
                    if let endDate = event.endDate {
                        Text("-")
                        Text(formatTime(endDate))
                    }
                }
                .dynamicFont(size: 12, fontManager: fontManager)
                .foregroundColor(.secondary)

                if let location = event.location, !location.isEmpty {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(location)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Circle()
                .fill(colorForCalendar(event.calendar))
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 2)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func colorForCalendar(_ calendar: EKCalendar?) -> Color {
        guard let calendar = calendar else { return .blue }
        return Color(calendar.cgColor)
    }
}