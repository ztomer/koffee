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

### Running Tests
```bash
cd LiquidContainer && rtk swift test
```

## Project Structure

```
Koffee/
├── main.swift              # App entry point with AppDelegate
├── Models.swift           # Sensitivity enum, Dose, Beverage structs
├── CaffeineCalculator.swift # Core algorithm (research-based)
├── ConfigManager.swift    # Config persistence to ~/.config/koffee.json
├── BeverageManager.swift   # Load beverages from JSON
├── CaffeineMeterView.swift # Arc gauge meter
├── Design.swift          # UI constants and design tokens
├── beverages.json         # Beverage definitions

LiquidContainer/            # Liquid physics simulation package
├── Package.swift
├── Sources/LiquidContainer/
│   ├── LiquidContainer.swift         # Package entry point
│   ├── Configuration.swift            # Layer configs (espresso, latte, etc.)
│   ├── LiquidPhysicsConstants.swift # All physics tunable parameters
│   ├── Physics.swift                # LiquidPhysicsEngine core
│   ├── Views.swift                  # LiquidContainerView rendering
│   ├── Noise.swift                 # Simplex noise utilities (unused)
│   └── default_config.json         # Config schema
└── Tests/LiquidContainerTests/      # Unit tests
```

## LiquidContainer Physics

The liquid simulation uses a multi-layer model with realistic wave physics:

### Layer Configuration
- **Espresso**: crema (top), liquid, dense (bottom)
- Each layer has: `waveDamping`, `phaseDelay`, colors, bubble settings

### Physics Parameters (in LiquidPhysicsConstants.swift)
- `ambientMotionEnabled`: Keeps liquid "alive" with subtle vibrations
- `waveMaxAmplitudes`: [8.0, 6.0, 4.0] - max wave height per layer
- `waveDamping`: [0.97, 0.88, 0.78] - higher = waves last longer
- `phaseDelay`: [0.0, 0.15, 0.40] - delay between layer responses
- `sloshImpulseStrength`: 15.0 - strength when dose changes

### Methods
- `addSloshImpulse(direction:)`: Trigger sloshing animation

## UI Design

- Native macOS window with transparent titlebar
- Coffee-tinted glass backgrounds
- Orange accent color (#FF9800)
- Arc gauge meter for caffeine level
- Real-time updates on parameter changes
- Liquid fills based on caffeine-to-safe-limit ratio

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
