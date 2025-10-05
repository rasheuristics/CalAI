import SwiftUI

/// Shimmer loading skeleton for calendar events
struct LoadingSkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Calendar header skeleton
            HStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(shimmerGradient)
                    .frame(width: 120, height: 28)

                Spacer()

                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(shimmerGradient)
                    .frame(width: 140, height: 32)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.xs)

            // Event skeleton cards
            ForEach(0..<5, id: \.self) { _ in
                EventSkeletonCard()
            }

            Spacer()
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemGray5),
                Color(.systemGray6),
                Color(.systemGray5)
            ]),
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }
}

/// Individual event card skeleton
struct EventSkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Time placeholder
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                    .fill(shimmerGradient)
                    .frame(width: 60, height: 16)

                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                    .fill(shimmerGradient)
                    .frame(width: 50, height: 12)
            }

            // Event content placeholder
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                    .fill(shimmerGradient)
                    .frame(height: 18)

                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                    .fill(shimmerGradient)
                    .frame(width: 120, height: 14)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color(.systemGray6))
        .cornerRadius(DesignSystem.CornerRadius.sm)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemGray4),
                Color(.systemGray5),
                Color(.systemGray4)
            ]),
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }
}

#Preview {
    LoadingSkeletonView()
}
