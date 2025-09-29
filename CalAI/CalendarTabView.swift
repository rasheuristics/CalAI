import SwiftUI
import EventKit

enum CalendarViewType: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

struct CalendarTabView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @State private var selectedDate = Date()
    @State private var currentViewType: CalendarViewType = .day
    @State private var showingDatePicker = false

    var body: some View {
        ZStack {
            // Background that extends to all edges
            Color(.systemGroupedBackground)
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Native iOS Calendar Header
                iOSCalendarHeader(
                    selectedDate: $selectedDate,
                    currentViewType: $currentViewType,
                    showingDatePicker: $showingDatePicker,
                    fontManager: fontManager
                )

                // Main calendar content
                Group {
                    switch currentViewType {
                    case .day:
                        CompressedDayTimelineView(
                            date: selectedDate, // Show selected day
                            events: unifiedEventsForDate(selectedDate).map { TimelineEvent(from: $0) },
                            fontManager: fontManager
                        )
                        .id("\(selectedDate.timeIntervalSince1970)") // Force recreation on date change
                    case .week:
                        WeekViewWithCompressedTimeline(
                            selectedDate: $selectedDate,
                            events: calendarManager.unifiedEvents,
                            fontManager: fontManager
                        )
                    case .month:
                        MonthCalendarView(selectedDate: $selectedDate)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .year:
                        iOSYearView(
                            selectedDate: $selectedDate,
                            fontManager: fontManager,
                            onMonthDoubleClick: { month in
                                selectedDate = month
                                currentViewType = .month
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // Always reset to day view showing today
            currentViewType = .day
            selectedDate = Date()
        }
    }

    // Filter unified events for a specific date
    private func eventsForDate(_ date: Date) -> [UnifiedEvent] {
        return calendarManager.unifiedEvents.filter { event in
            if event.isAllDay {
                // For all-day events, check if this day is within the event's date range
                let eventStartDay = calendar.startOfDay(for: event.startDate)
                let eventEndDay = calendar.startOfDay(for: event.endDate)
                let selectedDay = calendar.startOfDay(for: date)
                return selectedDay >= eventStartDay && selectedDay <= eventEndDay
            } else {
                // For timed events, use the same logic as Events tab
                return calendar.isDate(event.startDate, inSameDayAs: date)
            }
        }
    }

    // Calendar instance for date comparisons
    private let calendar = Calendar.current

    // MARK: - Helper Functions
    private func unifiedEventsForDate(_ date: Date) -> [UnifiedEvent] {
        let calendar = Calendar.current
        return calendarManager.unifiedEvents.filter { event in
            if event.isAllDay {
                // For all-day events, check if this day is within the event's date range
                let eventStartDay = calendar.startOfDay(for: event.startDate)
                let eventEndDay = calendar.startOfDay(for: event.endDate)
                let selectedDay = calendar.startOfDay(for: date)
                return selectedDay >= eventStartDay && selectedDay <= eventEndDay
            } else {
                return calendar.isDate(event.startDate, inSameDayAs: date)
            }
        }
    }
}

// MARK: - Native iOS Calendar Header
struct iOSCalendarHeader: View {
    @Binding var selectedDate: Date
    @Binding var currentViewType: CalendarViewType
    @Binding var showingDatePicker: Bool
    @ObservedObject var fontManager: FontManager

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with month/year and view switcher - exact iOS layout
            HStack {
                // Month/Year button (tappable like iOS)
                Button(action: { showingDatePicker = true }) {
                    Text(monthYearText)
                        .scaledFont(.title3, fontManager: fontManager)
                        .foregroundColor(.primary)
                }

                Spacer()

                // View switcher - exact iOS style
                HStack(spacing: 0) {
                    ForEach(CalendarViewType.allCases, id: \.self) { viewType in
                        Button(action: { currentViewType = viewType }) {
                            Text(viewType.rawValue.first?.uppercased() ?? "")
                                .scaledFont(.footnote, fontManager: fontManager)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(currentViewType == viewType ? Color.blue : Color.clear)
                                )
                                .foregroundColor(currentViewType == viewType ? .white : .blue)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(height: 32)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Navigation bar with Today button and arrows - exact iOS style
            HStack {
                Button("Today") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedDate = Date()
                    }
                }
                .scaledFont(.callout, fontManager: fontManager)
                .foregroundColor(.red)

                Spacer()

                HStack(spacing: 24) {
                    Button(action: previousPeriod) {
                        Image(systemName: "chevron.left")
                            .scaledFont(.title2, fontManager: fontManager)
                            .foregroundColor(.blue)
                    }

                    Button(action: nextPeriod) {
                        Image(systemName: "chevron.right")
                            .scaledFont(.title2, fontManager: fontManager)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingDatePicker) {
            iOSDatePicker(selectedDate: $selectedDate, fontManager: fontManager)
        }
    }

    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    private func previousPeriod() {
        let calendar = Calendar.current
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentViewType {
            case .day:
                selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            case .week:
                selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
            case .month:
                selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
            case .year:
                selectedDate = calendar.date(byAdding: .year, value: -1, to: selectedDate) ?? selectedDate
            }
        }
    }

    private func nextPeriod() {
        let calendar = Calendar.current
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentViewType {
            case .day:
                selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            case .week:
                selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
            case .month:
                selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
            case .year:
                selectedDate = calendar.date(byAdding: .year, value: 1, to: selectedDate) ?? selectedDate
            }
        }
    }
}

// MARK: - iOS Month View (Exact Design Match)
struct iOSMonthView: View {
    @Binding var selectedDate: Date
    let events: [EKEvent]
    @ObservedObject var fontManager: FontManager

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Week day headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .background(Color.gray.opacity(0.1))

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(monthDates, id: \.self) { date in
                    MonthDayCell(
                        date: date,
                        selectedDate: $selectedDate,
                        isCurrentMonth: calendar.isDate(date, equalTo: selectedDate, toGranularity: .month),
                        events: eventsForDate(date)
                    )
                }
            }
        }
        .background(Color.white)
    }

    private var weekdaySymbols: [String] {
        return ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    }

    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end - 1)
        else { return [] }

        var dates: [Date] = []
        var date = monthFirstWeek.start

        while date <= monthLastWeek.end {
            dates.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }

        return dates
    }

    private func eventsForDate(_ date: Date) -> [EKEvent] {
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }
}

