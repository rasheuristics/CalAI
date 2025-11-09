import SwiftUI
import EventKit

struct MorningBriefingScreen: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var taskManager: EventTaskManager
    @EnvironmentObject var fontManager: FontManager

    @State private var briefingText: String = ""
    @State private var isGenerating: Bool = false
    @State private var todayEvents: [UnifiedEvent] = []
    @State private var todayTasks: [EventTask] = []
    @State private var greeting: String = ""
    @State private var showAddEvent: Bool = false
    @State private var showAddTask: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with Gradient
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 200)
                    .cornerRadius(20)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sun.horizon.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)

                            Spacer()

                            Text(Date(), style: .date)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Text(greeting)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        if !todayEvents.isEmpty {
                            Text("You have \(todayEvents.count) events today")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(24)
                }
                .padding(.horizontal)

                // AI-Generated Briefing
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.purple)

                        Text("AI Briefing")
                            .font(.system(size: 22, weight: .bold))
                    }

                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Generating your briefing...")
                                .foregroundColor(.gray)
                        }
                        .padding()
                    } else if !briefingText.isEmpty {
                        Text(briefingText)
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                // Today's Schedule
                if !todayEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.blue)

                            Text("Today's Schedule")
                                .font(.system(size: 22, weight: .bold))
                        }

                        ForEach(todayEvents.prefix(8)) { event in
                            EventBriefingCard(event: event, fontManager: fontManager)
                        }
                    }
                    .padding(.horizontal)
                }

                // Today's Tasks
                if !todayTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.green)

                            Text("Today's Tasks")
                                .font(.system(size: 22, weight: .bold))
                        }

                        ForEach(todayTasks.prefix(5)) { task in
                            TaskBriefingCard(task: task, fontManager: fontManager)
                        }
                    }
                    .padding(.horizontal)
                }

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            QuickActionButton(
                                icon: "calendar.badge.plus",
                                title: "Add Event",
                                color: .blue
                            ) {
                                showAddEvent = true
                            }

                            QuickActionButton(
                                icon: "checkmark.circle.badge.plus",
                                title: "Add Task",
                                color: .green
                            ) {
                                showAddTask = true
                            }

                            QuickActionButton(
                                icon: "arrow.clockwise",
                                title: "Refresh",
                                color: .purple
                            ) {
                                loadBriefingData()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Morning Briefing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBriefingData()
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView(calendarManager: calendarManager, fontManager: fontManager, eventToEdit: nil)
        }
        .sheet(isPresented: $showAddTask) {
            StandaloneTaskSheet(
                taskManager: taskManager,
                fontManager: fontManager,
                initialList: .inbox,
                linkedEventId: nil,
                editingTask: nil,
                eventIdForEditing: nil
            )
        }
    }

    private func loadBriefingData() {
        // Set greeting based on time
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            greeting = "Good Morning!"
        case 12..<17:
            greeting = "Good Afternoon!"
        case 17..<22:
            greeting = "Good Evening!"
        default:
            greeting = "Good Night!"
        }

        // Get today's events
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        todayEvents = calendarManager.unifiedEvents.filter { event in
            event.startDate < endOfDay && event.endDate > startOfDay
        }.sorted { $0.startDate < $1.startDate }

        // Get today's tasks from all events
        todayTasks = []
        for (_, eventTaskData) in taskManager.eventTasks {
            let incompleteTasks = eventTaskData.tasks.filter { !$0.isCompleted }
            todayTasks.append(contentsOf: incompleteTasks)
        }
        todayTasks = todayTasks.prefix(5).map { $0 }

        // Fetch and save weather for widget
        fetchWeatherForWidget()

        // Generate AI briefing
        generateAIBriefing()
    }

    private func fetchWeatherForWidget() {
        print("🔴 fetchWeatherForWidget() called")
        WeatherService.shared.fetchCurrentWeather { result in
            print("🔴 Weather fetch completed with result")
            switch result {
            case .success(let weatherData):
                print("✅ Weather fetched successfully: \(weatherData.temperatureFormatted), \(weatherData.condition)")
                print("✅ Saving to shared storage...")
                SharedWeatherStorage.shared.saveWeather(weatherData)
                print("✅ Weather saved!")
            case .failure(let error):
                print("❌ Failed to fetch weather: \(error.localizedDescription)")
            }
        }
    }

    private func generateAIBriefing() {
        isGenerating = true

        if #available(iOS 26.0, *) {
            Task {
                do {
                    let aiService = OnDeviceAIService.shared
                    // For now, generate a simple text-based briefing
                    var briefing = "Good day! "

                    if !todayEvents.isEmpty {
                        briefing += "You have \(todayEvents.count) events scheduled. "
                        if let firstEvent = todayEvents.first {
                            briefing += "Your first event is \(firstEvent.title) at \(firstEvent.startDate.formatted(date: .omitted, time: .shortened)). "
                        }
                    }

                    if !todayTasks.isEmpty {
                        briefing += "You have \(todayTasks.count) tasks to complete today. "
                    }

                    if todayEvents.isEmpty && todayTasks.isEmpty {
                        briefing += "Your schedule is clear today - a great day to catch up or relax!"
                    }

                    await MainActor.run {
                        briefingText = briefing
                        isGenerating = false
                    }
                } catch {
                    await MainActor.run {
                        briefingText = "Unable to generate briefing at this time. Check your schedule and tasks below."
                        isGenerating = false
                    }
                }
            }
        } else {
            // Fallback for iOS < 26
            var briefing = "Good day! "

            if !todayEvents.isEmpty {
                briefing += "You have \(todayEvents.count) events scheduled. "
                if let firstEvent = todayEvents.first {
                    briefing += "Your first event is \(firstEvent.title) at \(firstEvent.startDate.formatted(date: .omitted, time: .shortened)). "
                }
            }

            if !todayTasks.isEmpty {
                briefing += "You have \(todayTasks.count) tasks to complete today. "
            }

            if todayEvents.isEmpty && todayTasks.isEmpty {
                briefing += "Your schedule is clear today - a great day to catch up or relax!"
            }

            briefingText = briefing
            isGenerating = false
        }
    }
}

struct EventBriefingCard: View {
    let event: UnifiedEvent
    let fontManager: FontManager

    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(event.startDate, style: .time)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)

                if !event.isAllDay {
                    Text(event.endDate, style: .time)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 60, alignment: .leading)

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .fontWeight(.semibold)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(location)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.gray)
                }

                // Video meeting indicator
                let detector = VideoMeetingDetector()
                if let meeting = detector.detectMeeting(from: event) {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10))
                        Text(meeting.platform.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.purple)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct TaskBriefingCard: View {
    let task: EventTask
    let fontManager: FontManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(task.isCompleted ? .green : .gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .dynamicFont(size: 15, fontManager: fontManager)

                if let description = task.description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .cornerRadius(12)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .frame(width: 100)
    }
}

#Preview {
    NavigationView {
        MorningBriefingScreen()
            .environmentObject(CalendarManager())
            .environmentObject(EventTaskManager.shared)
            .environmentObject(FontManager())
    }
}
