import SwiftUI

struct SmartReschedulingView: View {
    let events: [UnifiedEvent]
    @ObservedObject var fontManager: FontManager
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedStrategy: BulkRescheduleOperation.RescheduleStrategy = .sequential
    @State private var constraints = RescheduleConstraints.default
    @State private var suggestedSlots: [TimeSlot] = []
    @State private var isLoading = false
    @State private var showingResults = false
    @State private var rescheduleResults: BulkRescheduleOperation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundColor(.blue)

                        Text("Smart Rescheduling")
                            .dynamicFont(size: 22, weight: .bold, fontManager: fontManager)
                    }

                    Text("\(events.count) event\(events.count == 1 ? "" : "s") to reschedule")
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Events to Reschedule
                VStack(alignment: .leading, spacing: 8) {
                    Text("Events")
                        .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)

                    VStack(spacing: 8) {
                        ForEach(events) { event in
                            EventCard(event: event, fontManager: fontManager)
                        }
                    }
                }

                // Strategy Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rescheduling Strategy")
                        .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)

                    VStack(spacing: 12) {
                        StrategyOption(
                            strategy: .sequential,
                            title: "Sequential",
                            description: "Reschedule events one after another, avoiding conflicts",
                            icon: "arrow.right.circle",
                            isSelected: selectedStrategy == .sequential,
                            fontManager: fontManager,
                            onSelect: { selectedStrategy = .sequential }
                        )

                        StrategyOption(
                            strategy: .optimized,
                            title: "Optimized",
                            description: "Find globally optimal schedule for all events",
                            icon: "sparkles",
                            isSelected: selectedStrategy == .optimized,
                            fontManager: fontManager,
                            onSelect: { selectedStrategy = .optimized }
                        )

                        StrategyOption(
                            strategy: .compact,
                            title: "Compact",
                            description: "Pack events closely together to free up time",
                            icon: "rectangle.compress.vertical",
                            isSelected: selectedStrategy == .compact,
                            fontManager: fontManager,
                            onSelect: { selectedStrategy = .compact }
                        )

                        StrategyOption(
                            strategy: .spread,
                            title: "Spread Out",
                            description: "Distribute events evenly throughout the week",
                            icon: "rectangle.expand.vertical",
                            isSelected: selectedStrategy == .spread,
                            fontManager: fontManager,
                            onSelect: { selectedStrategy = .spread }
                        )
                    }
                }

                // Constraints
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferences")
                        .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)

                    Toggle(isOn: $constraints.avoidConflicts) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avoid Conflicts")
                                .dynamicFont(size: 16, fontManager: fontManager)
                            Text("Only suggest conflict-free slots")
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $constraints.maintainAttendees) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep Attendees")
                                .dynamicFont(size: 16, fontManager: fontManager)
                            Text("Maintain same participants")
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $constraints.maintainLocation) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep Location")
                                .dynamicFont(size: 16, fontManager: fontManager)
                            Text("Don't change meeting location")
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

                // Find Slots Button
                Button(action: findTimeSlots) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "magnifyingglass")
                            Text("Find Time Slots")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isLoading)

                // Results
                if showingResults, let results = rescheduleResults {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Results")
                                .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)

                            Spacer()

                            Text("\(Int(results.successRate))% Success")
                                .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                                .foregroundColor(results.successRate >= 80 ? .green : results.successRate >= 50 ? .orange : .red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    (results.successRate >= 80 ? Color.green : results.successRate >= 50 ? Color.orange : Color.red).opacity(0.1)
                                )
                                .cornerRadius(6)
                        }

                        VStack(spacing: 8) {
                            ForEach(results.results, id: \.originalEvent.id) { result in
                                RescheduleResultCard(result: result, fontManager: fontManager)
                            }
                        }

                        // Apply Changes Button
                        if results.successRate > 0 {
                            Button(action: applyChanges) {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text("Apply Changes")
                                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Reschedule")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        })
    }

    // MARK: - Actions

    private func findTimeSlots() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let results = SmartReschedulingEngine.bulkReschedule(
                events: events,
                strategy: selectedStrategy,
                constraints: constraints,
                allEvents: calendarManager.unifiedEvents
            )

            DispatchQueue.main.async {
                self.rescheduleResults = results
                self.showingResults = true
                self.isLoading = false
            }
        }
    }

    private func applyChanges() {
        guard let results = rescheduleResults else { return }

        // TODO: Implement actual calendar updates
        // For now, just dismiss
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Subviews

struct EventCard: View {
    let event: UnifiedEvent
    let fontManager: FontManager

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTimeRange(start: event.startDate, end: event.endDate))
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        let startStr = formatter.string(from: start)

        formatter.dateFormat = "h:mm a"
        let endStr = formatter.string(from: end)

        return "\(startStr) - \(endStr)"
    }
}

