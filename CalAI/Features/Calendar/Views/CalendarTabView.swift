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
    @ObservedObject var appearanceManager: AppearanceManager
    @State private var selectedDate = Date()
    @State private var currentViewType: CalendarViewType = .day
    @State private var showingDatePicker = false
    @State private var selectedEventForDetail: UnifiedEvent? = nil
    @State private var showEventDetail = false
    @State private var selectedEventForEdit: UnifiedEvent? = nil
    @State private var showingEditView = false
    @State private var selectedEventForShare: UnifiedEvent? = nil
    @State private var showingShareView = false
    @State private var showingConflictList = false

    private let eventFilterService = EventFilterService()

    var body: some View {
        ZStack {
            // Transparent background to show main gradient
            Color.clear
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Error banner (if present)
                if let error = calendarManager.errorState {
                    ErrorBannerView(
                        error: error,
                        onRetry: {
                            calendarManager.retryLastOperation()
                        },
                        onDismiss: {
                            calendarManager.dismissError()
                        }
                    )
                    .zIndex(1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: calendarManager.errorState)
                }

                // Conflict alert banner
                if !calendarManager.detectedConflicts.isEmpty {
                    ConflictAlertBanner(
                        conflictCount: calendarManager.detectedConflicts.count,
                        onTap: {
                            showingConflictList = true
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: calendarManager.detectedConflicts.count)
                }

                // Native iOS Calendar Header
                iOSCalendarHeader(
                    selectedDate: $selectedDate,
                    currentViewType: $currentViewType,
                    showingDatePicker: $showingDatePicker,
                    fontManager: fontManager,
                    calendarManager: calendarManager
                )

                // Main calendar content
                Group {
                    if calendarManager.isLoading && calendarManager.unifiedEvents.isEmpty {
                        // Show loading skeleton when initially loading
                        LoadingSkeletonView()
                    } else {
                        switch currentViewType {
                        case .day:
                            let dayEvents = unifiedEventsForDate(selectedDate)
                            if dayEvents.isEmpty && !calendarManager.isLoading {
                                EmptyStateView(
                                    icon: "calendar",
                                    title: isToday(selectedDate) ? "No Events Today" : "No Events",
                                    message: isToday(selectedDate) ? "Your calendar is clear for today." : "No events scheduled for this day."
                                )
                            } else {
                                CompressedDayTimelineView(
                                    date: selectedDate, // Show selected day
                                    events: dayEvents.map { TimelineEvent(from: $0) },
                                    fontManager: fontManager,
                                    isWeekView: false,
                                    refreshTrigger: calendarManager.unifiedEvents.map { "\($0.id)-\($0.startDate.timeIntervalSince1970)" }.joined(),
                                    onEventTap: { calendarEvent in
                                        // Find the corresponding UnifiedEvent
                                        if let unifiedEvent = calendarManager.unifiedEvents.first(where: { $0.id == calendarEvent.id }) {
                                            print("📱 Opening EditEventView for: \(unifiedEvent.title)")
                                            selectedEventForEdit = unifiedEvent
                                            showingEditView = true
                                        }
                                    }
                                )
                                .id("\(selectedDate.timeIntervalSince1970)-\(calendarManager.unifiedEvents.count)") // Force recreation on date change OR event count change
                            }
                        case .week:
                            WeekViewWithCompressedTimeline(
                                selectedDate: $selectedDate,
                                events: calendarManager.unifiedEvents,
                                fontManager: fontManager,
                                calendarManager: calendarManager,
                                onEventTap: { calendarEvent in
                                    // Find the corresponding UnifiedEvent
                                    if let unifiedEvent = calendarManager.unifiedEvents.first(where: { $0.id == calendarEvent.id }) {
                                        print("📱 Opening EditEventView for: \(unifiedEvent.title)")
                                        selectedEventForEdit = unifiedEvent
                                        showingEditView = true
                                    }
                                }
                            )
                        case .month:
                            MonthCalendarView(selectedDate: $selectedDate)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .year:
                            iOSYearView(
                                selectedDate: $selectedDate,
                                fontManager: fontManager,
                                appearanceManager: appearanceManager,
                                onMonthDoubleClick: { month in
                                    selectedDate = month
                                    currentViewType = .month
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showEventDetail) {
            if let event = selectedEventForDetail {
                EventDetailView(
                    calendarManager: calendarManager,
                    fontManager: fontManager,
                    event: event
                )
            }
        }
        .sheet(isPresented: $showingEditView) {
            if let event = selectedEventForEdit {
                EventManagementView(
                    calendarManager: calendarManager,
                    fontManager: fontManager,
                    event: event
                )
            }
        }
        .sheet(isPresented: $showingShareView) {
            if let event = selectedEventForShare {
                EventShareView(
                    event: event,
                    calendarManager: calendarManager,
                    fontManager: fontManager
                )
            }
        }
        .sheet(isPresented: $showingConflictList) {
            ConflictListView(calendarManager: calendarManager, fontManager: fontManager)
        }
        .sheet(isPresented: $calendarManager.showingAddEventFromCalendar) {
            AddEventView(calendarManager: calendarManager, fontManager: fontManager)
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
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func unifiedEventsForDate(_ date: Date) -> [UnifiedEvent] {
        let filtered = eventFilterService.filterUnifiedEvents(calendarManager.unifiedEvents, for: date)

        // Remove duplicates - events with same id AND startDate (handles recurring events)
        let unique = filtered.reduce(into: [UnifiedEvent]()) { result, event in
            if !result.contains(where: { $0.id == event.id && $0.startDate == event.startDate }) {
                result.append(event)
            }
        }

        if filtered.count != unique.count {
            print("🔍 unifiedEventsForDate: filtered \(filtered.count) -> unique \(unique.count) events for \(date)")
        }

        return unique
    }

    // Check if an event has conflicts
    private func eventHasConflict(_ eventId: String) -> ScheduleConflict? {
        return calendarManager.detectedConflicts.first { conflict in
            conflict.conflictingEvents.contains { $0.id == eventId }
        }
    }
}

// MARK: - Native iOS Calendar Header
struct iOSCalendarHeader: View {
    @Binding var selectedDate: Date
    @Binding var currentViewType: CalendarViewType
    @Binding var showingDatePicker: Bool
    @ObservedObject var fontManager: FontManager
    @ObservedObject var calendarManager: CalendarManager
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // Top bar with month/year and view switcher
                HStack(alignment: .top) {
                    // Month/Year button
                    Button(action: {
                        HapticManager.shared.light()
                        showingDatePicker = true
                    }) {
                        Text(monthYearText)
                            .font(.system(.title3, design: .default).bold())
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Current date: \(monthYearText)")
                    .accessibilityHint("Double tap to open date picker")

                    Spacer()

                    // Refresh button
                    Button(action: refreshCalendar) {
                        Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel("Refresh calendar")
                    .padding(.trailing, 8)

                    Spacer().frame(width: 8)

                    // View switcher - exact iOS style
                    HStack(spacing: 0) {
                        ForEach(CalendarViewType.allCases, id: \.self) { viewType in
                            Button(action: {
                                HapticManager.shared.selection()
                                currentViewType = viewType
                            }) {
                                Text(viewType.rawValue.first?.uppercased() ?? "")
                                    .scaledFont(.footnote, fontManager: fontManager)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(currentViewType == viewType ? Color.blue : Color.clear)
                                    )
                                    .foregroundColor(currentViewType == viewType ? .white : .blue)
                            }
                            .accessibilityLabel("\(viewType.rawValue) view")
                            .accessibilityHint("Switch to \(viewType.rawValue) calendar view")
                            .accessibilityAddTraits(currentViewType == viewType ? .isSelected : [])
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                            .frame(height: 32)
                    )
                }

                // Navigation bar with Today button, arrows, and + button
                HStack {
                    Button("Today") {
                        HapticManager.shared.medium()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedDate = Date()
                        }
                    }
                    .scaledFont(.callout, fontManager: fontManager)
                    .foregroundColor(.red)
                    .accessibilityLabel("Today")
                    .accessibilityHint("Jump to today's date")

                    Spacer()

                    // Only show arrows for Day, Month, and Year views (not Week)
                    if currentViewType != .week {
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

                    // Add Event button (right side, aligned with 2025 above)
                    Button(action: {
                        HapticManager.shared.light()
                        calendarManager.showingAddEventFromCalendar = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Add Event")
                    .accessibilityHint("Create a new calendar event")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Color.white.opacity(0.15))
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

    private func refreshCalendar() {
        guard !isRefreshing else { return }

        HapticManager.shared.light()
        isRefreshing = true

        print("🔄 Manual refresh triggered from UI")
        calendarManager.loadAllUnifiedEvents()

        // Stop animation after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRefreshing = false
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
    let onEventTap: (EKEvent) -> Void

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
                        DayEventCard(event: event) {
                            onEventTap(event)
                        }
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
        formatter.dateFormat = "EEEEE"
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
    let onEventTap: (EKEvent) -> Void

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
                        DayEventCard(event: event) {
                            onEventTap(event)
                        }
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
    let onTap: () -> Void

    @StateObject private var taskManager = EventTaskManager.shared

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
                HStack {
                    Text(event.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)

                    Spacer()

                    // Task Badge
                    TaskBadgeView(count: taskManager.getPendingTaskCount(for: event.eventIdentifier))
                }

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onTapGesture {
            onTap()
        }
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
    @ObservedObject var appearanceManager: AppearanceManager
    let onMonthDoubleClick: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(monthsInYear, id: \.self) { month in
                    YearMonthCard(
                        month: month,
                        selectedDate: $selectedDate,
                        fontManager: fontManager,
                        appearanceManager: appearanceManager,
                        onDoubleClick: onMonthDoubleClick
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color.clear)
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
    @ObservedObject var appearanceManager: AppearanceManager
    let onDoubleClick: (Date) -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            // Month name
            Text(monthName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 6)

            // Mini calendar grid
            VStack(spacing: 1) {
                // Week day headers
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 18)
                    }
                }

                // Calendar days
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 0), count: 7), spacing: 2) {
                    ForEach(monthDates, id: \.self) { date in
                        Button(action: {
                            selectedDate = date
                        }) {
                            Text(dayText(for: date))
                                .font(.system(size: 12, weight: .semibold))
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
        .padding(12)
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
        .onTapGesture(count: 2) {
            onDoubleClick(month)
        }
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month).uppercased()
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: selectedDate, toGranularity: .month)
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
        } else if isToday(date) && isCurrentMonth(date) {
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
        } else if isToday(date) && isCurrentMonth(date) {
            return .blue.opacity(0.1)
        } else {
            return .clear
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        // Only show selection if the date matches AND it's in the current month card
        calendar.isDate(date, inSameDayAs: selectedDate) && isCurrentMonth(date)
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
    @ObservedObject var calendarManager: CalendarManager
    var onEventTap: ((CalendarEvent) -> Void)? = nil

    private let calendar = Calendar.current
    private let eventFilterService = EventFilterService()
    @State private var dragTargetDay: Date? = nil // Track which day is being targeted by drag
    @State private var swipeDragOffset: CGFloat = 0 // Unified drag offset for both header and timeline
    @State private var isDragging = false
    @State private var gestureDirection: GestureDirection = .none
    @State private var isTransitioning = false // Prevent rapid swipes during transition
    @State private var swipeProgress: CGFloat = 0 // 0 to 1 progress for visual feedback

    // Week expansion state
    @State private var isWeekExpanded = false
    @State private var weekExpansionDragOffset: CGFloat = 0
    private let collapsedHeaderHeight: CGFloat = 72
    private let expandedHeaderHeight: CGFloat = 292

    private var weekHeaderHeight: CGFloat {
        return isWeekExpanded ? expandedHeaderHeight : collapsedHeaderHeight
    }

    enum GestureDirection {
        case none
        case horizontal
        case vertical
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Timeline view (always rendered, overlaid by expanded calendar)
            VStack(spacing: 0) {
                // Spacer for week header
                Color.clear
                    .frame(height: weekHeaderHeight)

                weekTimelineView()
            }

            // Expandable week header - overlays timeline when expanded
            VStack(spacing: 0) {
                // Day names row (always visible)
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        Text(Calendar.current.shortWeekdaySymbols[dayIndex])
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
                .background(Color(.systemGray6))

                // Date grid - 1 row when collapsed, 5 rows when expanded
                VStack(spacing: 0) {
                    ForEach(0..<(isWeekExpanded ? 5 : 1), id: \.self) { weekIndex in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                if let date = dateForExpandableGrid(week: weekIndex, day: dayIndex) {
                                    expandableDateCell(for: date, isInCurrentWeek: weekIndex == (isWeekExpanded ? 2 : 0))
                                }
                            }
                        }
                        .frame(height: 44)
                    }
                }
                .background(Color(.systemGray6))

                // Draggable handle (attached to bottom of week header)
                weekExpansionHandleView()
            }
            .background(Color(.systemGray6))
            .shadow(color: Color.black.opacity(isWeekExpanded ? 0.1 : 0), radius: 8, x: 0, y: 4)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Prevent gestures during transitions
                    guard !isTransitioning else { return }

                    let horizontalAmount = abs(value.translation.width)
                    let verticalAmount = abs(value.translation.height)

                    // Determine gesture direction on first movement
                    if gestureDirection == .none && (horizontalAmount > 10 || verticalAmount > 10) {
                        gestureDirection = horizontalAmount > verticalAmount ? .horizontal : .vertical
                    }

                    // Only process horizontal swipes
                    if gestureDirection == .horizontal && horizontalAmount > 20 {
                        isDragging = true

                        // Apply rubber-band effect at extremes (dampen beyond full screen width)
                        let screenWidth = UIScreen.main.bounds.width
                        let rawOffset = value.translation.width
                        let dampingFactor: CGFloat = 0.3 // Resistance beyond screen width

                        if abs(rawOffset) > screenWidth {
                            // Apply damping for over-scroll
                            let excess = abs(rawOffset) - screenWidth
                            let dampedExcess = excess * dampingFactor
                            swipeDragOffset = rawOffset > 0 ? screenWidth + dampedExcess : -(screenWidth + dampedExcess)
                        } else {
                            swipeDragOffset = rawOffset
                        }

                        // Calculate progress (0 to 1) based on distance to threshold
                        let threshold = screenWidth / 2
                        swipeProgress = min(abs(value.translation.width) / threshold, 1.0)
                    }
                }
                .onEnded { value in
                    guard !isTransitioning else { return }

                    if gestureDirection == .horizontal {
                        handleSwipeDragEnd(translation: value.translation.width, predictedEndTranslation: value.predictedEndTranslation.width)
                    }

                    // Reset gesture state
                    isDragging = false
                    swipeDragOffset = 0
                    swipeProgress = 0
                    gestureDirection = .none
                }
        )
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.8), value: swipeDragOffset)
        .onAppear {
            setupDragListener()
        }
    }

    private func handleSwipeDragEnd(translation: CGFloat, predictedEndTranslation: CGFloat) {
        let screenWidth = UIScreen.main.bounds.width
        let distanceThreshold = screenWidth / 2 // Midpoint of screen

        // Calculate velocity from predicted end translation
        let velocity = abs(predictedEndTranslation - translation)
        let velocityThreshold: CGFloat = 100 // Points per second threshold

        // Quick swipe with high velocity requires less distance
        let isQuickSwipe = velocity > velocityThreshold
        let effectiveThreshold = isQuickSwipe ? screenWidth / 3 : distanceThreshold

        if abs(translation) > effectiveThreshold {
            // Passed threshold - smoothly complete the transition
            isTransitioning = true
            HapticManager.shared.light()

            // Update date first
            if translation > 0 {
                // Swiped right - go to previous day
                if let newDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
                    selectedDate = newDate
                }
                // Animate: old page was at 0, new page comes from left (-screenWidth), slides to 0
                swipeDragOffset = -screenWidth
            } else {
                // Swiped left - go to next day
                if let newDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
                    selectedDate = newDate
                }
                // Animate: old page was at 0, new page comes from right (+screenWidth), slides to 0
                swipeDragOffset = screenWidth
            }

            // Animate new page sliding smoothly into center
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
                swipeDragOffset = 0
            }

            // Re-enable gestures after full transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTransitioning = false
            }
        } else {
            // Didn't pass threshold - slide back to current day with haptic feedback
            HapticManager.shared.light()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                swipeDragOffset = 0
            }

            // Reset transition flag after snap-back
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isTransitioning = false
            }
        }
    }

    private func setupDragListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WeekViewDragUpdate"),
            object: nil,
            queue: .main
        ) { notification in
            if let dayChange = notification.userInfo?["dayChange"] as? Int {
                // Calculate target day based on current selected date and day change
                if let targetDay = calendar.date(byAdding: .day, value: dayChange, to: selectedDate) {
                    dragTargetDay = targetDay
                }
            } else {
                dragTargetDay = nil
            }
        }
    }

    private func isDragTarget(_ day: Date) -> Bool {
        guard let dragTargetDay = dragTargetDay else { return false }
        return calendar.isDate(day, inSameDayAs: dragTargetDay)
    }

    @ViewBuilder
    private func dateNumberView(for day: Date) -> some View {
        Text("\(calendar.component(.day, from: day))")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(isSelected(day) ? .white : (isToday(day) ? .red : .primary))
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(isSelected(day) ? Color.blue : (isToday(day) ? Color.red.opacity(0.1) : Color.clear))
            )
            .frame(maxWidth: .infinity)
            .onTapGesture {
                selectedDate = day
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

    private var previousWeekDays: [Date] {
        guard let previousWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate),
              let weekInterval = calendar.dateInterval(of: .weekOfYear, for: previousWeekDate) else {
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

    private var nextWeekDays: [Date] {
        guard let nextWeekDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate),
              let weekInterval = calendar.dateInterval(of: .weekOfYear, for: nextWeekDate) else {
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

    private var previousDay: Date {
        calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    private var nextDay: Date {
        calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    private func dayOfWeekSymbol(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
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
        let filtered = eventFilterService.filterUnifiedEvents(events, for: date)

        // Remove duplicates - events with same id AND startDate (handles recurring events)
        let unique = filtered.reduce(into: [UnifiedEvent]()) { result, event in
            if !result.contains(where: { $0.id == event.id && $0.startDate == event.startDate }) {
                result.append(event)
            }
        }

        if filtered.count != unique.count {
            print("🔍 eventsForDate: filtered \(filtered.count) -> unique \(unique.count) events for \(date)")
        }

        return unique
    }

    // MARK: - Week View Components

    @ViewBuilder
    private func weekTimelineView() -> some View {
        // Timeline carousel (3 days: prev, current, next)
        ZStack {
            // Previous day timeline
            CompressedDayTimelineView(
                date: previousDay,
                events: eventsForDate(previousDay).map { TimelineEvent(from: $0) },
                fontManager: fontManager,
                isWeekView: true,
                refreshTrigger: calendarManager.unifiedEvents.map { "\($0.id)-\($0.startDate.timeIntervalSince1970)" }.joined(),
                onEventTap: onEventTap
            )
            .id("\(previousDay.timeIntervalSince1970)-\(calendarManager.unifiedEvents.count)")
            .offset(x: -UIScreen.main.bounds.width + swipeDragOffset)
            .opacity(swipeDragOffset > 0 ? 0.3 + (swipeProgress * 0.7) : 1.0)

            // Current day timeline
            CompressedDayTimelineView(
                date: selectedDate,
                events: eventsForDate(selectedDate).map { TimelineEvent(from: $0) },
                fontManager: fontManager,
                isWeekView: true,
                refreshTrigger: calendarManager.unifiedEvents.map { "\($0.id)-\($0.startDate.timeIntervalSince1970)" }.joined(),
                onEventTap: onEventTap
            )
            .id("\(selectedDate.timeIntervalSince1970)-\(calendarManager.unifiedEvents.count)")
            .offset(x: swipeDragOffset)
            .scaleEffect(1.0 - (swipeProgress * 0.05)) // Subtle scale effect

            // Next day timeline
            CompressedDayTimelineView(
                date: nextDay,
                events: eventsForDate(nextDay).map { TimelineEvent(from: $0) },
                fontManager: fontManager,
                isWeekView: true,
                refreshTrigger: calendarManager.unifiedEvents.map { "\($0.id)-\($0.startDate.timeIntervalSince1970)" }.joined(),
                onEventTap: onEventTap
            )
            .id("\(nextDay.timeIntervalSince1970)-\(calendarManager.unifiedEvents.count)")
            .offset(x: UIScreen.main.bounds.width + swipeDragOffset)
            .opacity(swipeDragOffset < 0 ? 0.3 + (swipeProgress * 0.7) : 1.0)
        }
        .onChange(of: selectedDate) { newDate in
            // Force timeline rebuild when date changes
            // Trigger lazy loading if approaching date boundaries
            calendarManager.loadAdditionalMonthsIfNeeded(for: newDate)
        }
    }

    @ViewBuilder
    private func expandableDateCell(for date: Date, isInCurrentWeek: Bool) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: Date())
        let isTodaysWeek = isDateInCurrentWeek(date)

        Text("\(dayNumber)")
            .font(.system(size: 18, weight: isToday ? .bold : isTodaysWeek ? .semibold : .regular))
            .foregroundColor(isToday ? .white : .primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    // Solid blue circle for today
                    if isToday {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                    }
                    // Outlined blue circle for other days in current week
                    else if isTodaysWeek {
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
                HapticManager.shared.light()
            }
    }

    private func isDateInCurrentWeek(_ date: Date) -> Bool {
        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return false
        }
        return date >= weekInterval.start && date < weekInterval.end
    }

    private func dateForExpandableGrid(week: Int, day: Int) -> Date? {
        // When collapsed: show current week (week index 0 = current week)
        // When expanded: show 5 weeks (week index 2 = current week, with 2 before and 2 after)
        let weekOffset = isWeekExpanded ? (week - 2) : 0

        guard let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStartDate) else {
            return nil
        }

        return calendar.date(byAdding: .day, value: day, to: targetWeekStart)
    }

    @ViewBuilder
    private func weekExpansionHandleView() -> some View {
        VStack(spacing: 0) {
            // Chevron indicator (down when collapsed to show you can expand down, up when expanded to show you can collapse up)
            Image(systemName: isWeekExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 8)

            // Draggable handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .gesture(
            DragGesture()
                .onChanged { value in
                    let verticalMovement = value.translation.height

                    if isWeekExpanded {
                        // Swipe up to collapse
                        if verticalMovement < 0 {
                            weekExpansionDragOffset = max(verticalMovement, -100)
                        }
                    } else {
                        // Swipe down to expand
                        if verticalMovement > 0 {
                            weekExpansionDragOffset = min(verticalMovement, 100)
                        }
                    }
                }
                .onEnded { value in
                    let verticalMovement = value.translation.height
                    let threshold: CGFloat = 60

                    if isWeekExpanded {
                        // Check if swiped up enough to collapse
                        if verticalMovement < -threshold {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isWeekExpanded = false
                                weekExpansionDragOffset = 0
                            }
                            HapticManager.shared.light()
                        } else {
                            // Snap back to expanded
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                weekExpansionDragOffset = 0
                            }
                        }
                    } else {
                        // Check if swiped down enough to expand
                        if verticalMovement > threshold {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isWeekExpanded = true
                                weekExpansionDragOffset = 0
                            }
                            HapticManager.shared.light()
                        } else {
                            // Snap back to collapsed
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                weekExpansionDragOffset = 0
                            }
                        }
                    }
                }
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isWeekExpanded.toggle()
            }
            HapticManager.shared.light()
        }
    }

    // Helper properties for expanded view
    private var currentWeekStartDate: Date {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return selectedDate
        }
        return weekInterval.start
    }

}

