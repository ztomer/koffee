import Foundation

@MainActor
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    private let configPath: URL

    @Published var weight: Double = 70.0
    @Published var sensitivity: Sensitivity = .medium
    @Published var wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @Published var sleepTime: Date = Calendar.current.date(from: DateComponents(hour: 23, minute: 0)) ?? Date()
    @Published var doses: [UserDose] = []

    struct UserDose: Codable, Identifiable, Equatable {
        var id = UUID()
        var time: Date
        var beverageIndex: Int
    }

    struct ConfigData: Codable {
        let weight: Double
        let sensitivity: String
        let wakeHour: Int
        let wakeMinute: Int
        let sleepHour: Int
        let sleepMinute: Int
        let doses: [DoseData]?

        struct DoseData: Codable {
            let time: String
            let beverage: Int
        }
    }

    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        configPath = homeDir.appendingPathComponent(".config/koffee.json")
        loadConfig()
    }

    func loadConfig() {
        guard FileManager.default.fileExists(atPath: configPath.path) else { return }

        do {
            let data = try Data(contentsOf: configPath)
            let config = try JSONDecoder().decode(ConfigData.self, from: data)

            weight = config.weight
            sensitivity = Sensitivity(rawValue: config.sensitivity) ?? .medium

            let calendar = Calendar.current
            wakeTime = calendar.date(from: DateComponents(hour: config.wakeHour, minute: config.wakeMinute)) ?? wakeTime
            sleepTime = calendar.date(from: DateComponents(hour: config.sleepHour, minute: config.sleepMinute)) ?? sleepTime

            if let configDoses = config.doses {
                doses = configDoses.compactMap { doseData in
                    guard let time = CaffeineCalculator.parseTime(doseData.time) else { return nil }
                    return UserDose(time: time, beverageIndex: doseData.beverage)
                }
            }
        } catch {
            print("Failed to load config: \(error)")
        }
    }

    func saveConfig(beverages: [Beverage]) {
        do {
            let directory = configPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let calendar = Calendar.current
            let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
            let sleepComponents = calendar.dateComponents([.hour, .minute], from: sleepTime)

            let doseData = doses.map { dose in
                ConfigData.DoseData(
                    time: CaffeineCalculator.formatTime(dose.time),
                    beverage: dose.beverageIndex
                )
            }

            let config = ConfigData(
                weight: weight,
                sensitivity: sensitivity.rawValue,
                wakeHour: wakeComponents.hour ?? 7,
                wakeMinute: wakeComponents.minute ?? 0,
                sleepHour: sleepComponents.hour ?? 23,
                sleepMinute: sleepComponents.minute ?? 0,
                doses: doseData
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: configPath)
        } catch {
            print("Failed to save config: \(error)")
        }
    }

    func addOptimalDoses() {
        let result = CaffeineCalculator.calculateOptimal(
            weightKg: weight,
            wakeTime: wakeTime,
            sleepTime: sleepTime,
            sensitivity: sensitivity
        )

        doses.removeAll()

        if let firstTime = result.firstDose.time, result.firstDose.amount > 0 {
            let bestIndex = BeverageManager.shared.findBestBeverageIndex(for: result.firstDose.amount)
            doses.append(UserDose(time: firstTime, beverageIndex: bestIndex))
        }

        if let secondTime = result.secondDose.time, result.secondDose.amount > 0 {
            let bestIndex = BeverageManager.shared.findBestBeverageIndex(for: result.secondDose.amount)
            doses.append(UserDose(time: secondTime, beverageIndex: bestIndex))
        }
    }
}
