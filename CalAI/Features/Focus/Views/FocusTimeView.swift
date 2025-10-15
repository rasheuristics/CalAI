import SwiftUI

/// Main view for Focus Time management
struct FocusTimeView: View {
    @ObservedObject var calendarManager: CalendarManager
    @StateObject private var focusOptimizer = FocusTimeOptimizer.shared
    @State private var showingAddFocusBlock = false
    @State private var showingAnalytics = false
    @State private var showingPreferences = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("View", selection: $selectedTab) {
                    Text("Schedule").tag(0)
                    Text("Suggestions").tag(1)
                    Text("Analytics").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Content
                TabView(selection: $selectedTab) {
                    ScheduledFocusView(
                        focusOptimizer: focusOptimizer,
                        onAddBlock: { showingAddFocusBlock = true }
                    )
                    .tag(0)

                    SuggestedWindowsView(
                        calendarManager: calendarManager,
                        focusOptimizer: focusOptimizer
                    )
                    .tag(1)

                    AnalyticsView(
                        calendarManager: calendarManager,
                        focusOptimizer: focusOptimizer
                    )
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Focus Time")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingPreferences = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingAddFocusBlock) {
                AddFocusBlockView(
                    calendarManager: calendarManager,
                    focusOptimizer: focusOptimizer
                )
            }
            .sheet(isPresented: $showingPreferences) {
                FocusTimePreferencesView(focusOptimizer: focusOptimizer)
            }
        }
    }
}

// MARK: - Scheduled Focus View

struct ScheduledFocusView: View {
    @ObservedObject var focusOptimizer: FocusTimeOptimizer
    let onAddBlock: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 50))
                        .foregroundColor(.purple)

                    Text("Your Scheduled Focus Blocks")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("\(focusOptimizer.scheduledFocusBlocks.count) blocks scheduled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()

                // Focus Blocks
                if focusOptimizer.scheduledFocusBlocks.isEmpty {
                    EmptyFocusBlocksView(onAdd: onAddBlock)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(focusOptimizer.scheduledFocusBlocks) { block in
                            FocusBlockCard(block: block, onDelete: {
                                focusOptimizer.removeFocusBlock(block.id)
                            })
                        }
                    }
                }

                // Add Button
                Button(action: onAddBlock) {
                    Label("Schedule Focus Block", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top)
            }
            .padding()
        }
    }
}

