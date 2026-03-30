import Foundation

struct CaffeineCalculator {
    private static let kgToLbs: Double = 2.20462
    private static let maxDailyCaffeineMg: Double = 400.0
    private static let mgCaffeinePerLb: Double = 2.72
    private static let caffeineHalfLifeHours: Double = 5.0
    private static let caffeineDelayAfterWakeMinutes: Double = 90
    private static let minDoseIntervalHours: Double = 4.0

    static func calculateOptimal(
        weightKg: Double,
        wakeTime: Date,
        sleepTime: Date,
        sensitivity: Sensitivity
    ) -> CaffeineResult {
        let weightLbs = weightKg * kgToLbs
        let baseLimit = min(weightLbs * mgCaffeinePerLb, maxDailyCaffeineMg)
        let dailyLimit = baseLimit * sensitivity.multiplier

        var adjustedSleepTime = sleepTime
        if sleepTime <= wakeTime {
            adjustedSleepTime = Calendar.current.date(byAdding: .day, value: 1, to: sleepTime) ?? sleepTime
        }

        let safeAtBedtime = sensitivity.safeCaffeineAtBedtime
        let bufferHours = sensitivity.hoursBeforeBedForLastDose

        guard let latestSafeTime = Calendar.current.date(
            byAdding: .hour,
            value: -Int(bufferHours),
            to: adjustedSleepTime
        ) else {
            return emptyResult(dailyLimit: dailyLimit, sensitivity: sensitivity, sleepTime: adjustedSleepTime)
        }

        guard let firstDoseTime = Calendar.current.date(
            byAdding: .minute,
            value: Int(caffeineDelayAfterWakeMinutes),
            to: wakeTime
        ) else {
            return emptyResult(dailyLimit: dailyLimit, sensitivity: sensitivity, sleepTime: adjustedSleepTime)
        }

        guard latestSafeTime > firstDoseTime else {
            return emptyResult(dailyLimit: dailyLimit, sensitivity: sensitivity, sleepTime: adjustedSleepTime)
        }

        guard let secondDoseTime = Calendar.current.date(
            byAdding: .hour,
            value: -2,
            to: latestSafeTime
        ) else {
            return emptyResult(dailyLimit: dailyLimit, sensitivity: sensitivity, sleepTime: adjustedSleepTime)
        }

        let hoursBetweenDoses = secondDoseTime.timeIntervalSince(firstDoseTime) / 3600
        let secondDoseAvailable = hoursBetweenDoses >= minDoseIntervalHours

        var doses: [(Date, Double)] = []

        if secondDoseAvailable {
            let firstAmount = dailyLimit * 0.4
            let secondAmount = dailyLimit * 0.6
            doses.append((firstDoseTime, firstAmount))
            doses.append((secondDoseTime, secondAmount))
        } else {
            let singleDose = dailyLimit * 0.6
            doses.append((firstDoseTime, singleDose))
        }

        if doses.isEmpty {
            return emptyResult(dailyLimit: dailyLimit, sensitivity: sensitivity, sleepTime: adjustedSleepTime)
        }

        doses.sort { $0.0 < $1.0 }

        let firstDose = Dose(
            time: doses.count > 0 ? doses[0].0 : nil,
            amount: doses.count > 0 ? doses[0].1 : 0
        )
        let secondDose = Dose(
            time: doses.count > 1 ? doses[1].0 : nil,
            amount: doses.count > 1 ? doses[1].1 : 0
        )
        let thirdDose = Dose(time: nil, amount: 0)

        let latestSafeCaffeineTime = formatTime(latestSafeTime)

        var warnings: [String] = []
        let caffeineAtBedtime = calculateCaffeineAtTime(
            doses: doses.map { ($0.0, $0.1) },
            targetTime: adjustedSleepTime
        )

        if caffeineAtBedtime > safeAtBedtime {
            warnings.append("For \(sensitivity.displayName.lowercased()) sensitivity, keep caffeine under \(Int(safeAtBedtime))mg at bedtime. Current plan leaves ~\(Int(caffeineAtBedtime))mg.")
        }

        return CaffeineResult(
            dailyLimit: dailyLimit,
            firstDose: firstDose,
            secondDose: secondDose,
            thirdDose: thirdDose,
            warnings: warnings,
            latestSafeCaffeineTime: latestSafeCaffeineTime
        )
    }

    private static func emptyResult(dailyLimit: Double, sensitivity: Sensitivity, sleepTime: Date) -> CaffeineResult {
        let latestSafeTime = Calendar.current.date(
            byAdding: .hour,
            value: -Int(sensitivity.hoursBeforeBedForLastDose),
            to: sleepTime
        )
        return CaffeineResult(
            dailyLimit: dailyLimit,
            firstDose: Dose(),
            secondDose: Dose(),
            thirdDose: Dose(),
            warnings: [],
            latestSafeCaffeineTime: latestSafeTime.map { formatTime($0) } ?? nil
        )
    }

    static func calculateCaffeineAtTime(doses: [(Date, Double)], targetTime: Date) -> Double {
        var total: Double = 0.0
        for (doseTime, amount) in doses {
            guard doseTime <= targetTime else { continue }
            let hoursElapsed = targetTime.timeIntervalSince(doseTime) / 3600
            let remaining = amount * pow(0.5, hoursElapsed / caffeineHalfLifeHours)
            total += remaining
        }
        return total
    }

    static func calculateCaffeineAtBedtime(doses: [Dose], wakeTime: Date, sleepTime: Date) -> Double {
        var adjustedSleepTime = sleepTime
        if sleepTime <= wakeTime {
            adjustedSleepTime = Calendar.current.date(byAdding: .day, value: 1, to: sleepTime) ?? sleepTime
        }

        var adjustedDoses: [(Date, Double)] = []
        for dose in doses {
            guard let doseTime = dose.time, dose.amount > 0 else { continue }
            var adjustedDoseTime = doseTime
            if doseTime <= wakeTime {
                adjustedDoseTime = Calendar.current.date(byAdding: .day, value: 1, to: doseTime) ?? doseTime
            }
            adjustedDoses.append((adjustedDoseTime, dose.amount))
        }

        return calculateCaffeineAtTime(doses: adjustedDoses, targetTime: adjustedSleepTime)
    }

    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func parseTime(_ timeString: String, baseDate: Date = Date()) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let time = formatter.date(from: timeString) else { return nil }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = components.year
        combined.month = components.month
        combined.day = components.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined)
    }
}
