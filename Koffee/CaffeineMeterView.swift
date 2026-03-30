import SwiftUI

struct CaffeineMeterView: View {
    let level: Double
    let safeLimit: Double
    
    private let arcRadius: CGFloat = 100  // HERO SIZE

    var statusText: String {
        if level <= safeLimit * 0.5 {
            return "Sleep well"
        } else if level <= safeLimit {
            return "Okay"
        } else {
            return "Too high"
        }
    }

    var statusColor: Color {
        if level <= safeLimit * 0.5 {
            return KoffeeColor.green
        } else if level <= safeLimit {
            return KoffeeColor.yellow
        } else {
            return KoffeeColor.red
        }
    }

    var body: some View {
        VStack(spacing: KoffeeSpacing.s) {
            ZStack {
                // Arc - THE HERO ELEMENT
                ArcShape()
                    .stroke(
                        LinearGradient(
                            colors: [KoffeeColor.green, KoffeeColor.yellow, KoffeeColor.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: arcRadius * 2, height: arcRadius)

                // Masking circle
                Circle()
                    .fill(KoffeeColor.background)
                    .frame(width: arcRadius * 1.5, height: arcRadius * 1.5)
                    .offset(y: arcRadius * 0.3)

                // Needle with animation
                if safeLimit > 0 {
                    let ratio = min(level / (safeLimit * 2), 1.0)
                    let angle = 180 * (1 - ratio)
                    NeedleView(angle: angle, length: arcRadius * 0.75, centerOffset: arcRadius * 0.3)
                        .animation(.easeOut(duration: 0.5), value: level)
                }

                // Center dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .offset(y: arcRadius * 0.3)
            }
            .frame(width: arcRadius * 2, height: arcRadius * 1.2)

            // Status text
            Text(statusText)
                .font(KoffeeFont.meterStatus)
                .foregroundColor(statusColor)
                .accessibilityLabel("Caffeine status: \(statusText)")

            // Caffeine level
            Text("~\(Int(level))mg at bedtime")
                .font(KoffeeFont.meterDetail)
                .foregroundColor(KoffeeColor.secondary)
                .accessibilityLabel("Approximately \(Int(level)) milligrams at bedtime")
        }
        .padding(KoffeeSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: KoffeeRadius.large)
                .fill(.ultraThinMaterial)
        )
    }
}

struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path
    }
}

struct NeedleView: View {
    let angle: Double
    let length: CGFloat
    let centerOffset: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2 + centerOffset

            Path { path in
                path.move(to: CGPoint(x: centerX, y: centerY))
                let radians = (180 - angle) * .pi / 180
                let endX = centerX + length * cos(radians)
                let endY = centerY - length * sin(radians)
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
            .stroke(Color.white, lineWidth: 3)
        }
    }
}

#Preview {
    CaffeineMeterView(level: 30, safeLimit: 50)
        .frame(width: 300, height: 250)
        .background(KoffeeColor.background)
}
