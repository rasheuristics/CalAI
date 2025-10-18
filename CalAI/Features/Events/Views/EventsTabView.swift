import SwiftUI
import EventKit

struct EventsTabView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @ObservedObject var appearanceManager: AppearanceManager
    @State private var showingUpcoming = true
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingAddEvent = false
    @State private var showUnifiedEvents = true
    @State private var selectedEventForEdit: UnifiedEvent?
    @State private var showingEditAlert = false
    @State private var showingReschedule = false
    @State private var eventsToReschedule: [UnifiedEvent] = []
    @State private var collapsedDays: Set<Date> = []

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Time Range", selection: $selectedTimeRange) {
                    Text("Today").tag(TimeRange.all)
                    Text("This Week").tag(TimeRange.week)
                    Text("This Month").tag(TimeRange.month)
                }
                .pickerStyle(SegmentedPickerStyle())

                Button(action: {
                    showingAddEvent = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding(.leading, 8)
            }

            HStack {
                Toggle("Show All Calendars", isOn: $showUnifiedEvents)
                    .dynamicFont(size: 14, fontManager: fontManager)

                Spacer()

                Button("Refresh All") {
                    calendarManager.refreshAllCalendars()
                }
                .font(.caption)
                .foregroundColor(.blue)

                Button("Add Sample") {
                    calendarManager.createSampleEvents()
                }
                .font(.caption)
                .foregroundColor(.green)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal)
    }

    private var emptyStateView: some View {
        VStack {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No events found")
                .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.gray)
            Text("Events will appear here when you create them")
                .dynamicFont(size: 12, fontManager: fontManager)
                .foregroundColor(.secondary)

            // Debug info
            VStack {
                Text("Debug Info:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("iOS Events: \(calendarManager.events.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Unified Events: \(calendarManager.unifiedEvents.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Filtered Events: \(showUnifiedEvents ? filteredUnifiedEvents.count : filteredEvents.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Has Calendar Access: \(calendarManager.hasCalendarAccess ? "Yes" : "No")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private var unifiedEventsList: some View {
        List {
                        ForEach(groupedUnifiedEvents.keys.sorted(), id: \.self) { date in
                            Section(header:
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 1.0)) {
                                        if collapsedDays.contains(date) {
                                            collapsedDays.remove(date)
                                        } else {
                                            collapsedDays.insert(date)
                                        }
                                    }
                                }) {
                                    HStack {
                                        Text(formatSectionHeader(date))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: collapsedDays.contains(date) ? "chevron.right" : "chevron.down")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            ) {
                                if !collapsedDays.contains(date) {
                                    ForEach(groupedUnifiedEvents[date] ?? [], id: \.id) { event in
                                        UnifiedEventDetailRow(event: event, fontManager: fontManager, calendarManager: calendarManager)
                                            .onTapGesture {
                                                selectedEventForEdit = event
                                                showingEditAlert = true
                                            }
                                            .swipeActions(edge: .leading) {
                                                Button {
                                                    eventsToReschedule = [event]
                                                    showingReschedule = true
                                                } label: {
                                                    Label("Reschedule", systemImage: "calendar.badge.clock")
                                                }
                                                .tint(.blue)
                                            }
                                    }
                                    .onDelete { indexSet in
                                        let eventsForDate = groupedUnifiedEvents[date] ?? []
                                        print("🗑️ Delete triggered in unified view - \(indexSet.count) event(s)")
                                        for index in indexSet {
                                            if index < eventsForDate.count {
                                                let event = eventsForDate[index]
                                                print("🗑️ Deleting unified event at index \(index): \(event.title)")
                                                deleteUnifiedEvent(event)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    calendarManager.refreshAllCalendars()
                }
    }

    private var iosEventsList: some View {
        List {
                        ForEach(groupedEvents.keys.sorted(), id: \.self) { date in
                            Section(header:
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 1.0)) {
                                        if collapsedDays.contains(date) {
                                            collapsedDays.remove(date)
                                        } else {
                                            collapsedDays.insert(date)
                                        }
                                    }
                                }) {
                                    HStack {
                                        Text(formatSectionHeader(date))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: collapsedDays.contains(date) ? "chevron.right" : "chevron.down")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            ) {
                                if !collapsedDays.contains(date) {
                                    ForEach(groupedEvents[date] ?? [], id: \.eventIdentifier) { event in
                                        EventDetailRow(event: event, fontManager: fontManager)
                                            .onTapGesture {
                                                // Convert EKEvent to UnifiedEvent for editing
                                                let unifiedEvent = UnifiedEvent(
                                                    id: event.eventIdentifier,
                                                    title: event.title ?? "Untitled Event",
                                                    startDate: event.startDate,
                                                    endDate: event.endDate ?? event.startDate.addingTimeInterval(3600),
                                                    location: event.location,
                                                    description: event.notes,
                                                    isAllDay: event.isAllDay,
                                                    source: .ios,
                                                    organizer: event.organizer?.name,
                                                    originalEvent: event,
                                                    calendarId: event.calendar?.calendarIdentifier,
                                                    calendarName: event.calendar?.title,
                                                    calendarColor: event.calendar?.cgColor != nil ? Color(event.calendar!.cgColor) : nil
                                                )
                                                selectedEventForEdit = unifiedEvent
                                                showingEditAlert = true
                                            }
                                    }
                                    .onDelete { indexSet in
                                        let eventsForDate = groupedEvents[date] ?? []
                                        for index in indexSet {
                                            if index < eventsForDate.count {
                                                let event = eventsForDate[index]
                                                print("🗑️ Deleting iOS-only view event: \(event.title ?? "Untitled")")
                                                calendarManager.deleteEvent(event)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    calendarManager.refreshAllCalendars()
                }
    }

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                headerView

                if showUnifiedEvents ? filteredUnifiedEvents.isEmpty : filteredEvents.isEmpty {
                    emptyStateView
                    Spacer()
                } else {
                    if showUnifiedEvents {
                        unifiedEventsList
                    } else {
                        iosEventsList
                    }
                }
            }
            .onAppear {
                calendarManager.refreshAllCalendars()
                // Collapse all days by default
                collapseAllDays()
            }
            .onChange(of: showUnifiedEvents) { _ in
                // Re-collapse all days when switching between views
                collapseAllDays()
            }
            .onChange(of: selectedTimeRange) { _ in
                // Re-collapse all days when changing time range
                collapseAllDays()
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(calendarManager: calendarManager, fontManager: fontManager)
            }
            .sheet(isPresented: $showingEditAlert) {
                if let eventToEdit = selectedEventForEdit {
                    AddEventView(calendarManager: calendarManager, fontManager: fontManager, eventToEdit: eventToEdit)
                }
            }
            .sheet(isPresented: $showingReschedule) {
                NavigationView {
                    if eventsToReschedule.count == 1, let event = eventsToReschedule.first {
                        SingleEventReschedulingView(
                            event: event,
                            fontManager: fontManager,
                            calendarManager: calendarManager
                        )
                    } else {
                        SmartReschedulingView(
                            events: eventsToReschedule,
                            fontManager: fontManager,
                            calendarManager: calendarManager
                        )
                    }
                }
            }
        }
    }

    private var filteredEvents: [EKEvent] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedTimeRange {
        case .week:
            let weekFromNow = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            return calendarManager.events.filter { event in
                event.startDate >= now && event.startDate <= weekFromNow
            }
        case .month:
            let monthFromNow = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            return calendarManager.events.filter { event in
                event.startDate >= now && event.startDate <= monthFromNow
            }
        case .all:
            return calendarManager.events.filter { event in
                calendar.isDate(event.startDate, inSameDayAs: now)
            }
        }
    }

    private var filteredUnifiedEvents: [UnifiedEvent] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedTimeRange {
        case .week:
            let weekFromNow = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            return calendarManager.unifiedEvents.filter { event in
                event.startDate >= now && event.startDate <= weekFromNow
            }
        case .month:
            let monthFromNow = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            return calendarManager.unifiedEvents.filter { event in
                event.startDate >= now && event.startDate <= monthFromNow
            }
        case .all:
            return calendarManager.unifiedEvents.filter { event in
                calendar.isDate(event.startDate, inSameDayAs: now)
            }
        }
    }

    private var groupedEvents: [Date: [EKEvent]] {
        let calendar = Calendar.current
        return Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.startDate)
        }
    }

    private var groupedUnifiedEvents: [Date: [UnifiedEvent]] {
        let calendar = Calendar.current
        return Dictionary(grouping: filteredUnifiedEvents) { event in
            calendar.startOfDay(for: event.startDate)
        }
    }

    private func formatSectionHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private func deleteUnifiedEvent(_ event: UnifiedEvent) {
        // IMMEDIATELY remove from unified events to prevent SwiftUI List crash
        // This gives instant UI feedback and prevents the count mismatch error
        calendarManager.unifiedEvents.removeAll { $0.id == event.id && $0.source == event.source }

        // Track deletion to prevent reappearance
        calendarManager.trackDeletedEvent(event.id, source: event.source)

        switch event.source {
        case .ios:
            if let ekEvent = event.originalEvent as? EKEvent {
                print("🗑️ Attempting to delete iOS event: \(event.title)")
                calendarManager.deleteEvent(ekEvent)
                // Note: CalendarManager.deleteEvent already handles:
                // - Deletion from iOS Calendar (EventStore)
                // - Deletion from Core Data cache
                // - Reloading iOS events
                // - Refreshing unified events
            }
        case .google:
            Task {
                print("🗑️ Attempting to delete Google event: \(event.title)")
                let success = await calendarManager.googleCalendarManager?.deleteEvent(eventId: event.id) ?? false

                await MainActor.run {
                    // Delete from Core Data cache regardless of server success
                    // This ensures the event is removed locally even if server delete fails
                    CoreDataManager.shared.permanentlyDeleteEvent(eventId: event.id, source: .google)

                    // Verify event was already removed from unified events (line 353)
                    let stillExists = calendarManager.unifiedEvents.contains {
                        $0.id == event.id && $0.source == .google
                    }

                    if stillExists {
                        print("⚠️ WARNING: Event still exists in unified events after deletion!")
                    } else {
                        print("✅ VERIFIED: Google event completely removed")
                    }

                    if success {
                        print("✅ Google event deleted successfully from server and cache")
                    } else {
                        print("⚠️ Failed to delete from Google server, but removed from local cache")
                    }
                }
            }
        case .outlook:
            Task {
                print("🗑️ Attempting to delete Outlook event: \(event.title)")
                let success = await calendarManager.outlookCalendarManager?.deleteEvent(eventId: event.id) ?? false

                await MainActor.run {
                    // Delete from Core Data cache regardless of server success
                    // This ensures the event is removed locally even if server delete fails
                    CoreDataManager.shared.permanentlyDeleteEvent(eventId: event.id, source: .outlook)

                    // Verify event was already removed from unified events (line 353)
                    let stillExists = calendarManager.unifiedEvents.contains {
                        $0.id == event.id && $0.source == .outlook
                    }

                    if stillExists {
                        print("⚠️ WARNING: Event still exists in unified events after deletion!")
                    } else {
                        print("✅ VERIFIED: Outlook event completely removed")
                    }

                    if success {
                        print("✅ Outlook event deleted successfully from server and cache")
                    } else {
                        print("⚠️ Failed to delete from Outlook server, but removed from local cache")
                    }
                }
            }
        }
    }

    private func collapseAllDays() {
        // Collapse all days based on current view mode
        if showUnifiedEvents {
            collapsedDays = Set(groupedUnifiedEvents.keys)
        } else {
            collapsedDays = Set(groupedEvents.keys)
        }
    }
}

enum TimeRange {
    case week, month, all
}

struct EventDetailRow: View {
    let event: EKEvent
    let fontManager: FontManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)

                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(formatTime(event.startDate))
                    if let endDate = event.endDate {
                        Text("-")
                        Text(formatTime(endDate))
                    }
                }
                .dynamicFont(size: 12, fontManager: fontManager)
                .foregroundColor(.secondary)

                if let location = event.location, !location.isEmpty {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(location)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Circle()
                .fill(colorForCalendar(event.calendar))
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 2)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func colorForCalendar(_ calendar: EKCalendar?) -> Color {
        guard let calendar = calendar else { return .blue }
        return Color(calendar.cgColor)
    }
}

struct UnifiedEventDetailRow: View {
    let event: UnifiedEvent
    let fontManager: FontManager
    @ObservedObject var calendarManager: CalendarManager
    @State private var showingMeetingPrep = false
    @State private var showingMeetingFollowUp = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)

                    Spacer()

                    Text(event.sourceLabel)
                        .dynamicFont(size: 10, weight: .medium, fontManager: fontManager)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }

                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(formatTime(event.startDate))
                    Text("-")
                    Text(formatTime(event.endDate))
                }
                .dynamicFont(size: 12, fontManager: fontManager)
                .foregroundColor(.secondary)

                if let location = event.location, !location.isEmpty {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(location)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }

                // Meeting Prep button for upcoming events
                if isUpcomingEvent {
                    Button(action: {
                        showingMeetingPrep = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                            Text("Meeting Prep")
                                .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                }

                // Meeting Summary button for completed events
                if isCompletedEvent {
                    Button(action: {
                        showingMeetingFollowUp = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                            Text("Meeting Summary")
                                .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                }
            }
            .sheet(isPresented: $showingMeetingPrep) {
                NavigationView {
                    MeetingPreparationView(
                        preparation: MeetingPreparationGenerator.generate(
                            for: event,
                            allEvents: calendarManager.unifiedEvents
                        ),
                        fontManager: fontManager
                    )
                }
            }
            .sheet(isPresented: $showingMeetingFollowUp) {
                NavigationView {
                    MeetingFollowUpView(
                        followUp: MeetingFollowUpGenerator.generate(
                            for: event,
                            notes: event.description,
                            allEvents: calendarManager.unifiedEvents
                        ),
                        fontManager: fontManager
                    )
                }
            }

            Spacer()

            Circle()
                .fill(colorForSource(event.source))
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 2)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func colorForSource(_ source: CalendarSource) -> Color {
        return DesignSystem.Colors.forCalendarSource(source)
    }

    private var isUpcomingEvent: Bool {
        // Show prep for events within next 24 hours and not yet finished
        let timeUntilStart = event.startDate.timeIntervalSinceNow
        let isNotFinished = event.endDate > Date()
        return timeUntilStart > 0 && timeUntilStart < 24 * 60 * 60 && isNotFinished
    }

    private var isCompletedEvent: Bool {
        // Show summary for events that ended within the last 7 days
        let timeSinceEnd = Date().timeIntervalSince(event.endDate)
        return timeSinceEnd > 0 && timeSinceEnd < 7 * 24 * 60 * 60
    }
}