import SwiftUI

/// Quick insights preview sheet - shown when tapping AI button in Calendar/Tasks tabs
/// Shows today's conflicts and duplicates with option to view full Insights tab
struct QuickInsightsSheet: View {
    @ObservedObject var viewModel: InsightsViewModel
    @ObservedObject var fontManager: FontManager
    @ObservedObject var appearanceManager: AppearanceManager
    @Binding var isPresented: Bool
    var onViewFullInsights: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching app theme
                LinearGradient(
                    colors: appearanceManager.backgroundGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection

                        // Today's Summary
                        todaySummaryCard

                        // Conflicts (if any)
                        if !viewModel.conflicts.isEmpty {
                            conflictsCard
                        }

                        // Duplicates (if any)
                        if !viewModel.duplicates.isEmpty {
                            duplicatesCard
                        }

                        // View Full Insights Button
                        viewFullInsightsButton
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.purple)

            Text("Quick Insights")
                .dynamicFont(size: 28, weight: .bold, fontManager: fontManager)
                .foregroundColor(.primary)

            Text("AI-powered schedule analysis")
                .dynamicFont(size: 14, weight: .regular, fontManager: fontManager)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }

    // MARK: - Today's Summary Card

    private var todaySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                Text("Today")
                    .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)
                    .foregroundColor(.primary)
            }

            HStack(spacing: 20) {
                // Total events today
                StatBadge(
                    icon: "calendar",
                    count: viewModel.eventsToday,
                    label: "Events",
                    color: .blue
                )

                // Conflicts today
                StatBadge(
                    icon: "exclamationmark.triangle.fill",
                    count: todayConflictsCount,
                    label: "Conflicts",
                    color: .orange
                )

                // Duplicates today
                StatBadge(
                    icon: "doc.on.doc.fill",
                    count: todayDuplicatesCount,
                    label: "Duplicates",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - Conflicts Card

    private var conflictsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Schedule Conflicts")
                    .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(viewModel.conflicts.count)")
                    .dynamicFont(size: 16, weight: .bold, fontManager: fontManager)
                    .foregroundColor(.orange)
            }

            Divider()

            // Show first 3 conflicts
            ForEach(viewModel.conflicts.prefix(3)) { conflict in
                ConflictRow(conflict: conflict, fontManager: fontManager)
            }

            if viewModel.conflicts.count > 3 {
                Text("+ \(viewModel.conflicts.count - 3) more")
                    .dynamicFont(size: 12, weight: .regular, fontManager: fontManager)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - Duplicates Card

    private var duplicatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(.purple)
                Text("Duplicate Events")
                    .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(viewModel.duplicates.count)")
                    .dynamicFont(size: 16, weight: .bold, fontManager: fontManager)
                    .foregroundColor(.purple)
            }

            Divider()

            // Show first 3 duplicates
            ForEach(viewModel.duplicates.prefix(3)) { duplicate in
                DuplicateRow(duplicate: duplicate, fontManager: fontManager)
            }

            if viewModel.duplicates.count > 3 {
                Text("+ \(viewModel.duplicates.count - 3) more")
                    .dynamicFont(size: 12, weight: .regular, fontManager: fontManager)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - View Full Insights Button

    private var viewFullInsightsButton: some View {
        Button(action: {
            isPresented = false
            onViewFullInsights()
        }) {
            HStack {
                Text("View Full Insights")
                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                Image(systemName: "arrow.right")
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .padding(.top, 8)
    }

    // MARK: - Computed Properties

    private var todayConflictsCount: Int {
        // For simplicity, show all conflicts (they're already filtered to 7 days)
        return viewModel.conflicts.count
    }

    private var todayDuplicatesCount: Int {
        // For simplicity, show all duplicates (they're already filtered to 7 days)
        return viewModel.duplicates.count
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ConflictRow: View {
    let conflict: InsightsScheduleConflict
    let fontManager: FontManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(sourceColor(conflict.event1Source))
                    .frame(width: 8, height: 8)
                Text(conflict.event1Title)
                    .dynamicFont(size: 14, weight: .regular, fontManager: fontManager)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(sourceColor(conflict.event2Source))
                    .frame(width: 8, height: 8)
                Text(conflict.event2Title)
                    .dynamicFont(size: 14, weight: .regular, fontManager: fontManager)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Text("\(conflict.overlapMinutes) min overlap • \(conflict.timeDescription)")
                .dynamicFont(size: 12, weight: .regular, fontManager: fontManager)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func sourceColor(_ source: CalendarSource) -> Color {
        switch source {
        case .google: return .green
        case .ios: return .red
        case .outlook: return .blue
        }
    }
}

struct DuplicateRow: View {
    let duplicate: InsightsDuplicateEvent
    let fontManager: FontManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(duplicate.eventTitle)
                .dynamicFont(size: 14, weight: .regular, fontManager: fontManager)
                .foregroundColor(.primary)
                .lineLimit(1)

            HStack(spacing: 8) {
                // Show calendar source indicators
                ForEach(duplicate.sources, id: \.self) { source in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(sourceColor(source))
                            .frame(width: 6, height: 6)
                        Text(source.rawValue.capitalized)
                            .dynamicFont(size: 11, weight: .regular, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Confidence badge
                Text("\(Int(duplicate.confidence * 100))%")
                    .dynamicFont(size: 12, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 4)
    }

    private func sourceColor(_ source: CalendarSource) -> Color {
        switch source {
        case .google: return .green
        case .ios: return .red
        case .outlook: return .blue
        }
    }
}

#Preview {
    QuickInsightsSheet(
        viewModel: InsightsViewModel(),
        fontManager: FontManager(),
        appearanceManager: AppearanceManager(),
        isPresented: .constant(true),
        onViewFullInsights: {}
    )
}
