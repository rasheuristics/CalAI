//
//  InvitationsInboxView.swift
//  CalAI
//
//  iOS-style calendar invitations inbox
//  Created by Claude Code on 11/9/25.
//

import SwiftUI

struct InvitationsInboxView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSegment = 0

    private var newInvitations: [CalendarInvitation] {
        calendarManager.invitations.filter { $0.status == .pending }
    }

    private var repliedInvitations: [CalendarInvitation] {
        calendarManager.invitations.filter { $0.status != .pending }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented control for New/Replied
                Picker("", selection: $selectedSegment) {
                    Text("New (\(newInvitations.count))").tag(0)
                    Text("Replied (\(repliedInvitations.count))").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Invitations list
                if selectedSegment == 0 {
                    if newInvitations.isEmpty {
                        EmptyInboxView(message: "No new invitations")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(newInvitations) { invitation in
                                    InvitationCard(
                                        invitation: invitation,
                                        fontManager: fontManager,
                                        onAccept: {
                                            calendarManager.respondToInvitation(invitation, response: .accepted)
                                        },
                                        onMaybe: {
                                            calendarManager.respondToInvitation(invitation, response: .tentative)
                                        },
                                        onDecline: {
                                            calendarManager.respondToInvitation(invitation, response: .declined)
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    if repliedInvitations.isEmpty {
                        EmptyInboxView(message: "No replied invitations")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(repliedInvitations) { invitation in
                                    RepliedInvitationCard(
                                        invitation: invitation,
                                        fontManager: fontManager
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Invitation Card (New)

struct InvitationCard: View {
    let invitation: CalendarInvitation
    @ObservedObject var fontManager: FontManager
    let onAccept: () -> Void
    let onMaybe: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with calendar source
            HStack {
                Image(systemName: invitation.source == .ios ? "calendar" : invitation.source == .google ? "globe" : "envelope")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(invitation.calendarName ?? invitation.source.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Event title
            Text(invitation.title)
                .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            // Organizer
            if let organizer = invitation.organizer {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(organizer)
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }

            // Date and time
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatDateRange(start: invitation.startDate, end: invitation.endDate))
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }

            // Location
            if let location = invitation.location, !location.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(location)
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                // Decline
                Button(action: onDecline) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Decline")
                            .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }

                // Maybe
                Button(action: onMaybe) {
                    HStack {
                        Image(systemName: "questionmark")
                        Text("Maybe")
                            .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }

                // Accept
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Accept")
                            .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let calendar = Calendar.current
        if calendar.isDate(start, inSameDayAs: end) {
            // Same day
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, h:mm a"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            return "\(dateFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
        } else {
            // Different days
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
}

// MARK: - Replied Invitation Card

struct RepliedInvitationCard: View {
    let invitation: CalendarInvitation
    @ObservedObject var fontManager: FontManager

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: invitation.status.icon)
                .font(.title2)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                // Event title
                Text(invitation.title)
                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.primary)

                // Date
                Text(formatDate(invitation.startDate))
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)

                // Status
                Text(invitation.status.displayName)
                    .dynamicFont(size: 13, fontManager: fontManager)
                    .foregroundColor(statusColor)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch invitation.status {
        case .accepted: return .green
        case .declined: return .red
        case .tentative: return .orange
        case .pending: return .blue
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Empty Inbox View

struct EmptyInboxView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    InvitationsInboxView(
        calendarManager: CalendarManager(),
        fontManager: FontManager()
    )
}
