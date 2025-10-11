import SwiftUI

struct ConflictWarningView: View {
    let conflictResult: ConflictResult
    let proposedEventTitle: String
    let proposedStartDate: Date
    let proposedEndDate: Date
    let fontManager: FontManager

    let onCancel: () -> Void
    let onFindAlternative: (Date) -> Void
    let onOverride: () -> Void

    @State private var selectedAlternative: Date?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("Schedule Conflict")
                    .dynamicFont(size: 20, weight: .bold, fontManager: fontManager)

                Text("The time you selected conflicts with existing events")
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            // Proposed Event
            VStack(alignment: .leading, spacing: 8) {
                Text("You're trying to schedule:")
                    .dynamicFont(size: 12, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(proposedEventTitle)
                            .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)

                        Text(formatTimeRange(start: proposedStartDate, end: proposedEndDate))
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .padding(.horizontal)

            // Conflicting Events
            VStack(alignment: .leading, spacing: 8) {
                Text("Conflicts with:")
                    .dynamicFont(size: 12, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.secondary)

                ForEach(conflictResult.conflictingEvents) { conflict in
                    ConflictEventCard(conflict: conflict, fontManager: fontManager)
                }
            }
            .padding(.horizontal)

            // Alternative Times
            if !conflictResult.alternativeTimes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available times instead:")
                        .dynamicFont(size: 12, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    ForEach(conflictResult.alternativeTimes, id: \.self) { alternativeTime in
                        Button(action: {
                            selectedAlternative = alternativeTime
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatAlternativeDate(alternativeTime))
                                        .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                                        .foregroundColor(.primary)

                                    Text(formatTimeRange(start: alternativeTime, end: alternativeTime.addingTimeInterval(proposedEndDate.timeIntervalSince(proposedStartDate))))
                                        .dynamicFont(size: 12, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedAlternative == alternativeTime {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedAlternative == alternativeTime ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedAlternative == alternativeTime ? Color.green : Color.clear, lineWidth: 2)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Action Buttons
            VStack(spacing: 12) {
                if let alternative = selectedAlternative {
                    Button(action: {
                        onFindAlternative(alternative)
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.checkmark")
                            Text("Schedule at Selected Time")
                        }
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Button(action: {
                    onOverride()
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Schedule Anyway (Override)")
                    }
                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    onCancel()
                }) {
                    Text("Cancel")
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func formatAlternativeDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

struct ConflictEventCard: View {
    let conflict: ConflictingEvent
    let fontManager: FontManager

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.red)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(conflict.title)
                    .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)

                Text(formatTimeRange(start: conflict.startDate, end: conflict.endDate))
                    .dynamicFont(size: 12, fontManager: fontManager)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text(conflict.calendarSource)
                        .dynamicFont(size: 11, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    if let location = conflict.location {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(location)
                            .dynamicFont(size: 11, fontManager: fontManager)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
