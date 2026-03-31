import Foundation

@MainActor
public final class LiquidPhysicsEngine: Observable {
    public struct WaveState: Sendable {
        public var amplitude: CGFloat
        public var velocity: CGFloat
        
        public init(amplitude: CGFloat = 0, velocity: CGFloat = 0) {
            self.amplitude = amplitude
            self.velocity = velocity
        }
    }
    
    public struct LayerWaveState: Sendable {
        public var surfaceAngle: CGFloat
        public var angleVelocity: CGFloat
        public var displacement: CGFloat
        public var displacementVelocity: CGFloat
        public var waves: [WaveState]
        public var waveDamping: CGFloat
        public var phaseDelay: CGFloat
        
        public init(
            surfaceAngle: CGFloat = 0,
            angleVelocity: CGFloat = 0,
            displacement: CGFloat = 0,
            displacementVelocity: CGFloat = 0,
            waveDamping: CGFloat = 0.88,
            phaseDelay: CGFloat = 0
        ) {
            self.surfaceAngle = surfaceAngle
            self.angleVelocity = angleVelocity
            self.displacement = displacement
            self.displacementVelocity = displacementVelocity
            self.waveDamping = waveDamping
            self.phaseDelay = phaseDelay
            self.waves = (0..<3).map { _ in WaveState() }
        }
    }
    
    public var surfaceAngle: CGFloat = 0
    public var angleVelocity: CGFloat = 0
    
    public var liquidDisplacement: CGFloat = 0
    public var displacementVelocity: CGFloat = 0
    
    public private(set) var waves: [WaveState] = []
    
    public var containerAccelX: CGFloat = 0
    public var containerVelocityX: CGFloat = 0
    public var logFrame: Int = 0
    
    private var _internalTime: Double = 0
    private var layerStates: [LayerWaveState] = []
    private var layerCount: Int = 1
    private var layerDampingFactors: [CGFloat] = []
    private var layerPhaseDelays: [CGFloat] = []
    private var waveCoupling: CGFloat = 0.6
    private var reflectionRatio: CGFloat = 0.6
    
    public var internalTime: Double {
        _internalTime
    }
    
    public var totalWaveAmplitude: CGFloat {
        waves.reduce(0) { $0 + abs($1.amplitude) }
    }
    
    public var totalLayerCount: Int {
        layerCount
    }
    
    public init(waveCount: Int = 3, layerCount: Int = 1) {
        waves = (0..<waveCount).map { _ in WaveState() }
        self.layerCount = layerCount
        initializeLayers()
    }
    
    public func configureLayers(
        count: Int,
        dampingFactors: [CGFloat],
        phaseDelays: [CGFloat],
        coupling: CGFloat = 0.6,
        reflection: CGFloat = 0.6
    ) {
        layerCount = count
        layerDampingFactors = dampingFactors
        layerPhaseDelays = phaseDelays
        waveCoupling = coupling
        reflectionRatio = reflection
        initializeLayers()
    }
    
    private func initializeLayers() {
        layerStates = (0..<layerCount).map { i in
            let damping = i < layerDampingFactors.count ? layerDampingFactors[i] : 0.85
            let phase = i < layerPhaseDelays.count ? layerPhaseDelays[i] : CGFloat(i) * 0.15
            return LayerWaveState(waveDamping: damping, phaseDelay: phase)
        }
    }
    
    public func step(deltaTime: Double) {
        _internalTime += deltaTime
        
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
            let coupling = i < LiquidPhysics.waveCoupling.count ? LiquidPhysics.waveCoupling[i] : 0.1
            
            waves[i].velocity += accel * LiquidPhysics.tiltResponse * coupling
            waves[i].velocity -= waves[i].amplitude * LiquidPhysics.springStrength
            waves[i].velocity *= LiquidPhysics.velocityDamping
            waves[i].amplitude += waves[i].velocity * LiquidPhysics.angleInertia
            waves[i].amplitude *= LiquidPhysics.angleDecay
            
            let maxAmp = i < LiquidPhysics.waveMaxAmplitudes.count ? LiquidPhysics.waveMaxAmplitudes[i] : CGFloat(15 - i * 3)
            if abs(waves[i].amplitude) > maxAmp {
                waves[i].amplitude = maxAmp * (waves[i].amplitude > 0 ? 1 : -1)
                waves[i].velocity *= -0.3
            }
        }
        
