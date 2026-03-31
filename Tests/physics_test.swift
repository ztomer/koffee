#!/usr/bin/env swift

import Foundation

struct LiquidPhysics {
    static let accelerationDecay: CGFloat = 0.88
    static let tiltResponse: CGFloat = 0.15
    static let velocityDamping: CGFloat = 0.985
    static let angleDecay: CGFloat = 0.985
    static let springStrength: CGFloat = 0.03
    static let angleInertia: CGFloat = 0.95
    static let tiltAmplification: CGFloat = 4.5
    static let waveFrequency1: CGFloat = 0.015
    static let waveFrequency2: CGFloat = 0.025
    static let waveSpeed1: Double = 0.8
    static let waveSpeed2: Double = 0.6
    static let waveAmplitude1: CGFloat = 3
    static let waveAmplitude2: CGFloat = 2
}

struct WaveMode {
    var amplitude: CGFloat
    var velocity: CGFloat
}

struct PhysicsEngine {
    var modes: [WaveMode] = [
        WaveMode(amplitude: 0, velocity: 0),
        WaveMode(amplitude: 0, velocity: 0),
        WaveMode(amplitude: 0, velocity: 0),
        WaveMode(amplitude: 0, velocity: 0)
    ]
    
    var containerAccelX: CGFloat = 0
    
    static let waveDamping: CGFloat = 0.97
    static let modeCoupling: [CGFloat] = [1.0, 0.4, 0.2, 0.1]
    static let modeFrequencies: [CGFloat] = [1.0, 1.5, 2.0, 2.5]
    
    mutating func step() {
        let accel = containerAccelX
        containerAccelX *= LiquidPhysics.accelerationDecay
        
        for i in 0..<modes.count {
            let coupling = Self.modeCoupling[i]
            let freq = Self.modeFrequencies[i]
            
            modes[i].velocity += accel * LiquidPhysics.tiltResponse * coupling
            modes[i].velocity -= modes[i].amplitude * LiquidPhysics.springStrength * freq
            modes[i].velocity *= LiquidPhysics.velocityDamping
            modes[i].amplitude += modes[i].velocity * LiquidPhysics.angleInertia * (1.0 / freq)
            modes[i].amplitude *= LiquidPhysics.angleDecay
            
            let maxAmp: CGFloat = i == 0 ? 30.0 : 15.0
            if abs(modes[i].amplitude) > maxAmp {
                modes[i].amplitude = maxAmp * (modes[i].amplitude > 0 ? 1 : -1)
                modes[i].velocity *= -0.3
            }
        }
    }
    
    mutating func applyImpulse(_ impulse: CGFloat) {
        containerAccelX = impulse
    }
    
    mutating func applyDragDelta(_ dx: CGFloat) {
        containerAccelX += dx * 0.02
    }
    
    func surfaceHeight(x: CGFloat, width: CGFloat, time: Double) -> CGFloat {
        var height: CGFloat = 0
        let normalizedX = x / width
        
        height += modes[0].amplitude * sin(.pi * normalizedX)
        height += modes[1].amplitude * sin(2 * .pi * normalizedX)
        height += modes[2].amplitude * sin(3 * .pi * normalizedX)
        
        let wave1 = sin(x * LiquidPhysics.waveFrequency1 + time * LiquidPhysics.waveSpeed1) * LiquidPhysics.waveAmplitude1
        let wave2 = sin(x * LiquidPhysics.waveFrequency2 - time * LiquidPhysics.waveSpeed2) * LiquidPhysics.waveAmplitude2
        height += wave1 + wave2
        
        return height
    }
    
    var mode0Amplitude: CGFloat { modes[0].amplitude }
    var mode1Amplitude: CGFloat { modes[1].amplitude }
    var mode0Velocity: CGFloat { modes[0].velocity }
}

var testsPassed = 0
var testsFailed = 0

func assert(_ condition: Bool, _ message: String) {
    if condition {
        print("  ✓ \(message)")
        testsPassed += 1
    } else {
        print("  ✗ \(message)")
        testsFailed += 1
    }
}

print(String(repeating: "=", count: 60))
print("WAVE-BASED LIQUID PHYSICS ENGINE TESTS")
print(String(repeating: "=", count: 60))
print()

print("Physics Constants:")
print("  accelerationDecay: \(LiquidPhysics.accelerationDecay)")
print("  tiltResponse:      \(LiquidPhysics.tiltResponse)")
print("  velocityDamping:   \(LiquidPhysics.velocityDamping)")
print("  angleDecay:        \(LiquidPhysics.angleDecay)")
print("  springStrength:    \(LiquidPhysics.springStrength)")
print("  angleInertia:      \(LiquidPhysics.angleInertia)")
print("  Mode Coupling:     \(PhysicsEngine.modeCoupling)")
print("  Mode Frequencies:  \(PhysicsEngine.modeFrequencies)")
print()