struct StrategyOption: View {
    let strategy: BulkRescheduleOperation.RescheduleStrategy
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let fontManager: FontManager
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.primary)

                    Text(description)
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RescheduleResultCard: View {
    let result: RescheduleResult
    let fontManager: FontManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)

                Text(result.originalEvent.title)
                    .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)

                Spacer()
            }

            if result.success, let newSlot = result.newTimeSlot {
                HStack(spacing: 16) {
                    // Original time
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Original")
                            .dynamicFont(size: 11, fontManager: fontManager)
                            .foregroundColor(.secondary)
                        Text(formatTime(result.originalEvent.startDate))
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.blue)

                    // New time
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Time")
                            .dynamicFont(size: 11, fontManager: fontManager)
                            .foregroundColor(.secondary)
                        Text(formatTime(newSlot.start))
                            .dynamicFont(size: 12, weight: .semibold, fontManager: fontManager)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    // Score badge
                    VStack(spacing: 2) {
                        Text("\(Int(newSlot.score))")
                            .dynamicFont(size: 16, weight: .bold, fontManager: fontManager)
                            .foregroundColor(scoreColor(newSlot.score))
                        Text("Score")
                            .dynamicFont(size: 9, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(scoreColor(newSlot.score).opacity(0.1))
                    .cornerRadius(8)
                }

                // Reasons
                if !newSlot.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(newSlot.reasons.prefix(3), id: \.self) { reason in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text(reason)
                                    .dynamicFont(size: 11, fontManager: fontManager)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Conflicts warning
                if !result.conflicts.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(result.conflicts.count) conflict(s) detected")
                            .dynamicFont(size: 11, fontManager: fontManager)
                            .foregroundColor(.orange)
                    }
                    .padding(6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            } else {
                Text(result.message)
                    .dynamicFont(size: 12, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(result.success ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 90 { return .green }
        else if score >= 75 { return .blue }
        else if score >= 50 { return .orange }
        else { return .red }
    }
}

// MARK: - Single Event Rescheduling

struct SingleEventReschedulingView: View {
    let event: UnifiedEvent
    @ObservedObject var fontManager: FontManager
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.presentationMode) var presentationMode

    @State private var suggestedSlots: [TimeSlot] = []
    @State private var selectedSlot: TimeSlot?
    @State private var isLoading = false
    @State private var constraints = RescheduleConstraints.default

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Event Info
                EventCard(event: event, fontManager: fontManager)

                // Find Slots Button
                Button(action: findTimeSlots) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "magnifyingglass")
                            Text("Find Alternative Times")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isLoading)

                // Suggested Slots
                if !suggestedSlots.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggested Times")
                            .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)

                        VStack(spacing: 8) {
                            ForEach(suggestedSlots.prefix(10)) { slot in
                                TimeSlotCard(
                                    slot: slot,
                                    isSelected: selectedSlot?.id == slot.id,
                                    fontManager: fontManager,
                                    onSelect: { selectedSlot = slot }
                                )
                            }
                        }
                    }
                }

                // Apply Button
                if selectedSlot != nil {
                    Button(action: applyReschedule) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Reschedule Event")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Reschedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func findTimeSlots() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let slots = SmartReschedulingEngine.findTimeSlots(
                for: event,
                constraints: constraints,
                allEvents: calendarManager.unifiedEvents,
                searchDays: 14
            )

            DispatchQueue.main.async {
                self.suggestedSlots = slots
                self.isLoading = false
            }
        }
    }

    private func applyReschedule() {
        // TODO: Implement actual calendar update
        presentationMode.wrappedValue.dismiss()
    }
}

struct TimeSlotCard: View {
    let slot: TimeSlot
    let isSelected: Bool
    let fontManager: FontManager
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatTime(slot.start))
                            .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)

                        Text(formatDuration(slot.duration))
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Score
                    VStack(spacing: 2) {
                        Text("\(Int(slot.score))")
                            .dynamicFont(size: 20, weight: .bold, fontManager: fontManager)
                            .foregroundColor(scoreColor)
                        Text(slot.scoreCategory.rawValue)
                            .dynamicFont(size: 10, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(scoreColor.opacity(0.1))
                    .cornerRadius(8)
                }

                // Reasons
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(slot.reasons.prefix(3), id: \.self) { reason in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(reason)
                                .dynamicFont(size: 11, fontManager: fontManager)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Conflicts
                if slot.hasConflicts {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(slot.conflicts.count) conflict(s)")
                            .dynamicFont(size: 11, fontManager: fontManager)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var scoreColor: Color {
        switch slot.scoreCategory {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
