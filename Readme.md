# Koffee

Native macOS caffeine intake optimization app built with SwiftUI.

## Building

```bash
./build.sh      # Generate Xcode project and build
./run.sh        # Build and run the app
```

Or open `Koffee.xcodeproj` in Xcode and press ⌘R to run.

## Features

- Optimal caffeine dose scheduling based on weight and sensitivity
- Caffeine half-life modeling for realistic accumulation tracking
- Real-time bedtime caffeine meter with arc gauge
- Coffee-tinted glass UI design
- Config persistence across sessions
- 16 beverages with emoji icons

## Project Structure

```
Koffee/
├── main.swift              # App entry point with AppDelegate
├── Models.swift           # Sensitivity enum, Dose, Beverage structs
├── CaffeineCalculator.swift # Core algorithm (research-based)
├── ConfigManager.swift     # Config persistence to ~/.config/koffee.json
├── BeverageManager.swift  # Load beverages from JSON
├── ContentView.swift      # Main UI layout
├── CaffeineMeterView.swift # Arc gauge meter
├── DoseEditorView.swift   # Dose card with time + beverage picker
└── beverages.json          # Beverage definitions
```

## Customizing Beverages

Edit `Koffee/beverages.json` to add, remove, or modify beverages:

```json
{
  "beverages": [
    {"name": "Espresso (1 shot, 30ml)", "caffeine_mg": 63, "category": "Coffee", "icon": "☕"}
  ]
}
```

## Configuration

User settings are stored in `~/.config/koffee.json`.

## Algorithm

Based on research:
- Caffeine half-life: ~5 hours
- First dose: 90 min after waking (aligns with cortisol peak)
- Sensitivity buffers: High=12h, Medium=9h, Low=6h before bed
- Safe bedtime caffeine: High=25mg, Medium=50mg, Low=100mg
