import SwiftUI

struct MeetingPreparationView: View {
    let preparation: MeetingPreparation
    @ObservedObject var fontManager: FontManager
    @State private var completedActions: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: preparation.briefing.meetingType.icon)
                            .font(.title2)
                            .foregroundColor(.blue)

                        Text(preparation.title)
                            .dynamicFont(size: 22, weight: .bold, fontManager: fontManager)
                    }

                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text(formatTimeRange(start: preparation.startDate, end: preparation.endDate))
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(timeUntilMeetingText)
                            .dynamicFont(size: 12, weight: .semibold, fontManager: fontManager)
                            .foregroundColor(timeUntilMeetingColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(timeUntilMeetingColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Summary", icon: "doc.text", fontManager: fontManager)

                    Text(preparation.briefing.summary)
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

                // Objective
                if let objective = preparation.briefing.objective {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Objective", icon: "target", fontManager: fontManager)

                        Text(objective)
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
                }

                // Agenda
                if !preparation.briefing.agenda.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Agenda", icon: "list.bullet", fontManager: fontManager)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(preparation.briefing.agenda.enumerated()), id: \.offset) { index, item in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1).")
                                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                        .foregroundColor(.blue)
                                        .frame(width: 24)

                                    Text(item)
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

                // Suggested Actions
                if !preparation.suggestedActions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Preparation Checklist", icon: "checkmark.circle", fontManager: fontManager)

                        VStack(spacing: 8) {
                            ForEach(preparation.suggestedActions) { action in
                                ActionRow(
                                    action: action,
                                    isCompleted: completedActions.contains(action.id),
                                    fontManager: fontManager,
                                    onToggle: {
                                        if completedActions.contains(action.id) {
                                            completedActions.remove(action.id)
                                        } else {
                                            completedActions.insert(action.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }

                // Attendees
                if !preparation.attendees.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Attendees", icon: "person.2", fontManager: fontManager)

                        VStack(spacing: 12) {
                            ForEach(preparation.attendees) { attendee in
                                AttendeeCard(attendee: attendee, fontManager: fontManager)
                            }
                        }
                    }
                }

                // Related Items
                if !preparation.relatedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Related", icon: "link", fontManager: fontManager)

                        VStack(spacing: 8) {
                            ForEach(preparation.relatedItems) { item in
                                RelatedItemRow(item: item, fontManager: fontManager)
                            }
                        }
                    }
                }

                // Key Topics
                if !preparation.briefing.keyTopics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Key Topics", icon: "bubble.left.and.bubble.right", fontManager: fontManager)

                        // Simple wrapping layout for iOS 15
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(preparation.briefing.keyTopics, id: \.self) { topic in
                                Text(topic)
                                    .dynamicFont(size: 14, fontManager: fontManager)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(16)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Meeting Prep")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var timeUntilMeetingText: String {
        let interval = preparation.timeUntilMeeting
        if interval < 0 {
            return "In Progress"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "In \(minutes) min"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "In \(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "In \(days)d"
        }
    }

    private var timeUntilMeetingColor: Color {
        let interval = preparation.timeUntilMeeting
        if interval < 0 {
            return .green
        } else if interval < 900 { // < 15 min
            return .red
        } else if interval < 3600 { // < 1 hour
            return .orange
        } else {
            return .blue
        }
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        let dateStr = formatter.string(from: start)

        formatter.dateFormat = "h:mm a"
        let startTime = formatter.string(from: start)
        let endTime = formatter.string(from: end)

        return "\(dateStr) • \(startTime) - \(endTime)"
    }
}

// MARK: - Subviews

struct SectionHeader: View {
    let title: String
    let icon: String
    let fontManager: FontManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
        }
    }
}

struct ActionRow: View {
    let action: SuggestedAction
    let isCompleted: Bool
    let fontManager: FontManager
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isCompleted ? .green : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .dynamicFont(size: 16, fontManager: fontManager)
                        .foregroundColor(.primary)
                        .overlay(
                            GeometryReader { geometry in
                                if isCompleted {
                                    Rectangle()
                                        .fill(Color.primary.opacity(0.5))
                                        .frame(height: 1)
                                        .offset(y: geometry.size.height / 2)
                                }
                            }
                        )

                    HStack(spacing: 8) {
                        // Priority badge
                        Text(action.priority.rawValue)
                            .dynamicFont(size: 11, weight: .semibold, fontManager: fontManager)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor(action.priority))
                            .cornerRadius(4)

                        if let time = action.estimatedTime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text("\(time) min")
                                    .dynamicFont(size: 11, fontManager: fontManager)
                            }
                            .foregroundColor(.secondary)
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
                    .stroke(isCompleted ? Color.green.opacity(0.3) : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func priorityColor(_ priority: ActionPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

struct AttendeeCard: View {
    let attendee: AttendeeContext
    let fontManager: FontManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(attendee.name.prefix(1).uppercased())
                            .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                            .foregroundColor(.blue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(attendee.name)
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)

                    if let role = attendee.role {
                        Text(role)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            if let lastMeeting = attendee.lastMeeting {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Last met \(timeAgo(lastMeeting))")
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }

            if let frequency = attendee.meetingFrequency {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Meets \(frequency.lowercased())")
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
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

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let days = Int(interval / 86400)

        if days == 0 {
            return "today"
        } else if days == 1 {
            return "yesterday"
        } else if days < 7 {
            return "\(days) days ago"
        } else if days < 30 {
            let weeks = days / 7
            return "\(weeks) week\(weeks > 1 ? "s" : "") ago"
        } else if days < 365 {
            let months = days / 30
            return "\(months) month\(months > 1 ? "s" : "") ago"
        } else {
            let years = days / 365
            return "\(years) year\(years > 1 ? "s" : "") ago"
        }
    }
}

struct RelatedItemRow: View {
    let item: RelatedItem
    let fontManager: FontManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)

                if let snippet = item.snippet {
                    Text(snippet)
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.url != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// FlowLayout removed - not needed for iOS 15 compatibility
