import SwiftUI

/// View that displays AI-powered smart scheduling suggestions
struct SmartSuggestionView: View {
    let suggestion: SmartSchedulingService.SchedulingSuggestion
    let onAccept: (Date) -> Void
    let onDismiss: () -> Void

    @State private var showingAlternatives = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                    .font(.title3)

                Text("Smart Suggestion")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }

            // Suggested Time
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Suggested Time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    ConfidenceBadge(confidence: suggestion.confidence)
                }

                Text(formatDate(suggestion.suggestedTime))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)

            // Reasons
            if !suggestion.reasons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Why this time?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(suggestion.reasons, id: \.self) { reason in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                    .offset(y: 2)

                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // Warnings (if any)
            if let warnings = suggestion.warnings, !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                                .offset(y: 2)

                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Actions
            VStack(spacing: 12) {
                // Accept button
                Button(action: {
                    onAccept(suggestion.suggestedTime)
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Use This Time")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }

                // Alternatives toggle
                if !suggestion.alternatives.isEmpty {
                    Button(action: {
                        withAnimation {
                            showingAlternatives.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: showingAlternatives ? "chevron.up" : "chevron.down")
                            Text(showingAlternatives ? "Hide Alternatives" : "Show \(suggestion.alternatives.count) Alternative Times")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
            }

            // Alternatives list (expandable)
            if showingAlternatives && !suggestion.alternatives.isEmpty {
                VStack(spacing: 8) {
                    ForEach(suggestion.alternatives, id: \.self) { altTime in
                        Button(action: {
                            onAccept(altTime)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatDate(altTime))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Text("Alternative option")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Badge showing confidence level
struct ConfidenceBadge: View {
    let confidence: Float

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.caption2)

            Text(confidenceText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(confidenceColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.15))
        .cornerRadius(12)
    }

    private var confidenceText: String {
        switch confidence {
        case 0.8...1.0:
            return "High Confidence"
        case 0.5..<0.8:
            return "Medium Confidence"
        default:
            return "Low Confidence"
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0:
            return .green
        case 0.5..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Pattern Confidence Indicator

/// View showing pattern analysis confidence
struct PatternConfidenceView: View {
    let patterns: SmartSchedulingService.CalendarPatterns

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)

                Text("AI Insights")
                    .font(.headline)

                Spacer()

                ConfidencePill(confidence: patterns.confidence)
            }

            if patterns.confidence != .none {
                VStack(alignment: .leading, spacing: 8) {
                    PatternRow(
                        icon: "clock",
                        label: "Preferred Times",
                        value: formatHours(patterns.preferredMeetingHours)
                    )

                    PatternRow(
                        icon: "timer",
                        label: "Typical Duration",
                        value: "\(Int(patterns.typicalMeetingDuration / 60)) min"
                    )

                    if patterns.hasLunchPattern, let lunchRange = patterns.lunchHourRange {
                        PatternRow(
                            icon: "fork.knife",
                            label: "Lunch Block",
                            value: formatLunchRange(lunchRange)
                        )
                    }

                    Text("Based on \(patterns.eventCount) events from the past 30 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Not enough calendar data yet. Add more events to get personalized suggestions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func formatHours(_ hours: [Int]) -> String {
        hours.map { hour in
            let period = hour >= 12 ? "PM" : "AM"
            let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
            return "\(displayHour)\(period)"
        }.joined(separator: ", ")
    }

    private func formatLunchRange(_ range: ClosedRange<Int>) -> String {
        let startPeriod = range.lowerBound >= 12 ? "PM" : "AM"
        let endPeriod = range.upperBound >= 12 ? "PM" : "AM"
        let startHour = range.lowerBound > 12 ? range.lowerBound - 12 : range.lowerBound
        let endHour = range.upperBound > 12 ? range.upperBound - 12 : range.upperBound
        return "\(startHour)\(startPeriod)-\(endHour)\(endPeriod)"
    }
}

struct PatternRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct ConfidencePill: View {
    let confidence: SmartSchedulingService.PatternConfidence

    var body: some View {
        Text(confidence.description)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(12)
    }

    private var color: Color {
        switch confidence {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .yellow
        case .none:
            return .gray
        }
    }
}

// MARK: - Preview

struct SmartSuggestionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SmartSuggestionView(
                suggestion: SmartSchedulingService.SchedulingSuggestion(
                    suggestedTime: Date().addingTimeInterval(86400),
                    confidence: 0.85,
                    reasons: [
                        "Matches your typical meeting time",
                        "Good buffer before your 11:30 call",
                        "Tuesday is typically a lighter day for you"
                    ],
                    alternatives: [
                        Date().addingTimeInterval(86400 + 3600),
                        Date().addingTimeInterval(86400 + 7200)
                    ],
                    warnings: ["During typical lunch hours"]
                ),
                onAccept: { _ in },
                onDismiss: {}
            )
            .padding()

            PatternConfidenceView(
                patterns: SmartSchedulingService.CalendarPatterns(
                    preferredMeetingHours: [10, 14, 16],
                    averageGapBetweenMeetings: 900,
                    typicalMeetingDuration: 1800,
                    busiestDays: [3, 5],
                    quietestDays: [2, 6],
                    hasLunchPattern: true,
                    lunchHourRange: 12...13,
                    confidence: .high,
                    eventCount: 45
                )
            )
            .padding()
        }
    }
}
