import SwiftUI
import EventKit

/// Interactive UI for resolving calendar event conflicts
struct ConflictResolutionView: View {
    let conflict: EventConflict
    let onResolve: (ConflictResolution) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedResolution: ConflictResolutionStrategy = .keepBoth
    @State private var isProcessing = false
    @State private var showingDetails = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Conflict Header
                    conflictHeader

                    // Event Comparison
                    eventComparison

                    // Resolution Options
                    resolutionOptions

                    // Action Buttons
                    actionButtons
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.Background.primary)
            .navigationTitle("Resolve Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Conflict Header

    private var conflictHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Sync Conflict Detected")
                .font(.title2.bold())
                .foregroundColor(DesignSystem.Colors.Text.primary)

            Text(conflict.description)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Event Comparison

    private var eventComparison: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Conflicting Versions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Local Version
                EventVersionCard(
                    title: "Your Device",
                    event: conflict.localEvent,
                    icon: "iphone",
                    color: .blue,
                    isSelected: selectedResolution == .keepLocal
                )
                .onTapGesture {
                    HapticManager.shared.selection()
                    selectedResolution = .keepLocal
                }

                // Remote Version
                EventVersionCard(
                    title: conflict.remoteSource.displayName,
                    event: conflict.remoteEvent,
                    icon: conflict.remoteSource.icon,
                    color: conflict.remoteSource.color,
                    isSelected: selectedResolution == .keepRemote
                )
                .onTapGesture {
                    HapticManager.shared.selection()
                    selectedResolution = .keepRemote
                }
            }

            // Differences
            if !conflict.differences.isEmpty {
                Button(action: {
                    showingDetails.toggle()
                    HapticManager.shared.light()
                }) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                        Text("View \(conflict.differences.count) Difference\(conflict.differences.count == 1 ? "" : "s")")
                        Spacer()
                        Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(DesignSystem.Spacing.md)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }

                if showingDetails {
                    DifferencesListView(differences: conflict.differences)
                }
            }
        }
    }

    // MARK: - Resolution Options

    private var resolutionOptions: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Resolution Strategy")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ResolutionOptionRow(
                strategy: .keepLocal,
                title: "Keep Your Version",
                description: "Overwrite the remote version with your local changes",
                icon: "checkmark.circle.fill",
                isSelected: selectedResolution == .keepLocal
            ) {
                HapticManager.shared.selection()
                selectedResolution = .keepLocal
            }

            ResolutionOptionRow(
                strategy: .keepRemote,
                title: "Keep Remote Version",
                description: "Discard your local changes and use the remote version",
                icon: "cloud.fill",
                isSelected: selectedResolution == .keepRemote
            ) {
                HapticManager.shared.selection()
                selectedResolution = .keepRemote
            }

            ResolutionOptionRow(
                strategy: .keepBoth,
                title: "Keep Both",
                description: "Create separate events for both versions",
                icon: "doc.on.doc.fill",
                isSelected: selectedResolution == .keepBoth
            ) {
                HapticManager.shared.selection()
                selectedResolution = .keepBoth
            }

            ResolutionOptionRow(
                strategy: .merge,
                title: "Merge (Advanced)",
                description: "Manually merge the two versions",
                icon: "arrow.triangle.merge",
                isSelected: selectedResolution == .merge
            ) {
                HapticManager.shared.selection()
                selectedResolution = .merge
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: resolveConflict) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Resolve Conflict")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.Primary.blue)
                .foregroundColor(.white)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
            .disabled(isProcessing)

            Button("Apply to All Similar Conflicts") {
                resolveAllSimilar()
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
    }

    // MARK: - Actions

    private func resolveConflict() {
        isProcessing = true
        HapticManager.shared.medium()

        let resolution = ConflictResolution(
            conflictId: conflict.id,
            strategy: selectedResolution,
            timestamp: Date()
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onResolve(resolution)
            HapticManager.shared.success()
            dismiss()
        }
    }

    private func resolveAllSimilar() {
        HapticManager.shared.light()
        // Implementation for applying resolution to all similar conflicts
        print("📋 Applying \(selectedResolution) to all similar conflicts")
    }
}

