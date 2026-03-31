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
        let layerHeight = layerBottomY - layerTopY
        guard layerHeight > 2 else { return }
        
        var layerPath = Path()
        layerPath.move(to: CGPoint(x: 0, y: layerBottomY))
        
        for x in stride(from: 0, through: size.width, by: LiquidPhysics.renderWaveStep) {
            let waveOffset = physicsEngine.layerSurfaceHeight(x: x, width: size.width, layerIndex: layerIndex)
            let y = layerTopY + waveOffset
            layerPath.addLine(to: CGPoint(x: x, y: y))
        }
        
        layerPath.addLine(to: CGPoint(x: size.width, y: layerBottomY))
        layerPath.addLine(to: CGPoint(x: size.width, y: size.height))
        layerPath.addLine(to: CGPoint(x: 0, y: size.height))
        layerPath.closeSubpath()
        
        let layerGradient = Gradient(colors: [
            layer.topColor,
            layer.bottomColor
        ])
        
        context.fill(layerPath, with: .linearGradient(
            layerGradient,
            startPoint: CGPoint(x: 0, y: layerTopY),
            endPoint: CGPoint(x: 0, y: layerBottomY)
        ))
        
        if layer.hasFoam && layerIndex == 0 {
            renderFoamBubbles(
                context: context,
                size: size,
                surfaceY: layerTopY,
                foamColor: layer.foamColor,
                bubbleDensity: layer.bubbleDensity,
                intTime: intTime
            )
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
        let bubbleCount = Int(50 * bubbleDensity)
        let cremaDepth = size.height * 0.12 * bubbleDensity
        
        for i in 0..<bubbleCount {
            let seed = i * 7919
            let xBase = CGFloat(seed % Int(size.width - 10)) + 5
            let depthInCrema = CGFloat((seed / 100) % Int(max(cremaDepth, 5)))
            let bubbleSize = CGFloat(2 + (seed % 3))
            
            let waveOffset = physicsEngine.layerSurfaceHeight(x: xBase, width: size.width, layerIndex: 0)
            let currentSurfaceY = surfaceY + waveOffset
            
            let phaseX = Double(seed % 100) * 0.1
            let speedX = 0.5 + Double(seed % 3) * 0.2
            
            let offsetX = sin(intTime * speedX + phaseX) * 2
            let offsetY = sin(intTime * 0.3 + Double(i)) * 0.5
            
            let currentX = xBase + CGFloat(offsetX)
            let currentY = currentSurfaceY + depthInCrema + CGFloat(offsetY)
            
            let brightness = 0.7 + Double(seed % 30) / 100.0
            let bubbleColor = Color(
                red: brightness * 0.95,
                green: brightness * 0.85,
                blue: brightness * 0.65
            )
            let alpha = 0.3 + Double(seed % 40) / 100.0
            
            var bubblePath = Path()
            bubblePath.addEllipse(in: CGRect(
                x: currentX,
                y: currentY,
                width: bubbleSize,
                height: bubbleSize * 0.9
            ))
            
            context.fill(bubblePath, with: .color(bubbleColor.opacity(alpha)))
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
