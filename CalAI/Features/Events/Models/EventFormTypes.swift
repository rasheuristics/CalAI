import SwiftUI
import EventKit
import UniformTypeIdentifiers

// MARK: - Repeat Options

enum RepeatOption: String, CaseIterable, Identifiable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Every Day"
        case .weekly: return "Every Week"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Every Month"
        case .yearly: return "Every Year"
        }
    }

    var ekRecurrenceFrequency: EKRecurrenceFrequency? {
        switch self {
        case .none: return nil
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        case .biweekly: return .weekly
        }
    }

    var interval: Int {
        switch self {
        case .biweekly: return 2
        default: return 1
        }
    }
}

// MARK: - Attachment Item

struct AttachmentItem: Identifiable {
    let id = UUID()
    let name: String
    let url: URL?
    let data: Data?
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentsPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onDocumentsPicked(urls)
        }
    }
}
