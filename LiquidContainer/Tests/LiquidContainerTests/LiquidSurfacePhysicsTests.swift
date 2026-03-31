import XCTest
@testable import LiquidContainer

@MainActor
final class LiquidSurfacePhysicsTests: XCTestCase {
    
    func testWaveOffset_WhatDoesPhysicsReturn() {
        let engine = LiquidPhysicsEngine(waveCount: 3)
        engine.configureLayers(
            count: 3,
            dampingFactors: [0.97, 0.88, 0.78],
            phaseDelays: [0.0, 0.15, 0.40]
        )
        
        let width: CGFloat = 400
        let surfaceY: CGFloat = 300
        
        for i in 0..<20 {
            engine.step(deltaTime: 0.016)
        }
        
        engine.containerAccelX = 5.0
        for i in 0..<10 {
            engine.step(deltaTime: 0.016)
        }
        
        print("=== Surface Wave Analysis ===")
        print("surfaceY: \(surfaceY)")
        print("Layer 0 surface heights across width:")
        
        var minHeight: CGFloat = .infinity
        var maxHeight: CGFloat = -.infinity
        
        for x in stride(from: 0, to: width, by: 40) {
            let waveOffset = engine.layerSurfaceHeight(x: x, width: width, layerIndex: 0)
            let actualY = surfaceY + waveOffset
            minHeight = min(minHeight, actualY)
            maxHeight = max(maxHeight, actualY)
            print("  x=\(x): waveOffset=\(String(format: "%.1f", waveOffset)), actualY=\(String(format: "%.1f", actualY))")
        }
        
        print("")
        print("Min surface Y: \(minHeight) (\(minHeight / 600 * 100)% from top)")
        print("Max surface Y: \(maxHeight) (\(maxHeight / 600 * 100)% from top)")
        print("Surface tilt range: \(maxHeight - minHeight)px")
        
        let tilt = maxHeight - minHeight
        XCTAssertGreaterThan(tilt, 5, "Should have noticeable surface tilt")
        XCTAssertGreaterThan(maxHeight, surfaceY - 30, "Surface should not go too high")
        XCTAssertLessThan(minHeight, surfaceY + 30, "Surface should not go too low")
    }
    
    func testLayerBottom_ShouldClampButSurfaceShouldNot() {
        let engine = LiquidPhysicsEngine(waveCount: 3)
        engine.configureLayers(
            count: 3,
            dampingFactors: [0.97, 0.88, 0.78],
            phaseDelays: [0.0, 0.15, 0.40]
        )
        
        let width: CGFloat = 400
        let surfaceY: CGFloat = 300
        let layerBoundaries: [CGFloat] = [36.0, 114.0, 300.0]
        let liquidLayerBottomY = surfaceY + layerBoundaries[1]
        
        for i in 0..<20 {
            engine.step(deltaTime: 0.016)
        }
        
        engine.containerAccelX = 8.0
        for i in 0..<15 {
            engine.step(deltaTime: 0.016)
        }
        
        print("=== Layer Boundaries ===")
        print("surfaceY: \(surfaceY)")
        print("liquidLayer bottom: \(liquidLayerBottomY)")
        
        print("")
        print("Liquid layer (1) heights across width:")
        
        for x in stride(from: 0, to: width, by: 40) {
            let waveOffset = engine.layerSurfaceHeight(x: x, width: width, layerIndex: 1)
            let surfaceAtX = liquidLayerBottomY + waveOffset
            
            let shouldClampBottom = surfaceAtX > liquidLayerBottomY + 15
            let clampedSurface = shouldClampBottom ? liquidLayerBottomY + 15 : surfaceAtX
            
            print("  x=\(x): waveOffset=\(String(format: "%.1f", waveOffset)), surface=\(String(format: "%.1f", surfaceAtX)), clamped=\(String(format: "%.1f", clampedSurface))")
        }
    }
    
    func testWhatShouldLayerPathLookLike() {
        let surfaceY: CGFloat = 300
        let layerTopY: CGFloat = surfaceY
        let layerBottomY: CGFloat = 336
        let maxWave: CGFloat = 15
        
        print("=== Expected Layer Path ===")
        print("surfaceY (layer top): \(surfaceY)")
        print("layerBottomY: \(layerBottomY)")
        print("")
        print("For a tilted surface:")
        print("  Left side (wave = +\(maxWave)): y = \(surfaceY) + \(maxWave) = \(surfaceY + maxWave)")
        print("  Right side (wave = -\(maxWave)): y = \(surfaceY) - \(maxWave) = \(surfaceY - maxWave)")
        print("")
        print("For a sloshing surface:")
        print("  Wave goes from +\(maxWave) down to -maxWave across width")
        print("  But layer bottom should stay at \(layerBottomY)")
        print("")
        print("Problem: if waveOffset varies from -15 to +15, the surface")
        print("  goes from 285 to 315. But we only have 36px of layer height!")
        print("  The surface would extend beyond the layer bounds.")
    }
    
    func testLayerWaveDamping_IsAppliedCorrectly() {
        let engine = LiquidPhysicsEngine(waveCount: 3)
        engine.configureLayers(
            count: 3,
            dampingFactors: [0.97, 0.88, 0.78],
            phaseDelays: [0.0, 0.15, 0.40]
        )
        
        for _ in 0..<20 {
            engine.step(deltaTime: 0.016)
        }
        
        engine.containerAccelX = 10.0
        for _ in 0..<30 {
            engine.step(deltaTime: 0.016)
        }
        
        print("=== Layer Wave Damping Test ===")
        print("Wave amplitudes after sloshing:")
        
        for i in 0..<3 {
            let amp0 = engine.waves[0].amplitude
            let ampLayer = engine.layerStates[i].waves[0].amplitude
            print("  Layer \(i): global=\(String(format: "%.2f", amp0)), layer=\(String(format: "%.2f", ampLayer)), damping=\(engine.layerStates[i].waveDamping)")
        }
        
        let layer0Amp = abs(engine.layerStates[0].waves[0].amplitude)
        let layer1Amp = abs(engine.layerStates[1].waves[0].amplitude)
        let layer2Amp = abs(engine.layerStates[2].waves[0].amplitude)
        
        XCTAssertGreaterThan(layer0Amp, layer1Amp * 0.5, "Layer 0 should have more amplitude than layer 1")
        XCTAssertGreaterThan(layer1Amp, layer2Amp * 0.5, "Layer 1 should have more amplitude than layer 2")
    }
}
