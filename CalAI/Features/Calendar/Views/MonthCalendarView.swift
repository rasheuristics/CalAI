import SwiftUI

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    @State private var visibleMonthDate: Date = Date()

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Fixed weekday header at top
            WeekdayHeader()

            // Scrollable date grid
            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ContinuousMonthGrid(
                                selectedDate: $selectedDate,
                                visibleMonthDate: $visibleMonthDate,
                                scrollViewHeight: geometry.size.height
                            )
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .onChange(of: visibleMonthDate) { newMonth in
                        // Update selectedDate to match the visible month
                        if !calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
                            selectedDate = newMonth
                        }
                    }
                    .onAppear {
                        // Scroll to current month on appear
                        let today = Date()
                        let monthKey = calendar.component(.year, from: today) * 12 + calendar.component(.month, from: today)
                        proxy.scrollTo(monthKey, anchor: .top)
                    }
                }
            }
        }
    }
}

// Fixed weekday header
struct WeekdayHeader: View {
    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 0) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
        }
        .background(Color(.systemGray6))
        .padding(.horizontal, 8)
    }
}

// Continuous scrolling grid showing multiple months
struct ContinuousMonthGrid: View {
    @Binding var selectedDate: Date
    @Binding var visibleMonthDate: Date
    let scrollViewHeight: CGFloat

    private let calendar = Calendar.current

    var body: some View {
        // Show 24 months: 12 past, current, 11 future
        ForEach(-12...11, id: \.self) { monthOffset in
            if let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: Date()) {
                GeometryReader { geo in
                    MonthSection(
                        monthDate: monthDate,
                        selectedDate: $selectedDate
                    )
                    .onAppear {
                        updateVisibleMonth(geo: geo, monthDate: monthDate)
                    }
                    .onChange(of: geo.frame(in: .named("scroll")).minY) { _ in
                        updateVisibleMonth(geo: geo, monthDate: monthDate)
                    }
                }
                .frame(minHeight: 300)
                .id(calendar.component(.year, from: monthDate) * 12 + calendar.component(.month, from: monthDate))
            }
        }
    }

    private func updateVisibleMonth(geo: GeometryProxy, monthDate: Date) {
        let frame = geo.frame(in: .named("scroll"))
        // Check if this month section is visible at the top of the scroll view
        // (within the first 100 points from the top, below the header)
        if frame.minY < 100 && frame.maxY > 50 {
            visibleMonthDate = monthDate
        }
    }
}

// Single month section with month label and dates
struct MonthSection: View {
    let monthDate: Date
    @Binding var selectedDate: Date

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Month label row (grid-based to align with day 1 below)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                // Empty cells before the month label
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(height: 50)
                }

                // Month label positioned above day 1
                Text(monthAbbreviation)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)

                // Fill remaining cells in the month label row
                ForEach((firstWeekdayOffset + 1)..<7, id: \.self) { _ in
                    Color.clear
                        .frame(height: 50)
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 8)

            // Date grid for this month
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                // Empty cells before first day of month (to align with weekday)
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(height: 50)
                }

                // Actual date cells (day 1 appears in column matching its weekday, directly below month label)
                ForEach(datesInMonth, id: \.self) { date in
                    SimpleMonthDayCell(date: date, selectedDate: $selectedDate)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: monthDate)
    }

    private var datesInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
            return []
        }

        var dates: [Date] = []
        var date = monthInterval.start

        while date < monthInterval.end {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        return dates
    }

    private var firstWeekdayOffset: Int {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
            return 0
        }

        let firstDayOfMonth = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        // weekday is 1-based (Sunday = 1), subtract 1 for 0-based offset
        return weekday - 1
    }
}

// Simple day cell for continuous month view
struct SimpleMonthDayCell: View {
    let date: Date
    @Binding var selectedDate: Date

    private let calendar = Calendar.current

    var body: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.system(size: 16))
            .fontWeight(isToday ? .bold : isCurrentWeek ? .semibold : .regular)
            .foregroundColor(isToday ? .white : .primary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                ZStack {
                    // Solid blue circle for today
                    if isToday {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                    }
                    // Outlined blue circle for current week (not today)
                    else if isCurrentWeek {
                        Circle()
                            .strokeBorder(Color.blue, lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                    }

                    // Light blue background for selected date (if not today)
                    if isSelected && !isToday {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 32, height: 32)
                    }
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedDate = date
            }
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var isCurrentWeek: Bool {
        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return false
        }
        return date >= weekInterval.start && date < weekInterval.end
    }

    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
}

// Legacy views kept for compatibility
struct FiveWeekBlock: View {
    @Binding var selectedDate: Date
    let baseDate: Date

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Days of week header
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .background(Color.gray.opacity(0.1))

            // 5 weeks grid
            ForEach(0..<5, id: \.self) { weekIndex in
                WeekRow(
                    selectedDate: $selectedDate,
                    weekStart: getWeekStart(offset: weekIndex)
                )
            }
        }
        .padding(.horizontal, 8)
    }

    private var weekdayHeaders: [String] {
        calendar.shortWeekdaySymbols
    }

    private func getWeekStart(offset: Int) -> Date {
        calendar.date(byAdding: .weekOfYear, value: offset, to: baseDate) ?? baseDate
    }
}

struct WeekRow: View {
    @Binding var selectedDate: Date
    let weekStart: Date

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { dayIndex in
                if let date = calendar.date(byAdding: .day, value: dayIndex, to: weekStart) {
                    DayCell(date: date, selectedDate: $selectedDate)
                }
            }
        }
    }
}

struct DayCell: View {
    let date: Date
    @Binding var selectedDate: Date

    private let calendar = Calendar.current

    var body: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.system(size: 16))
            .fontWeight(isToday ? .bold : isCurrentWeek ? .semibold : .regular)
            .foregroundColor(isToday ? .white : .primary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isToday ? Color.blue : Color.clear)
            .overlay(
                Circle()
                    .strokeBorder(isCurrentWeek && !isToday ? Color.blue : Color.clear, lineWidth: 1.5)
                    .padding(12)
            )
            .background(
                calendar.isDate(date, inSameDayAs: selectedDate) && !isToday ?
                Color.blue.opacity(0.1) : Color.clear
            )
            .onTapGesture {
                selectedDate = date
            }
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var isCurrentWeek: Bool {
        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return false
        }
        return date >= weekInterval.start && date < weekInterval.end
    }
}

struct SingleMonthView: View {
    @Binding var selectedDate: Date
    let displayDate: Date

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Month/Year header
            Text(dateFormatter.string(from: displayDate))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.bottom, 8)

            // Days of week header
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .background(Color.gray.opacity(0.1))

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                // Add empty cells for the days before the first day of the month
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Text("")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }

                ForEach(calendarDays, id: \.self) { date in
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            calendar.isDate(date, inSameDayAs: selectedDate) ?
                            Color.blue.opacity(0.3) : Color.clear
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                }
            }
        }
    }

    private var weekdayHeaders: [String] {
        let symbols = calendar.shortWeekdaySymbols
        return symbols
    }

    private var calendarDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayDate) else {
            return []
        }

        var days: [Date] = []
        var date = monthInterval.start

        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        return days
    }

    private func isDateInMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: displayDate, toGranularity: .month)
    }

    private var firstWeekdayOffset: Int {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayDate) else {
            return 0
        }

        let firstDayOfMonth = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        // weekday is 1-based (Sunday = 1), so we subtract 1 to get 0-based offset
        return weekday - 1
    }
}

// MonthDayCell moved to CalendarTabView.swift to match exact design requirements
