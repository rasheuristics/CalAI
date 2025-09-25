import SwiftUI

struct SyncStatusView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Real-time Sync Status
                    SyncStatusCard(calendarManager: calendarManager)

                    // Cross-Device Sync (Disabled)
                    CrossDeviceSyncDisabledCard()

                    // Performance Metrics
                    PerformanceMetricsCard(calendarManager: calendarManager)

                    // Webhooks Status
                    WebhooksStatusCard(calendarManager: calendarManager)

                    // Conflict Resolution
                    ConflictResolutionCard(calendarManager: calendarManager)

                    // Sync Actions
                    SyncActionsCard(calendarManager: calendarManager)
                }
                .padding()
            }
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await performRefresh()
            }
        }
    }

    private func performRefresh() async {
        await calendarManager.performOptimizedSync()
    }
}

struct SyncStatusCard: View {
    let calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Real-time Sync", systemImage: "arrow.clockwise.circle")
                .font(.headline)
                .foregroundColor(.primary)

            HStack {
                Circle()
                    .fill(syncStatusColor)
                    .frame(width: 12, height: 12)

                Text(syncStatusText)
                    .font(.subheadline)

                Spacer()

                if calendarManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let lastSync = calendarManager.lastSyncDate {
                Text("Last sync: \(lastSync.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !calendarManager.syncErrors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Errors:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)

                    ForEach(calendarManager.syncErrors.prefix(3)) { error in
                        Text("• \(error.description)")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var syncStatusColor: Color {
        if calendarManager.isSyncing {
            return .orange
        } else if calendarManager.syncErrors.isEmpty {
            return .green
        } else {
            return .red
        }
    }

    private var syncStatusText: String {
        if calendarManager.isSyncing {
            return "Syncing..."
        } else if calendarManager.syncErrors.isEmpty {
            return "Up to date"
        } else {
            return "Sync errors"
        }
    }
}

struct CrossDeviceSyncDisabledCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cross-Device Sync", systemImage: "icloud.slash")
                .font(.headline)
                .foregroundColor(.primary)

            HStack {
                Circle()
                    .fill(.gray)
                    .frame(width: 12, height: 12)

                Text("Disabled in this version")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }

            Text("Cross-device sync will be available in a future update")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PerformanceMetricsCard: View {
    let calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Performance Metrics", systemImage: "speedometer")
                .font(.headline)
                .foregroundColor(.primary)

            let metrics = calendarManager.deltaPerformanceMetrics

            HStack {
                VStack(alignment: .leading) {
                    Text("Processing Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2fs", metrics.averageProcessingTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Compression")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", metrics.compressionRatio * 100))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Events Cached")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(metrics.totalEventsCached)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WebhooksStatusCard: View {
    let calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Webhooks", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
                .foregroundColor(.primary)

            Text("\(calendarManager.registeredWebhooks.count) registered webhooks")
                .font(.subheadline)

            ForEach(calendarManager.registeredWebhooks) { webhook in
                HStack {
                    Circle()
                        .fill(webhook.isActive ? .green : .red)
                        .frame(width: 8, height: 8)

                    Text(webhook.source.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    if webhook.isExpiringSoon {
                        Text("Expiring Soon")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    } else {
                        Text("Active")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 2)
            }

            if calendarManager.registeredWebhooks.isEmpty {
                Text("No webhooks registered")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ConflictResolutionCard: View {
    let calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Conflict Resolution", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundColor(.primary)

            let pendingConflicts = calendarManager.pendingConflicts.count

            HStack {
                Circle()
                    .fill(pendingConflicts > 0 ? .orange : .green)
                    .frame(width: 12, height: 12)

                if pendingConflicts > 0 {
                    Text("\(pendingConflicts) conflicts need attention")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                } else {
                    Text("No conflicts")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }

                Spacer()
            }

            if pendingConflicts > 0 {
                Button("Resolve Conflicts") {
                    calendarManager.resolveAllConflicts()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SyncActionsCard: View {
    let calendarManager: CalendarManager

    var body: some View {
        VStack(spacing: 12) {
            Label("Sync Actions", systemImage: "gear")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                Button(action: {
                    Task {
                        await calendarManager.performOptimizedSync()
                    }
                }) {
                    VStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                        Text("Sync Now")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }


                Button(action: {
                    calendarManager.resolveAllConflicts()
                }) {
                    VStack {
                        Image(systemName: "checkmark.seal")
                            .font(.title2)
                        Text("Resolve Conflicts")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }

                Button(action: {
                    // Reset sync metrics
                    DeltaSyncManager.shared.resetPerformanceMetrics()
                }) {
                    VStack {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Reset Metrics")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    SyncStatusView(
        calendarManager: CalendarManager(),
        fontManager: FontManager()
    )
}