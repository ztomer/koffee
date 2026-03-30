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
                VStack(spacing: 6) {
                    bodySection
                    scheduleSection
                    meterSection
                    dosesSection
                }
                .padding(10)
            }
            .background(Color(white: 0.08))
            
            optimizeButton
                .padding(10)
                .background(Color(white: 0.08))
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
        VStack(alignment: .leading, spacing: 2) {
            Text("BODY")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("kg")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        TextField("", value: $config.weight, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 40)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sensitivity")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        HStack(spacing: 3) {
                            ForEach(Sensitivity.allCases) { sens in
                                Button {
                                    config.sensitivity = sens
                                } label: {
                                    Text(sens.displayName.prefix(1))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(config.sensitivity == sens ? .white : .secondary)
                                        .frame(width: 26, height: 24)
                                        .background(config.sensitivity == sens ? Color(hex: "FF9800") : Color.clear)
                                        .cornerRadius(5)
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
        VStack(alignment: .leading, spacing: 2) {
            Text("SCHEDULE")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wake")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $config.wakeTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 4) {
            Text("DOSE PLAN")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

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
                    Text("Add")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
        }
    }

    private var optimizeButton: some View {
        Button {
            config.addOptimalDoses()
        } label: {
            Text("✨ Optimize")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "FF9800"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(5)
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(5)
    }
}

struct DoseEditorView: View {
    @Binding var dose: ConfigManager.UserDose
    let beverages: [Beverage]
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
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
                Text("−")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(4)
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