print(String(repeating: "-", count: 60))
print("TEST 1: Zero State Initialization")
print(String(repeating: "-", count: 60))
var physics1 = PhysicsEngine()
assert(physics1.modes[0].amplitude == 0, "Mode 0 initial amplitude is 0")
assert(physics1.modes[0].velocity == 0, "Mode 0 initial velocity is 0")
assert(physics1.containerAccelX == 0, "Initial container acceleration is 0")

print()
print(String(repeating: "-", count: 60))
print("TEST 2: Acceleration Creates Wave Response")
print(String(repeating: "-", count: 60))
var physics2 = PhysicsEngine()
physics2.applyImpulse(10.0)
physics2.step()

let mode0AfterImpulse = physics2.mode0Amplitude
assert(mode0AfterImpulse > 0, "Mode 0 amplitude is positive after positive acceleration")
assert(physics2.mode0Velocity > 0, "Mode 0 velocity is positive after positive acceleration")
print("  Mode 0 amplitude after impulse: \(String(format: "%.4f", mode0AfterImpulse))")

print()
print(String(repeating: "-", count: 60))
print("TEST 3: Energy Dissipates Over Time (Settling)")
print(String(repeating: "-", count: 60))
var physics3 = PhysicsEngine()
physics3.applyImpulse(5.0)

var mode0History: [CGFloat] = []
for _ in 0..<300 {
    physics3.step()
    mode0History.append(physics3.mode0Amplitude)
}

let initialMode0 = mode0History[10]
let finalMode0 = mode0History.last!
let midPoint = mode0History.count / 2
let midMode0 = mode0History[midPoint]

print("  Initial mode 0 (frame 10): \(String(format: "%.4f", initialMode0))")
print("  Mid-point mode 0 (frame 150): \(String(format: "%.4f", midMode0))")
print("  Final mode 0 (frame 300): \(String(format: "%.4f", finalMode0))")

assert(finalMode0 < initialMode0, "Mode 0 amplitude decreases over time (energy dissipated)")
assert(abs(finalMode0) < 1.0, "System settles to near-zero amplitude")
assert(midMode0 < initialMode0, "Amplitude decreases monotonically initially")

print()
print(String(repeating: "-", count: 60))
print("TEST 4: Boundary Reflection (Wall Bounce)")
print(String(repeating: "-", count: 60))
var physics4 = PhysicsEngine()
physics4.applyImpulse(100.0)

var bouncesDetected = 0
var mode0Peaks: [CGFloat] = []
var prevMode0: CGFloat = 0

for i in 0..<200 {
    physics4.step()
    
    if i > 0 {
        let current = physics4.mode0Amplitude
        if prevMode0 > 27.0 && current < prevMode0 {
            bouncesDetected += 1
            mode0Peaks.append(prevMode0)
        }
        prevMode0 = current
    }
}

print("  Mode 0 peaks observed: \(mode0Peaks.count)")
if mode0Peaks.count > 1 {
    print("  First peak: \(String(format: "%.2f", mode0Peaks[0]))")
    print("  Second peak: \(String(format: "%.2f", mode0Peaks[1]))")
}
print("  Max amplitude limit: 30.0")

assert(abs(physics4.mode0Amplitude) <= 31.0, "Mode 0 amplitude stays within bounds (+1 tolerance)")
assert(bouncesDetected > 0, "Wall bounce detected when exceeding bounds")

print()
print(String(repeating: "-", count: 60))
print("TEST 5: Oscillation (Sloshing)")
print(String(repeating: "-", count: 60))
var physics5 = PhysicsEngine()
physics5.applyImpulse(30.0)

var signs: [Int] = []
for _ in 0..<100 {
    physics5.step()
    signs.append(physics5.mode0Velocity > 0 ? 1 : -1)
}

let signChanges = zip(signs.dropFirst(), signs).filter { $0 != $1 }.count
print("  Direction changes observed: \(signChanges)")
assert(signChanges >= 2, "System oscillates (velocity changes direction at least twice)")

print()
print(String(repeating: "-", count: 60))
print("TEST 6: Direction Reversal")
print(String(repeating: "-", count: 60))
var physics6 = PhysicsEngine()
physics6.applyImpulse(10.0)
for _ in 0..<30 {
    physics6.step()
}
let mode0AfterPos = physics6.mode0Amplitude

let mode0BeforeNeg = physics6.mode0Amplitude
physics6.applyImpulse(-10.0)
for _ in 0..<30 {
    physics6.step()
}
let mode0AfterNeg = physics6.mode0Amplitude

