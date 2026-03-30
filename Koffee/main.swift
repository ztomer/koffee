import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private var initialDosesAdded = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowSize = (width: 400.0, height: 700.0)
        
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
        window.minSize = NSSize(width: 360, height: 550)
        window.maxSize = NSSize(width: 500, height: 800)
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
    @State private var bubbleSeeds: [Int] = (0..<20).map { _ in Int.random(in: 0...10000) }

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
        .onAppear { onAppear() }
        .onAppear { updateCaffeineLevel() }
        .onChange(of: config.doses) { _ in updateCaffeineLevel() }
        .onChange(of: config.weight) { _ in updateCaffeineLevel() }
        .onChange(of: config.sensitivity) { _ in updateCaffeineLevel() }
        .onChange(of: config.wakeTime) { _ in updateCaffeineLevel() }
        .onChange(of: config.sleepTime) { _ in updateCaffeineLevel() }
    }
    
    private var coffeeBackground: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            Canvas { context, size in
                let fillRatio = min(caffeineAtBedtime / max(safeLimit, 1), 1.3)
                let liquidHeight = size.height * fillRatio
                let surfaceY = size.height - liquidHeight
                
                var liquidPath = Path()
                liquidPath.move(to: CGPoint(x: 0, y: size.height))
                liquidPath.addLine(to: CGPoint(x: 0, y: surfaceY + 30))
                
                for x in stride(from: 0, through: size.width, by: 3) {
                    let wave1 = sin(x * 0.02 + time * 1.5) * 8
                    let wave2 = sin(x * 0.03 - time * 1.2) * 5
                    let y = surfaceY + wave1 + wave2
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
                foamPath.move(to: CGPoint(x: 0, y: surfaceY + 25))
                
                for x in stride(from: 0, through: size.width, by: 3) {
                    let wave1 = sin(x * 0.02 + time * 1.5) * 8
                    let wave2 = sin(x * 0.03 - time * 1.2) * 5
                    let y = surfaceY + wave1 + wave2
                    foamPath.addLine(to: CGPoint(x: x, y: y))
                }
                
                foamPath.addLine(to: CGPoint(x: size.width, y: surfaceY + 25))
                foamPath.addLine(to: CGPoint(x: 0, y: surfaceY + 25))
                foamPath.closeSubpath()
                
                let foamGradient = Gradient(colors: [
                    Color(red: 0.85, green: 0.68, blue: 0.45).opacity(0.9),
                    Color(red: 0.70, green: 0.50, blue: 0.30).opacity(0.7)
                ])
                context.fill(foamPath, with: .linearGradient(
                    foamGradient,
                    startPoint: CGPoint(x: 0, y: surfaceY),
                    endPoint: CGPoint(x: 0, y: surfaceY + 40)
                ))
                
                for i in 0..<20 {
                    guard liquidHeight > 60 else { continue }
                    let seed = bubbleSeeds[i]
                    let bubbleX = CGFloat(seed % Int(size.width - 40)) + 20
                    let baseStartY = CGFloat((seed / 100) % Int(liquidHeight - 60)) + 30
                    let startY = surfaceY + baseStartY
                    let cycleTime = 60.0
                    let progress = (time.truncatingRemainder(dividingBy: cycleTime)) / cycleTime
                    let bubbleY = startY - progress * (liquidHeight * 0.7)
                    let bubbleSize = CGFloat(4 + (seed % 7))
                    let wobble = sin(time * 0.1 + CGFloat(seed)) * 0.5
                    
                    if bubbleY > surfaceY {
                        let bubblePath = Circle().path(in: CGRect(
                            x: bubbleX + wobble,
                            y: bubbleY,
                            width: bubbleSize,
                            height: bubbleSize
                        ))
                        context.fill(bubblePath, with: .color(.white.opacity(0.25)))
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            trafficLights
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Koffee")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("\(Int(caffeineAtBedtime))mg at bedtime")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            statusBadge
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in 
                    window.perform(Selector(("performDragWithEvent:")), with: NSApp.currentEvent)
                }
        )
    }
    
    private var trafficLights: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 1, green: 0.43, blue: 0.43))
                .frame(width: 12, height: 12)
                .onTapGesture { window.close() }
            
            Circle()
                .fill(Color(red: 1, green: 0.8, blue: 0.35))
                .frame(width: 12, height: 12)
                .onTapGesture { window.miniaturize(nil) }
            
            Circle()
                .fill(Color(red: 0.35, green: 0.78, blue: 0.35))
                .frame(width: 12, height: 12)
                .onTapGesture { window.zoom(nil) }
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
                TextField("", value: $config.weight, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 60)
                
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
                    Button {
                        config.sensitivity = sens
                    } label: {
                        Text(sens.displayName.prefix(1))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(config.sensitivity == sens ? .white : .secondary)
                            .frame(width: 44, height: 44)
                            .background(config.sensitivity == sens ? Color.orange : Color.clear)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular, in: .rect(cornerRadius: 10))
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
                Label("Add Dose", systemImage: "plus.circle.fill")
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
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