struct MonthDayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let isCurrentMonth: Bool
    let events: [EKEvent]

    private let calendar = Calendar.current

    var body: some View {
        Button(action: {
            selectedDate = date
        }) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)

                // Event indicator dots
                if !events.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(0..<min(events.count, 3), id: \.self) { _ in
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(backgroundColor)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .blue
        } else if isCurrentMonth {
            return .black
        } else {
            return .gray.opacity(0.4)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .blue.opacity(0.1)
        } else {
            return .clear
        }
    }

    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private var isToday: Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }
}

// MARK: - iOS Date Cell (Exact Replica)
struct iOSDateCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let currentMonth: Int
    let events: [EKEvent]
    @ObservedObject var fontManager: FontManager

    private let calendar = Calendar.current
    private let today = Date()

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = date
            }
        }) {
            VStack(spacing: 2) {
                // Date number
                Text("\(calendar.component(.day, from: date))")
                    .scaledFont(isToday ? .headline : .callout, fontManager: fontManager)
                    .foregroundColor(textColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(backgroundFill)
                    )

                // Event indicators - exact iOS style
                HStack(spacing: 2) {
                    ForEach(0..<min(events.count, 3), id: \.self) { index in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4)
                    }
                    if events.count > 3 {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }

    private var isToday: Bool {
        calendar.isDate(date, inSameDayAs: today)
    }

    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private var isCurrentMonth: Bool {
        calendar.component(.month, from: date) == currentMonth
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .red
        } else if isCurrentMonth {
            return .primary
        } else {
            return .secondary
        }
    }

    private var backgroundFill: Color {
        if isSelected {
            return .blue
        } else if isToday {
            return Color(.systemGray6)
        } else {
            return .clear
        }
    }
}

// MARK: - iOS Week View (Exact Replica)
struct iOSWeekView: View {
    @Binding var selectedDate: Date
    let events: [EKEvent]
    @ObservedObject var fontManager: FontManager

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 50

    var body: some View {
        VStack(spacing: 0) {
            // Week day headers - exactly like month view
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    Text(dayOfWeekSymbol(for: date))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .background(Color.gray.opacity(0.1))

            // Week calendar row - exactly like one row from month view
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    WeekDayCell(
                        date: date,
                        selectedDate: $selectedDate,
                        events: eventsForDate(date)
                    )
                }
            }

            // Selected day events display
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(selectedDayEvents, id: \.eventIdentifier) { event in
                        DayEventCard(event: event)
                    }

                    if selectedDayEvents.isEmpty {
                        Text("No events on this day")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.gray)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .background(Color.white)
    }

    private var weekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }

        var dates: [Date] = []
        var date = weekInterval.start

        for _ in 0..<7 {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        return dates
    }

    private func dayOfWeekSymbol(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date).uppercased()
    }

    private func eventsForDate(_ date: Date) -> [EKEvent] {
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }

    private var selectedDayEvents: [EKEvent] {
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: selectedDate)
        }
    }
}

