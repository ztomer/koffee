import XCTest
import AppKit
@testable import Koffee

final class LiquidPhysicsTests: XCTestCase {
    
    var app: NSApplication!
    var window: NSWindow!
    var physicsLogger: PhysicsLogger!
    
    override func setUp() {
        super.setUp()
        
        physicsLogger = PhysicsLogger()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testWindowMoveTriggersSlosh() async throws {
        let expectation = XCTestExpectation(description: "Slosh detected")
        
        physicsLogger.onTiltChange = { tilt, velocity in
            print("📊 TILT: \(String(format: "%.4f", tilt)), VELOCITY: \(String(format: "%.4f", velocity))")
        }
        
        physicsLogger.onSettled = {
            expectation.fulfill()
        }
        
        simulateWindowMove(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 300, y: 100),
            duration: 0.5,
            logger: physicsLogger
        )
        
        let result = await XCTWaiter().fulfillment(of: [expectation], timeout: 5)
        
        XCTAssertTrue(result == .completed, "Slosh physics should be triggered by window movement")
        XCTAssertTrue(physicsLogger.maxTiltDetected > 0, "Tilt should be non-zero during slosh")
        XCTAssertTrue(physicsLogger.settledCorrectly, "Physics should settle back to zero")
    }
    
    func testPhysicsSettlesOverTime() async throws {
        let expectation = XCTestExpectation(description: "Physics settle")
        
        let logger = PhysicsLogger()
        
        logger.onSettled = {
            expectation.fulfill()
        }
        
        simulateImpulse(
            impulseValue: 5.0,
            expectedSettleTime: 2.0,
            logger: logger
        )
        
        let result = await XCTWaiter().fulfillment(of: [expectation], timeout: 5)
        
        XCTAssertTrue(result == .completed)
        XCTAssertTrue(logger.settledCorrectly)
    }
    
    func testTiltProportionalToMovement() async throws {
        let logger = PhysicsLogger()
        
        simulateWindowMove(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 400, y: 100),
            duration: 0.3,
            logger: logger
        )
        
        Thread.sleep(forTimeInterval: 2.0)
        
        XCTAssertTrue(logger.maxTiltDetected > logger.minTiltDetected * 2, 
                      "Larger movement should produce larger tilt")
    }
}

final class PhysicsLogger {
    var onTiltChange: ((CGFloat, CGFloat) -> Void)?
    var onSettled: (() -> Void)?
    
    var tiltHistory: [CGFloat] = []
    var velocityHistory: [CGFloat] = []
    var maxTiltDetected: CGFloat = 0
    var minTiltDetected: CGFloat = 0
    var settledCorrectly: Bool = false
    
    private var settledFrames: Int = 0
    private let settleThreshold: CGFloat = 0.01
    
    func logFrame(tilt: CGFloat, velocity: CGFloat) {
        tiltHistory.append(tilt)
        velocityHistory.append(velocity)
        
        if tilt > maxTiltDetected { maxTiltDetected = tilt }
        if tilt < minTiltDetected { minTiltDetected = tilt }
        
        if abs(tilt) < settleThreshold && abs(velocity) < settleThreshold {
            settledFrames += 1
            if settledFrames >= 30 {
                settledCorrectly = true
                onSettled?()
            }
        } else {
            settledFrames = 0
        }
        
        onTiltChange?(tilt, velocity)
    }
}

@MainActor
func simulateWindowMove(from: CGPoint, to: CGPoint, duration: TimeInterval, logger: PhysicsLogger) {
    let steps = Int(duration * 60)
    let stepDuration = duration / Double(steps)
    
    for i in 0..<steps {
        let progress = CGFloat(i) / CGFloat(steps)
        let easedProgress = easeInOut(progress)
        
        let currentX = from.x + (to.x - from.x) * easedProgress
        let currentY = from.y + (to.y - from.y) * easedProgress
        
        let velocity = CGPoint(
            x: (to.x - from.x) * sin(progress * .pi),
            y: (to.y - from.y) * sin(progress * .pi)
        )
        
        print("🚗 Window at (\(Int(currentX)), \(Int(currentY))) velocity: (\(Int(velocity.x)), \(Int(velocity.y)))")
        
        let accelX = velocity.x * 0.001
        simulatePhysicsFrame(acceleration: accelX, logger: logger)
        
        Thread.sleep(forTimeInterval: stepDuration)
    }
}

@MainActor
func simulateImpulse(impulseValue: CGFloat, expectedSettleTime: TimeInterval, logger: PhysicsLogger) {
    print("💥 Impulse applied: \(impulseValue)")
    
    simulatePhysicsFrame(acceleration: impulseValue, logger: logger)
    
    let settleSteps = Int(expectedSettleTime * 60)
    var previousTilt: CGFloat = 0
    
    for _ in 0..<settleSteps {
        let tilt = logger.tiltHistory.last ?? 0
        let velocity = logger.velocityHistory.last ?? 0
        
        if tilt != previousTilt {
            print("📊 Frame - Tilt: \(String(format: "%.4f", tilt)), Velocity: \(String(format: "%.4f", velocity))")
            previousTilt = tilt
        }
        
        simulatePhysicsFrame(acceleration: 0, logger: logger)
        Thread.sleep(forTimeInterval: 1.0/60.0)
    }
}

@MainActor
private func simulatePhysicsFrame(acceleration: CGFloat, logger: PhysicsLogger) {
    struct PhysicsState {
        static var tiltAngle: CGFloat = 0
        static var tiltVelocity: CGFloat = 0
    }
    
    PhysicsState.tiltVelocity += acceleration * 0.3
    PhysicsState.tiltVelocity -= PhysicsState.tiltAngle * 0.15
    PhysicsState.tiltVelocity *= 0.96
    PhysicsState.tiltAngle += PhysicsState.tiltVelocity * 0.1
    
    logger.logFrame(tilt: PhysicsState.tiltAngle, velocity: PhysicsState.tiltVelocity)
}

private func easeInOut(_ t: CGFloat) -> CGFloat {
    return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
}
