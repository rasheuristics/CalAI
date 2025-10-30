import SwiftUI

/// Animated waveform icon that shows audio activity
struct AnimatedWaveformIcon: View {
    let isAnimating: Bool
    let color: Color
    let size: CGFloat

    @State private var waveOffsets: [CGFloat] = [0, 0, 0, 0, 0]

    init(isAnimating: Bool, color: Color = .white, size: CGFloat = 20) {
        self.isAnimating = isAnimating
        self.color = color
        self.size = size
    }

    var body: some View {
        HStack(spacing: size * 0.1) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(color)
                    .frame(width: size * 0.12, height: barHeight(for: index))
                    .animation(
                        isAnimating ?
                            Animation
                                .easeInOut(duration: randomDuration(for: index))
                                .repeatForever(autoreverses: true)
                                .delay(randomDelay(for: index))
                            : .default,
                        value: isAnimating
                    )
            }
        }
        .frame(width: size, height: size)
        .onChange(of: isAnimating) { newValue in
            if newValue {
                // Trigger animation by randomizing offsets
                withAnimation {
                    for i in 0..<5 {
                        waveOffsets[i] = CGFloat.random(in: 0.3...1.0)
                    }
                }
            } else {
                // Reset to minimal height
                waveOffsets = [0.3, 0.3, 0.3, 0.3, 0.3]
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight = size * 0.3 // Minimum height
        let maxHeight = size * 0.9  // Maximum height

        if isAnimating {
            return baseHeight + (maxHeight - baseHeight) * waveOffsets[index]
        } else {
            return baseHeight
        }
    }

    private func randomDuration(for index: Int) -> Double {
        // Stagger durations for more natural wave effect
        let baseDurations: [Double] = [0.4, 0.5, 0.35, 0.45, 0.4]
        return baseDurations[index]
    }

    private func randomDelay(for index: Int) -> Double {
        // Stagger start times
        let delays: [Double] = [0, 0.1, 0.05, 0.15, 0.08]
        return delays[index]
    }
}

/// Processing indicator - rotating circle or spinner
struct ProcessingIndicator: View {
    let color: Color
    let size: CGFloat

    @State private var isRotating = false

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1.0).repeatForever(autoreverses: false),
                    value: isRotating
                )
        }
        .onAppear {
            isRotating = true
        }
    }
}

// Preview
struct AnimatedWaveformIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Idle state
            HStack {
                Text("Idle:")
                AnimatedWaveformIcon(isAnimating: false)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(8)
            }

            // Listening state
            HStack {
                Text("Listening:")
                AnimatedWaveformIcon(isAnimating: true)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(8)
            }

            // Processing state
            HStack {
                Text("Processing:")
                ProcessingIndicator(color: .white, size: 20)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}