struct WeekDayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let events: [EKEvent]

    private let calendar = Calendar.current

    var body: some View {
        Button(action: {
            selectedDate = date
        }) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)

                // Event indicator dots
                if !events.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(0..<min(events.count, 3), id: \.self) { _ in
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(backgroundColor)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .blue
        } else {
            return .black
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .blue.opacity(0.1)
        } else {
            return .clear
        }
    }

    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private var isToday: Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }
}

// MARK: - iOS Day View (Exact Design Match)
struct iOSDayView: View {
    @Binding var selectedDate: Date
    let events: [EKEvent]
    @ObservedObject var fontManager: FontManager

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 24) {
            // Date display
            VStack(spacing: 8) {
                Text(dayOfWeekText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)

                Text(dayNumberText)
                    .font(.system(size: 72, weight: .light))
                    .foregroundColor(.black)
            }
            .padding(.top, 40)

            // Events list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(todayEvents, id: \.eventIdentifier) { event in
                        DayEventCard(event: event)
                    }

                    if todayEvents.isEmpty {
                        Text("No events today")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.gray)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .background(Color.white)
    }

    private var dayOfWeekText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate).uppercased()
    }

    private var dayNumberText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: selectedDate)
    }

    private var todayEvents: [EKEvent] {
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: selectedDate)
        }
    }
}

struct DayEventCard: View {
    let event: EKEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            VStack(alignment: .leading, spacing: 2) {
                Text(startTime)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)

                if !isAllDay {
                    Text(endTime)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 60, alignment: .leading)

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private var startTime: String {
        if event.isAllDay {
            return "All Day"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: event.startDate)
        }
    }

    private var endTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: event.endDate)
    }

    private var isAllDay: Bool {
        return event.isAllDay
    }
}

// MARK: - iOS Year View (Exact Design Match)
struct iOSYearView: View {
    @Binding var selectedDate: Date
    @ObservedObject var fontManager: FontManager
    let onMonthDoubleClick: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(monthsInYear, id: \.self) { month in
                    YearMonthCard(
                        month: month,
                        selectedDate: $selectedDate,
                        fontManager: fontManager,
                        onDoubleClick: onMonthDoubleClick
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.white)
    }

    private var monthsInYear: [Date] {
        let year = calendar.component(.year, from: selectedDate)
        var months: [Date] = []

        for monthIndex in 1...12 {
            if let date = calendar.date(from: DateComponents(year: year, month: monthIndex, day: 1)) {
                months.append(date)
            }
        }

        return months
    }
}

// MARK: - iOS Supporting Views
struct iOSWeekEventView: View {
    let event: EKEvent
    @ObservedObject var fontManager: FontManager

    var body: some View {
        HStack {
            Text(event.title)
                .scaledFont(.caption2, fontManager: fontManager)
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
        )
    }
}

struct iOSDayEventView: View {
    let event: EKEvent
    @ObservedObject var fontManager: FontManager

    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .scaledFont(.caption, fontManager: fontManager)
                    .foregroundColor(.primary)

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .scaledFont(.caption2, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

struct YearMonthCard: View {
    let month: Date
    @Binding var selectedDate: Date
    @ObservedObject var fontManager: FontManager
    let onDoubleClick: (Date) -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            // Month name
            Text(monthName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.black)
                .padding(.bottom, 4)

            // Mini calendar grid
            VStack(spacing: 1) {
                // Week day headers
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.gray)
                            .frame(width: 14, height: 12)
                    }
                }

                // Calendar days
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(14), spacing: 0), count: 7), spacing: 1) {
                    ForEach(monthDates, id: \.self) { date in
                        Button(action: {
                            selectedDate = date
                        }) {
                            Text(dayText(for: date))
                                .font(.system(size: 8, weight: .regular))
                                .foregroundColor(textColor(for: date))
                                .frame(width: 14, height: 14)
                                .background(
                                    Rectangle()
                                        .fill(backgroundFill(for: date))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .onTapGesture(count: 2) {
            onDoubleClick(month)
        }
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month).uppercased()
    }

    private var weekdaySymbols: [String] {
        return ["S", "M", "T", "W", "T", "F", "S"]
    }

    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }

        var dates: [Date] = []
        let startOfMonth = monthInterval.start
        let endOfMonth = monthInterval.end

        // Get the first day of the week for the month start
        let weekday = calendar.component(.weekday, from: startOfMonth)
        let daysFromStartOfWeek = (weekday - calendar.firstWeekday + 7) % 7

        // Add empty slots for days before the month starts (from previous month)
        for i in 0..<daysFromStartOfWeek {
            if let emptyDate = calendar.date(byAdding: .day, value: -(daysFromStartOfWeek - i), to: startOfMonth) {
                dates.append(emptyDate)
            }
        }

        // Add all days of the current month only
        var date = startOfMonth
        while date < endOfMonth {
            dates.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }

        // Pad to complete the grid (6 rows x 7 days = 42 total) with next month days
        while dates.count < 42 {
            if let nextDate = calendar.date(byAdding: .day, value: 1, to: dates.last ?? endOfMonth) {
                dates.append(nextDate)
            } else {
                break
            }
        }

        return dates
    }

    private func dayText(for date: Date) -> String {
        if isCurrentMonth(date) {
            return "\(calendar.component(.day, from: date))"
        } else {
            return ""
        }
    }

    private func textColor(for date: Date) -> Color {
        if isSelected(date) {
            return .white
        } else if isToday(date) {
            return .blue
        } else if isCurrentMonth(date) {
            return .black
        } else {
            return .clear // Hide non-current month days
        }
    }

    private func backgroundFill(for date: Date) -> Color {
        if isSelected(date) {
            return .blue
        } else if isToday(date) {
            return .blue.opacity(0.1)
        } else {
            return .clear
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }

    private func isCurrentMonth(_ date: Date) -> Bool {
        calendar.component(.month, from: date) == calendar.component(.month, from: month)
    }
}

