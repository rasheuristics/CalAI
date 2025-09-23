import SwiftUI
import EventKit

struct EventsTabView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @State private var showingUpcoming = true
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingAddEvent = false
    @State private var showUnifiedEvents = true
    @State private var selectedEventForEdit: UnifiedEvent?
    @State private var showingEditAlert = false

    var body: some View {
        ZStack {
            // Background that extends to all edges
            Color(.systemGroupedBackground)
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
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
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal)

            if showUnifiedEvents ? filteredUnifiedEvents.isEmpty : filteredEvents.isEmpty {
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
                }
                .padding()
                Spacer()
            } else {
                if showUnifiedEvents {
                    List {
                        ForEach(groupedUnifiedEvents.keys.sorted(), id: \.self) { date in
                            Section(header: Text(formatSectionHeader(date))) {
                                ForEach(groupedUnifiedEvents[date] ?? [], id: \.id) { event in
                                    UnifiedEventDetailRow(event: event, fontManager: fontManager)
                                        .onTapGesture(count: 2) {
                                            selectedEventForEdit = event
                                            showingEditAlert = true
                                        }
                                }
                                .onDelete { indexSet in
                                    let eventsForDate = groupedUnifiedEvents[date] ?? []
                                    for index in indexSet {
                                        if index < eventsForDate.count {
                                            deleteUnifiedEvent(eventsForDate[index])
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
                } else {
                    List {
                        ForEach(groupedEvents.keys.sorted(), id: \.self) { date in
                            Section(header: Text(formatSectionHeader(date))) {
                                ForEach(groupedEvents[date] ?? [], id: \.eventIdentifier) { event in
                                    EventDetailRow(event: event, fontManager: fontManager)
                                        .onTapGesture(count: 2) {
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
                                                originalEvent: event
                                            )
                                            selectedEventForEdit = unifiedEvent
                                            showingEditAlert = true
                                        }
                                }
                                .onDelete { indexSet in
                                    let eventsForDate = groupedEvents[date] ?? []
                                    for index in indexSet {
                                        if index < eventsForDate.count {
                                            calendarManager.deleteEvent(eventsForDate[index])
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
            }
            }
            .onAppear {
                calendarManager.refreshAllCalendars()
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(calendarManager: calendarManager, fontManager: fontManager)
            }
            .sheet(isPresented: $showingEditAlert) {
                if let eventToEdit = selectedEventForEdit {
                    AddEventView(calendarManager: calendarManager, fontManager: fontManager, eventToEdit: eventToEdit)
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
        switch event.source {
        case .ios:
            if let ekEvent = event.originalEvent as? EKEvent {
                calendarManager.deleteEvent(ekEvent)
            }
        case .google:
            // TODO: Implement Google Calendar event deletion
            print("📅 Google Calendar event deletion not yet implemented")
        case .outlook:
            // TODO: Implement Outlook Calendar event deletion
            print("📅 Outlook Calendar event deletion not yet implemented")
        }

        // Refresh the unified events after deletion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            calendarManager.loadAllUnifiedEvents()
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
        switch source {
        case .ios: return .blue
        case .google: return .green
        case .outlook: return .orange
        }
    }
}