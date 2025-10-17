import SwiftUI
import EventKit

/// Interactive UI for resolving sync/version conflicts between calendars
struct SyncConflictResolutionView: View {
    let conflict: EventConflict
    let onResolve: (ConflictResolutionResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedResolution: ConflictResolutionStrategy = .createSeparate
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
            .background(Color(.systemBackground))
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
                .foregroundColor(.primary)

            Text(conflictDescription)
                .font(.body)
                .foregroundColor(.secondary)
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
                // Primary Event
                EventVersionCard(
                    title: "Your Device",
                    event: conflict.primaryEvent,
                    icon: "iphone",
                    color: .blue,
                    isSelected: selectedResolution == .useLocal
                )
                .onTapGesture {
                    HapticManager.shared.selection()
                    selectedResolution = .useLocal
                }

                // Remote Version
                if let conflictingEvent = conflict.conflictingEvents.first {
                    EventVersionCard(
                        title: conflictingEvent.source.displayName,
                        event: conflictingEvent,
                        icon: conflictingEvent.source.icon,
                        color: conflictingEvent.source.color,
                        isSelected: selectedResolution == .useRemote
                    )
                    .onTapGesture {
                        HapticManager.shared.selection()
                        selectedResolution = .useRemote
                    }
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
                strategy: .useLocal,
                title: "Keep Your Version",
                description: "Overwrite the remote version with your local changes",
                icon: "checkmark.circle.fill",
                isSelected: selectedResolution == .useLocal
            ) {
                HapticManager.shared.selection()
                selectedResolution = .useLocal
            }

            ResolutionOptionRow(
                strategy: .useRemote,
                title: "Keep Remote Version",
                description: "Discard your local changes and use the remote version",
                icon: "cloud.fill",
                isSelected: selectedResolution == .useRemote
            ) {
                HapticManager.shared.selection()
                selectedResolution = .useRemote
            }

            ResolutionOptionRow(
                strategy: .createSeparate,
                title: "Keep Both",
                description: "Create separate events for both versions",
                icon: "doc.on.doc.fill",
                isSelected: selectedResolution == .createSeparate
            ) {
                HapticManager.shared.selection()
                selectedResolution = .createSeparate
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
                .background(.blue)
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

    // MARK: - Computed Properties

    private var conflictDescription: String {
        switch conflict.type {
        case .duplicate:
            return "Duplicate event detected across calendar sources."
        case .timeOverlap:
            return "This event overlaps with existing events."
        case .simultaneousEdit:
            return "This event was modified simultaneously from different sources."
        }
    }

    // MARK: - Actions

    private func resolveConflict() {
        isProcessing = true
        HapticManager.shared.medium()

        let resolution = ConflictResolutionResult(
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
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Label(event.startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let notes = event.description, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(Color(.tertiaryLabel))
                        .lineLimit(2)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.secondarySystemBackground))
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
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
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
        .background(Color(.systemGray6))
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
                    .foregroundColor(.primary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local:")
                            .font(.caption2)
                            .foregroundColor(Color(.tertiaryLabel))
                        Text(difference.localValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(Color(.tertiaryLabel))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remote:")
                            .font(.caption2)
                            .foregroundColor(Color(.tertiaryLabel))
                        Text(difference.remoteValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Types

struct ConflictResolutionResult {
    let conflictId: UUID
    let strategy: ConflictResolutionStrategy
    let timestamp: Date
}

struct EventDifference: Identifiable {
    let id = UUID()
    let field: String
    let localValue: String
    let remoteValue: String

    var icon: String {
        switch field.lowercased() {
        case "title": return "textformat"
        case "start time", "end time", "time": return "clock"
        case "location": return "location"
        case "notes", "description": return "note.text"
        default: return "pencil"
        }
    }
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
    SyncConflictResolutionView(
        conflict: EventConflict(
            type: .simultaneousEdit,
            primaryEvent: UnifiedEvent(
                id: "event-1",
                title: "Team Meeting",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                location: "Conference Room A",
                description: "Discuss Q4 goals",
                isAllDay: false,
                source: .ios,
                organizer: nil,
                originalEvent: Optional<Any>.none as Any,
                calendarId: "preview-calendar",
                calendarName: "Personal",
                calendarColor: .blue
            ),
            conflictingEvents: [
                UnifiedEvent(
                    id: "event-1",
                    title: "Team Meeting (Updated)",
                    startDate: Date().addingTimeInterval(1800),
                    endDate: Date().addingTimeInterval(5400),
                    location: "Conference Room B",
                    description: "Discuss Q4 goals and budget",
                    isAllDay: false,
                    source: .google,
                    organizer: nil,
                    originalEvent: Optional<Any>.none as Any,
                    calendarId: "google-calendar",
                    calendarName: "Work",
                    calendarColor: .green
                )
            ],
            detectedAt: Date()
        )
    ) { resolution in
        print("Resolved with strategy: \(resolution.strategy)")
    }
}
