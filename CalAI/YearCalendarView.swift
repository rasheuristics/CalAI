import SwiftUI

struct YearCalendarView: View {
    @Binding var selectedDate: Date
    @ObservedObject var appearanceManager: AppearanceManager

    private let calendar = Calendar.current
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 20) {
                ForEach(monthGroups, id: \.0) { group in
                    YearMonthGroupView(
                        months: group.1,
                        selectedDate: $selectedDate,
                        appearanceManager: appearanceManager
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.clear)
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
    @ObservedObject var appearanceManager: AppearanceManager

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(months, id: \.self) { month in
                YearMonthView(
                    month: month,
                    selectedDate: $selectedDate,
                    appearanceManager: appearanceManager
                )
                .frame(height: 160)
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
    @ObservedObject var appearanceManager: AppearanceManager

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 8) {
            // Month name
            Text(monthName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 12)

            // Weekday headers
            HStack(spacing: 2) {
                ForEach(weekdayHeaders, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 16)
                }
            }
            .padding(.horizontal, 8)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(monthDays, id: \.self) { date in
                    YearDayCell(
                        date: date,
                        selectedDate: $selectedDate,
                        month: month,
                        appearanceManager: appearanceManager
                    )
                    .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(appearanceManager.glassOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isCurrentMonth ? Color.blue.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentMonth ? Color.blue.opacity(0.6) : Color.white.opacity(appearanceManager.strokeOpacity), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
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
    @ObservedObject var appearanceManager: AppearanceManager

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            if isToday {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 14, height: 14)
            } else if isSelected {
                Circle()
                    .stroke(Color.blue, lineWidth: 1)
                    .frame(width: 14, height: 14)
            }

            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 9, weight: isToday ? .bold : .medium))
                .foregroundColor(textColor)
        }
        .frame(width: 16, height: 16)
        .onTapGesture {
            selectedDate = date
        }
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