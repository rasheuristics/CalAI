import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var aiManager = AIManager()
    @StateObject private var fontManager = FontManager()
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            // Background color
            Color(.systemBackground)

            // Tab content
            Group {
                switch selectedTab {
                case 0:
                    CalendarTabView(calendarManager: calendarManager, fontManager: fontManager)
                case 1:
                    EventsTabView(calendarManager: calendarManager, fontManager: fontManager)
                case 2:
                    AITabView(voiceManager: voiceManager, aiManager: aiManager, calendarManager: calendarManager, fontManager: fontManager)
                case 3:
                    SettingsTabView(calendarManager: calendarManager, voiceManager: voiceManager, fontManager: fontManager)
                default:
                    CalendarTabView(calendarManager: calendarManager, fontManager: fontManager)
                }
            }

            // Custom tab bar card in safe area
            VStack {
                Spacer()
                CustomTabBarCard(selectedTab: $selectedTab)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            calendarManager.requestCalendarAccess()
        }
    }

}

struct CustomTabBarCard: View {
    @Binding var selectedTab: Int
    @State private var tabBarOffset: CGFloat = 0
    @State private var isTabBarHidden: Bool = false

    private let tabItems = [
        "calendar",
        "list.bullet",
        "brain.head.profile",
        "gearshape"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Pull indicator
            if !isTabBarHidden {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .cornerRadius(2)
            }

            // Tab bar card
            HStack(spacing: 0) {
                ForEach(0..<tabItems.count, id: \.self) { index in
                    TabBarButton(
                        icon: tabItems[index],
                        isSelected: selectedTab == index,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = index
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -1)
            )
        }
        .offset(y: tabBarOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let translation = value.translation.height
                    if translation > 0 && !isTabBarHidden {
                        tabBarOffset = min(translation, 120)
                    } else if translation < 0 && isTabBarHidden {
                        tabBarOffset = max(120 + translation, 0)
                    }
                }
                .onEnded { value in
                    let translation = value.translation.height
                    let velocity = value.predictedEndLocation.y - value.location.y

                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        if translation > 60 || velocity > 100 {
                            tabBarOffset = 120
                            isTabBarHidden = true
                        } else {
                            tabBarOffset = 0
                            isTabBarHidden = false
                        }
                    }
                }
        )
        .overlay(
            // Show button when hidden
            VStack {
                Spacer()
                if isTabBarHidden {
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            tabBarOffset = 0
                            isTabBarHidden = false
                        }
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.bottom, 40)
                }
            }
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(isSelected ? .blue : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct VoiceInputButton: View {
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var aiManager: AIManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    var onTranscript: ((String) -> Void)? = nil
    var onResponse: ((AIResponse) -> Void)? = nil

    var body: some View {
        VStack {
            Button(action: {
                if voiceManager.isListening {
                    voiceManager.stopListening()
                } else {
                    voiceManager.startListening { transcript in
                        onTranscript?(transcript)
                        aiManager.processVoiceCommand(transcript) { result in
                            calendarManager.handleAIResponse(result)
                            onResponse?(result)
                        }
                    }
                }
            }) {
                Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 30))
                    .foregroundColor(voiceManager.isListening ? .red : .blue)
                    .padding()
                    .background(Circle().fill(Color.gray.opacity(0.2)))
            }

            Text(voiceManager.isListening ? "Listening..." : "Tap to speak")
                .dynamicFont(size: 12, fontManager: fontManager)
                .foregroundColor(.secondary)
        }
        .padding(.bottom)
    }
}

#Preview {
    ContentView()
}