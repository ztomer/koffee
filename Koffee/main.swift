import SwiftUI
import AppKit
import Foundation

let debugLogURL = URL(fileURLWithPath: "/tmp/koffee.log")

func debugLog(_ msg: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: debugLogURL.path) {
            if let handle = try? FileHandle(forWritingTo: debugLogURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: debugLogURL)
        }
    }
}

func clearDebugLog() {
    try? FileManager.default.removeItem(at: debugLogURL)
}

struct TrafficLightButton: View {
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        }
        .buttonStyle(.plain)
    }
}

struct BubbleState {
    var x: CGFloat
    var baseY: CGFloat
    var size: CGFloat
    var phase: Double
    var wobblePhase: Double
}

struct LiquidPhysics {
    static let accelerationDecay: CGFloat = 0.92
    static let tiltResponse: CGFloat = 0.08
    static let velocityDamping: CGFloat = 0.98
    static let angleDecay: CGFloat = 0.995
    static let springStrength: CGFloat = 0.0005
    static let angleInertia: CGFloat = 0.9
    static let tiltAmplification: CGFloat = 3.0
    static let waveFrequency1: CGFloat = 0.015
    static let waveFrequency2: CGFloat = 0.025
    static let waveSpeed1: Double = 0.8
    static let waveSpeed2: Double = 0.6
    static let waveAmplitude1: CGFloat = 3
    static let waveAmplitude2: CGFloat = 2
    static let bubbleTiltFactor: CGFloat = 0.5
    static let bubbleRiseFraction: CGFloat = 0.85
    static let bubbleCycleSeconds: Double = 8.0
    static let bubbleViscosityCoeff: Double = 2.0
    static let bubbleWobbleBase: CGFloat = 1.5
    static let minLiquidHeightForBubbles: CGFloat = 80
}

struct LiquidSurfaceView: View {
    let caffeineAtBedtime: Double
    let safeLimit: Double
    @Binding var containerAccelX: CGFloat
    let bubbleStates: [BubbleState]
    
    @State private var physicsState: (tiltAngle: CGFloat, tiltVelocity: CGFloat) = (0, 0)
    @State private var logFrame: Int = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                logFrame += 1
                
                var tiltAngle = physicsState.tiltAngle
                var tiltVelocity = physicsState.tiltVelocity
                
                let accel = containerAccelX
                containerAccelX *= LiquidPhysics.accelerationDecay
                
                tiltVelocity += accel * LiquidPhysics.tiltResponse
                tiltVelocity -= tiltAngle * LiquidPhysics.springStrength
                tiltVelocity *= LiquidPhysics.velocityDamping
                tiltAngle += tiltVelocity * LiquidPhysics.angleInertia
                tiltAngle *= LiquidPhysics.angleDecay
                
                physicsState = (tiltAngle, tiltVelocity)
                
                if logFrame % 30 == 0 && (abs(tiltAngle) > 0.01 || abs(accel) > 0.01) {
                    debugLog("PHYSICS accel:\(String(format: "%.4f", accel)) | tilt:\(String(format: "%.4f", tiltAngle)) vel:\(String(format: "%.4f", tiltVelocity))")
                }
                
                let fillRatio = min(caffeineAtBedtime / max(safeLimit, 1), 1.3)
                let liquidHeight = size.height * fillRatio
                let surfaceY = size.height - liquidHeight
                
                var liquidPath = Path()
                liquidPath.move(to: CGPoint(x: 0, y: size.height))
                liquidPath.addLine(to: CGPoint(x: 0, y: surfaceY + 20))
                