struct FocusBlockCard: View {
    let block: FocusBlock
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: block.focusType.icon)
                .font(.title2)
                .foregroundColor(focusColor)
                .frame(width: 50, height: 50)
                .background(focusColor.opacity(0.2))
                .clipShape(Circle())

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(block.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label(formatDate(block.startTime), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(block.durationFormatted, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if block.isProtected {
                    Label("Protected", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }

            Spacer()

            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var focusColor: Color {
        switch block.focusType.color {
        case "purple": return .purple
        case "blue": return .blue
        case "orange": return .orange
        case "gray": return .gray
        case "green": return .green
        case "pink": return .pink
        default: return .purple
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

struct EmptyFocusBlocksView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Focus Blocks Scheduled")
                .font(.headline)

            Text("Schedule dedicated time for deep work")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
}

// MARK: - Suggested Windows View

struct SuggestedWindowsView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var focusOptimizer: FocusTimeOptimizer
    @State private var suggestedWindows: [FocusTimeWindow] = []
    @State private var isLoading = false
    @State private var selectedDate = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Date Picker
                DatePicker("Find windows for", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onChange(of: selectedDate) { _ in
                        findWindows()
                    }

                // Suggested Windows
                if isLoading {
                    ProgressView("Analyzing your calendar...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if suggestedWindows.isEmpty {
                    NoWindowsView()
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggested Focus Windows")
                            .font(.headline)

                        ForEach(Array(suggestedWindows.enumerated()), id: \.offset) { index, window in
                            SuggestedWindowCard(
                                window: window,
                                rank: index + 1,
                                onSchedule: {
                                    scheduleWindow(window)
                                }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            findWindows()
        }
    }

    private func findWindows() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            suggestedWindows = focusOptimizer.findOptimalFocusWindows(
                events: calendarManager.unifiedEvents,
                targetDate: selectedDate,
                preferredDuration: 3600
            )
            isLoading = false
        }
    }

    private func scheduleWindow(_ window: FocusTimeWindow) {
        let block = FocusBlock(
            title: "Focus Time",
            startTime: window.startTime,
            endTime: window.endTime,
            focusType: .deepWork,
            isProtected: true,
            autoScheduled: false
        )
        focusOptimizer.scheduleFocusBlock(block)
    }
}

struct SuggestedWindowCard: View {
    let window: FocusTimeWindow
    let rank: Int
    let onSchedule: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("#\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreColor)
                    .cornerRadius(6)

                Text(timeRange)
                    .font(.headline)

                Spacer()

                ScoreIndicator(score: window.score)
            }

            Text(window.reason)
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: onSchedule) {
                Text("Schedule This Block")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: window.startTime)) - \(formatter.string(from: window.endTime))"
    }

    private var scoreColor: Color {
        if window.score > 0.8 { return .green }
        else if window.score > 0.6 { return .blue }
        else if window.score > 0.4 { return .orange }
        else { return .gray }
    }
}

struct ScoreIndicator: View {
    let score: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                Image(systemName: index < Int(score * 5) ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
}

struct NoWindowsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("No Available Windows")
                .font(.headline)

            Text("Your day is fully booked. Try another day or adjust your working hours.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var focusOptimizer: FocusTimeOptimizer
    @State private var analytics: FocusTimeAnalytics?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let analytics = analytics {
                    // Header Stats
                    VStack(spacing: 16) {
                        StatCard(
                            title: "Focus Time This Week",
                            value: formatTime(analytics.totalFocusTimeThisWeek),
                            change: analytics.weekOverWeekChange,
                            icon: "clock.fill",
                            color: .purple
                        )

                        HStack(spacing: 12) {
                            MiniStatCard(
                                title: "Blocks Completed",
                                value: "\(analytics.focusBlocksCompleted)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )

                            MiniStatCard(
                                title: "Completion Rate",
                                value: "\(Int(analytics.completionRate * 100))%",
                                icon: "chart.bar.fill",
                                color: .blue
                            )
                        }
                    }

                    // Best Hours
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Best Hours for Focus")
                            .font(.headline)

                        HStack(spacing: 8) {
                            ForEach(analytics.meetingFreeHours.prefix(5), id: \.self) { hour in
                                HourBadge(hour: hour, type: .free)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Productivity Insights
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Productivity Insights")
                            .font(.headline)

                        InsightRow(
                            icon: "sunrise.fill",
                            text: "Morning hours (9-12) are your most productive",
                            color: .orange
                        )

                        InsightRow(
                            icon: "brain.head.profile",
                            text: "Average focus session: \(formatTime(analytics.averageFocusBlockDuration))",
                            color: .purple
                        )

                        if analytics.weekOverWeekChange > 0 {
                            InsightRow(
                                icon: "arrow.up.right.circle.fill",
                                text: "You're improving! \(Int(analytics.weekOverWeekChange * 100))% more focus time than last week",
                                color: .green
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else {
                    ProgressView("Loading analytics...")
                        .padding()
                }
            }
            .padding()
        }
        .onAppear {
            loadAnalytics()
        }
    }

    private func loadAnalytics() {
        analytics = focusOptimizer.generateAnalytics(events: calendarManager.unifiedEvents)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let change: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()

                if change != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(Int(abs(change) * 100))%")
                    }
                    .font(.caption)
                    .foregroundColor(change > 0 ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((change > 0 ? Color.green : Color.red).opacity(0.1))
                    .cornerRadius(6)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct MiniStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HourBadge: View {
    let hour: Int
    enum BadgeType {
        case free, busy
    }
    let type: BadgeType

    var body: some View {
        Text(formatHour(hour))
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(type == .free ? .green : .red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background((type == .free ? Color.green : Color.red).opacity(0.1))
            .cornerRadius(8)
    }

    private func formatHour(_ hour: Int) -> String {
        let isPM = hour >= 12
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour)\(isPM ? "PM" : "AM")"
    }
}

struct InsightRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Add Focus Block View

struct AddFocusBlockView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var focusOptimizer: FocusTimeOptimizer
    @Environment(\.dismiss) private var dismiss

    @State private var title = "Focus Time"
    @State private var selectedType: FocusType = .deepWork
    @State private var startDate = Date()
    @State private var duration: TimeInterval = 7200 // 2 hours
    @State private var isProtected = true

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)

                    Picker("Type", selection: $selectedType) {
                        ForEach(FocusType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                }

                Section("Schedule") {
                    DatePicker("Start Time", selection: $startDate)

                    Picker("Duration", selection: $duration) {
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("1.5 hours").tag(TimeInterval(5400))
                        Text("2 hours").tag(TimeInterval(7200))
                        Text("2.5 hours").tag(TimeInterval(9000))
                        Text("3 hours").tag(TimeInterval(10800))
                    }
                }

                Section("Protection") {
                    Toggle("Protected Time", isOn: $isProtected)
                    Text("Protected blocks won't accept new meeting invitations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Schedule Focus Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFocusBlock()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveFocusBlock() {
        let endDate = startDate.addingTimeInterval(duration)

        let block = FocusBlock(
            title: title,
            startTime: startDate,
            endTime: endDate,
            focusType: selectedType,
            isProtected: isProtected,
            autoScheduled: false
        )

        focusOptimizer.scheduleFocusBlock(block)
        dismiss()
    }
}

// MARK: - Focus Time Preferences View

struct FocusTimePreferencesView: View {
    @ObservedObject var focusOptimizer: FocusTimeOptimizer
    @Environment(\.dismiss) private var dismiss

    @State private var preferences: FocusTimePreferences

    init(focusOptimizer: FocusTimeOptimizer) {
        self.focusOptimizer = focusOptimizer
        _preferences = State(initialValue: focusOptimizer.preferences)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("General") {
                    Toggle("Enable Focus Time", isOn: $preferences.isEnabled)
                    Toggle("Auto-Schedule Focus Blocks", isOn: $preferences.autoScheduleFocusBlocks)
                    Toggle("Protect Focus Time", isOn: $preferences.protectFocusTime)
                }

                Section("Working Hours") {
                    Picker("Start Hour", selection: $preferences.preferredFocusHoursStart) {
                        ForEach(6..<12) { hour in
                            Text("\(hour):00 AM").tag(hour)
                        }
                    }

                    Picker("End Hour", selection: $preferences.preferredFocusHoursEnd) {
                        ForEach(15..<20) { hour in
                            Text("\(hour > 12 ? hour - 12 : hour):00 \(hour >= 12 ? "PM" : "AM")").tag(hour)
                        }
                    }
                }

                Section("Do Not Disturb") {
                    Toggle("DND During Focus Blocks", isOn: $preferences.dndDuringFocusBlocks)
                    Toggle("Allow Calls", isOn: $preferences.dndAllowCalls)
                }

                Section("Auto-Scheduling") {
                    Stepper("Focus Blocks Per Week: \(preferences.focusBlocksPerWeek)", value: $preferences.focusBlocksPerWeek, in: 1...10)
                }
            }
            .navigationTitle("Focus Time Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func savePreferences() {
        focusOptimizer.updatePreferences(preferences)
        dismiss()
    }
}

// MARK: - Preview

struct FocusTimeView_Previews: PreviewProvider {
    static var previews: some View {
        FocusTimeView(calendarManager: CalendarManager())
    }
}
