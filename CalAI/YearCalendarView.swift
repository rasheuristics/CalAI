import SwiftUI

struct YearCalendarView: View {
    @Binding var selectedDate: Date

    private let calendar = Calendar.current
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 15) {
                ForEach(monthGroups, id: \.0) { group in
                    YearMonthGroupView(
                        months: group.1,
                        selectedDate: $selectedDate
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
    }

    // Group months into sets of 4 (2 rows of 2)
    private var monthGroups: [(Int, [Date])] {
        let yearStart = calendar.dateInterval(of: .year, for: selectedDate)?.start ?? selectedDate
        let allMonths = (0..<12).compactMap { monthOffset in
            calendar.date(byAdding: .month, value: monthOffset, to: yearStart)
        }

        var groups: [(Int, [Date])] = []
        for i in stride(from: 0, to: allMonths.count, by: 4) {
            let endIndex = min(i + 4, allMonths.count)
            let monthsInGroup = Array(allMonths[i..<endIndex])
            groups.append((i / 4, monthsInGroup))
        }

        return groups
    }
}

struct YearMonthGroupView: View {
    let months: [Date]
    @Binding var selectedDate: Date

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            ForEach(months, id: \.self) { month in
                YearMonthView(
                    month: month,
                    selectedDate: $selectedDate
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    selectedDate = month
                }
            }
        }
    }
}

struct YearMonthView: View {
    let month: Date
    @Binding var selectedDate: Date

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            // Month name
            Text(monthName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            // Mini calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                // Weekday headers (abbreviated)
                ForEach(weekdayHeaders, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Calendar days
                ForEach(monthDays, id: \.self) { date in
                    YearDayCell(
                        date: date,
                        selectedDate: $selectedDate,
                        month: month
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentMonth ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCurrentMonth ? Color.blue : Color.clear, lineWidth: 1)
                )
        )
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }

    private var weekdayHeaders: [String] {
        ["S", "M", "T", "W", "T", "F", "S"]
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: selectedDate, toGranularity: .month)
    }

    private var monthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
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
}

struct YearDayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let month: Date

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isToday {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            } else if isSelected {
                Circle()
                    .stroke(Color.blue, lineWidth: 1)
                    .frame(width: 10, height: 10)
            }

            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    private var textColor: Color {
        if isToday {
            return .white
        } else if !isCurrentMonth {
            return .clear
        } else {
            return .primary
        }
    }
}