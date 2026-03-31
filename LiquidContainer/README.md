# LiquidContainer

A Swift package for realistic liquid slosh physics with dynamic gradient rendering and bubble effects.

## Features

- **Slosh Physics**: Realistic liquid movement with wave propagation, surface tilt, and displacement
- **Dynamic Gradients**: Color gradients that shift and swirl based on liquid motion
- **Bubble Effects**: Rising bubbles with realistic wobble and viscosity damping
- **Configurable**: Pre-built liquid presets (coffee, water, wine) or custom colors

## Usage

### Basic Usage

```swift
import LiquidContainer

struct MyView: View {
    @State private var physicsEngine = LiquidPhysicsEngine()
    @State private var fillLevel: CGFloat = 0.5

    var body: some View {
        LiquidView(
            fillLevel: fillLevel,
            configuration: .coffee,
            physicsEngine: physicsEngine
        )
    }
}
```

### Custom Configuration

```swift
let customConfig = LiquidContainerConfiguration(
    liquidColor: Color(red: 0.3, green: 0.6, blue: 0.9),
    liquidColorDark: Color(red: 0.05, green: 0.2, blue: 0.4),
    liquidColorMid: Color(red: 0.15, green: 0.35, blue: 0.6),
    liquidColorLight: Color(red: 0.4, green: 0.7, blue: 0.95),
    foamColor: .white.opacity(0.4),
    minFillRatio: 0.1,
    maxFillRatio: 1.2
)
```

### Physics Integration

```swift
// Apply acceleration when dragging
DragGesture()
    .onChanged { value in
        physicsEngine.containerAccelX += value.translation.width * 0.02
    }
```

## API Reference

### LiquidPhysicsEngine

The core physics simulation engine.

- `step(deltaTime:)`: Advance physics simulation
- `surfaceHeight(x:width:)`: Calculate wave height at position
- `surfaceAngle`: Current liquid surface angle
- `liquidDisplacement`: Horizontal liquid displacement
- `totalWaveAmplitude`: Combined wave amplitude

### LiquidContainerConfiguration

Preset configurations:

- `.coffee`: Warm brown coffee gradient
- `.water`: Cool blue water gradient
- `.wine`: Deep red wine gradient

### LiquidView / LiquidContainerView

SwiftUI views for rendering liquid:

- `fillLevel`: 0.0 to 1.0+ fill ratio
- `configuration`: Liquid color configuration
- `physicsEngine`: Shared physics engine
- `bubbleCount`: Number of bubble particles

### LiquidPhysics Constants

Tunable physics parameters:

- `accelerationDecay`: 0.88
- `tiltResponse`: 0.15
- `velocityDamping`: 0.985
- `springStrength`: 0.03
- `waveFrequency1/waveFrequency2`: Wave patterns
- `bubbleRiseFraction`: 0.8
- `bubbleViscosityCoeff`: 2.5

## License

MIT
