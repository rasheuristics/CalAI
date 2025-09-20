import SwiftUI
import EventKit

struct WeekCalendarView: View {
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
                    // Header spacer for day names
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 44)

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

                // Week days scroll view
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        // Day headers
                        HStack(spacing: 0) {
                            ForEach(weekDays, id: \.self) { day in
                                DayHeaderCell(date: day)
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture {
                                        selectedDate = day
                                    }

                                if day != weekDays.last {
                                    Rectangle()
                                        .fill(Color(.systemGray4))
                                        .frame(width: 1)
                                }
                            }
                        }
                        .frame(height: 44)
                        .background(Color(.systemGray6))

                        // Week grid with events
                        ZStack(alignment: .topLeading) {
                            // Background grid
                            VStack(spacing: 0) {
                                ForEach(hours, id: \.self) { hour in
                                    HStack(spacing: 0) {
                                        ForEach(0..<7) { dayIndex in
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(maxWidth: .infinity)
                                                .overlay(
                                                    Rectangle()
                                                        .fill(Color(.systemGray5))
                                                        .frame(height: 1),
                                                    alignment: .top
                                                )

                                            if dayIndex < 6 {
                                                Rectangle()
                                                    .fill(Color(.systemGray4))
                                                    .frame(width: 1)
                                            }
                                        }
                                    }
                                    .frame(height: hourHeight * zoomScale)
                                }
                            }

                            // Events overlay
                            ForEach(Array(weekDays.enumerated()), id: \.offset) { dayIndex, day in
                                let dayEvents = eventsForDay(day)
                                ForEach(dayEvents, id: \.eventIdentifier) { event in
                                    WeekEventView(
                                        event: event,
                                        hourHeight: hourHeight * zoomScale,
                                        dayWidth: (geometry.size.width - 50) / 7
                                    )
                                    .offset(
                                        x: CGFloat(dayIndex) * ((geometry.size.width - 50) / 7),
                                        y: eventOffset(for: event)
                                    )
                                }
                            }
                        }
                        .frame(height: CGFloat(hours.count) * hourHeight * zoomScale)
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
    }

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }

    private func eventsForDay(_ day: Date) -> [EKEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: day)
        }
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

struct WeekEventView: View {
    let event: EKEvent
    let hourHeight: CGFloat
    let dayWidth: CGFloat

    var body: some View {
        HStack {
            Rectangle()
                .fill(Color(event.calendar?.cgColor ?? CGColor(red: 0, green: 0, blue: 1, alpha: 1)))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if eventHeight > 30, let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .background(Color(event.calendar?.cgColor ?? CGColor(red: 0, green: 0, blue: 1, alpha: 1)).opacity(0.2))
        .cornerRadius(2)
        .frame(width: dayWidth - 2, height: eventHeight)
    }

    private var eventHeight: CGFloat {
        let duration = event.endDate?.timeIntervalSince(event.startDate) ?? 3600 // Default 1 hour
        let hours = duration / 3600
        return max(15, CGFloat(hours) * hourHeight)
    }
}