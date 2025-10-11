import SwiftUI

/// Comprehensive sync status indicators and controls
struct SyncStatusBar: View {
    @ObservedObject var syncManager = SyncQueueManager.shared
    @ObservedObject var offlineManager = OfflineModeManager.shared

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Compact status bar
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    statusIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusText)
                            .font(.caption.weight(.medium))
                            .foregroundColor(statusColor)

                        if syncManager.isSyncing {
                            Text("\(Int(syncManager.syncProgress * 100))%")
                                .font(.caption2)
                                .foregroundColor(statusColor.opacity(0.7))
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(backgroundColor)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                expandedDetails
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Status Components

    private var statusIcon: some View {
        Group {
            if syncManager.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !offlineManager.isOnline {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.red)
            } else if offlineManager.isOfflineModeEnabled {
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
            } else if syncManager.syncErrors.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .frame(width: 20, height: 20)
    }

    private var statusText: String {
        if syncManager.isSyncing {
            return "Syncing..."
        } else if !offlineManager.isOnline {
            return "Offline"
        } else if offlineManager.isOfflineModeEnabled {
            return "Sync Paused"
        } else if !syncManager.syncErrors.isEmpty {
            return "\(syncManager.syncErrors.count) Sync Errors"
        } else if let lastSync = syncManager.lastSyncDate {
            return "Synced \(lastSync.timeAgoDisplay)"
        } else {
            return "Not Synced"
        }
    }

    private var statusColor: Color {
        if syncManager.isSyncing {
            return .blue
        } else if !offlineManager.isOnline || offlineManager.isOfflineModeEnabled {
            return .orange
        } else if !syncManager.syncErrors.isEmpty {
            return .red
        } else {
            return .green
        }
    }

    private var backgroundColor: Color {
        statusColor.opacity(0.1)
    }

    // MARK: - Expanded Details

    private var expandedDetails: some View {
        VStack(spacing: 12) {
            Divider()

            // Network Status
            HStack {
                Label("Network", systemImage: offlineManager.isOnline ? "wifi" : "wifi.slash")
                    .font(.caption)
                Spacer()
                Text(offlineManager.connectionType.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            // Pending Operations
            if offlineManager.pendingOperations.count > 0 {
                HStack {
                    Label("Pending", systemImage: "clock")
                        .font(.caption)
                    Spacer()
                    Text("\(offlineManager.pendingOperations.count) operations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
            }

            // Sync Progress
            if syncManager.isSyncing {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                        Spacer()
                        Text("\(syncManager.syncStatistics.activeTasks) active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: syncManager.syncProgress)
                        .tint(statusColor)
                }
                .padding(.horizontal, 16)
            }

            // Action Buttons
            HStack(spacing: 12) {
                if offlineManager.isOfflineModeEnabled {
                    Button(action: {
                        offlineManager.enableOfflineMode(false)
                    }) {
                        Label("Resume Sync", systemImage: "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                } else if !syncManager.isSyncing {
                    Button(action: {
                        syncManager.processSyncQueue()
                    }) {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }

                if !syncManager.syncErrors.isEmpty {
                    Button(action: {
                        syncManager.retryFailedTasks()
                    }) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }

                NavigationLink(destination: SyncQueueView()) {
                    Label("Details", systemImage: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Floating Sync Indicator

struct FloatingSyncIndicator: View {
    @ObservedObject var syncManager = SyncQueueManager.shared

    var body: some View {
        Group {
            if syncManager.isSyncing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)

                    Text("Syncing...")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(), value: syncManager.isSyncing)
    }
}

// MARK: - Event Sync Badge

struct EventSyncBadge: View {
    let status: EventSyncStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            if status != .synced {
                Text(status.displayName)
            }
        }
        .font(.caption2)
        .foregroundColor(status.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(status.color.opacity(0.15))
        )
    }
}

enum EventSyncStatus {
    case synced
    case pending
    case syncing
    case failed

    var displayName: String {
        switch self {
        case .synced:
            return ""
        case .pending:
            return "Pending"
        case .syncing:
            return "Syncing"
        case .failed:
            return "Failed"
        }
    }

    var icon: String {
        switch self {
        case .synced:
            return "checkmark.circle.fill"
        case .pending:
            return "clock.fill"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .synced:
            return .green
        case .pending:
            return .orange
        case .syncing:
            return .blue
        case .failed:
            return .red
        }
    }
}

// MARK: - Sync Progress HUD

struct SyncProgressHUD: View {
    @ObservedObject var syncManager = SyncQueueManager.shared
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented && syncManager.isSyncing {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }

                VStack(spacing: 16) {
                    ProgressView(value: syncManager.syncProgress)
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .tint(.white)

                    VStack(spacing: 4) {
                        Text("Syncing Events")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("\(Int(syncManager.syncProgress * 100))% Complete")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        Text("\(syncManager.syncStatistics.activeTasks) active tasks")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Date Extension

extension Date {
    var timeAgoDisplay: String {
        let seconds = Date().timeIntervalSince(self)

        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes) min ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Preview

#Preview("Sync Status Bar - Syncing") {
    VStack {
        SyncStatusBar()
            .onAppear {
                SyncQueueManager.shared.isSyncing = true
                SyncQueueManager.shared.syncProgress = 0.45
            }

        Spacer()
    }
}

#Preview("Sync Status Bar - Offline") {
    VStack {
        SyncStatusBar()
            .onAppear {
                OfflineModeManager.shared.isOnline = false
            }

        Spacer()
    }
}

#Preview("Floating Indicator") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        VStack {
            Spacer()
            FloatingSyncIndicator()
                .onAppear {
                    SyncQueueManager.shared.isSyncing = true
                }
            Spacer()
        }
    }
}

#Preview("Event Badges") {
    VStack(spacing: 12) {
        EventSyncBadge(status: .synced)
        EventSyncBadge(status: .pending)
        EventSyncBadge(status: .syncing)
        EventSyncBadge(status: .failed)
    }
    .padding()
}
