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
        .background(Color(.systemGroupedBackground))
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

// MARK: - iOS Month View (Exact Replica)
struct iOSMonthView: View {
    @Binding var selectedDate: Date
    let events: [EKEvent]
    @ObservedObject var fontManager: FontManager
    @State private var dragOffset: CGSize = .zero

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Week day headers - exact iOS style
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .scaledFont(.caption, fontManager: fontManager)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))

            // Calendar grid - exact iOS layout
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(monthDates, id: \.self) { date in
                    iOSDateCell(
                        date: date,
                        selectedDate: $selectedDate,
                        currentMonth: calendar.component(.month, from: selectedDate),
                        events: eventsForDate(date),
                        fontManager: fontManager
                    )
                }
            }
            .padding(.horizontal, 16)
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        withAnimation(.easeOut(duration: 0.3)) {
                            if value.translation.width > threshold {
                                // Swipe right - previous month
                                selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                            } else if value.translation.width < -threshold {
                                // Swipe left - next month
                                selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                            }
                            dragOffset = .zero
                        }
                    }
            )

            Spacer()
        }
        .background(Color(.systemBackground))
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
            // Week header with dates
            HStack(spacing: 0) {
                // Time column spacer
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 50)

                // Week days
                ForEach(weekDates, id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(dayOfWeekSymbol(for: date))
                            .scaledFont(.caption2, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Text("\(calendar.component(.day, from: date))")
                            .scaledFont(.callout, fontManager: fontManager)
                            .foregroundColor(isToday(date) ? .red : .primary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(isSelected(date) ? .blue : .clear)
                            )
                            .foregroundColor(isSelected(date) ? .white : (isToday(date) ? .red : .primary))
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            // Time grid
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        HStack(alignment: .top, spacing: 0) {
                            // Hour label
                            VStack {
                                if hour == 0 {
                                    Text("12 AM")
                                        .scaledFont(.caption2, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                } else if hour < 12 {
                                    Text("\(hour) AM")
                                        .scaledFont(.caption2, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                } else if hour == 12 {
                                    Text("12 PM")
                                        .scaledFont(.caption2, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(hour - 12) PM")
                                        .scaledFont(.caption2, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .frame(width: 50, height: hourHeight)

                            // Days columns
                            ForEach(weekDates, id: \.self) { date in
                                VStack {
                                    Divider()
                                        .opacity(0.3)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, minHeight: hourHeight)
                                .overlay(
                                    VStack(spacing: 1) {
                                        ForEach(eventsForDateAndHour(date, hour), id: \.eventIdentifier) { event in
                                            iOSWeekEventView(event: event, fontManager: fontManager)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                    , alignment: .topLeading
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.systemBackground))
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

    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func eventsForDateAndHour(_ date: Date, _ hour: Int) -> [EKEvent] {
        return events.filter { event in
            let eventHour = calendar.component(.hour, from: event.startDate)
            return calendar.isDate(event.startDate, inSameDayAs: date) && eventHour == hour
        }
    }
}

// MARK: - iOS Day View (Exact Replica)
struct iOSDayView: View {
    @Binding var selectedDate: Date
    let events: [EKEvent]
    @ObservedObject var fontManager: FontManager

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Date header
                    VStack(spacing: 4) {
                        Text(dayOfWeekText)
                            .scaledFont(.caption, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Text(dayNumberText)
                            .scaledFont(.largeTitle, fontManager: fontManager)
                            .foregroundColor(isToday ? .red : .primary)
                    }
                    .padding(.vertical, 16)

                    // Hour grid
                    LazyVStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 0) {
                                // Hour label
                                VStack {
                                    if hour == 0 {
                                        Text("12 AM")
                                            .scaledFont(.caption, fontManager: fontManager)
                                            .foregroundColor(.secondary)
                                    } else if hour < 12 {
                                        Text("\(hour) AM")
                                            .scaledFont(.caption, fontManager: fontManager)
                                            .foregroundColor(.secondary)
                                    } else if hour == 12 {
                                        Text("12 PM")
                                            .scaledFont(.caption, fontManager: fontManager)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("\(hour - 12) PM")
                                            .scaledFont(.caption, fontManager: fontManager)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .frame(width: 50, height: hourHeight)

                                // Hour content area
                                VStack {
                                    Divider()
                                    Spacer()
                                }
                                .frame(height: hourHeight)
                                .overlay(
                                    // Events for this hour
                                    VStack(spacing: 2) {
                                        ForEach(eventsForHour(hour), id: \.eventIdentifier) { event in
                                            iOSDayEventView(event: event, fontManager: fontManager)
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                    , alignment: .topLeading
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                // Scroll to current time
                let currentHour = calendar.component(.hour, from: Date())
                proxy.scrollTo(currentHour, anchor: .top)
            }
        }
        .background(Color(.systemBackground))
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

    private var isToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: Date())
    }

    private func eventsForHour(_ hour: Int) -> [EKEvent] {
        return events.filter { event in
            let eventHour = calendar.component(.hour, from: event.startDate)
            return calendar.isDate(event.startDate, inSameDayAs: selectedDate) && eventHour == hour
        }
    }
}

// MARK: - iOS Year View (Exact Replica)
struct iOSYearView: View {
    @Binding var selectedDate: Date
    @ObservedObject var fontManager: FontManager

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(monthsInYear, id: \.self) { month in
                    iOSYearMonthView(
                        month: month,
                        selectedDate: $selectedDate,
                        fontManager: fontManager
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemBackground))
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

struct iOSYearMonthView: View {
    let month: Date
    @Binding var selectedDate: Date
    @ObservedObject var fontManager: FontManager

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            // Month name
            Text(monthName)
                .scaledFont(.caption, fontManager: fontManager)
                .foregroundColor(.primary)

            // Mini calendar grid
            VStack(spacing: 2) {
                // Week day headers
                HStack(spacing: 0) {
                    ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { day in
                        Text(day)
                            .scaledFont(.caption2, fontManager: fontManager)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar days
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                    ForEach(monthDates, id: \.self) { date in
                        Button(action: {
                            selectedDate = date
                        }) {
                            Text("\(calendar.component(.day, from: date))")
                                .scaledFont(.caption2, fontManager: fontManager)
                                .foregroundColor(textColor(for: date))
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(backgroundFill(for: date))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }

    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
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

    private func textColor(for date: Date) -> Color {
        if isSelected(date) {
            return .white
        } else if isToday(date) {
            return .red
        } else if isCurrentMonth(date) {
            return .primary
        } else {
            return .secondary
        }
    }

    private func backgroundFill(for date: Date) -> Color {
        if isSelected(date) {
            return .blue
        } else if isToday(date) {
            return Color(.systemGray5)
        } else {
            return .clear
        }
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
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