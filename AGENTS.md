# Agent Guidelines for Koffee

Koffee is a native macOS app for calculating optimal caffeine intake, built with SwiftUI.

## Build/Lint/Test Commands

### Building
```bash
./build.sh      # Generate Xcode project and build
./run.sh        # Build and run the app
```

### XcodeGen
```bash
xcodegen generate    # Regenerate Xcode project from project.yml
```

### Opening in Xcode
```bash
open Koffee.xcodeproj
```

## Project Structure

```
Koffee/
├── main.swift              # App entry point with AppDelegate
├── Models.swift           # Sensitivity enum, Dose, Beverage structs
├── CaffeineCalculator.swift # Core algorithm (research-based)
├── ConfigManager.swift    # Config persistence to ~/.config/koffee.json
├── BeverageManager.swift   # Load beverages from JSON
├── ContentView.swift      # Main UI layout
├── CaffeineMeterView.swift # Arc gauge meter
├── DoseEditorView.swift   # Dose card with time + beverage picker
└── beverages.json          # Beverage definitions
```

## UI Design

- Native macOS window with transparent titlebar
- Coffee-tinted glass backgrounds
- Orange accent color (#FF9800)
- Arc gauge meter for caffeine level
- Real-time updates on parameter changes

## Configuration

User settings stored in `~/.config/koffee.json`:
- Weight, sensitivity, wake/sleep times
- Custom dose plan

## Beverages

Beverages loaded from `beverages.json`:
- `name`: Display name with portion
- `caffeine_mg`: Caffeine content
- `category`: Coffee, Tea, Energy, Other
- `icon`: Emoji for UI

## Algorithm

Based on caffeine research:
- Half-life: ~5 hours
- First dose: 90 min after waking
- Sensitivity buffers: High=12h, Medium=9h, Low=6h
- Safe bedtime caffeine: High=25mg, Medium=50mg, Low=100mg
