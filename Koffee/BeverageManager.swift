import Foundation

@MainActor
class BeverageManager: ObservableObject {
    static let shared = BeverageManager()

    @Published var beverages: [Beverage] = []

    private init() {
        loadBeverages()
    }

    private func loadBeverages() {
        guard let url = Bundle.main.url(forResource: "beverages", withExtension: "json") else {
            loadDefaultBeverages()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let beverageData = try JSONDecoder().decode(BeverageData.self, from: data)
            beverages = beverageData.beverages
        } catch {
            print("Failed to load beverages: \(error)")
            loadDefaultBeverages()
        }
    }

    private func loadDefaultBeverages() {
        beverages = [
            Beverage(name: "Espresso (1 shot, 30ml)", caffeineMg: 63, category: "Coffee", icon: "☕"),
            Beverage(name: "Brewed Coffee (240ml)", caffeineMg: 95, category: "Coffee", icon: "☕"),
            Beverage(name: "Instant Coffee (240ml)", caffeineMg: 62, category: "Coffee", icon: "☕"),
            Beverage(name: "Cold Brew (240ml)", caffeineMg: 200, category: "Coffee", icon: "☕"),
            Beverage(name: "Cafe Latte (240ml)", caffeineMg: 75, category: "Coffee", icon: "☕"),
            Beverage(name: "Black Tea (240ml)", caffeineMg: 47, category: "Tea", icon: "🍵"),
            Beverage(name: "Green Tea (240ml)", caffeineMg: 28, category: "Tea", icon: "🍵"),
            Beverage(name: "Cola (355ml)", caffeineMg: 40, category: "Energy", icon: "🥤"),
            Beverage(name: "Red Bull (240ml)", caffeineMg: 80, category: "Energy", icon: "⚡"),
            Beverage(name: "Energy Drink (240ml)", caffeineMg: 80, category: "Energy", icon: "⚡")
        ]
    }

    func findBestBeverageIndex(for amount: Double) -> Int {
        var bestIndex = 0
        var bestDiff = Double.infinity

        for (index, beverage) in beverages.enumerated() {
            let count = amount / Double(beverage.caffeineMg)
            let diff = abs(count - 1.0)
            if diff < bestDiff {
                bestDiff = diff
                bestIndex = index
            }
        }

        return bestIndex
    }
}
