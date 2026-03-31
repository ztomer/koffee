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

struct WaveState {
    var amplitude: CGFloat
    var phase: CGFloat
    var velocity: CGFloat
}

struct PhysicsEngine {
    var surfaceAngle: CGFloat = 0
    var angleVelocity: CGFloat = 0
    
    var liquidDisplacement: CGFloat = 0
    var displacementVelocity: CGFloat = 0
    
    var waves: [WaveState] = []
    
    var containerAccelX: CGFloat = 0
    var containerVelocityX: CGFloat = 0
    
    init() {
        waves = [
            WaveState(amplitude: 0, phase: 0, velocity: 0),
            WaveState(amplitude: 0, phase: 0, velocity: 0),
            WaveState(amplitude: 0, phase: 0, velocity: 0)
        ]
    }
    
    mutating func step() {
        let accel = containerAccelX
        containerAccelX *= LiquidPhysics.accelerationDecay
        
        containerVelocityX += accel * 0.5
        containerVelocityX *= 0.98
        
        angleVelocity += accel * LiquidPhysics.tiltResponse * 2.0
        angleVelocity -= surfaceAngle * LiquidPhysics.springStrength * 0.8
        angleVelocity *= LiquidPhysics.velocityDamping
        surfaceAngle += angleVelocity * LiquidPhysics.angleInertia
        surfaceAngle *= LiquidPhysics.angleDecay
        
        displacementVelocity += containerVelocityX * 0.003
        displacementVelocity -= liquidDisplacement * LiquidPhysics.springStrength * 0.3
        displacementVelocity *= LiquidPhysics.velocityDamping
        liquidDisplacement += displacementVelocity * LiquidPhysics.angleInertia
        liquidDisplacement *= LiquidPhysics.angleDecay
        
        for i in 0..<waves.count {
            let coupling: CGFloat = i == 0 ? 0.5 : (i == 1 ? 0.2 : 0.1)
            
            waves[i].velocity += accel * LiquidPhysics.tiltResponse * coupling
            waves[i].velocity -= waves[i].amplitude * LiquidPhysics.springStrength
            waves[i].velocity *= LiquidPhysics.velocityDamping
            waves[i].amplitude += waves[i].velocity * LiquidPhysics.angleInertia
            waves[i].amplitude *= LiquidPhysics.angleDecay
            
            let phaseSpeed: CGFloat = i == 0 ? 3.0 : (i == 1 ? 4.5 : 6.0)
            waves[i].phase += phaseSpeed
            if waves[i].phase > .pi * 2 { waves[i].phase -= .pi * 2 }
            if waves[i].phase < -.pi * 2 { waves[i].phase += .pi * 2 }
            
            let maxAmp: CGFloat = 15.0 - CGFloat(i) * 3.0
            if abs(waves[i].amplitude) > maxAmp {
                waves[i].amplitude = maxAmp * (waves[i].amplitude > 0 ? 1 : -1)
                waves[i].velocity *= -0.3
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
        let normalizedX = (x / width - 0.5) * 2
        
        let angleEffect = -surfaceAngle * normalizedX * 2.0
        
        let displacementEffect = liquidDisplacement * (normalizedX * 0.5 + 0.5) * 1.5
        
        var waveEffect: CGFloat = 0
        let waveFreqs: [CGFloat] = [0.03, 0.05, 0.07]
        let waveSpeeds: [Double] = [1.2, 1.8, 2.4]
        
        for i in 0..<waves.count {
            let wave = sin(x * waveFreqs[i] + t * waveSpeeds[i] + waves[i].phase) * waves[i].amplitude * 0.15
            waveEffect += wave
        }
        
        let ripple1 = sin(x * LiquidPhysics.waveFrequency1 + t * LiquidPhysics.waveSpeed1) * LiquidPhysics.waveAmplitude1 * 0.5
        let ripple2 = sin(x * LiquidPhysics.waveFrequency2 - t * LiquidPhysics.waveSpeed2) * LiquidPhysics.waveAmplitude2 * 0.5
        
        return angleEffect + displacementEffect + waveEffect + ripple1 + ripple2
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
print("LIQUID SLOSH PHYSICS ENGINE TESTS")
print(String(repeating: "=", count: 60))
print()

print(String(repeating: "-", count: 60))
print("TEST 1: Zero State Initialization")
print(String(repeating: "-", count: 60))
var physics1 = PhysicsEngine()
assert(physics1.surfaceAngle == 0, "Initial surface angle is 0")
assert(physics1.liquidDisplacement == 0, "Initial liquid displacement is 0")
assert(physics1.containerAccelX == 0, "Initial container acceleration is 0")

print()
print(String(repeating: "-", count: 60))
print("TEST 2: Acceleration Creates Surface Angle")
print(String(repeating: "-", count: 60))
var physics2 = PhysicsEngine()
physics2.applyImpulse(10.0)
physics2.step()

let angleAfterImpulse = physics2.surfaceAngle
assert(abs(angleAfterImpulse) > 0.5, "Surface angle is significant after positive acceleration")
print("  Surface angle after impulse: \(String(format: "%.4f", angleAfterImpulse))")

print()
print(String(repeating: "-", count: 60))
print("TEST 3: Surface Tilts - Left Side Rises on Rightward Acceleration")
print(String(repeating: "-", count: 60))
var physics3 = PhysicsEngine()
physics3.applyImpulse(15.0)
for _ in 0..<20 { physics3.step() }

let h0 = physics3.surfaceHeight(x: 0, width: 400, time: 0)
let h200 = physics3.surfaceHeight(x: 200, width: 400, time: 0)
let h400 = physics3.surfaceHeight(x: 400, width: 400, time: 0)

print("  Surface at x=0 (left): \(String(format: "%.2f", h0))")
print("  Surface at x=200 (center): \(String(format: "%.2f", h200))")
print("  Surface at x=400 (right): \(String(format: "%.2f", h400))")

let leftSideHigher = h0 > h400
print("  Left side \(leftSideHigher ? ">" : "<") right side")

assert(leftSideHigher, "Left side rises when accelerating right (trailing edge effect)")

print()
print(String(repeating: "-", count: 60))
print("TEST 4: Energy Dissipates Over Time")
print(String(repeating: "-", count: 60))
var physics4 = PhysicsEngine()
physics4.applyImpulse(5.0)

var angleHistory: [CGFloat] = []
for _ in 0..<300 {
    physics4.step()
    angleHistory.append(physics4.surfaceAngle)
}

let initialAngle = abs(angleHistory[10])
let finalAngle = abs(angleHistory.last!)

print("  Initial angle (frame 10): \(String(format: "%.4f", initialAngle))")
print("  Final angle (frame 300): \(String(format: "%.4f", finalAngle))")

assert(finalAngle < initialAngle * 0.5, "Surface angle decreases over time")

print()
print(String(repeating: "-", count: 60))
print("TEST 5: Liquid Displacement Tracks Velocity")
print(String(repeating: "-", count: 60))
var physics5 = PhysicsEngine()
physics5.applyImpulse(10.0)
for _ in 0..<30 { physics5.step() }

let displacement = physics5.liquidDisplacement
let velocity = physics5.containerVelocityX

print("  Container velocity: \(String(format: "%.4f", velocity))")
print("  Liquid displacement: \(String(format: "%.4f", displacement))")

assert(abs(displacement) > 0, "Liquid displacement is non-zero after acceleration")

print()
print(String(repeating: "-", count: 60))
print("TEST 6: Surface Height Changes Over Time (Wave Motion)")
print(String(repeating: "-", count: 60))
var physics6 = PhysicsEngine()
physics6.applyImpulse(10.0)
for _ in 0..<30 { physics6.step() }

let surfaceNow = physics6.surfaceHeight(x: 100, width: 400, time: 0)
let surfaceLater = physics6.surfaceHeight(x: 100, width: 400, time: 0.1)

print("  Surface at x=100, t=0: \(String(format: "%.4f", surfaceNow))")
print("  Surface at x=100, t=0.1: \(String(format: "%.4f", surfaceLater))")

assert(surfaceNow != surfaceLater, "Surface height changes over time (waves moving)")

print()
print(String(repeating: "-", count: 60))
print("TEST 7: Momentum Persistence - Liquid Continues After Stop")
print(String(repeating: "-", count: 60))
var physics7 = PhysicsEngine()

for _ in 0..<30 {
    physics7.applyDragDelta(20.0)
    physics7.step()
}

let displacementDuringDrag = physics7.liquidDisplacement

for _ in 0..<50 {
    physics7.step()
}

let displacementAfterStop = physics7.liquidDisplacement
print("  Displacement during drag: \(String(format: "%.4f", displacementDuringDrag))")
print("  Displacement 50 frames after stop: \(String(format: "%.4f", displacementAfterStop))")

assert(abs(displacementDuringDrag) > 0, "Drag creates liquid displacement")
assert(abs(displacementAfterStop) > 0.1, "Liquid displacement persists after drag stops")

print()
print(String(repeating: "-", count: 60))
print("TEST 8: Direction Reversal Changes Surface Shape")
print(String(repeating: "-", count: 60))
var physics8 = PhysicsEngine()

physics8.applyImpulse(10.0)
for _ in 0..<20 { physics8.step() }
let h0Pos = physics8.surfaceHeight(x: 0, width: 400, time: 0)

physics8.applyImpulse(-10.0)
for _ in 0..<20 { physics8.step() }
let h0Neg = physics8.surfaceHeight(x: 0, width: 400, time: 0)

print("  Left surface after positive impulse: \(String(format: "%.4f", h0Pos))")
print("  Left surface after negative impulse: \(String(format: "%.4f", h0Neg))")

assert(h0Pos != h0Neg, "Surface shape changes when direction reverses")

print()
print(String(repeating: "-", count: 60))
print("TEST 9: Multiple Wave Modes Active")
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
print("TEST 10: Asymmetric Surface - Leading vs Trailing Edge")
print(String(repeating: "-", count: 60))
var physics10 = PhysicsEngine()
physics10.applyImpulse(20.0)
for _ in 0..<40 { physics10.step() }

let leadingEdge = physics10.surfaceHeight(x: 400, width: 400, time: 0)
let trailingEdge = physics10.surfaceHeight(x: 0, width: 400, time: 0)
let difference = abs(leadingEdge - trailingEdge)

print("  Trailing edge (left): \(String(format: "%.2f", trailingEdge))")
print("  Leading edge (right): \(String(format: "%.2f", leadingEdge))")
print("  Edge difference: \(String(format: "%.2f", difference))")

assert(difference > 0.5, "Surface has asymmetric height between edges")

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
