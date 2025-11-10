//
//  ResumptionPromptView.swift
//  CalAI
//
//  UI component for conversation resumption prompts
//  Created by Claude Code on 11/9/25.
//

import SwiftUI

struct ResumptionPromptView: View {
    let prompt: String
    let onResume: () -> Void
    let onDismiss: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Compact prompt
            HStack(spacing: 12) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue where you left off?")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if !isExpanded {
                        Text(prompt)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if !isExpanded {
                    Button(action: { withAnimation { isExpanded = true } }) {
                        Image(systemName: "chevron.down.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(prompt)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation {
                                isExpanded = false
                                onDismiss()
                            }
                        }) {
                            HStack {
                                Image(systemName: "xmark")
                                Text("Dismiss")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }

                        Button(action: {
                            withAnimation {
                                isExpanded = false
                                onResume()
                            }
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Resume")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding()
    }
}

#Preview {
    VStack {
        ResumptionPromptView(
            prompt: "You were answering: 'What time should the meeting be?' (2 minutes ago). Would you like to continue?",
            onResume: { print("Resume") },
            onDismiss: { print("Dismiss") }
        )

        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
