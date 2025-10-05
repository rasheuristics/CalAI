import SwiftUI

struct ErrorBannerView: View {
    let error: AppError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(error.title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(error.message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }

            if error.isRetryable {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.gradient)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    VStack {
        ErrorBannerView(
            error: .calendarAccessDenied,
            onRetry: { },
            onDismiss: { }
        )

        ErrorBannerView(
            error: .failedToLoadEvents(NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network timeout"])),
            onRetry: { },
            onDismiss: { }
        )
    }
}
