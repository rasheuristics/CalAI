import SwiftUI
import EventKit

struct DayCalendarView: View {
    @Binding var selectedDate: Date
    let events: [EKEvent]
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize

    @State private var scrollOffset: CGFloat = 0
    private let hourHeight: CGFloat = 60
    private let hours = Array(0...23)

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Time labels column
                VStack(spacing: 0) {
                    // Header spacer
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 22)

                    // Hour labels
                    ForEach(hours, id: \.self) { hour in
                        HStack {
                            Text(formatHour(hour))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(height: hourHeight * zoomScale)
                    }
                }
                .frame(width: 50)
                .background(Color(.systemBackground))

                // Day column with events
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        // Header with day name and date
                        DayHeaderCell(date: selectedDate)
                            .frame(height: 22)
                            .background(Color(.systemGray6))

                        // All-day events section
                        if !allDayEvents.isEmpty {
                            VStack(spacing: 2) {
                                ForEach(allDayEvents, id: \.eventIdentifier) { event in
                                    AllDayEventView(event: event)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6).opacity(0.5))
                        }

                        // Timed events section
                        ZStack(alignment: .topLeading) {
                            // Background grid
                            VStack(spacing: 0) {
                                // Hour grid lines
                                ForEach(hours, id: \.self) { hour in
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, hourHeight * zoomScale - 1)
                                }
                            }

                            // Timed events positioned by time
                            ZStack(alignment: .topLeading) {
                                ForEach(timedEvents, id: \.eventIdentifier) { event in
                                    DayEventView(event: event, hourHeight: hourHeight * zoomScale)
                                        .offset(y: eventOffset(for: event))
                                }
                            }
                            .frame(height: CGFloat(hours.count) * hourHeight * zoomScale)
                        }
                    }
                }
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoomScale = max(0.5, min(3.0, value))
                        }
                )
            }
        }
        .onAppear {
            // Scroll to current time (8 AM default)
            scrollOffset = hourHeight * 8
        }
    }

    private var dayEvents: [EKEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: selectedDate)
        }
    }

    private var allDayEvents: [EKEvent] {
        return dayEvents.filter { $0.isAllDay }
    }

    private var timedEvents: [EKEvent] {
        return dayEvents.filter { !$0.isAllDay }
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }

    private func eventOffset(for event: EKEvent) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        return CGFloat(hour) * hourHeight * zoomScale + (CGFloat(minute) / 60.0) * hourHeight * zoomScale
    }
}

struct DayHeaderCell: View {
    let date: Date

    var body: some View {
        VStack(spacing: 1) {
            Text(dayText)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(dateText)
                .font(.caption)
                .fontWeight(isToday ? .bold : .medium)
                .foregroundColor(isToday ? .white : .primary)
                .frame(width: 15, height: 15)
                .background(isToday ? Color.blue : Color.clear)
                .clipShape(Circle())
        }
        .frame(maxWidth: .infinity)
    }

    private var dayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date).uppercased()
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

struct DayEventView: View {
    let event: EKEvent
    let hourHeight: CGFloat

    var body: some View {
        HStack {
            Rectangle()
                .fill(Color(event.calendar?.cgColor ?? CGColor(red: 0, green: 0, blue: 1, alpha: 1)))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(event.calendar?.cgColor ?? CGColor(red: 0, green: 0, blue: 1, alpha: 1)).opacity(0.2))
        .cornerRadius(4)
        .frame(height: eventHeight)
        .padding(.horizontal, 4)
    }

    private var eventHeight: CGFloat {
        let duration = event.endDate?.timeIntervalSince(event.startDate) ?? 3600 // Default 1 hour
        let hours = duration / 3600
        return max(20, CGFloat(hours) * hourHeight)
    }
}

struct AllDayEventView: View {
    let event: EKEvent

    var body: some View {
        HStack {
            Rectangle()
                .fill(Color(event.calendar?.cgColor ?? CGColor(red: 0, green: 0, blue: 1, alpha: 1)))
                .frame(width: 3)

            Text(event.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(event.calendar?.cgColor ?? CGColor(red: 0, green: 0, blue: 1, alpha: 1)).opacity(0.2))
        .cornerRadius(4)
        .frame(height: 20)
    }
}