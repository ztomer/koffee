import SwiftUI

public struct LiquidContainerView<Content: View>: View {
    let fillLevel: CGFloat
    let configuration: LiquidContainerConfiguration
    @Bindable var physicsEngine: LiquidPhysicsEngine
    let bubbleStates: [BubbleState]
    let content: () -> Content
    
    public init(
        fillLevel: CGFloat,
        configuration: LiquidContainerConfiguration = .coffee,
        physicsEngine: LiquidPhysicsEngine,
        bubbleStates: [BubbleState] = [],
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.fillLevel = fillLevel
        self.configuration = configuration
        self.physicsEngine = physicsEngine
        self.bubbleStates = bubbleStates
        self.content = content
    }
    
    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0, paused: false)) { _ in
            Canvas { context, size in
                let deltaTime: Double = 1.0 / 30.0
                physicsEngine.step(deltaTime: deltaTime)
                
                let intTime = physicsEngine.internalTime
                let fillRatio = min(max(fillLevel, 0), configuration.maxFillRatio)
                let liquidHeight = size.height * fillRatio
                let surfaceY = size.height - liquidHeight
                
                guard liquidHeight > 5 else { return }
                
                let layers = configuration.layerConfiguration.layers
                let transitionWidth = configuration.layerConfiguration.interLayerTransitionWidth
                
                var layerBoundaries: [CGFloat] = []
                for layer in layers {
                    layerBoundaries.append(layer.boundaryHeight * liquidHeight)
                }
                
                for (layerIndex, layer) in layers.enumerated() {
                    let layerTopY: CGFloat
                    let layerBottomY: CGFloat
                    
                    if layerIndex == 0 {
                        layerTopY = surfaceY
                        layerBottomY = surfaceY + layerBoundaries[0]
                    } else {
                        layerTopY = surfaceY + layerBoundaries[layerIndex - 1]
                        layerBottomY = surfaceY + layerBoundaries[layerIndex]
                    }
                    
                    let layerTopHeight = layerBottomY - layerTopY
                    guard layerTopHeight > 1 else { continue }
                    
                    renderLiquidLayer(
                        context: context,
                        size: size,
                        layer: layer,
                        layerIndex: layerIndex,
                        surfaceY: surfaceY,
                        layerTopY: layerTopY,
                        layerBottomY: layerBottomY,
                        liquidHeight: liquidHeight,
                        intTime: intTime
                    )
                }
                
                renderLayerBoundaries(
                    context: context,
                    size: size,
                    surfaceY: surfaceY,
                    layerBoundaries: layerBoundaries,
                    layers: layers,
                    transitionWidth: transitionWidth,
                    liquidHeight: liquidHeight
                )
            }
            
            content()
                .allowsHitTesting(false)
        }
        .onAppear {
            let layers = configuration.layerConfiguration.layers
            let dampingFactors = layers.map { $0.waveDamping }
            let phaseDelays = layers.map { $0.phaseDelay }
            physicsEngine.configureLayers(
                count: layers.count,
                dampingFactors: dampingFactors,
                phaseDelays: phaseDelays,
                coupling: configuration.layerConfiguration.waveCoupling,
                reflection: configuration.layerConfiguration.waveReflectionRatio
            )
        }
    }
    
    private func renderLiquidLayer(
        context: GraphicsContext,
        size: CGSize,
        layer: LiquidLayer,
        layerIndex: Int,
        surfaceY: CGFloat,
        layerTopY: CGFloat,
        layerBottomY: CGFloat,
        liquidHeight: CGFloat,
        intTime: Double
    ) {
        let prevLayerBottom: CGFloat
        let nextLayerTop: CGFloat
        
        if layerIndex == 0 {
            prevLayerBottom = surfaceY
        } else {
            prevLayerBottom = surfaceY
        }
        
        let maxWaveAmplitude: CGFloat = 15.0
        
        let clampedTop = layerTopY
        let clampedBottom = min(layerBottomY + maxWaveAmplitude, size.height)
        
        var layerPath = Path()
        layerPath.move(to: CGPoint(x: 0, y: clampedBottom + 5))
        
        for x in stride(from: 0, through: size.width, by: LiquidPhysics.renderWaveStep) {
            let waveOffset = physicsEngine.layerSurfaceHeight(x: x, width: size.width, layerIndex: layerIndex)
            let clampedWave = max(-clampedTop + prevLayerBottom, min(maxWaveAmplitude, waveOffset))
            let y = layerTopY + clampedWave
            layerPath.addLine(to: CGPoint(x: x, y: y))
        }
        
        layerPath.addLine(to: CGPoint(x: size.width, y: clampedBottom + 5))
        layerPath.addLine(to: CGPoint(x: size.width, y: size.height))
        layerPath.addLine(to: CGPoint(x: 0, y: size.height))
        layerPath.closeSubpath()
        
        let layerGradient = Gradient(colors: [
            layer.topColor,
            layer.bottomColor
        ])
        
        context.fill(layerPath, with: .linearGradient(
            layerGradient,
            startPoint: CGPoint(x: 0, y: clampedTop),
            endPoint: CGPoint(x: 0, y: clampedBottom)
        ))
        
        if layer.hasFoam && layerIndex == 0 {
            renderFoamBubbles(
                context: context,
                size: size,
                surfaceY: surfaceY,
                foamColor: layer.foamColor,
                bubbleDensity: layer.bubbleDensity,
                intTime: intTime
            )
        }
    }
    
    private func renderLayerBoundaries(
        context: GraphicsContext,
        size: CGSize,
        surfaceY: CGFloat,
        layerBoundaries: [CGFloat],
        layers: [LiquidLayer],
        transitionWidth: CGFloat,
        liquidHeight: CGFloat
    ) {
        for boundaryIndex in 1..<layerBoundaries.count {
            let boundaryY = surfaceY + layerBoundaries[boundaryIndex - 1]
            let prevLayer = layers[boundaryIndex - 1]
            let nextLayer = layers[boundaryIndex]
            
            let prevLayerTop = boundaryIndex == 1 ? surfaceY : surfaceY + layerBoundaries[boundaryIndex - 2]
            let nextLayerBottom = surfaceY + layerBoundaries[boundaryIndex]
            
            let transitionHeight = liquidHeight * transitionWidth
            let transitionTop = boundaryY - transitionHeight * 0.5
            let transitionBottom = boundaryY + transitionHeight * 0.5
            
            let clampedTop = max(transitionTop, prevLayerTop)
            let clampedBottom = min(transitionBottom, nextLayerBottom)
            
            guard clampedBottom > clampedTop else { continue }
            
            var transitionPath = Path()
            transitionPath.move(to: CGPoint(x: 0, y: clampedTop))
            
            for x in stride(from: 0, through: size.width, by: LiquidPhysics.renderWaveStep) {
                let waveOffset = physicsEngine.layerSurfaceHeight(x: x, width: size.width, layerIndex: boundaryIndex)
                let y = boundaryY + waveOffset * 0.3
                transitionPath.addLine(to: CGPoint(x: x, y: max(clampedTop, min(clampedBottom, y))))
            }
            
            transitionPath.addLine(to: CGPoint(x: size.width, y: clampedBottom))
            transitionPath.addLine(to: CGPoint(x: 0, y: clampedBottom))
            transitionPath.closeSubpath()
            
            let boundaryGradient = Gradient(colors: [
                prevLayer.bottomColor,
                nextLayer.topColor
            ])
            context.fill(transitionPath, with: .linearGradient(
                boundaryGradient,
                startPoint: CGPoint(x: 0, y: clampedTop),
                endPoint: CGPoint(x: 0, y: clampedBottom)
            ))
        }
    }
    
    private func renderFoam(
        context: GraphicsContext,
        size: CGSize,
        surfaceY: CGFloat,
        configuration: LiquidContainerConfiguration,
        physicsEngine: LiquidPhysicsEngine,
        intTime: Double
    ) {
        var foamPath = Path()
        foamPath.move(to: CGPoint(x: 0, y: surfaceY - 8))
        
        for x in stride(from: 0, through: size.width, by: LiquidPhysics.renderWaveStep) {
            let waveOffset = physicsEngine.surfaceHeight(x: x, width: size.width)
            let y = surfaceY + waveOffset
            foamPath.addLine(to: CGPoint(x: x, y: y))
        }
        
        foamPath.addLine(to: CGPoint(x: size.width, y: surfaceY - 8))
        foamPath.closeSubpath()
        
        context.fill(foamPath, with: .linearGradient(
            Gradient(colors: [
                .clear,
                configuration.liquidColor.opacity(LiquidPhysics.foamClearOpacity),
                configuration.liquidColorLight.opacity(LiquidPhysics.foamMidOpacity),
                configuration.liquidColorLight.opacity(LiquidPhysics.foamLightOpacity),
                configuration.foamCremaColor.opacity(LiquidPhysics.foamCreamOpacity),
                configuration.liquidColorLight.opacity(LiquidPhysics.foamLightOpacity),
                configuration.liquidColorLight.opacity(LiquidPhysics.foamMidOpacity),
                configuration.liquidColor.opacity(LiquidPhysics.foamClearOpacity),
                .clear
            ]),
            startPoint: CGPoint(x: 0, y: surfaceY - LiquidPhysics.foamClearOffset),
            endPoint: CGPoint(x: 0, y: surfaceY + LiquidPhysics.foamThickness)
        ))
    }
    
    private func renderFoamBubbles(
        context: GraphicsContext,
        size: CGSize,
        surfaceY: CGFloat,
        foamColor: Color,
        bubbleDensity: CGFloat,
        intTime: Double
    ) {
        let bubbleCount = Int(30 * bubbleDensity)
        
        for i in 0..<bubbleCount {
            let seed = i * 7919
            let x = CGFloat(seed % Int(size.width - 20)) + 10
            let baseY = CGFloat((seed / 100) % Int(30)) + surfaceY + 5
            let bubbleSize = CGFloat(3 + (seed % 5))
            
            let wobble = sin(intTime * LiquidPhysics.waveSpeed1 + Double(i) * 0.5) * 2
            let currentX = x + CGFloat(wobble)
            let currentY = baseY + sin(intTime * 0.3 + Double(i)) * 1.5
            
            let alpha = 0.15 + Double(seed % 20) / 100.0
            
            var bubblePath = Path()
            bubblePath.addEllipse(in: CGRect(
                x: currentX,
                y: currentY,
                width: bubbleSize,
                height: bubbleSize * 0.8
            ))
            
            context.fill(bubblePath, with: .color(foamColor.opacity(alpha)))
        }
    }
}

public struct LiquidView: View {
    let fillLevel: CGFloat
    let configuration: LiquidContainerConfiguration
    @Bindable var physicsEngine: LiquidPhysicsEngine
    let bubbleCount: Int
    
    private var bubbleStates: [BubbleState]
    
    public init(
        fillLevel: CGFloat,
        configuration: LiquidContainerConfiguration = .coffee,
        physicsEngine: LiquidPhysicsEngine,
        bubbleCount: Int = 20
    ) {
        self.fillLevel = fillLevel
        self.configuration = configuration
        self.physicsEngine = physicsEngine
        self.bubbleCount = bubbleCount
        self.bubbleStates = BubbleGenerator.generate(count: 20, width: 400, height: 650)
    }
    
    public var body: some View {
        LiquidContainerView(
            fillLevel: fillLevel,
            configuration: configuration,
            physicsEngine: physicsEngine,
            bubbleStates: bubbleStates
        )
    }
}