// MARK: - Corner Radius Extension for specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Calendar Source Colors (Deprecated - Use DesignSystem.Colors.forCalendarSource)
// Kept for backward compatibility, delegates to DesignSystem
func colorForCalendarSource(_ source: CalendarSource) -> Color {
    return DesignSystem.Colors.forCalendarSource(source)
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
    var isWeekView: Bool = false // New parameter to indicate week view mode
    var refreshTrigger: String = "" // Trigger to force rebuild when events change
    var onEventTap: ((CalendarEvent) -> Void)? = nil // Callback for event tap

    // Tuning constants
    let pxPerMinute: CGFloat
    let gapCollapseThresholdMin: Int
    let collapsedGapHeight: CGFloat

    @State private var segments: [TimelineSegment] = []
    @State private var expandedGaps: Set<UUID> = []
    @State private var currentTime = Date()
    @State private var allDayEvents_internal: [ClampedEvent] = []
    @State private var currentTimeTimer: Timer?

    private let hourLabelWidth: CGFloat = 60
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }()
    private let eventFilterService = EventFilterService()

    init(date: Date, events: [CalendarEvent], fontManager: FontManager,
         pxPerMinute: CGFloat = 1.0, gapCollapseThresholdMin: Int = 30, collapsedGapHeight: CGFloat = 48,
         isWeekView: Bool = false, refreshTrigger: String = "", onEventTap: ((CalendarEvent) -> Void)? = nil) {
        self.date = date
        self.refreshTrigger = refreshTrigger
        self.events = events
        self.fontManager = fontManager
        self.pxPerMinute = pxPerMinute
        self.gapCollapseThresholdMin = gapCollapseThresholdMin
        self.collapsedGapHeight = collapsedGapHeight
        self.isWeekView = isWeekView
        self.onEventTap = onEventTap
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
        .onDisappear {
            stopTimeTimer()
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
        .onChange(of: refreshTrigger) { newValue in
            // Rebuild segments when events change (triggered by parent)
            print("📊 Refresh trigger changed, rebuilding segments")
            print("   New trigger: \(newValue.prefix(100))...")

            // Small delay to allow drag animations to complete before rebuilding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
                    formattedTimeView(hourToDate(hour))
                        .offset(y: -8) // Offset up so grid line goes through center of AM/PM text
                    Spacer()
                }
                .frame(width: hourLabelWidth, height: CGFloat(60 * pxPerMinute), alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func formattedTimeView(_ date: Date) -> some View {
        let components = formatTimeComponents(date)
        HStack(spacing: 2) {
            Text(components.hour)
                .dynamicFont(size: 18, fontManager: fontManager)
                .foregroundColor(.secondary)
            Text(components.period)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private func formatTimeComponents(_ date: Date) -> (hour: String, period: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "h"
        let hour = formatter.string(from: date)
        formatter.dateFormat = "a"
        let period = formatter.string(from: date)
        return (hour, period)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill((isMultiDay ? Color.orange : Color.green).opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((isMultiDay ? Color.orange : Color.green).opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: (isMultiDay ? Color.orange : Color.green).opacity(0.3), radius: 8, x: 0, y: 4)
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
        DraggableEventView(
            event: event,
            lane: lane,
            width: width,
            pxPerMinute: pxPerMinute,
            fontManager: fontManager,
            isWeekView: isWeekView,
            onEventTap: onEventTap
        )
    }

// MARK: - Draggable Event View
struct DraggableEventView: View {
    let event: CalendarEvent
    let lane: Int
    let width: CGFloat
    let pxPerMinute: CGFloat
    @ObservedObject var fontManager: FontManager
    var isWeekView: Bool = false // New parameter for week view mode
    var onEventTap: ((CalendarEvent) -> Void)? = nil // Callback for event tap

    @State private var dragOffset: CGFloat = 0
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var pressStartTime: Date?
    @State private var isPressingDown = false
    @State private var dragDirection: DragDirection = .undetermined
    @State private var hasBeenMoved = false // Track if event was moved
    @State private var savedMinutesOffset: Int = 0 // Minutes offset after drag ends
    @State private var savedDayOffset: Int = 0 // Day offset after drag ends
    @StateObject private var colorManager = EventColorManager.shared

    enum DragDirection {
        case undetermined
        case vertical   // Time change
        case horizontal // Day change (week view only)
    }

    // Get color for event - custom color if set, otherwise calendar source color
    private var eventColor: Color {
        if colorManager.shouldUseCustomColor(for: event.id),
           let customColor = colorManager.getCustomColor(for: event.id) {
            return customColor
        }
        return colorForCalendarSource(event.source)
    }

    // Calculate live preview times based on current drag OR saved offset
    private var previewDates: (start: Date, end: Date) {
        let calendar = Calendar.current

        if isDragging && dragDirection == .vertical {
            // DRAGGING: Vertical drag - time change (live preview)
            let minutesPerPixel = 1.0 / pxPerMinute
            let totalMinutes = dragOffset / pxPerMinute
            let snappedMinutes = round(totalMinutes / 15.0) * 15.0

            let previewStart = calendar.date(byAdding: .minute, value: Int(snappedMinutes), to: event.start) ?? event.start
            let previewEnd = calendar.date(byAdding: .minute, value: Int(snappedMinutes), to: event.end) ?? event.end

            // Debug: Print preview times
            print("🕐 Preview (dragging): \(formatTime(previewStart)) to \(formatTime(previewEnd)) (offset: \(snappedMinutes) min)")

            return (previewStart, previewEnd)
        } else if isDragging && dragDirection == .horizontal && isWeekView {
            // DRAGGING: Horizontal drag - day change (live preview)
            let screenWidth = UIScreen.main.bounds.width
            let dayWidth = screenWidth / 7.0
            let dayChange = Int(round(horizontalDragOffset / dayWidth))

            let previewStart = calendar.date(byAdding: .day, value: dayChange, to: event.start) ?? event.start
            let previewEnd = calendar.date(byAdding: .day, value: dayChange, to: event.end) ?? event.end
            return (previewStart, previewEnd)
        } else if hasBeenMoved {
            // NOT DRAGGING but HAS BEEN MOVED: Show saved offset until view refreshes
            var previewStart = event.start
            var previewEnd = event.end

            if savedMinutesOffset != 0 {
                previewStart = calendar.date(byAdding: .minute, value: savedMinutesOffset, to: previewStart) ?? previewStart
                previewEnd = calendar.date(byAdding: .minute, value: savedMinutesOffset, to: previewEnd) ?? previewEnd
            }

            if savedDayOffset != 0 {
                previewStart = calendar.date(byAdding: .day, value: savedDayOffset, to: previewStart) ?? previewStart
                previewEnd = calendar.date(byAdding: .day, value: savedDayOffset, to: previewEnd) ?? previewEnd
            }

            print("🕐 Preview (saved): \(formatTime(previewStart)) to \(formatTime(previewEnd)) (minutes: \(savedMinutesOffset), days: \(savedDayOffset))")

            return (previewStart, previewEnd)
        } else {
            // PRISTINE: Not dragging and never moved - show actual event times
            return (event.start, event.end)
        }
    }

    var body: some View {
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

                    Text("\(formatTime(previewDates.start)) to \(formatTime(previewDates.end))")
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(isDragging ? .blue : .secondary)
                        .animation(.none, value: previewDates.start)

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
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(eventColor.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(eventColor.opacity(0.6), lineWidth: 1.5)
                    )
                    .shadow(color: eventColor.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .accessibilityLabel("\(event.title ?? "Untitled Event"), \(formatTime(event.start)) to \(formatTime(event.end))\(event.eventLocation.map { ", at \($0)" } ?? "")")
            .scaleEffect(isDragging ? 1.02 : (isPressingDown ? 0.98 : 1.0))
            .shadow(color: isDragging ? .black.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            .offset(x: horizontalDragOffset, y: dragOffset)
            .animation(.easeInOut(duration: 0.2), value: isDragging)
            .animation(.easeInOut(duration: 0.1), value: isPressingDown)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    // Start tracking press
                    if pressStartTime == nil {
                        pressStartTime = Date()
                        isPressingDown = true
                        print("👆 Touch started on: \(event.title ?? "Untitled")")
                    }

                    // Activate drag immediately when user starts moving (no timer delay)
                    if !isDragging && (abs(value.translation.width) > 3 || abs(value.translation.height) > 3) {
                        withAnimation {
                            isDragging = true
                        }

                        // If starting a new drag on a previously moved event, reset offsets
                        if hasBeenMoved {
                            dragOffset = 0
                            horizontalDragOffset = 0
                            hasBeenMoved = false
                            print("🔄 Resetting parked event for new drag")
                        }

                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        print("✅ Drag activated on movement: \(event.title ?? "Untitled")")
                    }

                    // If activated, determine drag direction and allow dragging
                    if isDragging {
                        // Determine drag direction if not yet set
                        if dragDirection == .undetermined {
                            let absX = abs(value.translation.width)
                            let absY = abs(value.translation.height)

                            if absX > 10 || absY > 10 {
                                if isWeekView && absX > absY {
                                    dragDirection = .horizontal
                                    print("📍 Horizontal drag mode (week view)")
                                } else {
                                    dragDirection = .vertical
                                    print("📍 Vertical drag mode (time change)")
                                }
                            }
                        }

                        // Handle dragging based on direction
                        if dragDirection == .horizontal && isWeekView {
                            // Horizontal drag for day change with snapping
                            let screenWidth = UIScreen.main.bounds.width
                            let dayWidth = screenWidth / 7.0
                            let dayChange = Int(round(value.translation.width / dayWidth))

                            // Snap to day columns
                            horizontalDragOffset = CGFloat(dayChange) * dayWidth

                            // Broadcast current day change for header indicator
                            NotificationCenter.default.post(
                                name: NSNotification.Name("WeekViewDragUpdate"),
                                object: nil,
                                userInfo: ["dayChange": dayChange]
                            )

                            print("📍 Horizontal drag: \(value.translation.width) -> Snapped to day: \(dayChange)")
                        } else if dragDirection == .vertical {
                            // Vertical drag for time change with snapping
                            let minutesPerPixel = 1.0 / pxPerMinute
                            let totalMinutes = value.translation.height * minutesPerPixel
                            let snappedMinutes = round(totalMinutes / 15.0) * 15.0

                            // Show snapped position while dragging
                            dragOffset = snappedMinutes * pxPerMinute
                            print("📍 Vertical drag: \(value.translation.height) -> Snapped: \(dragOffset)")
                        }
                    }
                }
                .onEnded { value in
                    print("🔴 Touch ended")

                    if isDragging {
                        if dragDirection == .horizontal && isWeekView {
                            // Calculate day change based on horizontal movement
                            let screenWidth = UIScreen.main.bounds.width
                            let dayWidth = screenWidth / 7.0
                            let dayChange = Int(round(value.translation.width / dayWidth))

                            if dayChange != 0 {
                                // Save the change to calendar and mark as moved
                                handleHorizontalDragEnd(dayChange: dayChange)
                                hasBeenMoved = true
                                print("🎯 Event parked at new day: \(dayChange)")
                                // KEEP horizontalDragOffset - event stays visually parked at new day
                                // DO NOT reset to 0! It needs to stay for visual consistency
                            } else {
                                print("🎯 No day change, reverting")
                                withAnimation {
                                    horizontalDragOffset = 0
                                }
                            }
                        } else if dragDirection == .vertical {
                            // Handle vertical (time) dragging
                            let minutesPerPixel = 1.0 / pxPerMinute
                            let totalMinutes = value.translation.height * minutesPerPixel
                            let snappedMinutes = round(totalMinutes / 15.0) * 15.0

                            if snappedMinutes != 0 {
                                // Save the change to calendar and mark as moved
                                handleVerticalDragEnd(snappedMinutes: snappedMinutes)
                                hasBeenMoved = true
                                print("🎯 Event parked at new time: \(snappedMinutes) minutes")
                                // KEEP dragOffset - event stays visually parked until segments rebuild with updated event
                                // DO NOT reset dragOffset to 0! It needs to stay for visual consistency
                            } else {
                                print("🎯 No time change, reverting")
                                withAnimation {
                                    dragOffset = 0
                                }
                            }
                        }
                    } else if pressStartTime != nil {
                        // User lifted finger without dragging - treat as tap
                        onEventTap?(event)
                        print("👆 Event tapped (no drag): \(event.title ?? "Untitled")")
                    }

                    // Clear drag indicator from week view headers
                    if isWeekView {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("WeekViewDragUpdate"),
                            object: nil,
                            userInfo: nil
                        )
                    }

                    // Reset drag state
                    withAnimation {
                        isDragging = false
                        isPressingDown = false
                        dragDirection = .undetermined
                    }
                    pressStartTime = nil
                }
            )

            // Fill remaining space (not interactive)
            Spacer()
        }
        .frame(width: width, height: height)
    }

    private func handleVerticalDragEnd(snappedMinutes: Double) {
        print("🎯 Event time changed by \(snappedMinutes) minutes")

        // Calculate new start and end times
        let calendar = Calendar.current
        guard let newStartDate = calendar.date(byAdding: .minute, value: Int(snappedMinutes), to: event.start),
              let newEndDate = calendar.date(byAdding: .minute, value: Int(snappedMinutes), to: event.end) else {
            print("❌ Failed to calculate new dates")
            return
        }

        print("✅ New times: \(newStartDate) - \(newEndDate)")

        // Save offset to keep displaying updated time until view refreshes
        savedMinutesOffset = Int(snappedMinutes)

        // Save to the actual calendar source (EKEvent, Google, or Outlook)
        // CalendarManager will update the events array, triggering a view rebuild
        saveEventTimeChange(eventId: event.id, newStart: newStartDate, newEnd: newEndDate, source: event.source)
    }

    private func handleHorizontalDragEnd(dayChange: Int) {
        print("🎯 Event moved by \(dayChange) day(s)")

        // Calculate new start and end dates by adding/subtracting days
        let calendar = Calendar.current
        guard let newStartDate = calendar.date(byAdding: .day, value: dayChange, to: event.start),
              let newEndDate = calendar.date(byAdding: .day, value: dayChange, to: event.end) else {
            print("❌ Failed to calculate new dates")
            return
        }

        print("✅ Event moved to new day: \(newStartDate)")

        // Save offset to keep displaying updated position until view refreshes
        savedDayOffset = dayChange

        // Save to the actual calendar source (EKEvent, Google, or Outlook)
        // CalendarManager will update the events array, triggering a view rebuild
        saveEventTimeChange(eventId: event.id, newStart: newStartDate, newEnd: newEndDate, source: event.source)
    }

    private func saveEventTimeChange(eventId: String, newStart: Date, newEnd: Date, source: CalendarSource) {
        // This needs access to CalendarManager or EventStore to save
        // For now, we'll use NotificationCenter to notify the parent
        print("📤 Posting notification to update event:")
        print("   ID: \(eventId)")
        print("   Original start: \(event.start)")
        print("   New start: \(newStart)")
        print("   New end: \(newEnd)")
        print("   Source: \(source)")

        NotificationCenter.default.post(
            name: NSNotification.Name("UpdateEventTime"),
            object: nil,
            userInfo: [
                "eventId": eventId,
                "newStart": newStart,
                "newEnd": newEnd,
                "source": source
            ]
        )
    }

    private func colorForCalendarSource(_ source: CalendarSource) -> Color {
        return DesignSystem.Colors.forCalendarSource(source)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"  // Format: 6:00 PM
        return formatter.string(from: date)
    }
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
            currentTimeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }

    private func stopTimeTimer() {
        currentTimeTimer?.invalidate()
        currentTimeTimer = nil
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
        return eventFilterService.filterCalendarEvents(events, dayStart: dayStart, dayEnd: dayEnd)
    }

    /// Core function to build segments from events and day boundaries
    private func buildSegments(events: [CalendarEvent], dayStart: Date, dayEnd: Date) -> [TimelineSegment] {
        // Remove duplicates - events with same id AND startDate (handles recurring events properly)
        let uniqueEvents = events.reduce(into: [CalendarEvent]()) { result, event in
            if !result.contains(where: { $0.id == event.id && $0.start == event.start }) {
                result.append(event)
            }
        }

        print("📊 buildSegments: input \(events.count) events, unique \(uniqueEvents.count) events")

        // Events are already filtered by filterEventsForDay, so separate all-day from timed
        let allDayEvents = uniqueEvents.filter { $0.isAllDay }.map { event in
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
        let timedEvents = uniqueEvents.filter { !$0.isAllDay }.map { event in
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

    /// Format date as time string (e.g., "6:00 PM", "9:00 AM")
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"  // Format: 6:00 PM
        return formatter.string(from: date)
    }
}

// MARK: - Event Card View
struct EventCardView: View {
    let event: EKEvent
    let lane: Int
    let hourHeight: CGFloat
    @ObservedObject var fontManager: FontManager
    @ObservedObject private var colorManager = EventColorManager.shared

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var pressStartTime: Date?
    @State private var isPressingDown = false
    @State private var draggedStartTime: Date?
    @State private var draggedEndTime: Date?

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
                        .foregroundColor(isDragging ? .primary : .secondary)

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
                .fill(eventColor.opacity(isDragging ? 0.2 : (isPressingDown ? 0.15 : 0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(eventColor.opacity(isDragging ? 0.6 : (isPressingDown ? 0.4 : 0.3)), lineWidth: isDragging ? 2 : 1)
                )
        )
        .frame(height: eventHeight)
        .scaleEffect(isDragging ? 1.02 : (isPressingDown ? 0.98 : 1.0))
        .shadow(color: isDragging ? .black.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        .offset(y: dragOffset)
        .animation(isDragging ? .interactiveSpring() : .none, value: dragOffset) // Smooth during drag, instant when released
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .animation(.easeInOut(duration: 0.1), value: isPressingDown)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    // Start tracking press
                    if pressStartTime == nil {
                        pressStartTime = Date()
                        isPressingDown = true
                        print("👆 Touch started on: \(event.title)")
                    }

                    // Activate drag immediately when user starts moving (no timer delay)
                    if !isDragging && (abs(value.translation.width) > 3 || abs(value.translation.height) > 3) {
                        withAnimation {
                            isDragging = true
                        }
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        print("✅ Drag activated on movement: \(event.title)")
                    }

                    // If activated, allow dragging
                    if isDragging {
                        dragOffset = value.translation.height

                        // Calculate new time in 15-minute increments while dragging
                        let minutesPerPixel = 60.0 / hourHeight // Based on hourHeight
                        let totalMinutes = value.translation.height * minutesPerPixel

                        // Snap to 15-minute increments
                        let snappedMinutes = round(totalMinutes / 15.0) * 15.0

                        // Update dragged times
                        let calendar = Calendar.current
                        if let newStartDate = calendar.date(byAdding: .minute, value: Int(snappedMinutes), to: event.startDate),
                           let newEndDate = calendar.date(byAdding: .minute, value: Int(snappedMinutes), to: event.endDate) {
                            draggedStartTime = newStartDate
                            draggedEndTime = newEndDate
                        }

                        print("📍 Dragging: \(value.translation.height), New time: \(snappedMinutes) min")
                    }
                }
                .onEnded { value in
                    print("🔴 Touch ended")

                    if isDragging {
                        // Complete the drag
                        handleDragEnd(translation: value.translation.height)
                    }

                    // Reset state
                    withAnimation {
                        isDragging = false
                        dragOffset = 0
                        isPressingDown = false
                        draggedStartTime = nil
                        draggedEndTime = nil
                    }
                    pressStartTime = nil
                }
        )
    }

    private var eventColor: Color {
        let colorManager = EventColorManager.shared

        // Check if event should use custom color
        if colorManager.shouldUseCustomColor(for: event.eventIdentifier),
           let customColor = colorManager.getCustomColor(for: event.eventIdentifier) {
            return customColor
        }

        // Fall back to calendar color
        return Color(event.calendar?.cgColor ?? CGColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0))
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
            // Show dragged time if currently dragging, otherwise show original time
            if isDragging, let draggedStart = draggedStartTime, let draggedEnd = draggedEndTime {
                return "\(formatTime(draggedStart)) to \(formatTime(draggedEnd))"
            } else {
                return "\(formatTime(event.startDate)) to \(formatTime(event.endDate))"
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"  // Format: 6:00 PM
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func handleDragEnd(translation: CGFloat) {
        // Calculate minutes moved based on pixel translation
        let minutesPerPixel = 1.0 // Assuming 1 pixel = 1 minute (adjust based on hourHeight)
        let totalMinutes = translation * minutesPerPixel

        // Snap to 15-minute increments
        let snappedMinutes = round(totalMinutes / 15.0) * 15.0

        // Update event times
        let calendar = Calendar.current
        guard let newStartDate = calendar.date(byAdding: .minute, value: Int(snappedMinutes), to: event.startDate),
              let newEndDate = calendar.date(byAdding: .minute, value: Int(snappedMinutes), to: event.endDate) else {
            return
        }

        // Update the event
        event.startDate = newStartDate
        event.endDate = newEndDate

        // Save the event
        do {
            let eventStore = EKEventStore()
            try eventStore.save(event, span: .thisEvent)
            print("✅ Event '\(event.title)' moved to new time: \(newStartDate)")
        } catch {
            print("❌ Failed to save event: \(error)")
        }
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

// MARK: - Conflict UI Components

/// Banner that appears at the top of the calendar to show conflict count
struct ConflictAlertBanner: View {
    let conflictCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(conflictCount) Scheduling Conflict\(conflictCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Tap to view and resolve")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// Full-screen view showing all conflicts
struct ConflictListView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedConflict: ScheduleConflict?
    @State private var showingResolution = false
    @State private var eventToDelete: UnifiedEvent?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            Group {
                if calendarManager.detectedConflicts.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)

                            Text("No Conflicts Detected")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("All your events are scheduled without overlaps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    List {
                        ForEach(calendarManager.detectedConflicts) { conflict in
                            Button(action: {
                                selectedConflict = conflict
                                showingResolution = true
                            }) {
                                ConflictDetailsCard(
                                    conflict: conflict,
                                    onDeleteEvent: { event in
                                        deleteEventFromConflict(event)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Schedule Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !calendarManager.detectedConflicts.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            calendarManager.detectAllConflicts()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingResolution) {
                if let conflict = selectedConflict {
                    ConflictResolutionView(conflict: conflict, calendarManager: calendarManager, fontManager: fontManager)
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteConfirmation, presenting: eventToDelete) { event in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    performDeleteEvent(event)
                }
            } message: { event in
                Text("Delete '\(event.title)'? This will remove the event from your calendar and resolve the conflict.")
            }
        }
    }

    // MARK: - Delete Event from Conflict

    private func deleteEventFromConflict(_ event: UnifiedEvent) {
        print("🗑️ Delete button tapped for: \(event.title)")
        eventToDelete = event
        showingDeleteConfirmation = true
    }

    private func performDeleteEvent(_ event: UnifiedEvent) {
        print("🗑️ Deleting event: \(event.title) (ID: \(event.id))")

        // Delete the event (don't refresh unified events - we'll handle it manually)
        calendarManager.deleteEvent(event, refreshUnifiedEvents: false)

        // Immediately remove from unified events
        calendarManager.unifiedEvents.removeAll { $0.id == event.id }
        print("📊 Removed event from unified events. Count: \(calendarManager.unifiedEvents.count)")

        // Re-detect conflicts with updated list
        calendarManager.detectAllConflicts()
        print("📊 Conflicts after deletion: \(calendarManager.detectedConflicts.count)")

        // Haptic feedback
        HapticManager.shared.success()
    }
}

// MARK: - Conflict Resolution Types

/// Types of resolution actions
fileprivate enum ResolutionType: String, CaseIterable {
    case reschedule = "Reschedule"
    case decline = "Decline"
    case shorten = "Shorten"
    case markOptional = "Mark Optional"
    case noAction = "Keep Both"

    var icon: String {
        switch self {
        case .reschedule: return "calendar.badge.clock"
        case .decline: return "xmark.circle"
        case .shorten: return "arrow.down.right.and.arrow.up.left"
        case .markOptional: return "questionmark.circle"
        case .noAction: return "checkmark.circle"
        }
    }
}

/// Individual resolution suggestion
fileprivate struct ResolutionSuggestion: Identifiable, Equatable {
    let id: UUID
    let type: ResolutionType
    let title: String
    let description: String
    let targetEvent: UnifiedEvent?
    let suggestedTime: Date?
    let confidence: Double // 0.0 to 1.0

    init(type: ResolutionType, title: String, description: String, targetEvent: UnifiedEvent? = nil, suggestedTime: Date? = nil, confidence: Double = 0.8) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.targetEvent = targetEvent
        self.suggestedTime = suggestedTime
        self.confidence = confidence
    }

    static func == (lhs: ResolutionSuggestion, rhs: ResolutionSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

/// AI-generated suggestions for resolving conflicts (local version)
fileprivate struct LocalConflictResolution: Identifiable {
    let id: UUID
    let conflict: ScheduleConflict
    let suggestions: [ResolutionSuggestion]

    init(conflict: ScheduleConflict, suggestions: [ResolutionSuggestion]) {
        self.id = UUID()
        self.conflict = conflict
        self.suggestions = suggestions
    }
}

/// AI-powered conflict resolution suggestion generator (local version)
fileprivate class LocalConflictResolutionAI {
    /// Generate rule-based suggestions for resolving a conflict
    func generateSuggestions(for conflict: ScheduleConflict, allEvents: [UnifiedEvent], completion: @escaping (LocalConflictResolution) -> Void) {
        guard conflict.conflictingEvents.count >= 2 else {
            completion(LocalConflictResolution(conflict: conflict, suggestions: []))
            return
        }

        let event1 = conflict.conflictingEvents[0]
        let event2 = conflict.conflictingEvents[1]

        var suggestions: [ResolutionSuggestion] = []

        // Determine which event is earlier and which is later
        let earlierEvent = event1.startDate < event2.startDate ? event1 : event2
        let laterEvent = event1.startDate < event2.startDate ? event2 : event1

        // Suggestion 1: Reschedule the shorter event to after the longer one ends
        let shorterEvent = event1.endDate.timeIntervalSince(event1.startDate) < event2.endDate.timeIntervalSince(event2.startDate) ? event1 : event2
        let longerEvent = shorterEvent.id == event1.id ? event2 : event1

        // Suggest rescheduling to 15 minutes after the longer event ends
        let rescheduleTime = longerEvent.endDate.addingTimeInterval(15 * 60)

        suggestions.append(ResolutionSuggestion(
            type: .reschedule,
            title: "Reschedule \(shorterEvent.title)",
            description: "Move to \(formatTime(rescheduleTime)) (after \(longerEvent.title) ends)",
            targetEvent: shorterEvent,
            suggestedTime: rescheduleTime,
            confidence: 0.8
        ))

        // Suggestion 2: Shorten the later event to start when the earlier one ends
        let shortenTime = earlierEvent.endDate

        suggestions.append(ResolutionSuggestion(
            type: .shorten,
            title: "Shorten \(laterEvent.title)",
            description: "Start at \(formatTime(shortenTime)) instead (after \(earlierEvent.title) ends)",
            targetEvent: laterEvent,
            suggestedTime: shortenTime,
            confidence: 0.7
        ))

        // Suggestion 3: Keep both
        suggestions.append(ResolutionSuggestion(
            type: .noAction,
            title: "Keep Both",
            description: "Keep both events and manage the overlap manually",
            confidence: 0.6
        ))

        let resolution = LocalConflictResolution(conflict: conflict, suggestions: suggestions)
        DispatchQueue.main.async {
            completion(resolution)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Schedule Conflict Resolution View

/// View for resolving time-based scheduling conflicts with AI suggestions
/// (For sync conflicts between calendar versions, see SyncConflictResolutionView)
struct ConflictResolutionView: View {
    let conflict: ScheduleConflict
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @State private var resolutionSuggestions: [ResolutionSuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var showingEditEvent = false
    @State private var eventToEdit: UnifiedEvent?
    @Environment(\.dismiss) var dismiss

    private let conflictAI = LocalConflictResolutionAI()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Conflict details
                ConflictDetailsCard(conflict: conflict, onDeleteEvent: nil)

                // AI Suggestions section
                HStack {
                    Text("AI-Powered Suggestions")
                        .font(.headline)

                    if isLoadingSuggestions {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.leading, 8)
                    }
                }
                .padding(.horizontal)

                if resolutionSuggestions.isEmpty && !isLoadingSuggestions {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)

                        Text("Generating smart suggestions...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        ForEach(resolutionSuggestions) { suggestion in
                            ResolutionSuggestionCard(
                                suggestion: suggestion,
                                onSelect: {
                                    handleSuggestion(suggestion)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Resolve Conflict")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAISuggestions()
        }
        .sheet(isPresented: $showingEditEvent) {
            if let event = eventToEdit {
                EditEventView(calendarManager: calendarManager, fontManager: fontManager, event: event)
            }
        }
    }

    private func loadAISuggestions() {
        isLoadingSuggestions = true

        conflictAI.generateSuggestions(
            for: conflict,
            allEvents: calendarManager.unifiedEvents
        ) { resolution in
            resolutionSuggestions = resolution.suggestions
            isLoadingSuggestions = false
        }
    }

    private func handleSuggestion(_ suggestion: ResolutionSuggestion) {
        print("🎯 User selected suggestion: \(suggestion.type.rawValue)")
        HapticManager.shared.light()

        // Handle "Keep Both" special case - doesn't need target event
        if suggestion.type == .noAction {
            calendarManager.approveConflict(conflict)
            dismiss()
            return
        }

        guard let targetEvent = suggestion.targetEvent else {
            print("❌ Missing target event")
            return
        }

        // Create modified event based on suggestion type
        let modifiedEvent: UnifiedEvent

        switch suggestion.type {
        case .reschedule:
            guard let newTime = suggestion.suggestedTime else {
                print("❌ Missing suggested time for reschedule")
                return
            }
            // Calculate duration and create rescheduled event
            let duration = targetEvent.endDate.timeIntervalSince(targetEvent.startDate)
            let newEndTime = newTime.addingTimeInterval(duration)

            modifiedEvent = UnifiedEvent(
                id: targetEvent.id,
                title: targetEvent.title,
                startDate: newTime,
                endDate: newEndTime,
                location: targetEvent.location,
                description: targetEvent.description,
                isAllDay: targetEvent.isAllDay,
                source: targetEvent.source,
                organizer: targetEvent.organizer,
                originalEvent: targetEvent.originalEvent,
                calendarId: targetEvent.calendarId,
                calendarName: targetEvent.calendarName,
                calendarColor: targetEvent.calendarColor
            )

        case .shorten:
            guard let newEndTime = suggestion.suggestedTime else {
                print("❌ Missing suggested time for shorten")
                return
            }
            // Create shortened event
            modifiedEvent = UnifiedEvent(
                id: targetEvent.id,
                title: targetEvent.title,
                startDate: targetEvent.startDate,
                endDate: newEndTime,
                location: targetEvent.location,
                description: targetEvent.description,
                isAllDay: targetEvent.isAllDay,
                source: targetEvent.source,
                organizer: targetEvent.organizer,
                originalEvent: targetEvent.originalEvent,
                calendarId: targetEvent.calendarId,
                calendarName: targetEvent.calendarName,
                calendarColor: targetEvent.calendarColor
            )

        case .markOptional:
            // Add optional indicator to title and description
            let optionalNote = (targetEvent.description ?? "") + "\n\n[OPTIONAL - Can skip if needed]"
            modifiedEvent = UnifiedEvent(
                id: targetEvent.id,
                title: "⚪️ \(targetEvent.title)",
                startDate: targetEvent.startDate,
                endDate: targetEvent.endDate,
                location: targetEvent.location,
                description: optionalNote,
                isAllDay: targetEvent.isAllDay,
                source: targetEvent.source,
                organizer: targetEvent.organizer,
                originalEvent: targetEvent.originalEvent,
                calendarId: targetEvent.calendarId,
                calendarName: targetEvent.calendarName,
                calendarColor: targetEvent.calendarColor
            )

        case .decline:
            // For decline, just open the original event to delete
            modifiedEvent = targetEvent

        case .noAction:
            // For keep both, mark conflict as approved and dismiss
            HapticManager.shared.light()
            calendarManager.approveConflict(conflict)
            dismiss()
            return
        }

        // Open edit view with the modified event
        print("📝 Opening EditEventView for: \(modifiedEvent.title)")
        print("📝 Event ID: \(modifiedEvent.id)")
        print("📝 Event source: \(modifiedEvent.source)")
        print("📝 Original event: \(type(of: modifiedEvent.originalEvent))")

        eventToEdit = modifiedEvent
        showingEditEvent = true
    }

}

// MARK: - Resolution Suggestion Card

fileprivate struct ResolutionSuggestionCard: View {
    let suggestion: ResolutionSuggestion
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: suggestion.type.icon)
                    .font(.title2)
                    .foregroundColor(typeColor)
                    .frame(width: 40)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // Confidence indicator
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(suggestion.confidence * 5) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(typeColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var typeColor: Color {
        switch suggestion.type {
        case .reschedule:
            return .blue
        case .decline:
            return .red
        case .shorten:
            return .orange
        case .markOptional:
            return .purple
        case .noAction:
            return .green
        }
    }
}

/// Detailed card showing conflict information
struct ConflictDetailsCard: View {
    let conflict: ScheduleConflict
    let onDeleteEvent: ((UnifiedEvent) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with severity indicator
            HStack {
                Image(systemName: conflict.severity.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(severityColor)
                    )

                Text("\(conflict.severity.rawValue) Conflict")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text(conflict.overlapDurationFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
            }

            // Overlapping period
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(timeRangeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Conflicting events
            VStack(alignment: .leading, spacing: 8) {
                ForEach(conflict.conflictingEvents) { event in
                    ConflictEventRow(event: event, onDelete: onDeleteEvent)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private var severityColor: Color {
        switch conflict.severity {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }

    private var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: conflict.overlapStart)) - \(formatter.string(from: conflict.overlapEnd))"
    }
}

/// Individual event row within a conflict card
struct ConflictEventRow: View {
    let event: UnifiedEvent
    let onDelete: ((UnifiedEvent) -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            // Source icon
            Text(sourceEmoji)
                .font(.caption)

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(timeString)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Delete button
            if let onDelete = onDelete {
                Button(action: {
                    onDelete(event)
                }) {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.red)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }

    private var sourceEmoji: String {
        switch event.source {
        case .ios: return "📱"
        case .google: return "🟢"
        case .outlook: return "🔵"
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}