// MARK: - Week View with Compressed Timeline
struct WeekViewWithCompressedTimeline: View {
    @Binding var selectedDate: Date
    let events: [UnifiedEvent]
    @ObservedObject var fontManager: FontManager

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Week day headers
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    VStack(spacing: 4) {
                        Text(dayOfWeekSymbol(for: day))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Text("\(calendar.component(.day, from: day))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isSelected(day) ? .white : (isToday(day) ? .red : .primary))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(isSelected(day) ? Color.blue : (isToday(day) ? Color.red.opacity(0.1) : Color.clear))
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        selectedDate = day
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))

            // Selected day timeline
            CompressedDayTimelineView(
                date: selectedDate,
                events: eventsForDate(selectedDate).map { TimelineEvent(from: $0) },
                fontManager: fontManager
            )
            .id("\(selectedDate.timeIntervalSince1970)") // Force recreation
            .onChange(of: selectedDate) { _ in
                // Force timeline rebuild when date changes
            }
        }
    }

    private var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }

        var dates: [Date] = []
        var date = weekInterval.start

        for _ in 0..<7 {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        return dates
    }

    private func dayOfWeekSymbol(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date).uppercased()
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }

    // Filter events for a specific date
    private func eventsForDate(_ date: Date) -> [UnifiedEvent] {
        return events.filter { event in
            if event.isAllDay {
                // For all-day events, check if this day is within the event's date range
                let eventStartDay = calendar.startOfDay(for: event.startDate)
                let eventEndDay = calendar.startOfDay(for: event.endDate)
                let selectedDay = calendar.startOfDay(for: date)
                return selectedDay >= eventStartDay && selectedDay <= eventEndDay
            } else {
                // For timed events, use the same logic as Events tab
                return calendar.isDate(event.startDate, inSameDayAs: date)
            }
        }
    }
}

// MARK: - Calendar Source Colors

func colorForCalendarSource(_ source: CalendarSource) -> Color {
    switch source {
    case .ios:
        return Color(red: 0/255, green: 122/255, blue: 255/255) // #007AFF - Apple's system blue
    case .google:
        return Color(red: 52/255, green: 168/255, blue: 83/255) // #34A853 - Google's brand green
    case .outlook:
        return Color(red: 255/255, green: 140/255, blue: 0/255) // #FF8C00 - Microsoft's Outlook orange
    }
}

// MARK: - Compressed Day Timeline Implementation

// Calendar Event Protocol for timeline
protocol CalendarEvent {
    var id: String { get }
    var title: String? { get }
    var start: Date { get }
    var end: Date { get }
    var eventLocation: String? { get }
    var isAllDay: Bool { get }
    var source: CalendarSource { get }
}

// Wrapper struct for UnifiedEvent to work with CalendarEvent protocol
struct TimelineEvent: CalendarEvent {
    let id: String
    let title: String?
    let start: Date
    let end: Date
    let eventLocation: String?
    let isAllDay: Bool
    let source: CalendarSource

    init(from unifiedEvent: UnifiedEvent) {
        self.id = unifiedEvent.id
        self.title = unifiedEvent.title
        self.start = unifiedEvent.startDate
        self.end = unifiedEvent.endDate
        self.eventLocation = unifiedEvent.location
        self.isAllDay = unifiedEvent.isAllDay
        self.source = unifiedEvent.source
    }

    // Legacy support for EKEvent if needed
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title
        self.start = ekEvent.startDate
        self.end = ekEvent.endDate
        self.eventLocation = ekEvent.location
        self.isAllDay = ekEvent.isAllDay
        self.source = .ios
    }
}

