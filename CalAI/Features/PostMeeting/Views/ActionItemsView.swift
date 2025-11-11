// DEPRECATED: This file is obsolete and should be removed from the Xcode project
// The ActionItemsView has been unified into InboxView as part of the task system unification
// All action items from meetings are now directly created as EventTasks with proper event linking

import SwiftUI

// This is a deprecated placeholder to prevent build errors
// TODO: Remove this file from the Xcode project's compile sources
@available(*, deprecated, message: "ActionItemsView has been unified into InboxView. Use InboxView instead.")
struct ActionItemsView: View {
    @ObservedObject var postMeetingService: PostMeetingService
    @ObservedObject var fontManager: FontManager
    @ObservedObject var calendarManager: CalendarManager

    var body: some View {
        VStack {
            Text("This view is deprecated")
                .foregroundColor(.red)
                .padding()
            Text("All action items are now unified in the Tasks tab")
                .foregroundColor(.secondary)
                .padding()
        }
        .navigationTitle("Deprecated View")
    }
}