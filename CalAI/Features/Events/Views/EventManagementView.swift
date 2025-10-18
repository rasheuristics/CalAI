import SwiftUI
import EventKit

/// Unified view for managing events with Edit, Tasks, Share, and Details tabs
struct EventManagementView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    let event: UnifiedEvent

    @State private var selectedTab: EventTab = .edit

    enum EventTab: String, CaseIterable {
        case edit = "Edit"
        case tasks = "Tasks"
        case share = "Share"

        var icon: String {
            switch self {
            case .edit: return "pencil"
            case .tasks: return "sparkles"
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
                    // Edit Tab
                    EditEventView(
                        calendarManager: calendarManager,
                        fontManager: fontManager,
                        event: event
                    )
                    .tag(EventTab.edit)

                    // Tasks Tab
                    EventTasksTabView(event: event, fontManager: fontManager)
                        .tag(EventTab.tasks)

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
                        dismiss()
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
