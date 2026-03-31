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
    
    public var targetFillLevel: CGFloat = 0.5
    public var animatedFillLevel: CGFloat = 0.5
    public var fillLevelVelocity: CGFloat = 0
    
    public var pendingSlosh: CGFloat? = nil
    public var sloshDirection: CGFloat = 1.0
    
    private var _internalTime: Double = 0
    public private(set) var layerStates: [LayerWaveState] = []
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
        
        let fillDiff = targetFillLevel - animatedFillLevel
        if abs(fillDiff) > 0.001 {
            let springForce = fillDiff * LiquidPhysics.fillLevelSpring
            fillLevelVelocity += springForce
            fillLevelVelocity *= LiquidPhysics.fillLevelDamping
            
            if abs(fillDiff) < 0.02 && abs(fillLevelVelocity) < 0.1 {
                fillLevelVelocity = 0
                animatedFillLevel = targetFillLevel
            } else {
                animatedFillLevel += fillLevelVelocity
            }
            
            if let pendingDir = pendingSlosh {
                sloshDirection = pendingDir > 0 ? 1.0 : -1.0
                pendingSlosh = nil
                let impulseStrength = abs(fillDiff) * LiquidPhysics.fillChangeSloshMultiplier
                containerAccelX += sloshDirection * impulseStrength
                angleVelocity += sloshDirection * impulseStrength * 0.5
            }
        }
        
        var accel = containerAccelX
        
        if LiquidPhysics.ambientMotionEnabled {
            let ambientAccel = sin(_internalTime * LiquidPhysics.ambientFrequency1) * LiquidPhysics.ambientAmplitude1
                            + sin(_internalTime * LiquidPhysics.ambientFrequency2) * LiquidPhysics.ambientAmplitude2
                            + sin(_internalTime * LiquidPhysics.ambientFrequency3) * LiquidPhysics.ambientAmplitude3
            accel += ambientAccel
        }
        
        containerAccelX *= LiquidPhysics.accelerationDecay
        
        containerVelocityX += accel * 0.5
        containerVelocityX *= LiquidPhysics.containerVelocityDecay
        
        angleVelocity += accel * LiquidPhysics.tiltResponse * LiquidPhysics.waveExcitationMultiplier
        angleVelocity -= surfaceAngle * LiquidPhysics.springStrength * LiquidPhysics.waveSpringMultiplier
        angleVelocity *= LiquidPhysics.velocityDamping
        surfaceAngle += angleVelocity * LiquidPhysics.angleInertia
        surfaceAngle *= LiquidPhysics.angleDecay
        
        displacementVelocity += containerVelocityX * LiquidPhysics.displacementCoupling
        displacementVelocity -= liquidDisplacement * LiquidPhysics.springStrength * LiquidPhysics.displacementSpring
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
                waves[i].velocity *= LiquidPhysics.waveReflectionBounce
            }
        }
        
        for layerIndex in 0..<layerStates.count {
            let layerDamping = layerStates[layerIndex].waveDamping
            
            layerStates[layerIndex].angleVelocity += accel * LiquidPhysics.tiltResponse * LiquidPhysics.waveExcitationMultiplier * layerDamping
            layerStates[layerIndex].angleVelocity -= layerStates[layerIndex].surfaceAngle * LiquidPhysics.springStrength * LiquidPhysics.waveSpringMultiplier
            layerStates[layerIndex].angleVelocity *= LiquidPhysics.velocityDamping * layerDamping
            layerStates[layerIndex].surfaceAngle += layerStates[layerIndex].angleVelocity * LiquidPhysics.angleInertia
            layerStates[layerIndex].surfaceAngle *= LiquidPhysics.angleDecay * layerDamping
            
            layerStates[layerIndex].displacementVelocity += containerVelocityX * LiquidPhysics.displacementCoupling * layerDamping
            layerStates[layerIndex].displacementVelocity -= layerStates[layerIndex].displacement * LiquidPhysics.springStrength * LiquidPhysics.displacementSpring
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
                    layerStates[layerIndex].waves[i].velocity *= LiquidPhysics.waveReflectionBounce
                }
            }
        }
        
        logFrame += 1
    }
    
    public func addSloshImpulse(direction: CGFloat = 1.0) {
        pendingSlosh = direction
        
        let strength = direction > 0 ? LiquidPhysics.pourWaveStrength : LiquidPhysics.settleWaveStrength
        containerAccelX += direction * strength
        angleVelocity += direction * strength * 0.6
        displacementVelocity += direction * strength * 0.4
        
        for (index, layerMultiplier) in LiquidPhysics.sloshLayerMultiplier.enumerated() where index < layerStates.count {
            layerStates[index].angleVelocity += direction * strength * layerMultiplier * 0.4
            layerStates[index].displacementVelocity += direction * strength * layerMultiplier * 0.3
            if index < layerStates[index].waves.count {
                layerStates[index].waves[0].velocity += direction * strength * layerMultiplier * 0.5
                layerStates[index].waves[1].velocity += direction * strength * layerMultiplier * 0.3
            }
        }
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
        
        var layerAngle: CGFloat
        var layerDisp: CGFloat
        var localWaves: [WaveState]
        var layerDamping: CGFloat
        var phaseDelay: CGFloat
        
        if layerIndex > 0 && layerIndex < layerStates.count {
            layerAngle = layerStates[layerIndex].surfaceAngle
            layerDisp = layerStates[layerIndex].displacement
            localWaves = layerStates[layerIndex].waves
            layerDamping = layerStates[layerIndex].waveDamping
            phaseDelay = layerStates[layerIndex].phaseDelay
        } else {
            layerAngle = surfaceAngle
            layerDisp = liquidDisplacement
            localWaves = waves
            layerDamping = 1.0
            phaseDelay = 0.0
        }
        
        let t = _internalTime - Double(phaseDelay)
        
        let angleEffect = -layerAngle * (normalizedX - 0.5) * LiquidPhysics.surfaceAngleEffect
        let displacementEffect = layerDisp * (normalizedX - 0.5) * LiquidPhysics.surfaceDisplacementEffect
        
        let waveDrift = layerDisp * LiquidPhysics.surfaceWaveDriftFactor * cos(t * LiquidPhysics.surfaceWaveDriftFrequency) * layerDamping
        
        let waveAmplitude = localWaves.reduce(CGFloat(0)) { $0 + abs($1.amplitude) }
        let curvature = waveAmplitude * LiquidPhysics.surfaceCurvatureFactor * layerDamping
        
        let curvatureEffect = curvature * sin(normalizedX * .pi * 2.0 + t * 2.0)
        let nonlinearity = waveAmplitude * LiquidPhysics.surfaceNonlinearityFactor * layerDamping * sin(normalizedX * .pi * 3.0 + t * 1.5)
        
        var waveEffect: CGFloat = 0
        
        for i in 0..<min(localWaves.count, 3) {
            let freq = i < LiquidPhysics.waveFrequencies.count ? LiquidPhysics.waveFrequencies[i] : CGFloat(0.015 + Double(i) * 0.01)
            let phaseOffset = i < LiquidPhysics.wavePhaseOffsets.count ? LiquidPhysics.wavePhaseOffsets[i] : Double(i) * 2.0
            let speedMult = i < LiquidPhysics.waveSpeedMultipliers.count ? LiquidPhysics.waveSpeedMultipliers[i] : 0.8 + Double(i) * 0.3
            let depthFactor = i < LiquidPhysics.waveDepthFactors.count ? LiquidPhysics.waveDepthFactors[i] : 1.0 - CGFloat(i) * 0.15
            
            let wave = sin(x * freq + t * speedMult + phaseOffset) * localWaves[i].amplitude * LiquidPhysics.surfaceWaveEffectFactor * depthFactor * layerDamping
            waveEffect += wave
        }
        
        let rippleDamping = layerDamping * LiquidPhysics.surfaceRippleDampingFactor
        let ripple1 = sin(x * LiquidPhysics.waveFrequency1 + t * LiquidPhysics.waveSpeed1) * LiquidPhysics.waveAmplitude1 * LiquidPhysics.surfaceRippleEffectFactor * rippleDamping
        let ripple2 = sin(x * LiquidPhysics.waveFrequency2 - t * LiquidPhysics.waveSpeed2) * LiquidPhysics.waveAmplitude2 * LiquidPhysics.surfaceRippleEffectFactor * rippleDamping
        
        let total = angleEffect + displacementEffect + waveDrift + curvatureEffect + nonlinearity + waveEffect + ripple1 + ripple2
        
        return total
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
