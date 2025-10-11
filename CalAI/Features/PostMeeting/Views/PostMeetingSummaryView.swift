import SwiftUI

struct PostMeetingSummaryView: View {
    let followUp: MeetingFollowUp
    @ObservedObject var postMeetingService: PostMeetingService
    @ObservedObject var fontManager: FontManager
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedActionItem: ActionItem?
    @State private var showingActionItemDetail = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Meeting Header
                    meetingHeaderSection

                    // Summary Section
                    summarySection

                    // Action Items Section
                    actionItemsSection

                    // Decisions Section
                    if !followUp.decisions.isEmpty {
                        decisionsSection
                    }

                    // Follow-Up Meetings Section
                    if !followUp.followUpMeetings.isEmpty {
                        followUpMeetingsSection
                    }

                    // Participants Section
                    if !followUp.participants.isEmpty {
                        participantsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Meeting Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: shareSummary) {
                            Label("Share Summary", systemImage: "square.and.arrow.up")
                        }

                        Button(action: exportActionItems) {
                            Label("Export Action Items", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Meeting Header

    private var meetingHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(followUp.eventTitle)
                .dynamicFont(size: 28, weight: .bold, fontManager: fontManager)
                .foregroundColor(.primary)

            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text(formatDate(followUp.meetingDate))
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text(formatDuration(followUp.summary.duration))
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }

            // Progress indicator
            if followUp.totalActionItems > 0 {
                HStack {
                    ProgressView(value: followUp.completionPercentage / 100.0)
                        .tint(.green)

                    Text("\(followUp.completedActionItems)/\(followUp.totalActionItems)")
                        .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Summary", systemImage: "doc.text")
                .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            Text(followUp.summary.highlights)
                .dynamicFont(size: 16, fontManager: fontManager)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !followUp.summary.outcomes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Outcomes")
                        .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    ForEach(followUp.summary.outcomes, id: \.self) { outcome in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(outcome)
                                .dynamicFont(size: 14, fontManager: fontManager)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.top, 8)
            }

            if !followUp.summary.topics.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Topics Discussed")
                        .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(followUp.summary.topics, id: \.self) { topic in
                                Text(topic)
                                    .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Action Items Section

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Action Items", systemImage: "checklist")
                    .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.primary)

                Spacer()

                if followUp.totalActionItems > 0 {
                    Text("\(followUp.completedActionItems) of \(followUp.totalActionItems) completed")
                        .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }

            if followUp.actionItems.isEmpty {
                Text("No action items extracted from this meeting")
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(followUp.actionItems.sorted(by: { $0.priority.sortOrder < $1.priority.sortOrder })) { item in
                    DetailedActionItemRow(
                        item: item,
                        fontManager: fontManager,
                        onToggle: {
                            postMeetingService.completeActionItem(item.id)
                            HapticManager.shared.light()
                        },
                        onDelete: {
                            postMeetingService.deleteActionItem(item.id)
                            HapticManager.shared.medium()
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Decisions Section

    private var decisionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Decisions Made", systemImage: "gavel")
                .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            ForEach(followUp.decisions) { decision in
                DecisionRow(decision: decision, fontManager: fontManager)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Follow-Up Meetings Section

    private var followUpMeetingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggested Follow-Ups", systemImage: "calendar.badge.plus")
                .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            ForEach(followUp.followUpMeetings) { meeting in
                FollowUpMeetingRow(
                    meeting: meeting,
                    fontManager: fontManager,
                    onSchedule: {
                        postMeetingService.scheduleFollowUpMeeting(meeting, for: followUp)
                        HapticManager.shared.success()
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Participants", systemImage: "person.2")
                .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(followUp.participants, id: \.self) { participant in
                        VStack {
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)

                            Text(participant)
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 80)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Actions

    private func shareSummary() {
        // Create shareable text
        var shareText = """
        Meeting Summary: \(followUp.eventTitle)
        Date: \(formatDate(followUp.meetingDate))
        Duration: \(formatDuration(followUp.summary.duration))

        Summary:
        \(followUp.summary.highlights)

        """

        if !followUp.actionItems.isEmpty {
            shareText += "\nAction Items:\n"
            for item in followUp.actionItems {
                shareText += "• \(item.title)\n"
                if let assignee = item.assignee {
                    shareText += "  Assignee: \(assignee)\n"
                }
            }
        }

        if !followUp.decisions.isEmpty {
            shareText += "\nDecisions:\n"
            for decision in followUp.decisions {
                shareText += "• \(decision.decision)\n"
            }
        }

        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func exportActionItems() {
        // Export action items as a shareable checklist
        var checklistText = "Action Items - \(followUp.eventTitle)\n\n"
        for item in followUp.actionItems {
            let checkbox = item.isCompleted ? "[x]" : "[ ]"
            checklistText += "\(checkbox) \(item.title)\n"
            if let assignee = item.assignee {
                checklistText += "   Assignee: \(assignee)\n"
            }
        }

        let activityVC = UIActivityViewController(activityItems: [checklistText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct DetailedActionItemRow: View {
    let item: ActionItem
    @ObservedObject var fontManager: FontManager
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.title)
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                    .overlay(
                        item.isCompleted ?
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(height: 1)
                            .offset(y: 0)
                        : nil
                    )

                // Metadata
                HStack(spacing: 12) {
                    // Priority
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(item.priority.color))
                            .frame(width: 8, height: 8)
                        Text(item.priority.rawValue)
                            .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }

                    // Category
                    Label(item.category.rawValue, systemImage: item.category.icon)
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    // Assignee
                    if let assignee = item.assignee {
                        Label(assignee, systemImage: "person")
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }

                // Description
                if let description = item.description {
                    Text(description)
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                // Completion date
                if item.isCompleted, let completedDate = item.completedDate {
                    Text("Completed \(formatRelativeDate(completedDate))")
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.green)
                        .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding()
        .background(item.isCompleted ? Color(.systemGray6) : Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(item.priority.color).opacity(0.3), lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DecisionRow: View {
    let decision: Decision
    @ObservedObject var fontManager: FontManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gavel.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(decision.decision)
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .foregroundColor(.primary)

                if let context = decision.context {
                    Text(context)
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct FollowUpMeetingRow: View {
    let meeting: FollowUpMeeting
    @ObservedObject var fontManager: FontManager
    let onSchedule: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: meeting.isScheduled ? "checkmark.circle.fill" : "calendar.badge.plus")
                .foregroundColor(meeting.isScheduled ? .green : .blue)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                    .foregroundColor(.primary)

                Text(meeting.purpose)
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)

                if let suggestedDate = meeting.suggestedDate {
                    Text("Suggested: \(formatDate(suggestedDate))")
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }

                if !meeting.attendees.isEmpty {
                    Text("With: \(meeting.attendees.joined(separator: ", "))")
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !meeting.isScheduled {
                Button(action: onSchedule) {
                    Text("Schedule")
                        .dynamicFont(size: 12, weight: .semibold, fontManager: fontManager)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
