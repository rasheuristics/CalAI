import SwiftUI
import EventKit

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    let events: [EKEvent]
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize

    @State private var scrollOffset: CGFloat = 0
    @State private var draggedEvent: EKEvent?
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    private let hourHeight: CGFloat = 60

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                timeLabelsColumn
                weekScrollView(geometry: geometry)
            }
        }
    }

    private var timeLabelsColumn: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 44)

            ForEach(displayHours, id: \.self) { hour in
                HStack {
                    formattedHourView(hour)
                    Spacer()
                }
                .frame(height: hourHeight * zoomScale)
            }
        }
        .frame(width: 50)
        .background(Color(.systemBackground))
    }

    private func weekScrollView(geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    dayHeadersView(proxy: proxy)
                    weekGridView(geometry: geometry)
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

    private func dayHeadersView(proxy: ScrollViewProxy) -> some View {
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
    }

    private func weekGridView(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            backgroundGrid
            eventsOverlay(geometry: geometry)
        }
        .frame(height: CGFloat(displayHours.count) * hourHeight * zoomScale)
    }

    private var backgroundGrid: some View {
        VStack(spacing: 0) {
            ForEach(displayHours, id: \.self) { hour in
                HStack(spacing: 0) {
                    ForEach(0..<7) { dayIndex in
                        gridCell(dayIndex: dayIndex)
                    }
                }
                .frame(height: hourHeight * zoomScale)
                .id("hour-\(hour)")
            }
        }
    }

    private func gridCell(dayIndex: Int) -> some View {
        Group {
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

    private func eventsOverlay(geometry: GeometryProxy) -> some View {
        let calculatedDayWidth = (geometry.size.width - 50) / 7

        return ForEach(Array(weekDays.enumerated()), id: \.offset) { dayIndex, day in
            let dayEvents = eventsForDay(day)
            ForEach(dayEvents, id: \.eventIdentifier) { event in
                eventView(
                    event: event,
                    dayIndex: dayIndex,
                    dayWidth: calculatedDayWidth
                )
            }
        }
    }

    private func eventView(event: EKEvent, dayIndex: Int, dayWidth: CGFloat) -> some View {
        let isEventDragging = draggedEvent?.eventIdentifier == event.eventIdentifier
        let xOffset = CGFloat(dayIndex) * dayWidth + (isEventDragging ? dragOffset.width : 0)
        let yOffset = eventOffset(for: event) + (isEventDragging ? dragOffset.height : 0)

        return WeekEventView(
            event: event,
            hourHeight: hourHeight * zoomScale,
            dayWidth: dayWidth,
            isDragging: isEventDragging,
            onDragChanged: { value in
                handleDragChanged(event: event, value: value, dayWidth: dayWidth)
            },
            onDragEnded: { value in
                handleDragEnded(event: event, value: value, dayWidth: dayWidth, originalDayIndex: dayIndex)
            }
        )
        .offset(x: xOffset, y: yOffset)
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

    @ViewBuilder
    private func formattedHourView(_ hour: Int) -> some View {
        let components = formatHourComponents(hour)
        HStack(spacing: 2) {
            Text(components.hour)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(components.period)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private func formatHourComponents(_ hour: Int) -> (hour: String, period: String) {
        if hour == 0 {
            return ("12", "AM")
        } else if hour < 12 {
            return ("\(hour)", "AM")
        } else if hour == 12 {
            return ("12", "PM")
        } else {
            return ("\(hour - 12)", "PM")
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

    private func handleDragChanged(event: EKEvent, value: DragGesture.Value, dayWidth: CGFloat) {
        if draggedEvent == nil {
            draggedEvent = event
        }

        // Calculate raw offsets
        let rawVerticalOffset = value.translation.height
        let rawHorizontalOffset = value.translation.width

        // Snap vertical (time) to 15-minute grid
        let totalVerticalOffset = eventOffset(for: event) + rawVerticalOffset
        let minutesPerPixel = 60.0 / (hourHeight * zoomScale)
        let totalMinutes = totalVerticalOffset * minutesPerPixel
        let snappedMinutes = round(totalMinutes / 15.0) * 15.0
        let snappedVerticalOffset = snappedMinutes / minutesPerPixel
        let snappedHeight = snappedVerticalOffset - eventOffset(for: event)

        // Snap horizontal (day) to full day columns
        let dayShift = round(rawHorizontalOffset / dayWidth)
        let snappedWidth = dayShift * dayWidth

        dragOffset = CGSize(width: snappedWidth, height: snappedHeight)
    }

    private func handleDragEnded(event: EKEvent, value: DragGesture.Value, dayWidth: CGFloat, originalDayIndex: Int) {
        guard let draggedEvent = draggedEvent else { return }

        // Calculate day shift
        let dayShift = Int(round(dragOffset.width / dayWidth))
        let newDayIndex = max(0, min(6, originalDayIndex + dayShift))

        // Calculate time shift (already snapped from dragOffset)
        let totalOffset = eventOffset(for: event) + dragOffset.height
        let minutesPerPixel = 60.0 / (hourHeight * zoomScale)
        let totalMinutes = totalOffset * minutesPerPixel
        let snappedMinutes = round(totalMinutes / 15.0) * 15.0

        let calendar = Calendar.current

        // Get event dates with explicit unwrapping for Swift type safety
        guard let eventStartDate = event.startDate as Date?,
              let eventEndDate = (event.endDate ?? event.startDate) as Date? else {
            // Reset drag state if dates are invalid
            self.draggedEvent = nil
            self.dragOffset = .zero
            return
        }

        let originalHour = calendar.component(.hour, from: eventStartDate)
        let originalMinute = calendar.component(.minute, from: eventStartDate)
        let originalTotalMinutes = Double(originalHour * 60 + originalMinute)
        let minuteShift = Int(snappedMinutes - originalTotalMinutes)

        // Calculate new date (day + time shift)
        var newStartDate = eventStartDate
        var newEndDate = eventEndDate

        // Apply day shift
        if dayShift != 0 {
            guard let shiftedStart = calendar.date(byAdding: .day, value: dayShift, to: newStartDate),
                  let shiftedEnd = calendar.date(byAdding: .day, value: dayShift, to: newEndDate) else {
                // Reset drag state if date calculation fails
                self.draggedEvent = nil
                self.dragOffset = .zero
                return
            }
            newStartDate = shiftedStart
            newEndDate = shiftedEnd
        }

        // Apply time shift
        if minuteShift != 0 {
            guard let shiftedStart = calendar.date(byAdding: .minute, value: minuteShift, to: newStartDate),
                  let shiftedEnd = calendar.date(byAdding: .minute, value: minuteShift, to: newEndDate) else {
                // Reset drag state if date calculation fails
                self.draggedEvent = nil
                self.dragOffset = .zero
                return
            }
            newStartDate = shiftedStart
            newEndDate = shiftedEnd
        }

        // Update the event
        event.startDate = newStartDate
        event.endDate = newEndDate

        // Save the event
        do {
            let eventStore = EKEventStore()
            try eventStore.save(event, span: .thisEvent)
            print("✅ Event moved to new day/time: \(newStartDate)")
        } catch {
            print("❌ Failed to save event: \(error)")
        }

        // Reset drag state
        self.draggedEvent = nil
        self.dragOffset = .zero
    }

}

struct WeekEventView: View {
    let event: EKEvent
    let hourHeight: CGFloat
    let dayWidth: CGFloat
    let isDragging: Bool
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void

    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = false

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
        .background(
            Color(event.calendar?.cgColor ?? CGColor(red: 0, green: 0, blue: 1, alpha: 1))
                .opacity(isDragging ? 0.4 : 0.2)
        )
        .cornerRadius(2)
        .frame(width: dayWidth - 2, height: eventHeight)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .shadow(color: isDragging ? .black.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: eventHeight)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .updating($isDetectingLongPress) { currentState, gestureState, transaction in
                    gestureState = currentState
                }
                .onEnded { finished in
                    self.completedLongPress = finished
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if completedLongPress {
                        onDragChanged(value)
                    }
                }
                .onEnded { value in
                    if completedLongPress {
                        onDragEnded(value)
                        completedLongPress = false
                    }
                }
        )
    }

    private var eventHeight: CGFloat {
        let duration = event.endDate?.timeIntervalSince(event.startDate) ?? 3600 // Default 1 hour
        let hours = duration / 3600
        return max(15, CGFloat(hours) * hourHeight)
    }
}