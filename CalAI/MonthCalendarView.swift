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

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                ForEach(calendarDays, id: \.self) { date in
                    MonthDayCell(
                        date: date,
                        selectedDate: $selectedDate,
                        isCurrentMonth: calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .onTapGesture {
                        selectedDate = date
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
}

struct MonthDayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let isCurrentMonth: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: isToday ? .bold : .regular))
                .foregroundColor(textColor)
                .frame(width: 28, height: 28)
                .background(backgroundColor)
                .clipShape(Circle())

            // Dot indicator for events would go here in full implementation
            Circle()
                .fill(Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Rectangle()
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1),
            alignment: .bottom
        )
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1),
            alignment: .trailing
        )
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private var textColor: Color {
        if isToday {
            return .white
        } else if !isCurrentMonth {
            return .secondary
        } else {
            return .primary
        }
    }

    private var backgroundColor: Color {
        if isToday {
            return .blue
        } else {
            return .clear
        }
    }
}