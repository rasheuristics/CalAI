import SwiftUI

/// A text view that automatically detects and makes URLs clickable
struct ClickableTextView: View {
    let text: String
    let fontSize: CGFloat
    let fontManager: FontManager

    init(_ text: String, fontSize: CGFloat = 17, fontManager: FontManager) {
        self.text = text
        self.fontSize = fontSize
        self.fontManager = fontManager
    }

    var body: some View {
        let url = extractURL(from: text)
        let _ = print("🔗 [ClickableTextView] Text: \(text.prefix(100))")
        let _ = print("🔗 [ClickableTextView] Extracted URL: \(url?.absoluteString ?? "none")")

        return Group {
            if let url = url {
                // If text contains a URL, make it clickable
                VStack(alignment: .leading, spacing: 8) {
                    // Show the text
                    Text(text)
                        .dynamicFont(size: fontSize, fontManager: fontManager)

                    // Show clickable link button
                    Button(action: {
                        UIApplication.shared.open(url)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: getLinkIcon(for: url))
                                .font(.system(size: 16, weight: .semibold))

                            Text(getLinkLabel(for: url))
                                .font(.system(size: 15, weight: .semibold))

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(getLinkColor(for: url))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // No URL, just show text
                Text(text)
                    .dynamicFont(size: fontSize, fontManager: fontManager)
            }
        }
    }

    // MARK: - URL Extraction

    private func extractURL(from text: String) -> URL? {
        // Define patterns for common URLs
        let patterns = [
            // Zoom
            "https?://[\\w.-]*zoom\\.us/j/[0-9?=&\\w-]+",
            "https?://[\\w.-]*zoom\\.us/wc/join/[0-9?=&\\w-]+",
            // Google Meet
            "https?://meet\\.google\\.com/[a-z0-9-]+",
            // Microsoft Teams
            "https?://teams\\.microsoft\\.com/l/meetup-join/[\\w/%?=&\\-._~:@!$'()*+,;]+",
            // Webex
            "https?://[\\w.-]+\\.webex\\.com/[\\w./\\-?=&]+",
            // Generic HTTP/HTTPS URLs
            "https?://[\\w\\-._~:/?#\\[\\]@!$&'()*+,;=]+"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range),
                   let urlRange = Range(match.range, in: text) {
                    let urlString = String(text[urlRange])
                    if let url = URL(string: urlString) {
                        return url
                    }
                }
            }
        }

        return nil
    }

    // MARK: - UI Helpers

    private func getLinkIcon(for url: URL) -> String {
        let urlString = url.absoluteString.lowercased()

        if urlString.contains("zoom.us") {
            return "video.fill"
        } else if urlString.contains("meet.google.com") {
            return "video.fill"
        } else if urlString.contains("teams.microsoft.com") {
            return "video.fill"
        } else if urlString.contains("webex.com") {
            return "video.fill"
        } else {
            return "link"
        }
    }

    private func getLinkLabel(for url: URL) -> String {
        let urlString = url.absoluteString.lowercased()

        if urlString.contains("zoom.us") {
            return "Join Zoom Meeting"
        } else if urlString.contains("meet.google.com") {
            return "Join Google Meet"
        } else if urlString.contains("teams.microsoft.com") {
            return "Join Teams Meeting"
        } else if urlString.contains("webex.com") {
            return "Join Webex Meeting"
        } else {
            return "Open Link"
        }
    }

    private func getLinkColor(for url: URL) -> Color {
        let urlString = url.absoluteString.lowercased()

        if urlString.contains("zoom.us") {
            return Color.blue
        } else if urlString.contains("meet.google.com") {
            return Color.green
        } else if urlString.contains("teams.microsoft.com") {
            return Color.purple
        } else if urlString.contains("webex.com") {
            return Color.blue
        } else {
            return Color.blue
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ClickableTextView(
            "Join the meeting at https://zoom.us/j/123456789",
            fontManager: FontManager()
        )

        ClickableTextView(
            "Meeting link: https://meet.google.com/abc-defg-hij",
            fontManager: FontManager()
        )

        ClickableTextView(
            "This is just regular text without any URLs",
            fontManager: FontManager()
        )
    }
    .padding()
}
