import SwiftUI

struct InsightsView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @ObservedObject var appearanceManager: AppearanceManager
    @StateObject private var viewModel = InsightsViewModel()
    @State private var showConflictSheet = false
    @State private var showHealthSheet = false
    @State private var selectedConflict: InsightsScheduleConflict?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView("Analyzing your schedule...")
                            .padding()
                    } else {
                        // Schedule Health Card
                        scheduleHealthCard

                        // Conflicts Card
                        if !viewModel.conflicts.isEmpty {
                            conflictsCard
                        }

                        // Logistics Analysis Card
                        if !viewModel.logisticsIssues.isEmpty {
                            logisticsCard
                        }

                        // Pattern Detection Card
                        if !viewModel.patterns.isEmpty {
                            patternsCard
                        }

                        // AI Recommendations Card
                        if !viewModel.recommendations.isEmpty {
                            recommendationsCard
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.configure(calendarManager: calendarManager)
                viewModel.analyzeSchedule()
            }
            .refreshable {
                await viewModel.refreshAnalysis()
            }
            .sheet(isPresented: $showConflictSheet) {
                if let conflict = selectedConflict {
                    ConflictDetailSheet(conflict: conflict, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showHealthSheet) {
                ScheduleHealthDetailSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Schedule Health Card
    private var scheduleHealthCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(.pink)
                Text("Schedule Health")
                    .dynamicFont(size: 20, weight: .bold, fontManager: fontManager)
                Spacer()
                Button(action: { showHealthSheet = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }

            // Circular Progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)

                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.healthScore) / 100)
                    .stroke(healthColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: viewModel.healthScore)

                VStack {
                    Text("\(Int(viewModel.healthScore))")
                        .dynamicFont(size: 48, weight: .bold, fontManager: fontManager)
                        .foregroundColor(healthColor)
                    Text("Health Score")
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 180, height: 180)
            .frame(maxWidth: .infinity)

            // Quick Stats
            VStack(spacing: 12) {
                statRow(icon: "calendar", label: "Events Today", value: "\(viewModel.eventsToday)")
                statRow(icon: "clock.fill", label: "Scheduled Hours", value: String(format: "%.1f hrs", viewModel.scheduledHours))
                statRow(icon: "exclamationmark.triangle.fill", label: "Conflicts", value: "\(viewModel.conflicts.count)", color: viewModel.conflicts.isEmpty ? .green : .red)
                statRow(icon: "car.fill", label: "Travel Time", value: String(format: "%.0f min", viewModel.totalTravelTime))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemGroupedBackground)))
    }

    private func statRow(icon: String, label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label)
                .dynamicFont(size: 14, fontManager: fontManager)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                .foregroundColor(color)
        }
    }

    private var healthColor: Color {
        if viewModel.healthScore >= 80 {
            return .green
        } else if viewModel.healthScore >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Conflicts Card
    private var conflictsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Schedule Conflicts")
                    .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)
                Spacer()
                Text("\(viewModel.conflicts.count)")
                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.red)
            }

            ForEach(viewModel.conflicts.prefix(3)) { conflict in
                Button(action: {
                    selectedConflict = conflict
                    showConflictSheet = true
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conflict.event1Title)
                                    .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)
                                Text(conflict.event2Title)
                                    .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }

                        Text(conflict.timeDescription)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("Overlap: \(conflict.overlapMinutes) min")
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
                }
            }

            if viewModel.conflicts.count > 3 {
                Text("+ \(viewModel.conflicts.count - 3) more conflicts")
                    .dynamicFont(size: 12, fontManager: fontManager)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemGroupedBackground)))
    }

    // MARK: - Logistics Card
    private var logisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.orange)
                Text("Logistics Analysis")
                    .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)
            }

            ForEach(viewModel.logisticsIssues) { issue in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: issue.icon)
                        .foregroundColor(issue.severity == .high ? .red : .orange)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.title)
                            .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                        Text(issue.description)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                        if let suggestion = issue.suggestion {
                            Text(suggestion)
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.blue)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemGroupedBackground)))
    }

    // MARK: - Patterns Card
    private var patternsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                Text("Schedule Patterns")
                    .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)
            }

            ForEach(viewModel.patterns) { pattern in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: pattern.icon)
                            .foregroundColor(.purple)
                        Text(pattern.title)
                            .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                    }

                    Text(pattern.description)
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    // Pattern visualization
                    if !pattern.dataPoints.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(pattern.dataPoints.indices, id: \.self) { index in
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.purple)
                                        .frame(height: CGFloat(pattern.dataPoints[index]) * 40)
                                }
                            }
                        }
                        .frame(height: 50)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.1)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemGroupedBackground)))
    }

    // MARK: - Recommendations Card
    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("AI Recommendations")
                    .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)
            }

            ForEach(viewModel.recommendations) { recommendation in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: recommendation.icon)
                            .foregroundColor(.blue)
                        Text(recommendation.title)
                            .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }

                    Text(recommendation.description)
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    if let action = recommendation.actionTitle {
                        Button(action: {
                            viewModel.executeRecommendation(recommendation)
                        }) {
                            Text(action)
                                .dynamicFont(size: 12, weight: .semibold, fontManager: fontManager)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemGroupedBackground)))
    }
}