                for x in stride(from: 0, through: size.width, by: 3) {
                    let normalizedX = (x / size.width - 0.5) * 2
                    let tiltOffset = normalizedX * tiltAngle * LiquidPhysics.tiltAmplification
                    let wave1 = sin(x * LiquidPhysics.waveFrequency1 + time * LiquidPhysics.waveSpeed1) * LiquidPhysics.waveAmplitude1
                    let wave2 = sin(x * LiquidPhysics.waveFrequency2 - time * LiquidPhysics.waveSpeed2) * LiquidPhysics.waveAmplitude2
                    let y = surfaceY + wave1 + wave2 + tiltOffset
                    liquidPath.addLine(to: CGPoint(x: x, y: y))
                }
                
                liquidPath.addLine(to: CGPoint(x: size.width, y: size.height))
                liquidPath.closeSubpath()
                
                let gradient = Gradient(colors: [
                    Color(red: 0.25, green: 0.12, blue: 0.05),
                    Color(red: 0.18, green: 0.08, blue: 0.03),
                    Color(red: 0.08, green: 0.03, blue: 0.01)
                ])
                context.fill(liquidPath, with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                
                var foamPath = Path()
                foamPath.move(to: CGPoint(x: 0, y: surfaceY + 15))
                
                for x in stride(from: 0, through: size.width, by: 3) {
                    let normalizedX = (x / size.width - 0.5) * 2
                    let tiltOffset = normalizedX * tiltAngle * LiquidPhysics.tiltAmplification
                    let wave1 = sin(x * LiquidPhysics.waveFrequency1 + time * LiquidPhysics.waveSpeed1) * LiquidPhysics.waveAmplitude1
                    let wave2 = sin(x * LiquidPhysics.waveFrequency2 - time * LiquidPhysics.waveSpeed2) * LiquidPhysics.waveAmplitude2
                    let y = surfaceY + wave1 + wave2 + tiltOffset
                    foamPath.addLine(to: CGPoint(x: x, y: y))
                }
                
                foamPath.addLine(to: CGPoint(x: size.width, y: surfaceY + 15))
                foamPath.addLine(to: CGPoint(x: 0, y: surfaceY + 15))
                foamPath.closeSubpath()
                
                let foamGradient = Gradient(colors: [
                    Color(red: 0.85, green: 0.68, blue: 0.45).opacity(0.85),
                    Color(red: 0.70, green: 0.50, blue: 0.30).opacity(0.6)
                ])
                context.fill(foamPath, with: .linearGradient(
                    foamGradient,
                    startPoint: CGPoint(x: 0, y: surfaceY),
                    endPoint: CGPoint(x: 0, y: surfaceY + 35)
                ))
                
                for i in 0..<min(30, bubbleStates.count) {
                    guard liquidHeight > LiquidPhysics.minLiquidHeightForBubbles else { continue }
                    let bubble = bubbleStates[i]
                    
                    let elapsedTime = time + bubble.phase
                    let progress = elapsedTime.truncatingRemainder(dividingBy: LiquidPhysics.bubbleCycleSeconds) / LiquidPhysics.bubbleCycleSeconds
                    
                    let startY = surfaceY + bubble.baseY
                    let riseDistance = liquidHeight * LiquidPhysics.bubbleRiseFraction
                    let currentY = startY - (progress * riseDistance)
                    
                    let viscosityDamping = exp(-progress * LiquidPhysics.bubbleViscosityCoeff)
                    let wobbleAmplitude = LiquidPhysics.bubbleWobbleBase * viscosityDamping
                    let wobble = sin(time * LiquidPhysics.waveSpeed1 + bubble.wobblePhase) * wobbleAmplitude
                    
                    let normalizedBubbleX = (bubble.x / size.width - 0.5) * 2
                    let currentX = bubble.x + wobble + normalizedBubbleX * tiltAngle * (LiquidPhysics.tiltAmplification * LiquidPhysics.bubbleTiltFactor)
                    
                    if currentY > surfaceY && currentY < size.height {
                        let alpha = min(0.3, 0.3 * viscosityDamping + 0.08)
                        let bubblePath = Circle().path(in: CGRect(
                            x: currentX,
                            y: currentY,
                            width: bubble.size,
                            height: bubble.size
                        ))
                        context.fill(bubblePath, with: .color(.white.opacity(Double(alpha))))
                    }
                }
            }
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private var initialDosesAdded = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowSize = (width: 400.0, height: 650.0)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height),
            styleMask: [.closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Koffee"
        window.center()
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NSSize(width: 360, height: 600)
        window.maxSize = NSSize(width: 500, height: 900)
        window.contentView = NSHostingView(rootView: KoffeeContentView(onAppear: addInitialDoses, window: window))
        window.makeKeyAndOrderFront(nil)
    }

    private func addInitialDoses() {
        guard !initialDosesAdded else { return }
        initialDosesAdded = true
        ConfigManager.shared.addOptimalDoses()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

struct KoffeeContentView: View {
    let onAppear: () -> Void
    let window: NSWindow

    @ObservedObject private var config = ConfigManager.shared
    @ObservedObject private var beverages = BeverageManager.shared

    @State private var caffeineAtBedtime: Double = 0
    @State private var bubbleSeeds: [Int] = (0..<30).map { _ in Int.random(in: 0...10000) }
    @State private var bubbleStates: [BubbleState] = (0..<30).map { i in
        let seed = Int.random(in: 0...10000)
        return BubbleState(
            x: CGFloat(seed % 360) + 20,
            baseY: CGFloat((seed / 100) % 400) + 20,
            size: CGFloat(4 + (seed % 7)),
            phase: Double(i) * 0.3,
            wobblePhase: Double(i) * 0.7
        )
    }
    
    @State private var containerAccelX: CGFloat = 0
    @State private var lastWindowPos: CGPoint? = nil
    @State private var frameCount: Int = 0

    var safeLimit: Double {
        config.sensitivity.safeCaffeineAtBedtime
    }

    var body: some View {
        ZStack {
            coffeeBackground
            
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    controlsSection
                    dosePlanSection
                }
                .padding(20)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let currentOrigin = window.frame.origin
                    let newX = currentOrigin.x + value.translation.width
                    let newY = currentOrigin.y - value.translation.height
                    
                    if let lastPos = lastWindowPos {
                        let dx = newX - lastPos.x
                        let dy = newY - lastPos.y
                        containerAccelX += dx * 0.08
                    }
                    
                    lastWindowPos = CGPoint(x: newX, y: newY)
                    window.setFrameOrigin(CGPoint(x: newX, y: newY))
                }
                .onEnded { value in
                    debugLog("DRAG_END velocity:\(String(format: "%.1f", value.velocity.width))")
                    containerAccelX = value.velocity.width * 0.001
                    lastWindowPos = nil
                }
        )
        .onAppear {
            clearDebugLog()
            debugLog("=== KOFFEE START ===")
        }
        .onAppear { onAppear() }
        .onAppear { updateCaffeineLevel() }
        .onChange(of: config.doses) { _ in updateCaffeineLevel() }
        .onChange(of: config.weight) { _ in updateCaffeineLevel() }
        .onChange(of: config.sensitivity) { _ in updateCaffeineLevel() }
        .onChange(of: config.wakeTime) { _ in updateCaffeineLevel() }
        .onChange(of: config.sleepTime) { _ in updateCaffeineLevel() }
    }
    
    private var coffeeBackground: some View {
        LiquidSurfaceView(
            caffeineAtBedtime: caffeineAtBedtime,
            safeLimit: safeLimit,
            containerAccelX: $containerAccelX,
            bubbleStates: bubbleStates
        )
    }
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            trafficLights
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Koffee")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("\(Int(caffeineAtBedtime))mg at bedtime")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            statusBadge
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 4) {
                Text("accel:\(String(format: "%.2f", containerAccelX))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(containerAccelX != 0 ? .orange : .secondary)
            }
            .padding(4)
        }
    }
    
    private var trafficLights: some View {
        HStack(spacing: 8) {
            TrafficLightButton(color: Color(red: 1, green: 0.43, blue: 0.43), action: { window.close() })
            TrafficLightButton(color: Color(red: 1, green: 0.8, blue: 0.35), action: { window.miniaturize(nil) })
            TrafficLightButton(color: Color(red: 0.35, green: 0.78, blue: 0.35), action: { window.zoom(nil) })
        }
        .padding(8)
        .glassEffect(.regular, in: .capsule)
    }
    
    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .shadow(color: statusColor.opacity(0.6), radius: 6)
            
            Text(statusText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
    }
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                weightControl
                sensitivityControl
            }
            
            HStack(spacing: 16) {
                wakeTimeControl
                sleepTimeControl
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
    
    private var weightControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            HStack {
                TextField("kg", value: $config.weight, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(width: 60)
                    .focusable()
                
                Text("kg")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var sensitivityControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sensitivity")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(Sensitivity.allCases) { sens in
                    SensitivityButton(
                        sensitivity: sens,
                        isSelected: config.sensitivity == sens,
                        action: { config.sensitivity = sens }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var wakeTimeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wake Time")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            DatePicker("", selection: $config.wakeTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(12)
                .focusable()
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var sleepTimeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Time")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            DatePicker("", selection: $config.sleepTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(12)
                .focusable()
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var dosePlanSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Dose Plan")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    config.addOptimalDoses()
                } label: {
                    Label("Optimize", systemImage: "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }
            
            ForEach($config.doses) { $dose in
                DoseRowView(dose: $dose, beverages: beverages.beverages) {
                    if let index = config.doses.firstIndex(where: { $0.id == dose.id }) {
                        config.doses.remove(at: index)
                    }
                }
            }
            
            Button {
                let defaultTime = Calendar.current.date(byAdding: .hour, value: 4, to: config.wakeTime) ?? config.wakeTime
                config.doses.append(ConfigManager.UserDose(time: defaultTime, beverageIndex: 0))
            } label: {
                Label("Add Cup", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
    
    private var statusText: String {
        if caffeineAtBedtime <= safeLimit * 0.5 {
            return "Sleep Ready"
        } else if caffeineAtBedtime <= safeLimit {
            return "Okay"
        } else {
            return "Too Much!"
        }
    }
    
    private var statusColor: Color {
        if caffeineAtBedtime <= safeLimit * 0.5 {
            return Color(red: 0.3, green: 0.85, blue: 0.4)
        } else if caffeineAtBedtime <= safeLimit {
            return Color(red: 1.0, green: 0.8, blue: 0.2)
        } else {
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }

    private func updateCaffeineLevel() {
        guard !config.doses.isEmpty else {
            caffeineAtBedtime = 0
            return
        }
        
        let doses = config.doses.compactMap { userDose -> Dose? in
            guard userDose.beverageIndex >= 0, 
                  userDose.beverageIndex < beverages.beverages.count else {
                return nil
            }
            return Dose(time: userDose.time, amount: Double(beverages.beverages[userDose.beverageIndex].caffeineMg))
        }
        caffeineAtBedtime = CaffeineCalculator.calculateCaffeineAtBedtime(
            doses: doses,
            wakeTime: config.wakeTime,
            sleepTime: config.sleepTime
        )
    }
}

struct DoseRowView: View {
    @Binding var dose: ConfigManager.UserDose
    let beverages: [Beverage]
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            DatePicker("", selection: $dose.time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(width: 80)
                .focusable()
            
            Picker("", selection: $dose.beverageIndex) {
                ForEach(Array(beverages.enumerated()), id: \.offset) { index, beverage in
                    Text("\(beverage.icon) \(beverage.name)")
                        .tag(index)
                }
            }
            .pickerStyle(.menu)
            
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

struct SensitivityButton: View {
    let sensitivity: Sensitivity
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(sensitivity.displayName.prefix(1))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.orange : Color.clear)
                .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
