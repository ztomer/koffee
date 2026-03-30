import SwiftUI

struct CaffeineMeterView: View {
    let level: Double
    let safeLimit: Double

    private let arcRadius: CGFloat = 50

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
            return Color(red: 0.3, green: 0.69, blue: 0.31)
        } else if level <= safeLimit {
            return Color(red: 1.0, green: 0.76, blue: 0.03)
        } else {
            return Color(red: 0.96, green: 0.26, blue: 0.21)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                ArcShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color.green, Color.yellow, Color.red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: arcRadius * 2, height: arcRadius)

                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: arcRadius * 1.4, height: arcRadius * 1.4)
                    .offset(y: arcRadius * 0.25)

                if safeLimit > 0 {
                    let ratio = min(level / (safeLimit * 2), 1.0)
                    let angle = 180 * (1 - ratio)
                    NeedleView(angle: angle, length: arcRadius * 0.8, centerOffset: arcRadius * 0.25)
                }

                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .offset(y: arcRadius * 0.25)
            }
            .frame(width: arcRadius * 2, height: arcRadius * 1.1)

            Text(statusText)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusColor)

            Text("~\(Int(level))mg")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
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
            .stroke(Color.white, lineWidth: 1.5)
        }
    }
}

#Preview {
    CaffeineMeterView(level: 30, safeLimit: 50)
        .frame(width: 150, height: 100)
        .background(Color(white: 0.08))
}