// MARK: - Conflict Detail Sheet
struct ConflictDetailSheet: View {
    let conflict: InsightsScheduleConflict
    @ObservedObject var viewModel: InsightsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Conflict Overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Conflicting Events")
                            .font(.headline)

                        eventCard(title: conflict.event1Title, time: conflict.event1Time)
                        eventCard(title: conflict.event2Title, time: conflict.event2Time)

                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.red)
                            Text("Overlap: \(conflict.overlapMinutes) minutes")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
                    }

                    // Resolution Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resolution Options")
                            .font(.headline)

                        ForEach(conflict.resolutionOptions, id: \.self) { option in
                            Button(action: {
                                viewModel.resolveConflict(conflict, with: option)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.blue)
                                    Text(option)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Conflict Details")
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

    private func eventCard(title: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.tertiarySystemGroupedBackground)))
    }
}

// MARK: - Schedule Health Detail Sheet
struct ScheduleHealthDetailSheet: View {
    @ObservedObject var viewModel: InsightsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Health Score Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Health Score Breakdown")
                            .font(.headline)

                        healthMetricRow(title: "Time Utilization", score: viewModel.timeUtilizationScore, icon: "clock.fill")
                        healthMetricRow(title: "Conflict Management", score: viewModel.conflictScore, icon: "exclamationmark.triangle.fill")
                        healthMetricRow(title: "Work-Life Balance", score: viewModel.balanceScore, icon: "scale.3d")
                        healthMetricRow(title: "Buffer Time", score: viewModel.bufferScore, icon: "hourglass")
                    }

                    Divider()

                    // Detailed Metrics
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Detailed Metrics")
                            .font(.headline)

                        metricCard(title: "Events Today", value: "\(viewModel.eventsToday)", icon: "calendar", color: .blue)
                        metricCard(title: "Scheduled Hours", value: String(format: "%.1f hrs", viewModel.scheduledHours), icon: "clock.fill", color: .green)
                        metricCard(title: "Total Travel Time", value: String(format: "%.0f min", viewModel.totalTravelTime), icon: "car.fill", color: .orange)
                        metricCard(title: "Free Time Blocks", value: "\(viewModel.freeTimeBlocks)", icon: "moon.fill", color: .purple)
                    }
                }
                .padding()
            }
            .navigationTitle("Schedule Health")
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

    private func healthMetricRow(title: String, score: Double, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(score))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(scoreColor(score))
                        .frame(width: geometry.size.width * CGFloat(score / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.1)))
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}