        for layerIndex in 0..<layerStates.count {
            let layerDamping = layerStates[layerIndex].waveDamping
            
            layerStates[layerIndex].angleVelocity += accel * LiquidPhysics.tiltResponse * 2.0 * layerDamping
            layerStates[layerIndex].angleVelocity -= layerStates[layerIndex].surfaceAngle * LiquidPhysics.springStrength * 0.8
            layerStates[layerIndex].angleVelocity *= LiquidPhysics.velocityDamping * layerDamping
            layerStates[layerIndex].surfaceAngle += layerStates[layerIndex].angleVelocity * LiquidPhysics.angleInertia
            layerStates[layerIndex].surfaceAngle *= LiquidPhysics.angleDecay * layerDamping
            
            layerStates[layerIndex].displacementVelocity += containerVelocityX * 0.003 * layerDamping
            layerStates[layerIndex].displacementVelocity -= layerStates[layerIndex].displacement * LiquidPhysics.springStrength * 0.3
            layerStates[layerIndex].displacementVelocity *= LiquidPhysics.velocityDamping * layerDamping
            layerStates[layerIndex].displacement += layerStates[layerIndex].displacementVelocity * LiquidPhysics.angleInertia
            layerStates[layerIndex].displacement *= LiquidPhysics.angleDecay * layerDamping
            
            for i in 0..<layerStates[layerIndex].waves.count {
                let coupling = i < LiquidPhysics.waveCoupling.count ? LiquidPhysics.waveCoupling[i] : 0.1
                
                var waveAccel = accel
                if layerIndex > 0 {
                    waveAccel += layerStates[layerIndex - 1].surfaceAngle * waveCoupling * reflectionRatio * (1.0 - CGFloat(layerIndex) * 0.2)
                }
                
                layerStates[layerIndex].waves[i].velocity += waveAccel * LiquidPhysics.tiltResponse * coupling * layerDamping
                layerStates[layerIndex].waves[i].velocity -= layerStates[layerIndex].waves[i].amplitude * LiquidPhysics.springStrength
                layerStates[layerIndex].waves[i].velocity *= LiquidPhysics.velocityDamping * layerDamping
                layerStates[layerIndex].waves[i].amplitude += layerStates[layerIndex].waves[i].velocity * LiquidPhysics.angleInertia
                layerStates[layerIndex].waves[i].amplitude *= LiquidPhysics.angleDecay * layerDamping
                
                let maxAmp = i < LiquidPhysics.waveMaxAmplitudes.count ? LiquidPhysics.waveMaxAmplitudes[i] : CGFloat(15 - i * 3)
                if abs(layerStates[layerIndex].waves[i].amplitude) > maxAmp {
                    layerStates[layerIndex].waves[i].amplitude = maxAmp * (layerStates[layerIndex].waves[i].amplitude > 0 ? 1 : -1)
                    layerStates[layerIndex].waves[i].velocity *= -0.3
                }
            }
        }
        
