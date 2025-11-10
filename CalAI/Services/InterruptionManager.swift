//
//  InterruptionManager.swift
//  CalAI
//
//  Intelligent interruption detection and conversation resumption
//  Created by Claude Code on 11/9/25.
//

import Foundation
import Combine
import UIKit

// MARK: - Interruption Types

enum InterruptionType: String, Codable {
    case phoneCall = "phone_call"
    case notification = "notification"
    case appBackground = "app_background"
    case userPause = "user_pause"
    case timeout = "timeout"
    case systemInterruption = "system_interruption"
}

enum ConversationPhase: String, Codable {
    case listening = "listening"
    case processing = "processing"
    case responding = "responding"
    case awaitingConfirmation = "awaiting_confirmation"
    case awaitingClarification = "awaiting_clarification"
    case completed = "completed"
}

// MARK: - Conversation Snapshot

struct ConversationSnapshot: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let phase: ConversationPhase
    let lastUserInput: String
    let lastAIResponse: String?
    let pendingCommand: PendingCommandSnapshot?
    let contextMessages: [String]
    let needsClarification: Bool
    let clarificationQuestion: String?
    let interruptionType: InterruptionType
    let sessionId: String

    // Time tracking
    let timeElapsedSinceStart: TimeInterval
    let expectedResumeWindow: TimeInterval // How long until context becomes stale

    init(
        id: String = UUID().uuidString,
        phase: ConversationPhase,
        lastUserInput: String,
        lastAIResponse: String? = nil,
        pendingCommand: PendingCommandSnapshot? = nil,
        contextMessages: [String] = [],
        needsClarification: Bool = false,
        clarificationQuestion: String? = nil,
        interruptionType: InterruptionType,
        sessionId: String,
        timeElapsedSinceStart: TimeInterval = 0
    ) {
        self.id = id
        self.timestamp = Date()
        self.phase = phase
        self.lastUserInput = lastUserInput
        self.lastAIResponse = lastAIResponse
        self.pendingCommand = pendingCommand
        self.contextMessages = contextMessages
        self.needsClarification = needsClarification
        self.clarificationQuestion = clarificationQuestion
        self.interruptionType = interruptionType
        self.sessionId = sessionId
        self.timeElapsedSinceStart = timeElapsedSinceStart

        // Context freshness based on conversation phase
        switch phase {
        case .awaitingClarification, .awaitingConfirmation:
            self.expectedResumeWindow = 600 // 10 minutes - user likely to return
        case .processing, .responding:
            self.expectedResumeWindow = 300 // 5 minutes - mid-conversation
        case .listening:
            self.expectedResumeWindow = 120 // 2 minutes - just started
        case .completed:
            self.expectedResumeWindow = 60 // 1 minute - already done
        }
    }

    var isStale: Bool {
        let age = Date().timeIntervalSince(timestamp)
        return age > expectedResumeWindow
    }

    var ageInMinutes: Int {
        let age = Date().timeIntervalSince(timestamp)
        return Int(age / 60)
    }
}

struct PendingCommandSnapshot: Codable {
    let commandType: String
    let title: String?
    let startDate: Date?
    let endDate: Date?
    let location: String?
    let notes: String?
    let missingFields: [String]
}

// MARK: - Interruption Manager

class InterruptionManager: ObservableObject {
    static let shared = InterruptionManager()

    @Published var currentSnapshot: ConversationSnapshot?
    @Published var hasInterruptedConversation: Bool = false
    @Published var resumptionSuggested: Bool = false

    private var snapshotHistory: [ConversationSnapshot] = []
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let snapshotsKey = "conversation_snapshots"
    private let maxSnapshotHistory = 10

    // Interruption detection
    private var lastUserInteractionTime: Date?
    private var conversationStartTime: Date?
    private var inactivityTimer: Timer?
    private let inactivityThreshold: TimeInterval = 30 // 30 seconds of no input = potential pause

    init() {
        loadSnapshots()
        setupInterruptionObservers()
        checkForResumableConversation()
    }

    // MARK: - Interruption Detection

    private func setupInterruptionObservers() {
        // Detect app backgrounding
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppBackground()
            }
            .store(in: &cancellables)

