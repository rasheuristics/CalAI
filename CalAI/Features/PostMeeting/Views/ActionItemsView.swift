import SwiftUI

struct ActionItemsView: View {
    @ObservedObject var postMeetingService: PostMeetingService
    @ObservedObject var fontManager: FontManager
    @ObservedObject var calendarManager: CalendarManager

    @State private var filterOption: FilterOption = .all
    @State private var sortOption: SortOption = .priority
    @State private var searchText = ""
    @State private var selectedMeeting: MeetingFollowUp?
    @State private var showingMeetingSummary = false

    enum FilterOption: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case completed = "Completed"
        case urgent = "Urgent"
        case today = "Due Today"
    }

    enum SortOption: String, CaseIterable {
        case priority = "Priority"
        case date = "Date"
        case meeting = "Meeting"
        case assignee = "Assignee"
    }

    var filteredAndSortedItems: [ActionItem] {
        var items = postMeetingService.pendingActionItems

        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.description?.localizedCaseInsensitiveContains(searchText) == true ||
                item.assignee?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Apply filter option
        switch filterOption {
        case .all:
            break // No filtering
        case .pending:
            items = items.filter { !$0.isCompleted }
        case .completed:
            items = items.filter { $0.isCompleted }
        case .urgent:
            items = items.filter { $0.priority == .urgent || $0.priority == .high }
        case .today:
            if let today = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date()),
               let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) {
                items = items.filter { item in
                    if let dueDate = item.dueDate {
                        return dueDate >= today && dueDate < tomorrow
                    }
                    return false
                }
            }
        }

        // Apply sort
        switch sortOption {
        case .priority:
            items.sort { $0.priority.sortOrder < $1.priority.sortOrder }
        case .date:
            items.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .meeting:
            items.sort { itemA, itemB in
                let meetingA = findMeetingForActionItem(itemA)
                let meetingB = findMeetingForActionItem(itemB)
                return (meetingA?.meetingDate ?? .distantPast) > (meetingB?.meetingDate ?? .distantPast)
            }
        case .assignee:
            items.sort { ($0.assignee ?? "zzz") < ($1.assignee ?? "zzz") }
        }

        return items
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
                statsHeaderView

                // Search and Filters
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search action items...", text: $searchText)
                            .dynamicFont(size: 16, fontManager: fontManager)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FilterOption.allCases, id: \.self) { option in
                                FilterChip(
                                    title: option.rawValue,
                                    isSelected: filterOption == option,
                                    fontManager: fontManager
                                ) {
                                    filterOption = option
                                    HapticManager.shared.light()
                                }
                            }
                        }
                    }

                    // Sort picker
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding()

                // Action Items List
                if filteredAndSortedItems.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredAndSortedItems) { item in
                            ActionItemCard(
                                item: item,
                                meeting: findMeetingForActionItem(item),
                                fontManager: fontManager,
                                onToggle: {
                                    postMeetingService.completeActionItem(item.id)
                                    HapticManager.shared.light()
                                },
                                onDelete: {
                                    postMeetingService.deleteActionItem(item.id)
                                    HapticManager.shared.medium()
                                },
                                onMeetingTap: {
                                    if let meeting = findMeetingForActionItem(item) {
                                        selectedMeeting = meeting
                                        showingMeetingSummary = true
                                    }
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Action Items")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingMeetingSummary) {
                if let meeting = selectedMeeting {
                    PostMeetingSummaryView(
                        followUp: meeting,
                        postMeetingService: postMeetingService,
                        fontManager: fontManager,
                        calendarManager: calendarManager
                    )
                }
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeaderView: some View {
        let totalItems = postMeetingService.pendingActionItems.count
        let completedItems = postMeetingService.pendingActionItems.filter { $0.isCompleted }.count
        let pendingItems = totalItems - completedItems
        let urgentItems = postMeetingService.pendingActionItems.filter { $0.priority == .urgent && !$0.isCompleted }.count

        return HStack(spacing: 20) {
            StatCard(
                title: "Pending",
                value: "\(pendingItems)",
                icon: "circle",
                color: .blue,
                fontManager: fontManager
            )

            StatCard(
                title: "Completed",
                value: "\(completedItems)",
                icon: "checkmark.circle.fill",
                color: .green,
                fontManager: fontManager
            )

            StatCard(
                title: "Urgent",
                value: "\(urgentItems)",
                icon: "exclamationmark.circle.fill",
                color: .red,
                fontManager: fontManager
            )
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Action Items")
                .dynamicFont(size: 22, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            Text(getEmptyStateMessage())
                .dynamicFont(size: 16, fontManager: fontManager)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func getEmptyStateMessage() -> String {
        switch filterOption {
        case .all:
            return "You're all caught up! No pending action items from your recent meetings."
        case .pending:
            return "No pending action items. Great job staying on top of things!"
        case .completed:
            return "No completed action items yet. Start checking off tasks above."
        case .urgent:
            return "No urgent action items at the moment."
        case .today:
            return "No action items due today."
        }
    }

    // MARK: - Helpers

    private func findMeetingForActionItem(_ item: ActionItem) -> MeetingFollowUp? {
        return postMeetingService.recentlyCompletedMeetings.first { meeting in
            meeting.actionItems.contains { $0.id == item.id }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @ObservedObject var fontManager: FontManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .dynamicFont(size: 28, weight: .bold, fontManager: fontManager)
                .foregroundColor(.primary)

            Text(title)
                .dynamicFont(size: 12, fontManager: fontManager)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    @ObservedObject var fontManager: FontManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .dynamicFont(size: 14, weight: isSelected ? .semibold : .regular, fontManager: fontManager)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActionItemCard: View {
    let item: ActionItem
    let meeting: MeetingFollowUp?
    @ObservedObject var fontManager: FontManager
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onMeetingTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                Button(action: onToggle) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.isCompleted ? .green : .gray)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(item.title)
                        .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                        .overlay(
                            item.isCompleted ?
                            Rectangle()
                                .fill(Color.secondary)
                                .frame(height: 1)
                                .offset(y: 0)
                            : nil
                        )

                    // Metadata row
                    HStack(spacing: 12) {
                        // Priority badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(item.priority.color))
                                .frame(width: 6, height: 6)
                            Text(item.priority.rawValue)
                                .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                        }
                        .foregroundColor(.secondary)

                        // Category
                        Label(item.category.rawValue, systemImage: item.category.icon)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        // Assignee
                        if let assignee = item.assignee {
                            Label(assignee, systemImage: "person")
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Meeting source
                    if let meeting = meeting {
                        Button(action: onMeetingTap) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(meeting.eventTitle)
                                    .dynamicFont(size: 12, fontManager: fontManager)
                                Text("•")
                                    .dynamicFont(size: 10, fontManager: fontManager)
                                Text(formatDate(meeting.meetingDate))
                                    .dynamicFont(size: 12, fontManager: fontManager)
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Description
                    if let description = item.description {
                        Text(description)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(item.priority.color).opacity(0.2), lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
