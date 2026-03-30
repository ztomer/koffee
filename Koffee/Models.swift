import Foundation

enum Sensitivity: String, CaseIterable, Identifiable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .low: return 1.2
        case .medium: return 1.0
        case .high: return 0.8
        }
    }

    var safeCaffeineAtBedtime: Double {
        switch self {
        case .low: return 100.0
        case .medium: return 50.0
        case .high: return 25.0
        }
    }

    var hoursBeforeBedForLastDose: Double {
        switch self {
        case .low: return 6.0
        case .medium: return 9.0
        case .high: return 12.0
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

struct Dose: Equatable {
    var time: Date?
    var amount: Double

    init(time: Date? = nil, amount: Double = 0) {
        self.time = time
        self.amount = amount
    }

    var timeString: String? {
        guard let time = time else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
}

struct CaffeineResult: Equatable {
    let dailyLimit: Double
    let firstDose: Dose
    let secondDose: Dose
    let thirdDose: Dose
    let warnings: [String]
    let latestSafeCaffeineTime: String?
}

struct Beverage: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let caffeineMg: Int
    let category: String
    let icon: String

    enum CodingKeys: String, CodingKey {
        case name
        case caffeineMg = "caffeine_mg"
        case category
        case icon
    }
}

struct BeverageData: Codable {
    let beverages: [Beverage]
}
