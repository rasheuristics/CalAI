import SwiftUI
import EventKit

/// Unified view for managing events with Edit, Tasks, Share, and Details tabs
struct EventManagementView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    let event: UnifiedEvent

    @State private var selectedTab: EventTab = .tasks
    @State private var triggerSave: Bool = false

    enum EventTab: String, CaseIterable {
        case tasks = "Tasks"
        case edit = "Edit"
        case share = "Share"

        var icon: String {
            switch self {
            case .tasks: return "sparkles"
            case .edit: return "pencil"
            case .share: return "square.and.arrow.up"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    ForEach(EventTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab Content
                TabView(selection: $selectedTab) {
                    // Tasks Tab
                    EventTasksTabView(event: event, fontManager: fontManager)
                        .tag(EventTab.tasks)

                    // Edit Tab
                    EditEventView(
                        calendarManager: calendarManager,
                        fontManager: fontManager,
                        event: event,
                        triggerSave: $triggerSave
                    )
                    .tag(EventTab.edit)

                    // Share Tab
                    shareTabContent
                        .tag(EventTab.share)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Trigger save for the current tab
                        triggerSave.toggle()
                    }
                    .dynamicFont(size: 17, fontManager: fontManager)
                }
            }
        }
    }

    // MARK: - Share Tab Content

    private var shareTabContent: some View {
        EventShareTabView(
            event: event,
            calendarManager: calendarManager,
            fontManager: fontManager
        )
    }
}

#Preview {
    EventManagementView(
        calendarManager: CalendarManager(),
        fontManager: FontManager(),
        event: UnifiedEvent(
            id: "preview-event",
            title: "Sample Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: "Sample Location",
            description: "Sample notes",
            isAllDay: false,
            source: .ios,
            organizer: nil,
            originalEvent: Optional<Any>.none as Any,
            calendarId: "preview-calendar",
            calendarName: "Personal",
            calendarColor: .blue
        )
    )
}
