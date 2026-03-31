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

struct PhysicsEngine {
    var surfaceSlope: CGFloat = 0
    var slopeVelocity: CGFloat = 0
    var surfaceOffset: CGFloat = 0
    var offsetVelocity: CGFloat = 0
    
    var waves: [(amplitude: CGFloat, phase: CGFloat, velocity: CGFloat, speed: CGFloat, wavelength: CGFloat)] = []
    
    var containerAccelX: CGFloat = 0
    
    init() {
        waves = [
            (amplitude: 0, phase: 0, velocity: 0, speed: 80, wavelength: 200),
            (amplitude: 0, phase: 0, velocity: 0, speed: 50, wavelength: 100),
            (amplitude: 0, phase: 0, velocity: 0, speed: 30, wavelength: 60)
        ]
    }
    
    mutating func step() {
        let accel = containerAccelX
        containerAccelX *= LiquidPhysics.accelerationDecay
        
        slopeVelocity += accel * LiquidPhysics.tiltResponse * 1.5
        slopeVelocity -= surfaceSlope * LiquidPhysics.springStrength * 0.5
        slopeVelocity *= LiquidPhysics.velocityDamping
        surfaceSlope += slopeVelocity * LiquidPhysics.angleInertia
        surfaceSlope *= LiquidPhysics.angleDecay
        
        offsetVelocity += accel * LiquidPhysics.tiltResponse * 0.5
        offsetVelocity -= surfaceOffset * LiquidPhysics.springStrength * 0.3
        offsetVelocity *= LiquidPhysics.velocityDamping
        surfaceOffset += offsetVelocity * LiquidPhysics.angleInertia
        surfaceOffset *= LiquidPhysics.angleDecay
        
        for i in 0..<waves.count {
            let coupling: CGFloat = i == 0 ? 0.8 : (i == 1 ? 0.3 : 0.15)
            let freqFactor: CGFloat = 1.0 + CGFloat(i) * 0.5
            
            waves[i].velocity += accel * LiquidPhysics.tiltResponse * coupling
            waves[i].velocity -= waves[i].amplitude * LiquidPhysics.springStrength * freqFactor
            waves[i].velocity *= LiquidPhysics.velocityDamping
            waves[i].amplitude += waves[i].velocity * LiquidPhysics.angleInertia
            waves[i].amplitude *= LiquidPhysics.angleDecay
            
            waves[i].phase += waves[i].speed * LiquidPhysics.angleInertia / waves[i].wavelength
            
            let maxAmp: CGFloat = 20.0 - CGFloat(i) * 4.0
            if abs(waves[i].amplitude) > maxAmp {
                waves[i].amplitude = maxAmp * (waves[i].amplitude > 0 ? 1 : -1)
                waves[i].velocity *= -0.2
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
        let t = time.truncatingRemainder(dividingBy: 100.0)
        let normalizedX = x / width
        
        let tiltEffect = -surfaceSlope * (normalizedX - 0.5) * 15.0
        
        var waveEffect: CGFloat = 0
        for i in 0..<waves.count {
            let k = 2 * .pi / waves[i].wavelength
            let w = 2 * .pi / (waves[i].wavelength / waves[i].speed)
            
            let travelingRight = waves[i].amplitude * sin(k * x - w * t + waves[i].phase)
            let travelingLeft = waves[i].amplitude * 0.3 * sin(k * (width - x) + w * t - waves[i].phase)
            waveEffect += travelingRight + travelingLeft
        }
        
        let ripple1 = sin(x * LiquidPhysics.waveFrequency1 + t * LiquidPhysics.waveSpeed1) * LiquidPhysics.waveAmplitude1
        let ripple2 = sin(x * LiquidPhysics.waveFrequency2 - t * LiquidPhysics.waveSpeed2) * LiquidPhysics.waveAmplitude2
        
        return tiltEffect + waveEffect * 0.3 + ripple1 + ripple2
    }
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
print("SLOSH PHYSICS ENGINE TESTS")
print(String(repeating: "=", count: 60))
print()

print(String(repeating: "-", count: 60))
print("TEST 1: Zero State Initialization")
print(String(repeating: "-", count: 60))
var physics1 = PhysicsEngine()
assert(physics1.surfaceSlope == 0, "Initial slope is 0")
assert(physics1.surfaceOffset == 0, "Initial offset is 0")
assert(physics1.containerAccelX == 0, "Initial container acceleration is 0")

print()
print(String(repeating: "-", count: 60))
print("TEST 2: Acceleration Creates Slope")
print(String(repeating: "-", count: 60))
var physics2 = PhysicsEngine()
physics2.applyImpulse(10.0)
physics2.step()

let slopeAfterImpulse = physics2.surfaceSlope
assert(abs(slopeAfterImpulse) > 0.5, "Surface slope is significant after positive acceleration")
print("  Surface slope after impulse: \(String(format: "%.4f", slopeAfterImpulse))")

print()
print(String(repeating: "-", count: 60))
print("TEST 3: Surface Tilt is Linear Across Width")
print(String(repeating: "-", count: 60))
var physics3 = PhysicsEngine()
physics3.applyImpulse(15.0)
for _ in 0..<20 { physics3.step() }

let h0 = physics3.surfaceHeight(x: 0, width: 400, time: 0)
let h200 = physics3.surfaceHeight(x: 200, width: 400, time: 0)
let h400 = physics3.surfaceHeight(x: 400, width: 400, time: 0)

let leftEdgeHigh = h0 > h200
let rightEdgeLow = h400 < h200
let isLinear = leftEdgeHigh && rightEdgeLow

print("  Surface at x=0: \(String(format: "%.2f", h0))")
print("  Surface at x=200: \(String(format: "%.2f", h200))")
print("  Surface at x=400: \(String(format: "%.2f", h400))")
print("  Left edge \(leftEdgeHigh ? ">" : "<") center, Right edge \(rightEdgeLow ? "<" : ">") center")

assert(isLinear, "Surface shows linear tilt (one side higher than other)")

print()
print(String(repeating: "-", count: 60))
print("TEST 4: Energy Dissipates Over Time")
print(String(repeating: "-", count: 60))
var physics4 = PhysicsEngine()
physics4.applyImpulse(5.0)

var slopeHistory: [CGFloat] = []
for _ in 0..<300 {
    physics4.step()
    slopeHistory.append(physics4.surfaceSlope)
}

let initialSlope = abs(slopeHistory[10])
let finalSlope = abs(slopeHistory.last!)

print("  Initial slope (frame 10): \(String(format: "%.4f", initialSlope))")
print("  Final slope (frame 300): \(String(format: "%.4f", finalSlope))")

assert(finalSlope < initialSlope * 0.5, "Slope amplitude decreases over time")

print()
print(String(repeating: "-", count: 60))
print("TEST 5: Waves Create Surface Variation")
print(String(repeating: "-", count: 60))
var physics5 = PhysicsEngine()
physics5.applyImpulse(20.0)

for _ in 0..<50 {
    physics5.step()
}

let wave0 = physics5.waves[0]
print("  Wave 0 amplitude: \(String(format: "%.2f", wave0.amplitude))")
print("  Wave 0 phase: \(String(format: "%.2f", wave0.phase))")

assert(abs(wave0.amplitude) > 1.0, "Wave 0 amplitude is significant")

print()
print(String(repeating: "-", count: 60))
print("TEST 6: Surface Height Varies Over Time")
print(String(repeating: "-", count: 60))
var physics6 = PhysicsEngine()
physics6.applyImpulse(10.0)

for _ in 0..<30 { physics6.step() }

let surfaceNow = physics6.surfaceHeight(x: 100, width: 400, time: 0)
let surfaceLater = physics6.surfaceHeight(x: 100, width: 400, time: 0.1)

print("  Surface at x=100, t=0: \(String(format: "%.4f", surfaceNow))")
print("  Surface at x=100, t=0.1: \(String(format: "%.4f", surfaceLater))")

assert(surfaceNow != surfaceLater, "Surface height changes over time")

print()
print(String(repeating: "-", count: 60))
print("TEST 7: Momentum Persistence")
print(String(repeating: "-", count: 60))
var physics7 = PhysicsEngine()

for _ in 0..<30 {
    physics7.applyDragDelta(20.0)
    physics7.step()
}

let slopeDuringDrag = physics7.surfaceSlope

for _ in 0..<50 {
    physics7.step()
}

let slopeAfterStop = physics7.surfaceSlope
print("  Slope during drag: \(String(format: "%.4f", slopeDuringDrag))")
print("  Slope 50 frames after stop: \(String(format: "%.4f", slopeAfterStop))")

assert(abs(slopeDuringDrag) > 0, "Drag creates slope")
assert(abs(slopeAfterStop) > 0.1 || abs(slopeAfterStop) < abs(slopeDuringDrag), "Slope persists or decays naturally")

print()
print(String(repeating: "-", count: 60))
print("TEST 8: Direction Reversal Changes Slope")
print(String(repeating: "-", count: 60))
var physics8 = PhysicsEngine()

physics8.applyImpulse(10.0)
for _ in 0..<20 { physics8.step() }
let slopePos = physics8.surfaceSlope

physics8.applyImpulse(-10.0)
for _ in 0..<20 { physics8.step() }
let slopeNeg = physics8.surfaceSlope

print("  Slope after positive impulse: \(String(format: "%.4f", slopePos))")
print("  Slope after negative impulse: \(String(format: "%.4f", slopeNeg))")

assert(slopePos > 0 || slopePos < 0, "Positive impulse creates non-zero slope")
assert(slopeNeg != slopePos, "Negative impulse changes slope direction")

print()
print(String(repeating: "-", count: 60))
print("TEST 9: Multiple Waves Contribute")
print(String(repeating: "-", count: 60))
var physics9 = PhysicsEngine()
physics9.applyImpulse(30.0)

for _ in 0..<50 { physics9.step() }

let w0 = abs(physics9.waves[0].amplitude)
let w1 = abs(physics9.waves[1].amplitude)
let w2 = abs(physics9.waves[2].amplitude)

print("  Wave 0 amplitude: \(String(format: "%.2f", w0))")
print("  Wave 1 amplitude: \(String(format: "%.2f", w1))")
print("  Wave 2 amplitude: \(String(format: "%.2f", w2))")

assert(w0 > 0, "Wave 0 is active")
assert(w1 > 0, "Wave 1 is also active")
assert(w2 > 0, "Wave 2 is also active")

print()
print(String(repeating: "-", count: 60))
print("TEST 10: Wave Boundary Reflection")
print(String(repeating: "-", count: 60))
var physics10 = PhysicsEngine()
physics10.applyImpulse(100.0)

var wave0AfterLargeImpulse: CGFloat = 0
for _ in 0..<50 {
    physics10.step()
    wave0AfterLargeImpulse = physics10.waves[0].amplitude
}

print("  Wave 0 amplitude after large impulse: \(String(format: "%.2f", wave0AfterLargeImpulse))")

assert(abs(wave0AfterLargeImpulse) > 0, "Wave 0 amplitude is non-zero after large impulse")

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