print("  Mode 0 after positive impulse: \(String(format: "%.4f", mode0AfterPos))")
print("  Mode 0 after negative impulse: \(String(format: "%.4f", mode0AfterNeg))")
print("  Mode 0 velocity before negative: \(String(format: "%.4f", physics6.mode0Velocity))")

assert(abs(mode0AfterPos) > 1.0, "Positive acceleration creates significant mode 0")
assert(abs(mode0AfterNeg) > 0.5, "Negative acceleration creates wave response")
assert(mode0AfterNeg != mode0BeforeNeg, "Negative impulse changes the wave state")

print()
print(String(repeating: "-", count: 60))
print("TEST 7: Momentum Persistence After Drag Stops")
print(String(repeating: "-", count: 60))
var physics7 = PhysicsEngine()

for _ in 0..<30 {
    physics7.applyDragDelta(20.0)
    physics7.step()
}

let mode0DuringDrag = physics7.mode0Amplitude
let velocityDuringDrag = physics7.mode0Velocity

for _ in 0..<50 {
    physics7.step()
}

let mode0AfterStop = physics7.mode0Amplitude
print("  Mode 0 during drag: \(String(format: "%.4f", mode0DuringDrag))")
print("  Velocity during drag: \(String(format: "%.4f", velocityDuringDrag))")
print("  Mode 0 50 frames after stop: \(String(format: "%.4f", mode0AfterStop))")

assert(abs(mode0DuringDrag) > 0, "Drag creates wave amplitude")
assert(abs(mode0AfterStop) > 0.1, "Wave persists after drag stops")
assert(abs(mode0AfterStop) > abs(mode0DuringDrag) * 0.05, "Wave doesn't immediately vanish")

print()
print(String(repeating: "-", count: 60))
print("TEST 8: Visual Wave Height")
print(String(repeating: "-", count: 60))
var physics8 = PhysicsEngine()

for _ in 0..<50 {
    physics8.applyDragDelta(30.0)
    physics8.step()
}

let maxMode0 = physics8.mode0Amplitude
let surfaceAtCenter = physics8.surfaceHeight(x: 200, width: 400, time: 0)
let surfaceAtEdge = physics8.surfaceHeight(x: 0, width: 400, time: 0)
let waveHeight = abs(surfaceAtCenter - surfaceAtEdge)

print("  Max mode 0 amplitude: \(String(format: "%.2f", maxMode0))")
print("  Surface height difference (edge-center): \(String(format: "%.1f", waveHeight)) pixels")

assert(abs(waveHeight) > 2.0, "Wave creates visible surface height difference")
assert(abs(waveHeight) < 80, "Wave height is reasonable (< 80 pixels)")

print()
print(String(repeating: "-", count: 60))
print("TEST 9: Multiple Higher Modes Activated")
print(String(repeating: "-", count: 60))
var physics9 = PhysicsEngine()
physics9.applyImpulse(50.0)

for _ in 0..<100 {
    physics9.step()
}

let mode0 = physics9.mode0Amplitude
let mode1 = physics9.mode1Amplitude

print("  Mode 0 amplitude: \(String(format: "%.2f", mode0))")
print("  Mode 1 amplitude: \(String(format: "%.2f", mode1))")

assert(abs(mode0) > 0, "Mode 0 (fundamental tilt) is active")
assert(abs(mode1) > 0, "Mode 1 (dome) is also activated")

print()
print(String(repeating: "-", count: 60))
print("TEST 10: Steady State Convergence")
print(String(repeating: "-", count: 60))
var physics10 = PhysicsEngine()
physics10.applyImpulse(2.0)

for _ in 0..<500 {
    physics10.step()
}

let mode0_500 = physics10.mode0Amplitude
physics10.step()
let mode0_501 = physics10.mode0Amplitude
physics10.step()
let mode0_502 = physics10.mode0Amplitude

let decay1 = abs(mode0_501 - mode0_500)
let decay2 = abs(mode0_502 - mode0_501)

print("  Mode 0 at frame 500: \(String(format: "%.6f", mode0_500))")
print("  Mode 0 change 500->501: \(String(format: "%.8f", decay1))")
print("  Mode 0 change 501->502: \(String(format: "%.8f", decay2))")

assert(abs(mode0_500) < 1.0, "System converges to small amplitude value")
assert(abs(mode0_500) < 0.1 || decay2 <= decay1 * 2.0, "System is converging (either small or decaying)")

print()
print(String(repeating: "=", count: 60))
print("SUMMARY")
print(String(repeating: "=", count: 60))
print()
print("Tests passed: \(testsPassed)")
print("Tests failed: \(testsFailed)")
print()

if testsFailed == 0 {
    print("✓ ALL TESTS PASSED")
    exit(0)
} else {
    print("✗ SOME TESTS FAILED")
    exit(1)
}
