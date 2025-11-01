import SwiftUI

struct TaskTemplatesView: View {
    @ObservedObject var fontManager: FontManager
    @ObservedObject var appearanceManager: AppearanceManager
    @StateObject private var automationService = TaskAutomationService.shared

    @State private var showingAddTemplate = false
    @State private var showingPatternDetection = false
    @State private var detectedPatterns: [AutomationTemplate] = []

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: appearanceManager.backgroundGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if automationService.templates.isEmpty {
                        emptyStateView
                    } else {
                        templateListView
                    }
                }
            }
            .navigationTitle("Task Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingAddTemplate = true
                        }) {
                            Label("Create Template", systemImage: "plus.circle")
                        }

                        Button(action: {
                            detectPatterns()
                        }) {
                            Label("Detect Patterns", systemImage: "sparkles")
                        }

                        Button(action: {
                            automationService.createDefaultTemplates()
                        }) {
                            Label("Add Default Templates", systemImage: "star")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddTemplate) {
                TemplateEditorSheet(
                    fontManager: fontManager,
                    onSave: { template in
                        automationService.addTemplate(template)
                    }
                )
            }
            .sheet(isPresented: $showingPatternDetection) {
                PatternDetectionSheet(
                    detectedPatterns: detectedPatterns,
                    fontManager: fontManager,
                    onAdd: { template in
                        automationService.addTemplate(template)
                    }
                )
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.5))

            Text("No Task Templates")
                .dynamicFont(size: 22, weight: .bold, fontManager: fontManager)

            Text("Create templates to automatically generate tasks for recurring events")
                .dynamicFont(size: 14, fontManager: fontManager)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                automationService.createDefaultTemplates()
            }) {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Add Default Templates")
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
    }

    private var templateListView: some View {
        List {
            ForEach(automationService.templates) { template in
                TemplateRow(template: template, fontManager: fontManager)
                    .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteTemplates)
        }
        .listStyle(PlainListStyle())
        .background(Color.clear)
    }

    private func detectPatterns() {
        let taskManager = EventTaskManager.shared
        let history = taskManager.getTaskHistory()

        detectedPatterns = automationService.detectTaskPatterns(from: history)

        if !detectedPatterns.isEmpty {
            showingPatternDetection = true
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            let template = automationService.templates[index]
            automationService.deleteTemplate(template.id)
        }
    }
}

// MARK: - Template Row

struct TemplateRow: View {
    let template: AutomationTemplate
    let fontManager: FontManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)

                Text(template.title)
                    .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)

                Spacer()

                if template.autoSchedule {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 12) {
                // Priority
                HStack(spacing: 4) {
                    Image(systemName: template.priority.icon)
                        .font(.system(size: 10))
                    Text(template.priority.rawValue)
                        .font(.system(size: 12))
                }
                .foregroundColor(Color(template.priority.color))

                // Category
                HStack(spacing: 4) {
                    Image(systemName: template.category.icon)
                        .font(.system(size: 10))
                    Text(template.category.rawValue)
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)

                // Event Pattern
                if let pattern = template.eventPattern {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 10))
                        Text("\"\(pattern)\"")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.blue)
                }

                Spacer()
            }

            // Recurrence
            if let recurrence = template.recurrence {
                HStack(spacing: 4) {
                    Image(systemName: recurrence.frequency.icon)
                        .font(.system(size: 10))
                    Text(recurrence.frequency.rawValue)
                        .font(.system(size: 12))
                }
                .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Template Editor Sheet

struct TemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var fontManager: FontManager

    let onSave: (AutomationTemplate) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .preparation
    @State private var timing: TaskTiming = .before(hours: 24)
    @State private var estimatedMinutes: Int = 30
    @State private var eventPattern = ""
    @State private var autoSchedule = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Template Name", text: $title)
                        .dynamicFont(size: 16, fontManager: fontManager)

                    TextField("Event Pattern (e.g., \"meeting\")", text: $eventPattern)
                        .dynamicFont(size: 16, fontManager: fontManager)
                        .autocapitalization(.none)
                }

                Section(header: Text("Task Details")) {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }

                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }

                    Stepper("Estimated: \(estimatedMinutes) min", value: $estimatedMinutes, in: 5...240, step: 5)
                        .dynamicFont(size: 16, fontManager: fontManager)
                }

                Section(header: Text("Automation")) {
                    Toggle("Auto-schedule", isOn: $autoSchedule)
                        .dynamicFont(size: 16, fontManager: fontManager)
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveTemplate() {
        let template = AutomationTemplate(
            title: title,
            description: description.isEmpty ? nil : description,
            priority: priority,
            category: category,
            timing: timing,
            estimatedMinutes: estimatedMinutes,
            eventPattern: eventPattern.isEmpty ? nil : eventPattern,
            autoSchedule: autoSchedule
        )

        onSave(template)
        dismiss()
    }
}

// MARK: - Pattern Detection Sheet

struct PatternDetectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let detectedPatterns: [AutomationTemplate]
    let fontManager: FontManager
    let onAdd: (AutomationTemplate) -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Detected \(detectedPatterns.count) Pattern(s)")) {
                    ForEach(detectedPatterns) { pattern in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pattern.title)
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)

                            HStack {
                                Text(pattern.priority.rawValue)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(pattern.priority.color))

                                Text("•")
                                    .foregroundColor(.secondary)

                                Text(pattern.category.rawValue)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Button(action: {
                                onAdd(pattern)
                            }) {
                                Text("Add as Template")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Pattern Detection")
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
}
