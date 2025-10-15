import SwiftUI

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    
    @State private var topMonth: Date
    
    private var months: [Date]
    private let calendar = Calendar.current

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._topMonth = State(initialValue: Calendar.current.startOfMonth(for: selectedDate.wrappedValue) ?? Date())
        
        let today = calendar.startOfDay(for: Date())
        var monthArray: [Date] = []
        for i in -24...24 {
            if let month = calendar.date(byAdding: .month, value: i, to: today) {
                if let startOfMonth = calendar.startOfMonth(for: month) {
                    monthArray.append(startOfMonth)
                }
            }
        }
        self.months = monthArray
    }

    var body: some View {
        VStack(spacing: 0) {
            WeekdayHeader()
                .padding(.horizontal, 8)
                .background(Color(.systemBackground).opacity(0.8))
                .zIndex(1)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 30) {
                        ForEach(months, id: \.self) { month in
                            SingleMonthBlockView(monthDate: month, selectedDate: $selectedDate)
                                .id(month)
                                .background(
                                    GeometryReader { geo -> Color in
                                        let frame = geo.frame(in: .named("scroll"))
                                        if frame.minY < 100 && frame.minY > -100 {
                                            DispatchQueue.main.async {
                                                self.topMonth = month
                                            }
                                        }
                                        return Color.clear
                                    }
                                )
                        }
                    }
                    .padding(.top, 20)
                }
                .coordinateSpace(name: "scroll")
                .onAppear {
                    if let today = Calendar.current.startOfMonth(for: Date()) {
                        proxy.scrollTo(today, anchor: .center)
                    }
                }
                .onChange(of: topMonth) { newMonth in
                    if !calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
                        selectedDate = newMonth
                    }
                }
                .onChange(of: selectedDate) { newDate in
                    // If the date is set to today (e.g., by the "Today" button), scroll to the current month.
                    if calendar.isDateInToday(newDate) {
                        if let currentMonth = calendar.startOfMonth(for: Date()) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(currentMonth, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

private struct WeekdayHeader: View {
    private let calendar = Calendar.current
    var body: some View {
        HStack(spacing: 0) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct SingleMonthBlockView: View {
    let monthDate: Date
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    private let monthFormatter: DateFormatter
    
    private var days: [Date] { calendar.daysInMonth(for: monthDate) }
    private var startingSpaces: Int { calendar.firstWeekdayOffset(for: monthDate) }
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    init(monthDate: Date, selectedDate: Binding<Date>) {
        self.monthDate = monthDate
        self._selectedDate = selectedDate
        self.monthFormatter = DateFormatter()
        self.monthFormatter.dateFormat = "MMM"
    }

    var body: some View {
        VStack(spacing: 10) {
            // Grid for the month identifier
            LazyVGrid(columns: columns) {
                ForEach(0..<startingSpaces, id: \.self) { _ in
                    Color.clear.frame(height: 1) // Occupy space but be invisible
                }
                Text(monthFormatter.string(from: monthDate))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Grid for the days of the month
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<startingSpaces, id: \.self) { _ in
                    Color.clear
                }
                ForEach(days, id: \.self) { day in
                    SimpleMonthDayCell(date: day, selectedDate: $selectedDate)
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct SimpleMonthDayCell: View {
    let date: Date
    @Binding var selectedDate: Date

    private let calendar = Calendar.current
    private var isToday: Bool { calendar.isDateInToday(date) }
    private var isSelected: Bool { calendar.isDate(date, inSameDayAs: selectedDate) }

    var body: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.system(size: 18))
            .fontWeight(isToday ? .bold : .regular)
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(backgroundCircle)
            .contentShape(Rectangle())
            .onTapGesture { selectedDate = date }
    }
    
    private var textColor: Color {
        if isSelected { return .white }
        if isToday { return .white }
        return .primary
    }
    
    @ViewBuilder
    private var backgroundCircle: some View {
        if isSelected {
            Circle().fill(Color.blue)
        } else if isToday {
            Circle().fill(Color.red)
        }
    }
}

// MARK: - Calendar Helpers

fileprivate extension Calendar {
    func daysInMonth(for date: Date) -> [Date] {
        guard let monthInterval = dateInterval(of: .month, for: date),
              let days = dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day else {
            return []
        }
        var dates: [Date] = []
        for dayOffset in 0..<days {
            if let newDate = self.date(byAdding: .day, value: dayOffset, to: monthInterval.start) {
                dates.append(newDate)
            }
        }
        return dates
    }
    
    func firstWeekdayOffset(for date: Date) -> Int {
        guard let firstDayOfMonth = startOfMonth(for: date) else {
            return 0
        }
        let weekday = component(.weekday, from: firstDayOfMonth)
        return (weekday - firstWeekday + 7) % 7
    }
}
