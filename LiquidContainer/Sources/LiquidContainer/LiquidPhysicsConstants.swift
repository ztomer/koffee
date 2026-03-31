import Foundation

/// Physics constants for realistic liquid simulation
/// 
/// ## Wave Physics Model
/// The liquid simulation uses a multi-layer model where each layer (crema, liquid, dense)
/// has independent physics parameters. Waves propagate through layers with damping and
/// phase delay to simulate the physical behavior of espresso.
/// 
/// ## Key Concepts:
/// - **Surface Angle**: The tilt of the liquid surface relative to horizontal
/// - **Displacement**: The center-of-mass shift of the liquid
/// - **Wave Amplitudes**: Multiple overlapping sine waves for organic motion
/// - **Layer Damping**: Each layer dampens waves differently (crema = loose, dense = tight)
/// 
/// ## Tuning Tips:
/// - Increase `waveMaxAmplitudes` for more dramatic sloshing
/// - Increase `angleDecay` for longer-lasting waves
/// - Adjust `ambientMotionEnabled` to control idle animation
public struct LiquidPhysics {
    // MARK: - Ambient Motion
    // Subtle environmental vibrations to keep liquid "alive" when stationary
    public static let ambientMotionEnabled: Bool = true
    public static let ambientFrequency1: Double = 1.7
    public static let ambientFrequency2: Double = 2.3
    public static let ambientFrequency3: Double = 3.1
    public static let ambientAmplitude1: CGFloat = 0.02
    public static let ambientAmplitude2: CGFloat = 0.015
    public static let ambientAmplitude3: CGFloat = 0.01
    
    // MARK: - Container Physics
    public static let accelerationDecay: CGFloat = 0.88
    public static let tiltResponse: CGFloat = 0.15
    public static let velocityDamping: CGFloat = 0.985
    public static let angleDecay: CGFloat = 0.985
    public static let springStrength: CGFloat = 0.03
    public static let angleInertia: CGFloat = 0.95
    public static let tiltAmplification: CGFloat = 4.5
    
    // Velocity and displacement tuning
    public static let containerVelocityDecay: CGFloat = 0.98
    public static let displacementCoupling: CGFloat = 0.003
    public static let displacementSpring: CGFloat = 0.3
    
    // Wave excitation tuning
    public static let waveExcitationMultiplier: CGFloat = 2.0
    public static let waveSpringMultiplier: CGFloat = 0.8
    public static let waveReflectionBounce: CGFloat = -0.3
    
    public static let waveFrequency1: CGFloat = 0.015
    public static let waveFrequency2: CGFloat = 0.025
    public static let waveSpeed1: Double = 0.8
    public static let waveSpeed2: Double = 0.6
    public static let waveAmplitude1: CGFloat = 2
    public static let waveAmplitude2: CGFloat = 1.5
    
    public static let waveFrequencies: [CGFloat] = [0.015, 0.025, 0.035]
    public static let wavePhaseOffsets: [Double] = [0.0, 2.0, 4.0]
    public static let waveSpeedMultipliers: [Double] = [0.8, 1.1, 1.4]
    public static let waveDepthFactors: [CGFloat] = [1.0, 0.85, 0.7]
    public static let waveMaxAmplitudes: [CGFloat] = [8.0, 6.0, 4.0]
    public static let waveCoupling: [CGFloat] = [0.5, 0.2, 0.1]
    
    // MARK: - Surface Height Calculation
    public static let surfaceAngleEffect: CGFloat = 1.0
    public static let surfaceDisplacementEffect: CGFloat = 2.0
    public static let surfaceWaveDriftFactor: CGFloat = 0.5
    public static let surfaceWaveDriftFrequency: Double = 0.5
    public static let surfaceCurvatureFactor: CGFloat = 0.15
    public static let surfaceNonlinearityFactor: CGFloat = 0.08
    public static let surfaceWaveEffectFactor: CGFloat = 0.15
    public static let surfaceRippleEffectFactor: CGFloat = 0.1
    public static let surfaceRippleDampingFactor: CGFloat = 0.4
    public static let maxWaveOffset: CGFloat = 40.0
    
