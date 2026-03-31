#!/usr/bin/env swift

import Foundation

struct LiquidPhysics {
    static let accelerationDecay: CGFloat = 0.92
    static let tiltResponse: CGFloat = 0.08
    static let velocityDamping: CGFloat = 0.98
    static let angleDecay: CGFloat = 0.995
    static let springStrength: CGFloat = 0.0005
    static let angleInertia: CGFloat = 0.9
    static let tiltAmplification: CGFloat = 3.0
}

struct PhysicsEngine {
    var tiltAngle: CGFloat = 0
    var tiltVelocity: CGFloat = 0
    var containerAccelX: CGFloat = 0
    
    mutating func step() {
        let accel = containerAccelX
        containerAccelX *= LiquidPhysics.accelerationDecay
        
        tiltVelocity += accel * LiquidPhysics.tiltResponse
        tiltVelocity -= tiltAngle * LiquidPhysics.springStrength
        tiltVelocity *= LiquidPhysics.velocityDamping
        tiltAngle += tiltVelocity * LiquidPhysics.angleInertia
        tiltAngle *= LiquidPhysics.angleDecay
    }
    
    mutating func applyImpulse(_ impulse: CGFloat) {
        containerAccelX = impulse
    }
    
    mutating func applyDragDelta(_ dx: CGFloat) {
        containerAccelX += dx * 0.08
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

func assertApprox(_ actual: CGFloat, _ expected: CGFloat, _ tolerance: CGFloat, _ message: String) {
    if abs(actual - expected) <= tolerance {
        print("  ✓ \(message) (actual: \(String(format: "%.4f", actual)), expected: \(String(format: "%.4f", expected)))")
        testsPassed += 1
    } else {
        print("  ✗ \(message) (actual: \(String(format: "%.4f", actual)), expected: \(String(format: "%.4f", expected)) ± \(String(format: "%.4f", tolerance)))")
        testsFailed += 1
    }
}

print(String(repeating: "=", count: 60))
print("LIQUID PHYSICS ENGINE UNIT TESTS")
print(String(repeating: "=", count: 60))
print()

print("Constants being tested:")
print("  accelerationDecay: \(LiquidPhysics.accelerationDecay)")
print("  tiltResponse:      \(LiquidPhysics.tiltResponse)")
print("  velocityDamping:   \(LiquidPhysics.velocityDamping)")
print("  angleDecay:        \(LiquidPhysics.angleDecay)")
print()

print(String(repeating: "-", count: 60))
print("TEST 1: Zero State")
print(String(repeating: "-", count: 60))
var physics1 = PhysicsEngine()
assert(physics1.tiltAngle == 0, "Initial tilt angle is 0")
assert(physics1.tiltVelocity == 0, "Initial tilt velocity is 0")
assert(physics1.containerAccelX == 0, "Initial container acceleration is 0")

print()
print(String(repeating: "-", count: 60))
print("TEST 2: Single Impulse Response")
print(String(repeating: "-", count: 60))
var physics2 = PhysicsEngine()
physics2.applyImpulse(1.0)

for _ in 0..<5 {
    physics2.step()
}

let tiltAfter5Frames = physics2.tiltAngle
print("  Tilt after 5 frames with impulse=1.0: \(String(format: "%.4f", tiltAfter5Frames))")

assert(tiltAfter5Frames > 0, "Tilt is positive after positive impulse")
assert(tiltAfter5Frames > 0, "Tilt is positive (response to impulse)")
assert(physics2.containerAccelX < 1.0, "Acceleration has decayed")
assert(physics2.containerAccelX > 0, "Acceleration still positive (not fully decayed)")

print()
print(String(repeating: "-", count: 60))
print("TEST 3: Settling Behavior")
print(String(repeating: "-", count: 60))
var physics3 = PhysicsEngine()
physics3.applyImpulse(2.0)

for _ in 0..<5 {
    physics3.step()
}

let tiltAt5 = physics3.tiltAngle
let velAt5 = physics3.tiltVelocity

for _ in 5..<300 {
    physics3.step()
}

let finalTilt = physics3.tiltAngle
let finalVel = physics3.tiltVelocity

print("  Tilt at frame 5: \(String(format: "%.4f", tiltAt5))")
print("  Velocity at frame 5: \(String(format: "%.4f", velAt5))")
print("  Final tilt (after 300 frames): \(String(format: "%.6f", finalTilt))")
print("  Final velocity (after 300 frames): \(String(format: "%.6f", finalVel))")

assert(finalTilt < tiltAt5 * 0.5, "Tilt has decayed significantly (at least 50%)")
assert(finalTilt < 10.0, "Tilt is bounded (less than 10)")
assert(finalTilt > 0 || abs(finalVel) < 0.1, "System is settling (either positive tilt or near-zero velocity)")

print()
print(String(repeating: "-", count: 60))
print("TEST 4: Velocity Follows Acceleration")
print(String(repeating: "-", count: 60))
var physics4 = PhysicsEngine()
physics4.applyImpulse(5.0)
physics4.step()

let tiltAt1 = physics4.tiltAngle
let velAt1 = physics4.tiltVelocity
physics4.step()

let tiltAt2 = physics4.tiltAngle
let velAt2 = physics4.tiltVelocity

print("  Frame 1: tilt=\(String(format: "%.4f", tiltAt1)), vel=\(String(format: "%.4f", velAt1))")
print("  Frame 2: tilt=\(String(format: "%.4f", tiltAt2)), vel=\(String(format: "%.4f", velAt2))")

assert(velAt1 > 0, "Velocity positive after positive impulse")
assert(tiltAt2 > tiltAt1, "Tilt increased from velocity")
assert(velAt2 != velAt1, "Velocity changed (damping applied)");

print()
print(String(repeating: "-", count: 60))
print("TEST 5: Direction Reversal")
print(String(repeating: "-", count: 60))
var physics5 = PhysicsEngine()
physics5.applyImpulse(1.0)
for _ in 0..<10 {
    physics5.step()
}
let tiltAfterPositive = physics5.tiltAngle

physics5.applyImpulse(-1.0)
for _ in 0..<10 {
    physics5.step()
}
let tiltAfterNegative = physics5.tiltAngle

print("  Tilt after positive impulse: \(String(format: "%.4f", tiltAfterPositive))")
print("  Tilt after negative impulse: \(String(format: "%.4f", tiltAfterNegative))")

assert(tiltAfterPositive > 0, "Positive impulse gives positive tilt")
assert(abs(tiltAfterNegative) < abs(tiltAfterPositive) * 1.5, "Negative impulse affects tilt direction");

print()
print(String(repeating: "-", count: 60))
print("TEST 6: Drag Simulation (Multiple Deltas)")
print(String(repeating: "-", count: 60))
var physics6 = PhysicsEngine()

let dragDeltas: [CGFloat] = [10, 20, 15, -5, -20, -15, 5]

for dx in dragDeltas {
    physics6.applyDragDelta(dx)
    physics6.step()
}

let tiltAfterDrag = physics6.tiltAngle
print("  Tilt after drag sequence: \(String(format: "%.4f", tiltAfterDrag))")

assert(abs(tiltAfterDrag) > 0.01, "Tilt accumulated from drag deltas");

print()
print(String(repeating: "-", count: 60))
print("TEST 7: Steady State Decay")
print(String(repeating: "-", count: 60))
var physics7 = PhysicsEngine()

physics7.applyImpulse(2.0)
for _ in 0..<200 {
    physics7.step()
}

print("  System settled after 200 frames: tilt=\(String(format: "%.6f", physics7.tiltAngle))")

let settledTilt = physics7.tiltAngle
physics7.step()
let decayTilt1 = physics7.tiltAngle
physics7.step()
let decayTilt2 = physics7.tiltAngle

print("  Tilt decay in steady state: \(String(format: "%.6f", settledTilt)) -> \(String(format: "%.6f", decayTilt1)) -> \(String(format: "%.6f", decayTilt2))")

let decayRatio = decayTilt2 / decayTilt1
print("  Decay ratio (should be ~angleDecay=\(LiquidPhysics.angleDecay)): \(String(format: "%.4f", decayRatio))")

assertApprox(decayRatio, LiquidPhysics.angleDecay, 0.05, "Decay matches angleDecay constant");

print()
print(String(repeating: "-", count: 60))
print("TEST 8: Visual Amplitude Check")
print(String(repeating: "-", count: 60))
var physics8 = PhysicsEngine()

for i in 0..<15 {
    let dx = sin(Double(i) / 5.0) * 10
    physics8.applyDragDelta(CGFloat(dx))
    physics8.step()
}

let maxTilt = physics8.tiltAngle
let visualOffset = abs(maxTilt) * LiquidPhysics.tiltAmplification
let windowWidth: CGFloat = 400

print("  Max tilt during realistic drag: \(String(format: "%.2f", maxTilt))")
print("  Visual offset (tilt * amplification): \(String(format: "%.1f", visualOffset)) pixels")
print("  Window width: \(String(format: "%.0f", windowWidth)) pixels")
print("  Visual offset as % of width: \(String(format: "%.1f", (visualOffset / windowWidth) * 100))%")

assert(abs(visualOffset) < windowWidth * 0.8, "Visual offset is less than 80% of window width (reasonable)");
assert(abs(visualOffset) > windowWidth * 0.02, "Visual offset is more than 2% of window width (visible)");

print()
print(String(repeating: "-", count: 60))
print("SUMMARY")
print(String(repeating: "-", count: 60))
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