// Internal struct for events clamped to day boundaries
private struct ClampedEvent: CalendarEvent {
    let id: String
    let title: String?
    let start: Date
    let end: Date
    let eventLocation: String?
    let isAllDay: Bool
    let source: CalendarSource
    let originalEvent: CalendarEvent

    var isClampedStart: Bool {
        return start != originalEvent.start
    }

    var isClampedEnd: Bool {
        return end != originalEvent.end
    }
}

// Timeline Segment Types
enum TimelineSegment: Identifiable {
    case gap(id: UUID, start: Date, end: Date, isExpanded: Bool)
    case event(id: UUID, event: CalendarEvent, lane: Int)

    var id: UUID {
        switch self {
        case .gap(let id, _, _, _): return id
        case .event(let id, _, _): return id
        }
    }
}

// Main compressed timeline view
struct CompressedDayTimelineView: View {
    let date: Date
    let events: [CalendarEvent]
    @ObservedObject var fontManager: FontManager

    // Tuning constants
    let pxPerMinute: CGFloat
    let gapCollapseThresholdMin: Int
    let collapsedGapHeight: CGFloat

    @State private var segments: [TimelineSegment] = []
    @State private var expandedGaps: Set<UUID> = []
    @State private var currentTime = Date()
    @State private var allDayEvents_internal: [ClampedEvent] = []

