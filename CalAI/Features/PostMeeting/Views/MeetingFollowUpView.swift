import SwiftUI

struct MeetingFollowUpView: View {
    let followUp: MeetingFollowUp
    @ObservedObject var fontManager: FontManager
    @State private var actionItemStates: [UUID: Bool] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)

                        Text(followUp.eventTitle)
                            .dynamicFont(size: 22, weight: .bold, fontManager: fontManager)
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        Text(formatDate(followUp.meetingDate))
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Spacer()

                        if followUp.totalActionItems > 0 {
                            HStack(spacing: 4) {
                                Text("\(followUp.completedActionItems)/\(followUp.totalActionItems)")
                                    .dynamicFont(size: 12, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(completionColor)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Summary Highlights
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Summary", icon: "doc.text", fontManager: fontManager)

                    Text(followUp.summary.highlights)
                        .dynamicFont(size: 16, fontManager: fontManager)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }

                // Outcomes
                if !followUp.summary.outcomes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Outcomes", icon: "target", fontManager: fontManager)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(followUp.summary.outcomes.enumerated()), id: \.offset) { index, outcome in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.body)

                                    Text(outcome)
                                        .dynamicFont(size: 16, fontManager: fontManager)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }
                }

                // Action Items
                if !followUp.actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SectionHeader(title: "Action Items", icon: "list.bullet.circle", fontManager: fontManager)

                            Spacer()

                            if followUp.completionPercentage > 0 {
                                Text("\(Int(followUp.completionPercentage))%")
                                    .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(completionColor)
                            }
                        }

                        VStack(spacing: 8) {
                            ForEach(sortedActionItems) { item in
                                ActionItemRow(
                                    item: item,
                                    fontManager: fontManager,
                                    onToggle: {
                                        toggleActionItem(item.id)
                                    }
                                )
                            }
                        }
                    }
                }

                // Decisions
                if !followUp.decisions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Decisions Made", icon: "checkmark.shield", fontManager: fontManager)

                        VStack(spacing: 12) {
                            ForEach(followUp.decisions) { decision in
                                DecisionCard(decision: decision, fontManager: fontManager)
                            }
                        }
                    }
                }

                // Follow-up Meetings
                if !followUp.followUpMeetings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Suggested Follow-ups", icon: "calendar.badge.plus", fontManager: fontManager)

                        VStack(spacing: 12) {
                            ForEach(followUp.followUpMeetings) { meeting in
                                FollowUpMeetingCard(meeting: meeting, fontManager: fontManager)
                            }
                        }
                    }
                }

                // Participants
                if !followUp.participants.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Participants", icon: "person.2", fontManager: fontManager)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(followUp.participants, id: \.self) { participant in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text(participant.prefix(1).uppercased())
                                                .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                                                .foregroundColor(.blue)
                                        )

                                    Text(participant)
                                        .dynamicFont(size: 16, fontManager: fontManager)

                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }
                }

                // Topics Discussed
                if !followUp.summary.topics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Topics Discussed", icon: "bubble.left.and.bubble.right", fontManager: fontManager)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(followUp.summary.topics, id: \.self) { topic in
                                Text(topic)
                                    .dynamicFont(size: 14, fontManager: fontManager)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundColor(.purple)
                                    .cornerRadius(16)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Meeting Summary")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize action item states
            for item in followUp.actionItems {
                actionItemStates[item.id] = item.isCompleted
            }
        }
    }

    // MARK: - Computed Properties

    private var sortedActionItems: [ActionItem] {
        followUp.actionItems.sorted { item1, item2 in
            // Sort by completion status first (incomplete first), then by priority
            if item1.isCompleted != item2.isCompleted {
                return !item1.isCompleted
            }
            return item1.priority.sortOrder < item2.priority.sortOrder
        }
    }

    private var completionColor: Color {
        let percentage = followUp.completionPercentage
        if percentage >= 100 {
            return .green
        } else if percentage >= 50 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func toggleActionItem(_ id: UUID) {
        actionItemStates[id]?.toggle()
    }
}

// MARK: - Subviews

struct ActionItemRow: View {
    let item: ActionItem
    let fontManager: FontManager
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isCompleted ? .green : .gray)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .dynamicFont(size: 16, fontManager: fontManager)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .overlay(
                            GeometryReader { geometry in
                                if item.isCompleted {
                                    Rectangle()
                                        .fill(Color.primary.opacity(0.5))
                                        .frame(height: 1)
                                        .offset(y: geometry.size.height / 2)
                                }
                            }
                        )

                    HStack(spacing: 8) {
                        // Priority badge
                        Text(item.priority.rawValue)
                            .dynamicFont(size: 11, weight: .semibold, fontManager: fontManager)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor(item.priority))
                            .cornerRadius(4)

                        // Category badge
                        HStack(spacing: 4) {
                            Image(systemName: item.category.icon)
                                .font(.caption2)
                            Text(item.category.rawValue)
                                .dynamicFont(size: 11, fontManager: fontManager)
                        }
                        .foregroundColor(.secondary)

                        if let assignee = item.assignee {
                            HStack(spacing: 4) {
                                Image(systemName: "person")
                                    .font(.caption2)
                                Text(assignee)
                                    .dynamicFont(size: 11, fontManager: fontManager)
                            }
                            .foregroundColor(.blue)
                        }

                        if let dueDate = item.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(formatDueDate(dueDate))
                                    .dynamicFont(size: 11, fontManager: fontManager)
                            }
                            .foregroundColor(dueDateColor(dueDate))
                        }
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(item.isCompleted ? Color.green.opacity(0.3) : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func priorityColor(_ priority: ActionItem.ActionPriority) -> Color {
        switch priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func dueDateColor(_ date: Date) -> Color {
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if daysUntil < 0 {
            return .red
        } else if daysUntil < 3 {
            return .orange
        } else {
            return .secondary
        }
    }
}

struct DecisionCard: View {
    let decision: Decision
    let fontManager: FontManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.purple)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(decision.decision)
                        .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                        .foregroundColor(.primary)

                    if let context = decision.context {
                        Text(context)
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        if let madeBy = decision.madeBy {
                            HStack(spacing: 4) {
                                Image(systemName: "person")
                                    .font(.caption)
                                Text(madeBy)
                                    .dynamicFont(size: 12, fontManager: fontManager)
                            }
                            .foregroundColor(.secondary)
                        }

                        if let timestamp = decision.timestamp {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text(formatTime(timestamp))
                                    .dynamicFont(size: 12, fontManager: fontManager)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct FollowUpMeetingCard: View {
    let meeting: FollowUpMeeting
    let fontManager: FontManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)

                    Text(meeting.purpose)
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if meeting.isScheduled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }

            if let suggestedDate = meeting.suggestedDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(formatSuggestedDate(suggestedDate))
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.blue)
                }
            }

            if !meeting.attendees.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(meeting.attendees.joined(separator: ", "))
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            if !meeting.isScheduled {
                Button(action: {
                    // TODO: Implement scheduling
                }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("Schedule Meeting")
                            .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(meeting.isScheduled ? Color.green.opacity(0.3) : Color(.systemGray4), lineWidth: 1)
        )
    }

    private func formatSuggestedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}
