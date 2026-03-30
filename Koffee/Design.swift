import SwiftUI

// MARK: - Typography
enum KoffeeFont {
    static let sectionLabel: Font = .system(size: 12, weight: .semibold)
    static let fieldLabel: Font = .system(size: 12, weight: .regular)
    static let body: Font = .system(size: 14, weight: .medium)
    static let input: Font = .system(size: 16, weight: .bold)
    static let button: Font = .system(size: 14, weight: .semibold)
    static let meterStatus: Font = .system(size: 18, weight: .bold)
    static let meterDetail: Font = .system(size: 14, weight: .regular)
}

// MARK: - Colors
enum KoffeeColor {
    static let green = Color(red: 0.298, green: 0.686, blue: 0.314)
    static let yellow = Color(red: 1.0, green: 0.757, blue: 0.027)
    static let red = Color(red: 0.957, green: 0.263, blue: 0.208)
    static let orange = Color(red: 1.0, green: 0.596, blue: 0.0)
    static let background = Color(white: 0.08)
    static let secondary = Color(white: 0.6)
}

// MARK: - Spacing (8pt grid)
enum KoffeeSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    
    static let sectionSpacing: CGFloat = 16
    static let elementSpacing: CGFloat = 8
    static let labelToContent: CGFloat = 8
}

// MARK: - Touch Targets
enum KoffeeTouch {
    static let minSize: CGFloat = 44
    static let buttonHeight: CGFloat = 48
    static let smallButton: CGFloat = 32
    static let sensitivityButton: CGFloat = 36
}

// MARK: - Corner Radius
enum KoffeeRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
}

// MARK: - Window Layout
enum KoffeeLayout {
    static let titleBarHeight: CGFloat = 28
    static let contentPadding: CGFloat = 16
    
    // Calculate total height based on number of doses
    static func calculateHeight(doseCount: Int, hasScroll: Bool) -> CGFloat {
        let bodySection: CGFloat = 60
        let scheduleSection: CGFloat = 60
        let meterSection: CGFloat = 180  // HERO size
        let dosesSectionBase: CGFloat = 40
        let doseEditorHeight: CGFloat = 52
        let addButtonHeight: CGFloat = 48
        let optimizeButtonHeight: CGFloat = 48
        let spacing: CGFloat = 64  // 8 sections × 8px
        
        let dosesSection = dosesSectionBase + (CGFloat(doseCount) * doseEditorHeight) + addButtonHeight
        
        let total = titleBarHeight + contentPadding + bodySection + scheduleSection + 
                    meterSection + dosesSection + optimizeButtonHeight + spacing
        
        // If content exceeds max, allow scrolling
        let maxHeight: CGFloat = 700
        return min(total, maxHeight)
    }
    
    // Calculate width based on longest content
    static func calculateWidth() -> CGFloat {
        // Longest beverage name + DatePicker + button + padding
        let datePicker: CGFloat = 70
        let picker: CGFloat = 220  // ~25 chars × 8px + icon
        let removeButton: CGFloat = 32
        let padding: CGFloat = 40  // horizontal padding × 2 + spacing
        
        return datePicker + picker + removeButton + padding + 20  // extra buffer
    }
}
