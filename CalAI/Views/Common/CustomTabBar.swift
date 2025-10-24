import SwiftUI

// MARK: - Tab Item Model

struct TabItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let icon: String
    var order: Int
    let isFixed: Bool // Settings tab will be fixed

    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tab Bar Manager

class TabBarManager: ObservableObject {
    @Published var tabs: [TabItem] = []
    @AppStorage("customTabOrder") private var tabOrderData: Data = Data()

    init() {
        loadTabs()
    }

    private func loadTabs() {
        // Try to load saved order
        if let decoded = try? JSONDecoder().decode([TabItem].self, from: tabOrderData) {
            tabs = decoded
            print("📊 Loaded saved tab order: \(tabs.map { $0.title })")
        } else {
            // Default order
            tabs = [
                TabItem(id: "ai", title: "AI", icon: "brain.head.profile", order: 0, isFixed: false),
                TabItem(id: "calendar", title: "Calendar", icon: "calendar", order: 1, isFixed: false),
                TabItem(id: "events", title: "Events", icon: "list.bullet", order: 2, isFixed: false),
                TabItem(id: "tasks", title: "Tasks", icon: "tray.fill", order: 3, isFixed: false),
                TabItem(id: "settings", title: "Settings", icon: "gearshape", order: 4, isFixed: true)
            ]
            saveTabs()
        }
    }

    func saveTabs() {
        // Update order values
        for (index, _) in tabs.enumerated() {
            tabs[index].order = index
        }

        if let encoded = try? JSONEncoder().encode(tabs) {
            tabOrderData = encoded
            print("💾 Saved tab order: \(tabs.map { $0.title })")
        }
    }

    func moveTab(from source: Int, to destination: Int) {
        // Don't allow moving if either position is the settings tab
        if tabs[source].isFixed || tabs[destination].isFixed {
            print("⚠️ Cannot move fixed tab (Settings)")
            return
        }

        // Don't allow moving past settings
        if destination >= tabs.count - 1 {
            print("⚠️ Cannot move past Settings tab")
            return
        }

        withAnimation {
            let movedTab = tabs.remove(at: source)
            tabs.insert(movedTab, at: destination)
            saveTabs()
        }
    }
}

// MARK: - Custom Tab Bar View

struct CustomTabBar: View {
    @ObservedObject var tabBarManager: TabBarManager
    @Binding var selectedTab: String
    let activeTaskCount: Int

    @State private var draggedTab: TabItem?
    @State private var draggedOffset: CGSize = .zero

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabBarManager.tabs.enumerated()), id: \.element.id) { index, tab in
                CustomTabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab.id,
                    badge: tab.id == "tasks" ? activeTaskCount : nil,
                    isDragging: draggedTab?.id == tab.id,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab.id
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .offset(draggedTab?.id == tab.id ? draggedOffset : .zero)
                .zIndex(draggedTab?.id == tab.id ? 1 : 0)
                .opacity(draggedTab?.id == tab.id ? 0.8 : 1.0)
                .gesture(
                    tab.isFixed ? nil : // Settings tab cannot be dragged
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if draggedTab == nil {
                                draggedTab = tab
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                            draggedOffset = value.translation

                            // Calculate which position we're over
                            let itemWidth = UIScreen.main.bounds.width / CGFloat(tabBarManager.tabs.count)
                            let currentX = CGFloat(index) * itemWidth + value.translation.width
                            let newIndex = Int(round(currentX / itemWidth))

                            // Check if we've moved to a new position
                            if newIndex != index && newIndex >= 0 && newIndex < tabBarManager.tabs.count - 1 {
                                // Don't allow moving past settings (last position)
                                tabBarManager.moveTab(from: index, to: newIndex)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                draggedOffset = .zero
                                draggedTab = nil
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                )
            }
        }
        .frame(height: 49) // Standard tab bar height
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
        )
    }
}

// MARK: - Custom Tab Bar Item

struct CustomTabBarItem: View {
    let tab: TabItem
    let isSelected: Bool
    let badge: Int?
    let isDragging: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .blue : .gray)
                        .scaleEffect(isDragging ? 1.1 : 1.0)

                    // Badge
                    if let count = badge, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
                }

                Text(tab.title)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