// MARK: - Event Version Card

struct EventVersionCard: View {
    let title: String
    let event: UnifiedEvent
    let icon: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.Text.secondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Divider()

            // Event Details
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.Text.primary)
                    .lineLimit(2)

                Label(event.startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.Text.secondary)

                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.Text.secondary)
                        .lineLimit(1)
                }

                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.Text.tertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.Background.secondary)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(isSelected ? color : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Resolution Option Row

struct ResolutionOptionRow: View {
    let strategy: ConflictResolutionStrategy
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.Text.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(isSelected ? Color.blue.opacity(0.1) : DesignSystem.Colors.Background.secondary)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Differences List

struct DifferencesListView: View {
    let differences: [EventDifference]

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(differences) { difference in
                DifferenceRow(difference: difference)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.Background.tertiary)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

struct DifferenceRow: View {
    let difference: EventDifference

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: difference.icon)
                .foregroundColor(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(difference.field)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.Text.primary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local:")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.Text.tertiary)
                        Text(difference.localValue)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.Text.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.Text.tertiary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remote:")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.Text.tertiary)
                        Text(difference.remoteValue)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.Text.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Types

struct EventConflict: Identifiable {
    let id: String
    let localEvent: UnifiedEvent
    let remoteEvent: UnifiedEvent
    let remoteSource: CalendarSource
    let differences: [EventDifference]
    let detectedAt: Date

    var description: String {
        "This event has been modified on both your device and \(remoteSource.displayName). Choose which version to keep."
    }
}

struct EventDifference: Identifiable {
    let id = UUID()
    let field: String
    let localValue: String
    let remoteValue: String

    var icon: String {
        switch field.lowercased() {
        case "title":
            return "textformat"
        case "time", "start", "end":
            return "clock"
        case "location":
            return "location"
        case "notes", "description":
            return "note.text"
        default:
            return "pencil"
        }
    }
}

enum ConflictResolutionStrategy {
    case keepLocal
    case keepRemote
    case keepBoth
    case merge
}

struct ConflictResolution {
    let conflictId: String
    let strategy: ConflictResolutionStrategy
    let timestamp: Date
}

extension CalendarSource {
    var displayName: String {
        switch self {
        case .ios:
            return "iOS Calendar"
        case .google:
            return "Google Calendar"
        case .outlook:
            return "Outlook Calendar"
        }
    }

    var icon: String {
        switch self {
        case .ios:
            return "calendar"
        case .google:
            return "globe"
        case .outlook:
            return "envelope"
        }
    }

    var color: Color {
        return DesignSystem.Colors.forCalendarSource(self)
    }
}

// MARK: - Preview

#Preview {
    ConflictResolutionView(
        conflict: EventConflict(
            id: "conflict-1",
            localEvent: UnifiedEvent(
                id: "event-1",
                title: "Team Meeting",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                location: "Conference Room A",
                notes: "Discuss Q4 goals",
                isAllDay: false,
                calendarSource: .ios
            ),
            remoteEvent: UnifiedEvent(
                id: "event-1",
                title: "Team Meeting (Updated)",
                startDate: Date().addingTimeInterval(1800),
                endDate: Date().addingTimeInterval(5400),
                location: "Conference Room B",
                notes: "Discuss Q4 goals and budget",
                isAllDay: false,
                calendarSource: .google
            ),
            remoteSource: .google,
            differences: [
                EventDifference(field: "Title", localValue: "Team Meeting", remoteValue: "Team Meeting (Updated)"),
                EventDifference(field: "Start Time", localValue: "2:00 PM", remoteValue: "2:30 PM"),
                EventDifference(field: "Location", localValue: "Conference Room A", remoteValue: "Conference Room B"),
                EventDifference(field: "Notes", localValue: "Discuss Q4 goals", remoteValue: "Discuss Q4 goals and budget")
            ],
            detectedAt: Date()
        )
    ) { resolution in
        print("Resolved with strategy: \(resolution.strategy)")
    }
}