    private let hourLabelWidth: CGFloat = 60
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }()

    init(date: Date, events: [CalendarEvent], fontManager: FontManager,
         pxPerMinute: CGFloat = 1.0, gapCollapseThresholdMin: Int = 30, collapsedGapHeight: CGFloat = 48) {
        self.date = date
        self.events = events
        self.fontManager = fontManager
        self.pxPerMinute = pxPerMinute
        self.gapCollapseThresholdMin = gapCollapseThresholdMin
        self.collapsedGapHeight = collapsedGapHeight
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Sticky all-day events section
                if !allDayEvents_internal.isEmpty {
                    allDayEventsView(width: geometry.size.width)
                        .background(Color(.systemBackground))
                        .shadow(radius: 2)
                        .zIndex(1)
                }

                // Scrollable timeline content
                ScrollView(.vertical, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        // Hour labels column
                        hourLabelsView()

                        // Timeline content with now marker overlay
                        HStack(spacing: 0) {
                            Color.clear.frame(width: hourLabelWidth)

                            ZStack(alignment: .topLeading) {
                                // Events and gaps
                                timelineContentView(width: geometry.size.width - hourLabelWidth)

                                // Now marker overlay
                                if isToday {
                                    nowMarkerView()
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            buildSegments()
            startTimeTimer()
        }
        .onChange(of: date) { _ in
            // Clear ALL state and rebuild completely
            withAnimation(.none) {
                allDayEvents_internal = []
                segments = []
                expandedGaps = []
            }

            // Force immediate rebuild on main thread
            DispatchQueue.main.async {
                buildSegments()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            currentTime = Date()
        }
    }

    @ViewBuilder
    private func hourLabelsView() -> some View {
        VStack(spacing: 0) {
            ForEach(Array(0...23), id: \.self) { hour in
                HStack {
                    Text(formatTime(hourToDate(hour)))
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(width: hourLabelWidth, height: CGFloat(60 * pxPerMinute))
            }
        }
    }

    @ViewBuilder
    private func timelineContentView(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Background timeline with hour divisions
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: CGFloat(60) * pxPerMinute)
                        .overlay(
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 0.5),
                            alignment: .top
                        )
                }
            }

            // Events positioned absolutely based on their time
            ForEach(segments) { segment in
                switch segment {
                case .event(_, let event, let lane):
                    absolutePositionedEventView(event: event, lane: lane, width: width)
                case .gap:
                    EmptyView() // Gaps not needed with absolute positioning
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func absolutePositionedEventView(event: CalendarEvent, lane: Int, width: CGFloat) -> some View {
        let dayStart = calendar.startOfDay(for: date)
        let minutesFromDayStart = calendar.dateComponents([.minute], from: dayStart, to: event.start).minute ?? 0
        let yOffset = CGFloat(minutesFromDayStart) * pxPerMinute

        eventView(event: event, lane: lane, width: width)
            .offset(y: yOffset)
    }

    @ViewBuilder
    private func allDayEventsView(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            // All-day section header
            HStack {
                Text("All Day")
                    .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // All-day events
            LazyVStack(spacing: 4) {
                ForEach(Array(allDayEvents_internal.enumerated()), id: \.element.id) { index, event in
                    allDayEventCard(event: event, width: width - 32)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func allDayEventCard(event: ClampedEvent, width: CGFloat) -> some View {
        let isMultiDay = !calendar.isDate(event.originalEvent.start, inSameDayAs: event.originalEvent.end)

        HStack(spacing: 8) {
            // Multi-day indicator
            Rectangle()
                .fill(isMultiDay ? Color.orange : Color.green)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled Event")
                    .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let location = event.eventLocation, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .dynamicFont(size: 10, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Text(location)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((isMultiDay ? Color.orange : Color.green).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((isMultiDay ? Color.orange : Color.green).opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityLabel("\(isMultiDay ? "Multi-day" : "All day") event: \(event.title ?? "Untitled Event")\(event.eventLocation.map { ", at \($0)" } ?? "")")
    }

    @ViewBuilder
    private func segmentView(for segment: TimelineSegment, width: CGFloat) -> some View {
        switch segment {
        case .gap(let id, let start, let end, let isExpanded):
            let duration = end.timeIntervalSince(start)
            let durationMinutes = duration / 60.0
            let shouldCollapse = durationMinutes > Double(gapCollapseThresholdMin)

            gapView(
                duration: duration,
                shouldCollapse: shouldCollapse,
                isExpanded: isExpanded,
                width: width,
                onToggle: { toggleGap(id) }
            )

        case .event(_, let event, let lane):
            eventView(event: event, lane: lane, width: width)
        }
    }

    @ViewBuilder
    private func gapView(duration: TimeInterval, shouldCollapse: Bool, isExpanded: Bool, width: CGFloat, onToggle: @escaping () -> Void) -> some View {
        let durationMinutes = duration / 60.0
        let actualHeight = CGFloat(durationMinutes) * pxPerMinute
        let displayHeight = (shouldCollapse && !isExpanded) ? collapsedGapHeight : actualHeight

        ZStack {
            // Dashed vertical line through the gap
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    VStack {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundColor(.secondary.opacity(0.6))
                            .frame(width: 1)
                    }
                )

            // Gap content
            if shouldCollapse && !isExpanded {
                // Collapsed gap chip
                VStack {
                    Spacer()
                    Button(action: onToggle) {
                        HStack(spacing: 8) {
                            Text("\(formatDuration(duration)) gap")
                                .dynamicFont(size: 13, weight: .medium, fontManager: fontManager)
                                .foregroundColor(.secondary)

                            Image(systemName: "chevron.down")
                                .dynamicFont(size: 10, fontManager: fontManager)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                        .foregroundColor(.secondary.opacity(0.5))
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Gap of \(formatDuration(duration)). Double-tap to expand.")
                    .accessibilityHint("Expands the time gap to show full duration")
                    Spacer()
                }
            } else if shouldCollapse && isExpanded {
                // Expanded gap with collapse button
                VStack {
                    Spacer()
                    Button(action: onToggle) {
                        HStack(spacing: 6) {
                            Text("\(formatDuration(duration)) gap")
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.secondary)

                            Image(systemName: "chevron.up")
                                .dynamicFont(size: 10, fontManager: fontManager)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Gap of \(formatDuration(duration)). Double-tap to collapse.")
                    .accessibilityHint("Collapses the time gap to save space")
                    Spacer()
                }
            }
        }
        .frame(width: width, height: displayHeight)
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }

    @ViewBuilder
    private func eventView(event: CalendarEvent, lane: Int, width: CGFloat) -> some View {
        let duration = event.end.timeIntervalSince(event.start)
        let height = max(CGFloat(duration / 60.0) * pxPerMinute, 40) // Minimum height of 40
        let maxLanes = 3
        let laneWidth = width / CGFloat(maxLanes)
        let offsetX = CGFloat(lane) * laneWidth
        let cardWidth = min(laneWidth - 4, width - offsetX - 4)

        HStack(spacing: 0) {
            // Lane offset
            if lane > 0 {
                Color.clear.frame(width: offsetX)
            }

            // Event card
            VStack(alignment: .leading, spacing: 4) {
                // Event title with multi-day indicator
                HStack(spacing: 4) {
                    Text(event.title ?? "Untitled Event")
                        .dynamicFont(size: 15, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    if let clampedEvent = event as? ClampedEvent {
                        if clampedEvent.isClampedStart || clampedEvent.isClampedEnd {
                            Image(systemName: "arrow.left.arrow.right")
                                .dynamicFont(size: 10, fontManager: fontManager)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Time range with continuation indicators
                HStack(spacing: 2) {
                    if let clampedEvent = event as? ClampedEvent, clampedEvent.isClampedStart {
                        Text("...")
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }

                    Text("\(formatTime(event.start)) - \(formatTime(event.end))")
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    if let clampedEvent = event as? ClampedEvent, clampedEvent.isClampedEnd {
                        Text("...")
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }

                // Location
                if let location = event.eventLocation, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .dynamicFont(size: 10, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Text(location)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(width: cardWidth, height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorForCalendarSource(event.source).opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(colorForCalendarSource(event.source).opacity(0.4), lineWidth: 1)
                    )
            )
            .accessibilityLabel("\(event.title ?? "Untitled Event"), \(formatTime(event.start)) to \(formatTime(event.end))\(event.eventLocation.map { ", at \($0)" } ?? "")")

            // Fill remaining space
            Spacer()
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private func nowMarkerView() -> some View {
        let minutesSinceMidnight = calendar.dateComponents([.hour, .minute], from: currentTime)
        let totalMinutes = (minutesSinceMidnight.hour ?? 0) * 60 + (minutesSinceMidnight.minute ?? 0)
        let yOffset = CGFloat(totalMinutes) * pxPerMinute

        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.red)
                .frame(height: 2)

            Text("Now")
                .dynamicFont(size: 10, weight: .medium, fontManager: fontManager)
                .foregroundColor(.red)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red.opacity(0.1))
                )
        }
        .offset(y: yOffset)
        .zIndex(100)
    }

    private var isToday: Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }

    private func toggleGap(_ gapId: UUID) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedGaps.contains(gapId) {
                expandedGaps.remove(gapId)
            } else {
                expandedGaps.insert(gapId)
            }
        }
    }

    private func hourToDate(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }

    private func startTimeTimer() {
        if isToday {
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }

    // MARK: - Helper Functions

    /// Build timeline segments from events, creating gaps between events
    private func buildSegments() {
        // Ensure we're on the main thread for UI updates
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.buildSegments()
            }
            return
        }

        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            allDayEvents_internal = []
            segments = []
            return
        }

        // Clear state first to ensure clean rebuild
        allDayEvents_internal = []
        segments = []

        // Filter events for this specific day only
        let daySpecificEvents = filterEventsForDay(events: events, dayStart: dayStart, dayEnd: dayEnd)
        segments = buildSegments(events: daySpecificEvents, dayStart: dayStart, dayEnd: dayEnd)
    }

    /// Filter events to only include those relevant for the specific day
    /// Uses the EXACT same logic as the Events tab: calendar.isDate(event.startDate, inSameDayAs: date)
    private func filterEventsForDay(events: [CalendarEvent], dayStart: Date, dayEnd: Date) -> [CalendarEvent] {
        return events.filter { event in
            if event.isAllDay {
                // For all-day events, check if this day is within the event's date range
                // Multi-day all-day events should appear on each day they span
                let eventStartDay = calendar.startOfDay(for: event.start)
                let eventEndDay = calendar.startOfDay(for: event.end)
                let selectedDay = dayStart

                return selectedDay >= eventStartDay && selectedDay <= eventEndDay
            } else {
                // For timed events, use EXACTLY the same logic as Events tab
                // This is the exact line from eventsForDate(_ date: Date) in the Events tab
                return calendar.isDate(event.start, inSameDayAs: dayStart)
            }
        }
    }

    /// Core function to build segments from events and day boundaries
    private func buildSegments(events: [CalendarEvent], dayStart: Date, dayEnd: Date) -> [TimelineSegment] {
        // Events are already filtered by filterEventsForDay, so separate all-day from timed
        let allDayEvents = events.filter { $0.isAllDay }.map { event in
            ClampedEvent(
                id: event.id,
                title: event.title,
                start: dayStart,
                end: dayEnd,
                eventLocation: event.eventLocation,
                isAllDay: true,
                source: event.source,
                originalEvent: event
            )
        }.sorted { $0.title ?? "" < $1.title ?? "" }

        // Filter timed events (events are already filtered by filterEventsForDay)
        let timedEvents = events.filter { !$0.isAllDay }.map { event in
            // Keep original event times for proper positioning, only clamp end if needed
            let actualStart = event.start
            let clampedEnd = min(event.end, dayEnd)

            return ClampedEvent(
                id: event.id,
                title: event.title,
                start: actualStart, // Use actual start time for proper timeline positioning
                end: clampedEnd,
                eventLocation: event.eventLocation,
                isAllDay: false,
                source: event.source,
                originalEvent: event
            )
        }.sorted { $0.start < $1.start }

        // Store all-day events separately for sticky header
        allDayEvents_internal = allDayEvents

        var result: [TimelineSegment] = []
        var currentTime = dayStart

        // Assign lanes to handle overlapping timed events only
        let eventsWithLanes = assignLanes(to: timedEvents)

        for eventWithLane in eventsWithLanes {
            let event = eventWithLane.event
            let lane = eventWithLane.lane

            // Add gap before event if there's empty time
            if currentTime < event.start {
                let gapDuration = event.start.timeIntervalSince(currentTime)
                if gapDuration > 60 { // Only show gaps longer than 1 minute
                    let gapId = UUID()
                    let isExpanded = expandedGaps.contains(gapId)
                    result.append(.gap(id: gapId, start: currentTime, end: event.start, isExpanded: isExpanded))
                }
            }

            // Add the event
            result.append(.event(id: UUID(), event: event, lane: lane))

            // Advance current time to the end of this event
            currentTime = max(currentTime, event.end)
        }

        // Add final gap to end of day if needed
        if currentTime < dayEnd {
            let gapDuration = dayEnd.timeIntervalSince(currentTime)
            if gapDuration > 60 {
                let gapId = UUID()
                let isExpanded = expandedGaps.contains(gapId)
                result.append(.gap(id: gapId, start: currentTime, end: dayEnd, isExpanded: isExpanded))
            }
        }

        return result
    }

    private func assignLanes(to events: [CalendarEvent]) -> [(event: CalendarEvent, lane: Int)] {
        var result: [(event: CalendarEvent, lane: Int)] = []
        var laneEndTimes: [Date] = []

        for event in events {
            // Find the first available lane
            var assignedLane = 0
            for (index, endTime) in laneEndTimes.enumerated() {
                if event.start >= endTime {
                    assignedLane = index
                    laneEndTimes[index] = event.end
                    break
                }
                assignedLane = index + 1
            }

            // If no available lane found, create a new one
            if assignedLane >= laneEndTimes.count {
                laneEndTimes.append(event.end)
            }

            result.append((event: event, lane: min(assignedLane, 2))) // Max 3 lanes
        }

        return result
    }

    /// Format time interval as human-readable duration (e.g., "2h 15m", "45m", "3h")
    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    /// Format date as time string (e.g., "9:00 AM", "2:30 PM")
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Event Card View
struct EventCardView: View {
    let event: EKEvent
    let lane: Int
    let hourHeight: CGFloat
    @ObservedObject var fontManager: FontManager

    var body: some View {
        HStack(spacing: 8) {
            // Lane indicator
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Rectangle()
                        .fill(index == lane ? eventColor : Color.clear)
                        .frame(width: 3, height: 20)
                }
            }
            .frame(width: 24)

            // Event content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(timeRangeText)
                        .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    Spacer()

                    if event.isAllDay {
                        Text("All Day")
                            .dynamicFont(size: 11, fontManager: fontManager)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(eventColor.opacity(0.2))
                            .foregroundColor(eventColor)
                            .clipShape(Capsule())
                    }
                }

                Text(event.title)
                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let location = event.location, !location.isEmpty {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                            .font(.caption2)

                        Text(location)
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(eventColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(eventColor.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(height: eventHeight)
    }

    private var eventColor: Color {
        Color(event.calendar?.cgColor ?? CGColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0))
    }

    private var eventHeight: CGFloat {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let hours = duration / 3600
        let baseHeight: CGFloat = 60
        return max(baseHeight, CGFloat(hours) * hourHeight * 0.8)
    }

    private var timeRangeText: String {
        if event.isAllDay {
            return formatDate(event.startDate)
        } else {
            return "\(formatTime(event.startDate)) - \(formatTime(event.endDate))"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Gap Chip View
struct GapChipView: View {
    let duration: TimeInterval
    let isExpanded: Bool
    @ObservedObject var fontManager: FontManager
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Expanded gap - show true scale
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: expandedHeight)
                    .overlay(
                        VStack {
                            dashedLine
                            Spacer()
                            dashedLine
                        }
                    )
            } else {
                // Compressed gap chip
                Button(action: onToggle) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Text(durationText)
                            .dynamicFont(size: 13, weight: .medium, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Text("gap")
                            .dynamicFont(size: 13, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                    .foregroundColor(.secondary.opacity(0.5))
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Collapse button for expanded gaps
            if isExpanded {
                Button(action: onToggle) {
                    HStack {
                        Text(durationText)
                            .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Text("gap")
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Image(systemName: "chevron.up")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var dashedLine: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(height: 1)
            .overlay(
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(.secondary.opacity(0.5))
            )
    }

    private var expandedHeight: CGFloat {
        let hours = duration / 3600
        return max(40, CGFloat(hours) * 50) // Scaled down for compressed view
    }

    private var durationText: String {
        formatDuration(duration)
    }
}

// MARK: - Now Marker View
struct NowMarkerView: View {
    @State private var pulseAnimation = false

    var body: some View {
        HStack {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: pulseAnimation
                )

            Rectangle()
                .fill(Color.red)
                .frame(height: 2)

            Text("Now")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.1))
                )
        }
        .onAppear {
            pulseAnimation = true
        }
    }
}

// MARK: - Helper Functions
private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60

    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)m"
    } else if hours > 0 {
        return "\(hours)h"
    } else {
        return "\(minutes)m"
    }
}

// MARK: - iOS Date Picker Sheet
struct iOSDatePicker: View {
    @Binding var selectedDate: Date
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
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