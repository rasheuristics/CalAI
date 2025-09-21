import SwiftUI

struct MonthCalendarView: View {
    @Binding var selectedDate: Date

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Days of week header
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { weekday in
                    Text(weekday)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            // Calendar grid - Two column layout
            HStack(spacing: 0) {
                // First column (weeks 1-3)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                    ForEach(firstColumnDays, id: \.self) { date in
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .onTapGesture {
                                selectedDate = date
                            }
                    }
                }

                // Second column (weeks 4-6)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                    ForEach(secondColumnDays, id: \.self) { date in
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .onTapGesture {
                                selectedDate = date
                            }
                    }
                }
            }

            Spacer()
        }
    }

    private var weekdayHeaders: [String] {
        let symbols = calendar.shortWeekdaySymbols
        return symbols
    }

    private var calendarDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end - 1) else {
            return []
        }

        var days: [Date] = []
        var date = monthFirstWeek.start

        while date < monthLastWeek.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        return days
    }

    private var firstColumnDays: [Date] {
        let days = calendarDays
        let weeksInFirstColumn = 3
        let daysPerWeek = 7
        return Array(days.prefix(weeksInFirstColumn * daysPerWeek))
    }

    private var secondColumnDays: [Date] {
        let days = calendarDays
        let weeksInFirstColumn = 3
        let daysPerWeek = 7
        return Array(days.dropFirst(weeksInFirstColumn * daysPerWeek))
    }
}

// MonthDayCell moved to CalendarTabView.swift to match exact design requirements