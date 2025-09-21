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
    @State private var currentViewType: CalendarViewType = .month
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
                        iOSDayView(selectedDate: $selectedDate, events: calendarManager.events, fontManager: fontManager)
                    case .week:
                        iOSWeekView(selectedDate: $selectedDate, events: calendarManager.events, fontManager: fontManager)
                    case .month:
                        iOSMonthView(selectedDate: $selectedDate, events: calendarManager.events, fontManager: fontManager)
                    case .year:
                        iOSYearView(selectedDate: $selectedDate, fontManager: fontManager)
                    }
                }
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

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(monthsInYear, id: \.self) { month in
                    YearMonthCard(
                        month: month,
                        selectedDate: $selectedDate,
                        fontManager: fontManager
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