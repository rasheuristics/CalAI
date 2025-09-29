import SwiftUI

struct MonthCalendarView: View {
    @Binding var selectedDate: Date

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 8) {
            // First Month
            SingleMonthView(
                selectedDate: $selectedDate,
                displayDate: selectedDate
            )
            .frame(maxHeight: .infinity)

            // Second Month (next month)
            SingleMonthView(
                selectedDate: $selectedDate,
                displayDate: nextMonth
            )
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }

    private var nextMonth: Date {
        calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
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