        logFrame += 1
    }
    
    public func surfaceHeight(x: CGFloat, width: CGFloat) -> CGFloat {
        baseSurfaceHeight(x: x, width: width, layerIndex: 0)
    }
    
    public func layerSurfaceHeight(x: CGFloat, width: CGFloat, layerIndex: Int) -> CGFloat {
        guard layerIndex < layerStates.count else {
            return baseSurfaceHeight(x: x, width: width, layerIndex: 0)
        }
        return baseSurfaceHeight(x: x, width: width, layerIndex: layerIndex)
    }
    
    private func baseSurfaceHeight(x: CGFloat, width: CGFloat, layerIndex: Int) -> CGFloat {
        let normalizedX = x / width
        let t = _internalTime
        
        var angle = surfaceAngle
        var disp = liquidDisplacement
        var localWaves = waves
        
        if layerIndex > 0 && layerIndex < layerStates.count {
            let phaseDelay = layerStates[layerIndex].phaseDelay
            let delayedTime = t - Double(phaseDelay)
            angle = surfaceAngle * CGFloat(cos(Double(phaseDelay)))
            disp = liquidDisplacement * CGFloat(cos(Double(phaseDelay)))
            localWaves = layerStates[layerIndex].waves
        }
        
        let angleEffect = -angle * (normalizedX - 0.5) * 2.0
        let displacementEffect = disp * (normalizedX - 0.5) * 8.0
        
        let waveAmplitude = localWaves.reduce(CGFloat(0)) { $0 + abs($1.amplitude) }
        let curvature = waveAmplitude * 0.3
        
        let curvatureEffect = curvature * sin(normalizedX * .pi * 2.0 + t * 2.0)
        let nonlinearity = waveAmplitude * 0.15 * sin(normalizedX * .pi * 3.0 + t * 1.5)
        
        var waveEffect: CGFloat = 0
        
        for i in 0..<min(localWaves.count, 3) {
            let freq = i < LiquidPhysics.waveFrequencies.count ? LiquidPhysics.waveFrequencies[i] : CGFloat(0.015 + Double(i) * 0.01)
            let phaseOffset = i < LiquidPhysics.wavePhaseOffsets.count ? LiquidPhysics.wavePhaseOffsets[i] : Double(i) * 2.0
            let speedMult = i < LiquidPhysics.waveSpeedMultipliers.count ? LiquidPhysics.waveSpeedMultipliers[i] : 0.8 + Double(i) * 0.3
            let depthFactor = i < LiquidPhysics.waveDepthFactors.count ? LiquidPhysics.waveDepthFactors[i] : 1.0 - CGFloat(i) * 0.15
            
            let wave = sin(x * freq + t * speedMult + phaseOffset) * localWaves[i].amplitude * 0.25 * depthFactor
            waveEffect += wave
        }
        
        let ripple1 = sin(x * LiquidPhysics.waveFrequency1 + t * LiquidPhysics.waveSpeed1) * LiquidPhysics.waveAmplitude1 * 0.3
        let ripple2 = sin(x * LiquidPhysics.waveFrequency2 - t * LiquidPhysics.waveSpeed2) * LiquidPhysics.waveAmplitude2 * 0.3
        
        return angleEffect + displacementEffect + curvatureEffect + nonlinearity + waveEffect + ripple1 + ripple2
    }
    
    public func bottomWaveOffset(x: CGFloat, width: CGFloat) -> CGFloat {
        let normalizedX = x / width
        let t = _internalTime
        
        let bottomPhaseLag: Double = 0.4
        let bottomDepthFactor: CGFloat = 0.35
        let bottomDamping: CGFloat = 0.4
        
        let baseAngle = surfaceAngle * bottomDepthFactor
        let baseDisplacement = liquidDisplacement * bottomDepthFactor * 0.5
        
        let angleEffect = -baseAngle * (normalizedX - 0.5) * 1.5
        let displacementEffect = baseDisplacement * (normalizedX - 0.5) * 3.0
        
        let waveAmplitude = abs(waves[0].amplitude) + abs(waves[1].amplitude) + abs(waves[2].amplitude)
        let bottomWave = waveAmplitude * bottomDamping * sin(normalizedX * .pi * 2.0 + t * 1.5 - bottomPhaseLag)
        
        let rippleBottom = sin(x * LiquidPhysics.waveFrequency1 + t * LiquidPhysics.waveSpeed1) * LiquidPhysics.waveAmplitude1 * 0.15
        
        return angleEffect + displacementEffect + bottomWave + rippleBottom
    }
    
    public func reset() {
        surfaceAngle = 0
        angleVelocity = 0
        liquidDisplacement = 0
        displacementVelocity = 0
        containerAccelX = 0
        containerVelocityX = 0
        _internalTime = 0
        for i in 0..<waves.count {
            waves[i] = WaveState()
        }
        for i in 0..<layerStates.count {
            layerStates[i] = LayerWaveState(waveDamping: layerDampingFactors[safe: i] ?? 0.85, phaseDelay: layerPhaseDelays[safe: i] ?? 0)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