        // Detect app foregrounding
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppForeground()
            }
            .store(in: &cancellables)

        // Detect system interruptions (calls, etc.)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleSystemInterruption(notification)
            }
            .store(in: &cancellables)
    }

    private func handleAppBackground() {
        print("📱 App entering background - checking for active conversation...")
        if let snapshot = currentSnapshot, !snapshot.phase.isTerminal {
            saveSnapshot(snapshot, interruptionType: .appBackground)
        }
    }

    private func handleAppForeground() {
        print("📱 App entering foreground - checking for resumable conversation...")
        checkForResumableConversation()
    }

    private func handleSystemInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if type == .began {
            print("📞 System interruption began (e.g., phone call)")
            if let snapshot = currentSnapshot, !snapshot.phase.isTerminal {
                saveSnapshot(snapshot, interruptionType: .systemInterruption)
            }
        } else if type == .ended {
            print("📞 System interruption ended")
            checkForResumableConversation()
        }
    }

    // MARK: - Conversation Tracking

    func startConversation(sessionId: String) {
        conversationStartTime = Date()
        lastUserInteractionTime = Date()
        resumptionSuggested = false
        print("🎤 Conversation started - session: \(sessionId)")
    }

    func recordUserInteraction() {
        lastUserInteractionTime = Date()
        resetInactivityTimer()
    }

    func updateConversationState(
        phase: ConversationPhase,
        lastUserInput: String,
        lastAIResponse: String? = nil,
        pendingCommand: PendingCommandSnapshot? = nil,
        contextMessages: [String] = [],
        needsClarification: Bool = false,
        clarificationQuestion: String? = nil,
        sessionId: String
    ) {
        let timeElapsed = conversationStartTime.map { Date().timeIntervalSince($0) } ?? 0

        currentSnapshot = ConversationSnapshot(
            phase: phase,
            lastUserInput: lastUserInput,
            lastAIResponse: lastAIResponse,
            pendingCommand: pendingCommand,
            contextMessages: contextMessages,
            needsClarification: needsClarification,
            clarificationQuestion: clarificationQuestion,
            interruptionType: .userPause, // Default, will be updated on actual interruption
            sessionId: sessionId,
            timeElapsedSinceStart: timeElapsed
        )

        hasInterruptedConversation = !phase.isTerminal
        recordUserInteraction()
    }

    func endConversation() {
        currentSnapshot = nil
        hasInterruptedConversation = false
        conversationStartTime = nil
        lastUserInteractionTime = nil
        inactivityTimer?.invalidate()
        print("✅ Conversation completed")
    }

    // MARK: - Snapshot Management

    func saveSnapshot(_ snapshot: ConversationSnapshot, interruptionType: InterruptionType) {
        var updatedSnapshot = snapshot
        // Can't directly modify, need to recreate with new interruption type
        let newSnapshot = ConversationSnapshot(
            id: snapshot.id,
            phase: snapshot.phase,
            lastUserInput: snapshot.lastUserInput,
            lastAIResponse: snapshot.lastAIResponse,
            pendingCommand: snapshot.pendingCommand,
            contextMessages: snapshot.contextMessages,
            needsClarification: snapshot.needsClarification,
            clarificationQuestion: snapshot.clarificationQuestion,
            interruptionType: interruptionType,
            sessionId: snapshot.sessionId,
            timeElapsedSinceStart: snapshot.timeElapsedSinceStart
        )

        currentSnapshot = newSnapshot
        snapshotHistory.insert(newSnapshot, at: 0)

        // Prune old snapshots
        if snapshotHistory.count > maxSnapshotHistory {
            snapshotHistory = Array(snapshotHistory.prefix(maxSnapshotHistory))
        }

        hasInterruptedConversation = true
        persistSnapshots()

        print("💾 Saved conversation snapshot - phase: \(snapshot.phase.rawValue), interruption: \(interruptionType.rawValue)")
    }

    // MARK: - Resumption

    func checkForResumableConversation() {
        guard let latest = snapshotHistory.first else {
            hasInterruptedConversation = false
            resumptionSuggested = false
            return
        }

        if latest.isStale {
            print("⏰ Latest conversation snapshot is stale (\(latest.ageInMinutes) min old)")
            hasInterruptedConversation = false
            resumptionSuggested = false
            return
        }

        if latest.phase.isTerminal {
            print("✅ Latest conversation was already completed")
            hasInterruptedConversation = false
            resumptionSuggested = false
            return
        }

        print("🔄 Found resumable conversation from \(latest.ageInMinutes) min ago")
        hasInterruptedConversation = true
        resumptionSuggested = true
        currentSnapshot = latest
    }

    func generateResumptionPrompt() -> String? {
        guard let snapshot = currentSnapshot else { return nil }

        let timeAgo = formatTimeAgo(snapshot.timestamp)

        switch snapshot.phase {
        case .awaitingClarification:
            if let question = snapshot.clarificationQuestion {
                return "You were answering: '\(question)' (\(timeAgo)). Would you like to continue?"
            }
            return "We need some more information about '\(snapshot.lastUserInput)' (\(timeAgo)). Ready to continue?"

        case .awaitingConfirmation:
            if let command = snapshot.pendingCommand {
                return "You were about to \(command.commandType) '\(command.title ?? "an event")' (\(timeAgo)). Should I proceed?"
            }
            return "You had a pending action (\(timeAgo)). Would you like to complete it?"

        case .processing, .responding:
            return "We were working on '\(snapshot.lastUserInput)' (\(timeAgo)). Let me finish that for you."

        case .listening:
            return "You started saying something (\(timeAgo)). What would you like to do?"

        case .completed:
            return nil // Shouldn't reach here due to isTerminal check
        }
    }

    func generateContextualResumption() -> String {
        guard let snapshot = currentSnapshot else { return "" }

        var context = "Resuming from earlier:\n"

        // Add conversation context
        if !snapshot.contextMessages.isEmpty {
            context += "Previous context:\n"
            for msg in snapshot.contextMessages.suffix(3) {
                context += "- \(msg)\n"
            }
        }

        // Add last interaction
        context += "\nYou said: \"\(snapshot.lastUserInput)\"\n"

        if let response = snapshot.lastAIResponse {
            context += "I responded: \"\(response)\"\n"
        }

        // Add pending action
        if let command = snapshot.pendingCommand {
            context += "\nPending: \(command.commandType)"
            if !command.missingFields.isEmpty {
                context += " (missing: \(command.missingFields.joined(separator: ", ")))"
            }
            context += "\n"
        }

        return context
    }

    func resumeConversation() -> ConversationSnapshot? {
        guard let snapshot = currentSnapshot else { return nil }

        print("▶️ Resuming conversation - phase: \(snapshot.phase.rawValue)")
        resumptionSuggested = false

        return snapshot
    }

    func dismissResumption() {
        print("❌ User dismissed resumption")
        currentSnapshot = nil
        hasInterruptedConversation = false
        resumptionSuggested = false

        // Move to history but mark as dismissed
        if let snapshot = snapshotHistory.first {
            // Remove from active consideration
            snapshotHistory.removeFirst()
        }
    }

    // MARK: - Inactivity Detection

    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()

        inactivityTimer = Timer.scheduledTimer(withTimeInterval: inactivityThreshold, repeats: false) { [weak self] _ in
            self?.handleInactivity()
        }
    }

    private func handleInactivity() {
        guard let lastInteraction = lastUserInteractionTime else { return }

        let inactiveDuration = Date().timeIntervalSince(lastInteraction)

        if inactiveDuration >= inactivityThreshold {
            print("⏸️ User inactive for \(Int(inactiveDuration))s - potential pause")

            if let snapshot = currentSnapshot, !snapshot.phase.isTerminal {
                saveSnapshot(snapshot, interruptionType: .userPause)
            }
        }
    }

    // MARK: - Persistence

    private func loadSnapshots() {
        if let data = userDefaults.data(forKey: snapshotsKey),
           let decoded = try? JSONDecoder().decode([ConversationSnapshot].self, from: data) {
            snapshotHistory = decoded
            print("📚 Loaded \(snapshotHistory.count) conversation snapshots")
        }
    }

    private func persistSnapshots() {
        if let encoded = try? JSONEncoder().encode(snapshotHistory) {
            userDefaults.set(encoded, forKey: snapshotsKey)
        }
    }

    // MARK: - Utilities

    private func formatTimeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        let minutes = Int(seconds / 60)
        let hours = Int(seconds / 3600)

        if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            return "just now"
        }
    }

    func getSnapshotSummary() -> [String: Any] {
        return [
            "has_interrupted_conversation": hasInterruptedConversation,
            "resumption_suggested": resumptionSuggested,
            "current_phase": currentSnapshot?.phase.rawValue ?? "none",
            "snapshot_age_minutes": currentSnapshot?.ageInMinutes ?? 0,
            "total_snapshots": snapshotHistory.count
        ]
    }
}

// MARK: - Extensions

extension ConversationPhase {
    var isTerminal: Bool {
        return self == .completed
    }

    var requiresUserInput: Bool {
        return self == .awaitingClarification || self == .awaitingConfirmation
    }
}

// MARK: - AVAudioSession Import

import AVFoundation
