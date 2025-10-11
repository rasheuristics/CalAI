import SwiftUI

/// Settings view for crash reporting and diagnostics
struct CrashReportingSettingsView: View {
    @AppStorage("crashReportingEnabled") private var crashReportingEnabled = true
    @State private var showingTestCrashAlert = false
    @State private var showingTestErrorAlert = false
    @State private var crashLogs: String = ""
    @State private var isLoadingLogs = false

    var body: some View {
        Form {
            // Enable/Disable Section
            Section {
                Toggle("Enable Crash Reporting", isOn: $crashReportingEnabled.onChange { enabled in
                    CrashReporter.shared.setEnabled(enabled)
                    HapticManager.shared.light()
                })

                VStack(alignment: .leading, spacing: 8) {
                    Text("Help improve CalAI by automatically sending crash reports.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("We collect crash data, device info, and app version. No personal data or calendar events are included.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Label("Crash Reporting", systemImage: "exclamationmark.triangle")
            }

            // What We Collect
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(icon: "info.circle", text: "Crash stack traces")
                    InfoRow(icon: "iphone", text: "Device model and OS version")
                    InfoRow(icon: "app.badge", text: "App version and build number")
                    InfoRow(icon: "network", text: "Network connectivity status")
                }
            } header: {
                Text("What We Collect")
            } footer: {
                Text("All data is anonymized and used solely for improving app stability.")
                    .font(.caption)
            }

            // What We Don't Collect
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(icon: "xmark.circle", text: "Calendar event details", color: .red)
                    InfoRow(icon: "xmark.circle", text: "Personal information", color: .red)
                    InfoRow(icon: "xmark.circle", text: "Location data", color: .red)
                    InfoRow(icon: "xmark.circle", text: "Credentials or API keys", color: .red)
                }
            } header: {
                Text("What We Don't Collect")
            }

            // Debug Section (Development only)
            #if DEBUG
            Section {
                Button(action: {
                    showingTestCrashAlert = true
                }) {
                    Label("Test Fatal Crash", systemImage: "exclamationmark.octagon")
                        .foregroundColor(.red)
                }

                Button(action: {
                    showingTestErrorAlert = true
                }) {
                    Label("Test Non-Fatal Error", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }

                Button(action: loadCrashLogs) {
                    HStack {
                        Label("View Crash Logs", systemImage: "doc.text")
                        if isLoadingLogs {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
            } header: {
                Text("Debug Tools")
            } footer: {
                Text("These tools are only available in development builds.")
                    .font(.caption)
            }
            #endif
        }
        .navigationTitle("Crash Reporting")
        .navigationBarTitleDisplayMode(.large)
        .alert("Test Fatal Crash?", isPresented: $showingTestCrashAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Crash App", role: .destructive) {
                CrashReporter.shared.testCrash()
            }
        } message: {
            Text("This will intentionally crash the app to test crash reporting. The app will close immediately.")
        }
        .alert("Test Non-Fatal Error?", isPresented: $showingTestErrorAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Log Error", role: .destructive) {
                CrashReporter.shared.testNonFatalError()
            }
        } message: {
            Text("This will log a test error without crashing the app.")
        }
        .sheet(isPresented: .constant(!crashLogs.isEmpty)) {
            CrashLogsView(logs: crashLogs, onDismiss: {
                crashLogs = ""
            })
        }
    }

    private func loadCrashLogs() {
        isLoadingLogs = true

        DispatchQueue.global(qos: .userInitiated).async {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let crashLogPath = documentsPath.appendingPathComponent("crash_logs.txt")

            if let logs = try? String(contentsOf: crashLogPath, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.crashLogs = logs
                    self.isLoadingLogs = false
                }
            } else {
                DispatchQueue.main.async {
                    self.crashLogs = "No crash logs found."
                    self.isLoadingLogs = false
                }
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let text: String
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(color)
        }
    }
}

// MARK: - Crash Logs View

struct CrashLogsView: View {
    let logs: String
    let onDismiss: () -> Void

    @State private var showingShareSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                Text(logs)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Crash Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [logs])
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Binding Extension

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        CrashReportingSettingsView()
    }
}
