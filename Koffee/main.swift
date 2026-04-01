import SwiftUI
import AppKit
import Foundation
import LiquidContainer

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

class KoffeeWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
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

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private var initialDosesAdded = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowSize = (width: 400.0, height: 650.0)
        
        window = KoffeeWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height),
            styleMask: [.closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Koffee"
        window.center()
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
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
    @State private var bubbleStates: [BubbleState] = BubbleGenerator.generate(count: 30, width: 400, height: 650)
    
    @State private var physicsEngine = LiquidPhysicsEngine()
    @State private var lastWindowPos: CGPoint? = nil
    @State private var weightText: String = ""
    @FocusState private var isWeightFocused: Bool

    var safeLimit: Double {
        config.sensitivity.safeCaffeineAtBedtime
    }
    
    var fillRatio: Double {
        caffeineAtBedtime / max(safeLimit, 1)
    }
    
    var liquidConfiguration: LiquidContainerConfiguration {
        guard let firstDose = config.doses.first,
              firstDose.beverageIndex >= 0,
              firstDose.beverageIndex < beverages.beverages.count else {
            return .coffee
        }
        
        let category = beverages.beverages[firstDose.beverageIndex].category.lowercased()
        
        switch category {
        case "coffee":
            return .coffee
        case "tea":
            return LiquidContainerConfiguration(
                liquidColor: Color(red: 0.65, green: 0.55, blue: 0.40),
                liquidColorDark: Color(red: 0.15, green: 0.10, blue: 0.05),
                liquidColorMid: Color(red: 0.35, green: 0.25, blue: 0.15),
                liquidColorLight: Color(red: 0.75, green: 0.65, blue: 0.50),
                foamColor: Color(red: 0.90, green: 0.85, blue: 0.75),
                foamCremaColor: Color(red: 0.85, green: 0.75, blue: 0.60),
                minFillRatio: 0.05,
                maxFillRatio: 1.3,
                layerConfiguration: LiquidLayerConfiguration(
                    layers: [
                        LiquidLayer(
                            name: "foam",
                            topColor: Color(red: 0.95, green: 0.90, blue: 0.85),
                            bottomColor: Color(red: 0.80, green: 0.70, blue: 0.60),
                            boundaryHeight: 0.15,
                            waveDamping: 0.96,
                            phaseDelay: 0.0,
                            hasFoam: true,
                            foamColor: Color(red: 0.95, green: 0.90, blue: 0.85),
                            bubbleDensity: 0.6
                        ),
                        LiquidLayer(
                            name: "liquid",
                            topColor: Color(red: 0.50, green: 0.35, blue: 0.20),
                            bottomColor: Color(red: 0.20, green: 0.12, blue: 0.06),
                            boundaryHeight: 1.0,
                            waveDamping: 0.88,
                            phaseDelay: 0.15
                        )
                    ]
                )
            )
        case "energy":
            return LiquidContainerConfiguration(
                liquidColor: Color(red: 0.95, green: 0.85, blue: 0.10),
                liquidColorDark: Color(red: 0.60, green: 0.40, blue: 0.02),
                liquidColorMid: Color(red: 0.80, green: 0.60, blue: 0.05),
                liquidColorLight: Color(red: 0.98, green: 0.92, blue: 0.30),
                foamColor: Color(red: 1.0, green: 0.95, blue: 0.70),
                foamCremaColor: Color(red: 0.95, green: 0.85, blue: 0.50),
                minFillRatio: 0.05,
                maxFillRatio: 1.3,
                layerConfiguration: LiquidLayerConfiguration(
                    layers: [
                        LiquidLayer(
                            name: "foam",
                            topColor: Color(red: 1.0, green: 0.98, blue: 0.85),
                            bottomColor: Color(red: 0.95, green: 0.90, blue: 0.70),
                            boundaryHeight: 0.08,
                            waveDamping: 0.97,
                            phaseDelay: 0.0,
                            hasFoam: true,
                            foamColor: Color(red: 1.0, green: 0.98, blue: 0.85),
                            bubbleDensity: 0.9
                        ),
                        LiquidLayer(
                            name: "liquid",
                            topColor: Color(red: 0.85, green: 0.65, blue: 0.08),
                            bottomColor: Color(red: 0.50, green: 0.30, blue: 0.02),
                            boundaryHeight: 1.0,
                            waveDamping: 0.86,
                            phaseDelay: 0.12
                        )
                    ]
                )
            )
        default:
            return .coffee
        }
    }

    var body: some View {
        ZStack {
            LiquidContainerView(
                fillLevel: CGFloat(fillRatio),
                configuration: liquidConfiguration,
                physicsEngine: physicsEngine,
                bubbleStates: bubbleStates
            )
            
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
                        physicsEngine.containerAccelX += dx * 0.02
                    }
                    
                    lastWindowPos = CGPoint(x: newX, y: newY)
                    window.setFrameOrigin(CGPoint(x: newX, y: newY))
                }
                .onEnded { value in
                    debugLog("DRAG_END velocity:\(String(format: "%.1f", value.velocity.width))")
                    physicsEngine.containerAccelX = value.velocity.width * 0.002
                    lastWindowPos = nil
                }
        )
        .onAppear {
            clearDebugLog()
            debugLog("=== KOFFEE START ===")
        }
        .onAppear { onAppear() }
        .onAppear { updateCaffeineLevel() }
        .onChange(of: config.doses) { oldDoses, newDoses in
            let wasAdded = newDoses.count > oldDoses.count
            updateCaffeineLevel()
            if wasAdded {
                physicsEngine.addSloshImpulse(direction: Double.random(in: 0.5...1.5))
            } else if newDoses.count < oldDoses.count {
                physicsEngine.addSloshImpulse(direction: Double.random(in: -1.5 ... -0.5))
            }
        }
        .onChange(of: config.weight) { _, _ in updateCaffeineLevel() }
        .onChange(of: config.sensitivity) { _, _ in updateCaffeineLevel() }
        .onChange(of: config.wakeTime) { _, _ in updateCaffeineLevel() }
        .onChange(of: config.sleepTime) { _, _ in updateCaffeineLevel() }
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
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }
    
    private var weightControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            HStack {
                TextField("kg", text: $weightText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(width: 80)
                    .focused($isWeightFocused)
                    .onChange(of: weightText) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            weightText = filtered
                        }
                        if let weight = Double(filtered), !filtered.isEmpty {
                            config.weight = min(max(weight, 20), 200)
                        } else if filtered.isEmpty {
                            weightText = "0"
                            config.weight = 20
                        }
                    }
                    .onChange(of: isWeightFocused) { _, newValue in
                        if !newValue {
                            weightText = String(format: "%.0f", config.weight)
                        }
                    }
                    .onAppear {
                        weightText = String(format: "%.0f", config.weight)
                    }
                
                Text("kg")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
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
            
            EditableTimePicker(selection: $config.wakeTime)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var sleepTimeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Time")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            EditableTimePicker(selection: $config.sleepTime)
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
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 12))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
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
            EditableTimePicker(selection: $dose.time)
                .frame(width: 100)
            
            Picker("", selection: $dose.beverageIndex) {
                ForEach(Array(beverages.enumerated()), id: \.offset) { index, beverage in
                    Text("\(beverage.icon) \(beverage.name) - \(beverage.caffeineMg)mg")
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
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct SensitivityButton: View {
    let sensitivity: Sensitivity
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.orange : Color.clear)
                
                Text(sensitivity.displayName.prefix(1))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
