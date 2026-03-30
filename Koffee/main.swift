import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private var initialDosesAdded = false

    private func loadWindowConfig() -> (width: CGFloat, height: CGFloat) {
        guard let url = Bundle.main.url(forResource: "config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode([String: WindowConfig].self, from: data),
              let window = json["window"] else {
            return (320, 600)
        }
        return (CGFloat(window.width), CGFloat(window.height))
    }

    struct WindowConfig: Codable {
        let width: Int
        let height: Int
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = loadWindowConfig()
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: config.width, height: config.height),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Koffee"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(Color(white: 0.08))
        window.contentView = NSHostingView(rootView: ContentView(onAppear: addInitialDoses))
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

struct ContentView: View {
    let onAppear: () -> Void

    @ObservedObject var config = ConfigManager.shared
    @ObservedObject var beverages = BeverageManager.shared

    @State private var caffeineAtBedtime: Double = 0

    var safeLimit: Double {
        config.sensitivity.safeCaffeineAtBedtime
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: KoffeeSpacing.sectionSpacing) {
                    bodySection
                    scheduleSection
                    meterSection
                    dosesSection
                }
                .padding(KoffeeSpacing.l)
            }
            .background(KoffeeColor.background)
            
            optimizeButton
                .padding(KoffeeSpacing.l)
                .background(KoffeeColor.background)
        }
        .onAppear { onAppear() }
        .onAppear { updateCaffeineLevel() }
        .onChange(of: config.doses) { _ in updateCaffeineLevel() }
        .onChange(of: config.weight) { _ in updateCaffeineLevel() }
        .onChange(of: config.sensitivity) { _ in updateCaffeineLevel() }
        .onChange(of: config.wakeTime) { _ in updateCaffeineLevel() }
        .onChange(of: config.sleepTime) { _ in updateCaffeineLevel() }
    }

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: KoffeeSpacing.xs) {
            Text("BODY")
                .font(KoffeeFont.sectionLabel)
                .foregroundColor(KoffeeColor.secondary)

            HStack(spacing: KoffeeSpacing.s) {
                GlassCard {
                    VStack(alignment: .leading, spacing: KoffeeSpacing.xs) {
                        Text("Weight")
                            .font(KoffeeFont.fieldLabel)
                            .foregroundColor(KoffeeColor.secondary)
                        HStack(spacing: KoffeeSpacing.xs) {
                            TextField("", value: $config.weight, format: .number)
                                .textFieldStyle(.plain)
                                .font(KoffeeFont.input)
                                .frame(width: 50)
                            Text("kg")
                                .font(KoffeeFont.fieldLabel)
                                .foregroundColor(KoffeeColor.secondary)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: KoffeeSpacing.xs) {
                        Text("Sensitivity")
                            .font(KoffeeFont.fieldLabel)
                            .foregroundColor(KoffeeColor.secondary)
                        HStack(spacing: KoffeeSpacing.xs) {
                            ForEach(Sensitivity.allCases) { sens in
                                Button {
                                    config.sensitivity = sens
                                } label: {
                                    Text(sens.displayName.prefix(1))
                                        .font(KoffeeFont.body)
                                        .foregroundColor(config.sensitivity == sens ? .white : KoffeeColor.secondary)
                                        .frame(width: KoffeeTouch.sensitivityButton, height: KoffeeTouch.sensitivityButton)
                                        .background(config.sensitivity == sens ? KoffeeColor.orange : Color.clear)
                                        .cornerRadius(KoffeeRadius.small)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: KoffeeSpacing.xs) {
            Text("SCHEDULE")
                .font(KoffeeFont.sectionLabel)
                .foregroundColor(KoffeeColor.secondary)

            HStack(spacing: KoffeeSpacing.s) {
                GlassCard {
                    VStack(alignment: .leading, spacing: KoffeeSpacing.xs) {
                        Text("Wake")
                            .font(KoffeeFont.fieldLabel)
                            .foregroundColor(KoffeeColor.secondary)
                        DatePicker("", selection: $config.wakeTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: KoffeeSpacing.xs) {
                        Text("Sleep")
                            .font(KoffeeFont.fieldLabel)
                            .foregroundColor(KoffeeColor.secondary)
                        DatePicker("", selection: $config.sleepTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }
            }
        }
    }

    private var meterSection: some View {
        CaffeineMeterView(level: caffeineAtBedtime, safeLimit: safeLimit)
    }

    private var dosesSection: some View {
        VStack(alignment: .leading, spacing: KoffeeSpacing.s) {
            Text("DOSE PLAN")
                .font(KoffeeFont.sectionLabel)
                .foregroundColor(KoffeeColor.secondary)

            ForEach($config.doses) { $dose in
                DoseEditorView(
                    dose: $dose,
                    beverages: beverages.beverages,
                    onRemove: {
                        if let index = config.doses.firstIndex(where: { $0.id == dose.id }) {
                            config.doses.remove(at: index)
                        }
                    }
                )
            }

            Button {
                let defaultTime = Calendar.current.date(
                    byAdding: .hour,
                    value: 4,
                    to: config.wakeTime
                ) ?? config.wakeTime
                config.doses.append(ConfigManager.UserDose(time: defaultTime, beverageIndex: 0))
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Dose")
                }
                .font(KoffeeFont.button)
                .foregroundColor(KoffeeColor.secondary)
                .frame(maxWidth: .infinity, minHeight: KoffeeTouch.minSize)
                .background(.ultraThinMaterial)
                .cornerRadius(KoffeeRadius.medium)
            }
            .buttonStyle(.plain)
        }
    }

    private var optimizeButton: some View {
        Button {
            config.addOptimalDoses()
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("Optimize")
            }
            .font(KoffeeFont.button)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: KoffeeTouch.buttonHeight)
            .background(KoffeeColor.orange)
            .cornerRadius(KoffeeRadius.medium)
        }
        .buttonStyle(.plain)
    }

    private func updateCaffeineLevel() {
        let doses = config.doses.map { userDose -> Dose in
            Dose(time: userDose.time, amount: Double(beverages.beverages[userDose.beverageIndex].caffeineMg))
        }
        caffeineAtBedtime = CaffeineCalculator.calculateCaffeineAtBedtime(
            doses: doses,
            wakeTime: config.wakeTime,
            sleepTime: config.sleepTime
        )
    }
}

struct GlassCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    var body: some View {
        content()
            .padding(.horizontal, KoffeeSpacing.s)
            .padding(.vertical, KoffeeSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(KoffeeRadius.medium)
    }
}

struct DoseEditorView: View {
    @Binding var dose: ConfigManager.UserDose
    let beverages: [Beverage]
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: KoffeeSpacing.s) {
            DatePicker("", selection: $dose.time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .fixedSize()
                .colorScheme(.dark)

            Picker("", selection: $dose.beverageIndex) {
                ForEach(0..<beverages.count, id: \.self) { index in
                    Text("\(beverages[index].icon) \(beverages[index].name)")
                        .tag(index)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(KoffeeColor.secondary)
                    .frame(width: KoffeeTouch.smallButton, height: KoffeeTouch.smallButton)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, KoffeeSpacing.s)
        .padding(.vertical, KoffeeSpacing.s)
        .background(.ultraThinMaterial)
        .cornerRadius(KoffeeRadius.medium)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
