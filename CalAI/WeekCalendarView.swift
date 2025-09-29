import SwiftUI
import EventKit

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    let events: [EKEvent]
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize

    @State private var scrollOffset: CGFloat = 0
    private let hourHeight: CGFloat = 60

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
                    ForEach(displayHours, id: \.self) { hour in
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
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        // Day headers
                        HStack(spacing: 0) {
                            ForEach(weekDays, id: \.self) { day in
                                DayHeaderCell(date: day)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .onTapGesture {
                                        print("👆 Day header tapped: \(day)")
                                        selectedDate = day
                                        scrollToStartTime(proxy: proxy)
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
                                ForEach(displayHours, id: \.self) { hour in
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
                                    .id("hour-\(hour)")
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
                        .frame(height: CGFloat(displayHours.count) * hourHeight * zoomScale)
                    }
                    .onAppear {
                        scrollToStartTime(proxy: proxy)
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
        // Adjust offset based on the dynamic start hour
        let adjustedHour = hour - displayStartHour
        return CGFloat(adjustedHour) * hourHeight * zoomScale + (CGFloat(minute) / 60.0) * hourHeight * zoomScale
    }

    private var displayHours: [Int] {
        return Array(displayStartHour...displayEndHour)
    }

    private var displayStartHour: Int {
        guard !timedWeekEvents.isEmpty else { return 6 } // Default start at 6 AM if no events

        let earliestHour = timedWeekEvents.compactMap { event in
            Calendar.current.component(.hour, from: event.startDate)
        }.min() ?? 6

        // Start one hour before the earliest event, but not before 0
        return max(0, earliestHour - 1)
    }

    private var displayEndHour: Int {
        return 23 // Always end at 11 PM
    }

    private var timedWeekEvents: [EKEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            // Filter out all-day events and only include events in current week
            !event.isAllDay && weekDays.contains { day in
                calendar.isDate(event.startDate, inSameDayAs: day)
            }
        }
    }

    private func scrollToStartTime(proxy: ScrollViewProxy) {
        // Get events for the selected date
        let selectedDateEvents = eventsForDay(selectedDate).filter { !$0.isAllDay }

        let targetHour: Int
        if !selectedDateEvents.isEmpty {
            let earliestHour = selectedDateEvents.compactMap { event in
                Calendar.current.component(.hour, from: event.startDate)
            }.min() ?? 6
            targetHour = max(0, earliestHour - 1)
        } else {
            targetHour = max(displayStartHour, 0)
        }

        print("🔄 Scrolling to hour: \(targetHour) for date: \(selectedDate)")
        print("📅 Events for selected date: \(selectedDateEvents.count)")
        print("🎯 Target scroll ID: 'hour-\(targetHour)'")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.8)) {
                proxy.scrollTo("hour-\(targetHour)", anchor: .top)
            }
        }
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