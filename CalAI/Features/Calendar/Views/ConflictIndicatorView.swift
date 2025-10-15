import SwiftUI

// MARK: - Conflict Indicator Badge

/// Small badge that appears on calendar events to indicate conflicts
struct ConflictIndicatorBadge: View {
    let severity: ConflictSeverity

    var body: some View {
        Image(systemName: severity.icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(4)
            .background(
                Circle()
                    .fill(severityColor)
            )
            .shadow(color: severityColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }

    private var severityColor: Color {
        switch severity {
        case .low:
            return .yellow
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
}

// MARK: - Conflict Alert Banner

/// Banner that appears at the top of the calendar to show conflict count
struct ConflictAlertBanner: View {
    let conflictCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(conflictCount) Scheduling Conflict\(conflictCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Tap to view and resolve")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Conflict Details Card

/// Detailed card showing conflict information
struct ConflictDetailsCard: View {
    let conflict: ScheduleConflict

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with severity indicator
            HStack {
                ConflictIndicatorBadge(severity: conflict.severity)

                Text("\(conflict.severity.rawValue) Conflict")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text(conflict.overlapDurationFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
            }

            // Overlapping period
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(timeRangeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Conflicting events
            VStack(alignment: .leading, spacing: 8) {
                ForEach(conflict.conflictingEvents) { event in
                    ConflictEventRow(event: event)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: conflict.overlapStart)) - \(formatter.string(from: conflict.overlapEnd))"
    }
}

// MARK: - Conflict Event Row

/// Individual event row within a conflict card
struct ConflictEventRow: View {
    let event: UnifiedEvent

    var body: some View {
        HStack(spacing: 10) {
            // Source icon
            Text(sourceEmoji)
                .font(.caption)

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(timeString)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }

    private var sourceEmoji: String {
        switch event.source {
        case .ios:
            return "📱"
        case .google:
            return "🟢"
        case .outlook:
            return "🔵"
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}

// MARK: - Conflict List View

/// Full-screen view showing all conflicts
struct ConflictListView: View {
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedConflict: ScheduleConflict?
    @State private var showingConflictResolution = false

    var body: some View {
        NavigationView {
            ScrollView {
                if calendarManager.detectedConflicts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("No Conflicts Detected")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("All your events are scheduled without overlaps")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(calendarManager.detectedConflicts) { conflict in
                            Button(action: {
                                selectedConflict = conflict
                                showingConflictResolution = true
                            }) {
                                ConflictDetailsCard(conflict: conflict)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                ForEach(conflict.conflictingEvents) { event in
                                    Button(role: .destructive) {
                                        deleteEventFromConflict(event)
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: "trash.fill")
                                                .font(.title3)
                                            Text(event.title)
                                                .font(.caption2)
                                                .lineLimit(1)
                                        }
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .sheet(isPresented: $showingConflictResolution) {
                        if let conflict = selectedConflict {
                            ConflictResolutionView(conflict: conflict, calendarManager: calendarManager)
                        }
                    }
                }
            }
            .navigationTitle("Schedule Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !calendarManager.detectedConflicts.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            calendarManager.detectAllConflicts()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Delete Event from Conflict

    private func deleteEventFromConflict(_ event: UnifiedEvent) {
        print("🗑️ Swipe delete triggered for: \(event.title)")

        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete Event",
            message: "Delete '\(event.title)'? This will remove the event from your calendar and resolve the conflict.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.performDeleteEvent(event)
        })

        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    private func performDeleteEvent(_ event: UnifiedEvent) {
        print("🗑️ Deleting event: \(event.title) (ID: \(event.id))")

        // Delete the event (don't refresh unified events - we'll handle it manually)
        calendarManager.deleteEvent(event, refreshUnifiedEvents: false)

        // Immediately remove from unified events
        calendarManager.unifiedEvents.removeAll { $0.id == event.id }
        print("📊 Removed event from unified events. Count: \(calendarManager.unifiedEvents.count)")

        // Re-detect conflicts with updated list
        calendarManager.detectAllConflicts()
        print("📊 Conflicts after deletion: \(calendarManager.detectedConflicts.count)")

        // Haptic feedback
        HapticManager.shared.success()
    }
}

// MARK: - Schedule Conflict Resolution View

/// View for resolving time-based scheduling conflicts with AI suggestions
/// (For sync conflicts between calendar versions, see SyncConflictResolutionView)
struct ConflictResolutionView: View {
    let conflict: ScheduleConflict
    @ObservedObject var calendarManager: CalendarManager
    @State private var resolutionSuggestions: [ResolutionSuggestion] = []
    @State private var isLoadingSuggestions = false
    @Environment(\.dismiss) var dismiss

    private let conflictAI = ConflictResolutionAI()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Conflict details
                ConflictDetailsCard(conflict: conflict)

                // AI Suggestions section
                HStack {
                    Text("AI-Powered Suggestions")
                        .font(.headline)

                    if isLoadingSuggestions {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.leading, 8)
                    }
                }
                .padding(.horizontal)

                if resolutionSuggestions.isEmpty && !isLoadingSuggestions {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)

                        Text("Generating smart suggestions...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        ForEach(resolutionSuggestions) { suggestion in
                            ResolutionSuggestionCard(
                                suggestion: suggestion,
                                onSelect: {
                                    handleSuggestion(suggestion)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Resolve Conflict")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAISuggestions()
        }
    }

    private func loadAISuggestions() {
        isLoadingSuggestions = true

        conflictAI.generateSuggestions(
            for: conflict,
            allEvents: calendarManager.unifiedEvents
        ) { resolution in
            resolutionSuggestions = resolution.suggestions
            isLoadingSuggestions = false
        }
    }

    private func handleSuggestion(_ suggestion: ResolutionSuggestion) {
        print("🎯 User selected suggestion: \(suggestion.type.rawValue)")
        HapticManager.shared.light()

        switch suggestion.type {
        case .reschedule:
            rescheduleEvent(suggestion)
        case .decline:
            declineEvent(suggestion)
        case .shorten:
            shortenEvent(suggestion)
        case .markOptional:
            markAsOptional(suggestion)
        case .noAction:
            keepBoth(suggestion)
        }
    }

    // MARK: - Resolution Actions

    private func rescheduleEvent(_ suggestion: ResolutionSuggestion) {
        guard let targetEvent = suggestion.targetEvent,
              let newTime = suggestion.suggestedTime else {
            print("❌ Missing target event or suggested time")
            return
        }

        HapticManager.shared.medium()

        // Calculate duration of original event
        let duration = targetEvent.endDate.timeIntervalSince(targetEvent.startDate)
        let newEndTime = newTime.addingTimeInterval(duration)

        // Create updated event
        let updatedEvent = UnifiedEvent(
            id: targetEvent.id,
            title: targetEvent.title,
            startDate: newTime,
            endDate: newEndTime,
            location: targetEvent.location,
            description: targetEvent.description,
            isAllDay: targetEvent.isAllDay,
            source: targetEvent.source,
            organizer: targetEvent.organizer,
            originalEvent: targetEvent.originalEvent
        )

        // Update in calendar manager
        calendarManager.updateEvent(updatedEvent)

        HapticManager.shared.success()
        showSuccessMessage("Event rescheduled to \(formatTime(newTime))")

        // Refresh conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            calendarManager.detectAllConflicts()
            dismiss()
        }
    }

    private func declineEvent(_ suggestion: ResolutionSuggestion) {
        guard let targetEvent = suggestion.targetEvent else {
            print("❌ Missing target event")
            return
        }

        HapticManager.shared.medium()

        // Delete the event (don't refresh unified events - we'll handle it manually)
        calendarManager.deleteEvent(targetEvent, refreshUnifiedEvents: false)

        // Immediately remove from unified events to update conflicts
        calendarManager.unifiedEvents.removeAll { $0.id == targetEvent.id }
        print("📊 Removed event from unified events. Count: \(calendarManager.unifiedEvents.count)")

        // Re-detect conflicts with updated list
        calendarManager.detectAllConflicts()
        print("📊 Conflicts after deletion: \(calendarManager.detectedConflicts.count)")

        HapticManager.shared.success()
        showSuccessMessage("Event '\(targetEvent.title)' declined")

        // Dismiss after showing message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }

    private func shortenEvent(_ suggestion: ResolutionSuggestion) {
        guard let targetEvent = suggestion.targetEvent,
              let newEndTime = suggestion.suggestedTime else {
            print("❌ Missing target event or suggested time")
            return
        }

        HapticManager.shared.medium()

        // Create updated event with shortened duration
        let updatedEvent = UnifiedEvent(
            id: targetEvent.id,
            title: targetEvent.title,
            startDate: targetEvent.startDate,
            endDate: newEndTime,
            location: targetEvent.location,
            description: targetEvent.description,
            isAllDay: targetEvent.isAllDay,
            source: targetEvent.source,
            organizer: targetEvent.organizer,
            originalEvent: targetEvent.originalEvent
        )

        // Update in calendar manager
        calendarManager.updateEvent(updatedEvent)

        HapticManager.shared.success()
        showSuccessMessage("Event shortened to end at \(formatTime(newEndTime))")

        // Refresh conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            calendarManager.detectAllConflicts()
            dismiss()
        }
    }

    private func markAsOptional(_ suggestion: ResolutionSuggestion) {
        guard let targetEvent = suggestion.targetEvent else {
            print("❌ Missing target event")
            return
        }

        HapticManager.shared.light()

        // Update event notes to indicate it's optional
        let optionalNote = (targetEvent.description ?? "") + "\n\n[OPTIONAL - Can skip if needed]"

        let updatedEvent = UnifiedEvent(
            id: targetEvent.id,
            title: "⚪️ \(targetEvent.title)", // Add indicator to title
            startDate: targetEvent.startDate,
            endDate: targetEvent.endDate,
            location: targetEvent.location,
            description: optionalNote,
            isAllDay: targetEvent.isAllDay,
            source: targetEvent.source,
            organizer: targetEvent.organizer,
            originalEvent: targetEvent.originalEvent
        )

        // Update in calendar manager
        calendarManager.updateEvent(updatedEvent)

        HapticManager.shared.success()
        showSuccessMessage("Event marked as optional")

        // Refresh conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            calendarManager.detectAllConflicts()
            dismiss()
        }
    }

    private func keepBoth(_ suggestion: ResolutionSuggestion) {
        HapticManager.shared.light()

        showSuccessMessage("Keeping both events as scheduled")

        // Just dismiss - user accepts the conflict
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }

    // MARK: - Helper Methods

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func showSuccessMessage(_ message: String) {
        print("✅ \(message)")
        // TODO: Show toast notification to user
    }
}

// MARK: - Resolution Suggestion Card

struct ResolutionSuggestionCard: View {
    let suggestion: ResolutionSuggestion
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: suggestion.type.icon)
                    .font(.title2)
                    .foregroundColor(typeColor)
                    .frame(width: 40)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // Confidence indicator
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(suggestion.confidence * 5) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(typeColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var typeColor: Color {
        switch suggestion.type {
        case .reschedule:
            return .blue
        case .decline:
            return .red
        case .shorten:
            return .orange
        case .markOptional:
            return .purple
        case .noAction:
            return .green
        }
    }
}

// MARK: - Resolution Option Card

struct ResolutionOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}
