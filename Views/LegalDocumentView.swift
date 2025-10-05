import SwiftUI

struct LegalDocumentView: View {
    let documentType: DocumentType
    @Environment(\.dismiss) private var dismiss
    @State private var documentText: String = "Loading..."

    enum DocumentType {
        case privacyPolicy
        case termsOfService

        var title: String {
            switch self {
            case .privacyPolicy: return "Privacy Policy"
            case .termsOfService: return "Terms of Service"
            }
        }

        var fileName: String {
            switch self {
            case .privacyPolicy: return "PRIVACY_POLICY"
            case .termsOfService: return "TERMS_OF_SERVICE"
            }
        }

        var icon: String {
            switch self {
            case .privacyPolicy: return "hand.raised.fill"
            case .termsOfService: return "doc.text.fill"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: documentType.icon)
                            .font(.title)
                            .foregroundColor(.blue)

                        Text(documentType.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }

                    Text("Last updated: January 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                Divider()

                // Document content
                Text(documentText)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle(documentType.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: documentText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            loadDocument()
        }
    }

    private func loadDocument() {
        guard let url = Bundle.main.url(forResource: documentType.fileName, withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            documentText = "Error: Unable to load \(documentType.title). Please contact support."
            return
        }

        // Convert markdown to plain text with formatting
        documentText = formatMarkdown(content)
    }

    private func formatMarkdown(_ markdown: String) -> String {
        // Basic markdown formatting for display
        var formatted = markdown

        // Remove markdown links but keep text
        formatted = formatted.replacingOccurrences(of: #"\[(.*?)\]\(.*?\)"#, with: "$1", options: .regularExpression)

        // Convert headers to bold
        formatted = formatted.replacingOccurrences(of: #"^### (.*?)$"#, with: "$1", options: [.regularExpression, .anchorsMatchLines])
        formatted = formatted.replacingOccurrences(of: #"^## (.*?)$"#, with: "$1", options: [.regularExpression, .anchorsMatchLines])
        formatted = formatted.replacingOccurrences(of: #"^# (.*?)$"#, with: "$1", options: [.regularExpression, .anchorsMatchLines])

        // Remove bold markers
        formatted = formatted.replacingOccurrences(of: "**", with: "")

        // Clean up extra newlines
        formatted = formatted.replacingOccurrences(of: "\n\n\n", with: "\n\n")

        return formatted
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(documentType: .privacyPolicy)
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        LegalDocumentView(documentType: .termsOfService)
    }
}

// MARK: - Preview
#Preview("Privacy Policy") {
    NavigationView {
        PrivacyPolicyView()
    }
}

#Preview("Terms of Service") {
    NavigationView {
        TermsOfServiceView()
    }
}