    public static let minLiquidHeightForBubbles: CGFloat = 30
    public static let bubbleCycleSeconds: Double = 8.0
    public static let bubbleRiseFraction: CGFloat = 0.8
    public static let bubbleViscosityCoeff: Double = 2.5
    public static let bubbleWobbleBase: CGFloat = 3.0
    public static let bubbleTiltFactor: CGFloat = 30.0
    public static let bubbleMaxAlpha: CGFloat = 0.3
    
    public static let causticSpeed: Double = 0.3
    public static let causticScale: Double = 0.02
    public static let causticLightPenetration: Double = 0.08
    public static let causticDepthFalloff: CGFloat = 0.7
    public static let causticSpotWidth: CGFloat = 6.0
    public static let causticSpotHeightMin: CGFloat = 12.0
    public static let causticSpotHeightMax: CGFloat = 32.0
    public static let causticColor: (r: Double, g: Double, b: Double) = (0.92, 0.88, 0.80)
    
    public static let foamThickness: CGFloat = 20.0
    public static let foamClearOffset: CGFloat = 12.0
    public static let foamClearOpacity: Double = 0.2
    public static let foamMidOpacity: Double = 0.5
    public static let foamLightOpacity: Double = 0.7
    public static let foamCreamOpacity: Double = 0.8
    
    public static let renderWaveStep: CGFloat = 2.0
    public static let renderCausticStep: CGFloat = 2.0
    public static let animationFramerate: Double = 1.0 / 30.0
    public static let gradientShiftFactor: CGFloat = 10.0
    public static let gradientAngleFactor: CGFloat = 0.8
    public static let gradientDisplacementFactor: CGFloat = 0.05
    public static let gradientWaveFactor: CGFloat = 0.02
    
    // MARK: - Dose Animation
    public static let fillLevelAnimationDuration: Double = 0.8
    public static let fillLevelAnimationEasing: Double = 0.3
    public static let fillLevelSpring: CGFloat = 0.15
    public static let fillLevelDamping: CGFloat = 0.75
    public static let fillChangeSloshMultiplier: CGFloat = 20.0
    
    // MARK: - Slosh Effect
    public static let sloshImpulseStrength: CGFloat = 15.0
    public static let sloshLayerMultiplier: [CGFloat] = [1.0, 0.7, 0.4]
    public static let sloshDampingExtra: CGFloat = 0.1
    
    // Pour animation
    public static let pourWaveStrength: CGFloat = 25.0
    public static let pourOscillationCount: Int = 3
    public static let settleWaveStrength: CGFloat = 8.0
}

public struct LiquidPhysicsConfig: Codable {
    public let physics: PhysicsConfig
    public let bubble: BubbleConfig
    public let caustics: CausticsConfig
    public let foam: FoamConfig
    public let rendering: RenderingConfig
    
    public struct PhysicsConfig: Codable {
        public let accelerationDecay: Double
        public let tiltResponse: Double
        public let velocityDamping: Double
        public let angleDecay: Double
        public let springStrength: Double
        public let angleInertia: Double
    }
    
    public struct BubbleConfig: Codable {
        public let minLiquidHeight: Double
        public let cycleSeconds: Double
        public let riseFraction: Double
        public let viscosityCoeff: Double
        public let wobbleBase: Double
    }
    
    public struct CausticsConfig: Codable {
        public let speed: Double
        public let scale: Double
        public let lightPenetration: Double
        public let depthFalloff: Double
        public let spotWidth: Double
        public let spotHeightMin: Double
        public let spotHeightMax: Double
        public let colorRed: Double
        public let colorGreen: Double
        public let colorBlue: Double
    }
    
    public struct FoamConfig: Codable {
        public let thickness: Double
        public let clearOffset: Double
        public let clearOpacity: Double
        public let midOpacity: Double
        public let lightOpacity: Double
        public let creamOpacity: Double
    }
    
    public struct RenderingConfig: Codable {
        public let waveStep: Double
        public let causticStep: Double
        public let animationFramerate: Double
        public let gradientShiftFactor: Double
        public let gradientAngleFactor: Double
        public let gradientDisplacementFactor: Double
        public let gradientWaveFactor: Double
    }
    
    public static func load() -> LiquidPhysicsConfig? {
        guard let url = Bundle.module.url(forResource: "default_config", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(LiquidPhysicsConfig.self, from: data)
    }
}
