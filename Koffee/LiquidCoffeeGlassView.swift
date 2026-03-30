import SwiftUI
import AppKit

class LiquidGlassWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        
        contentView = NSVisualEffectView(frame: contentRect)
        (contentView as? NSVisualEffectView)?.material = .hudWindow
        (contentView as? NSVisualEffectView)?.blendingMode = .behindWindow
        (contentView as? NSVisualEffectView)?.state = .active
    }
}

struct LiquidCoffeeGlassView: View {
    let caffeineLevel: Double
    let safeLimit: Double
    let doses: [ConfigManager.UserDose]
    let beverages: [Beverage]
    let onAddDose: () -> Void
    let onOptimize: () -> Void
    let onRemoveDose: (ConfigManager.UserDose) -> Void
    let onUpdateDose: (ConfigManager.UserDose, Date?, Int) -> Void
    
    @State private var liquidLevel: CGFloat = 0.3
    @State private var waveOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    private let coffeeGradient = LinearGradient(
        colors: [
            Color(red: 0.35, green: 0.18, blue: 0.08),
            Color(red: 0.22, green: 0.10, blue: 0.04),
            Color(red: 0.12, green: 0.05, blue: 0.02)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    private let foamGradient = LinearGradient(
        colors: [
            Color(red: 0.85, green: 0.72, blue: 0.55),
            Color(red: 0.65, green: 0.48, blue: 0.32)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var fillRatio: CGFloat {
        guard safeLimit > 0 else { return 0 }
        return min(CGFloat(caffeineLevel / safeLimit), 1.3)
    }
    
    var isOverflowing: Bool {
        caffeineLevel > safeLimit
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let glassPadding: CGFloat = 20
            let glassWidth = width - glassPadding * 2
            let glassHeight = height - 120
            let liquidHeight = glassHeight * 0.85
            
            ZStack {
                Color(red: 0.06, green: 0.04, blue: 0.03)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 30)
                    
                    glassContainer(width: width, height: height, glassWidth: glassWidth, glassHeight: glassHeight, glassPadding: glassPadding, liquidHeight: liquidHeight)
                    
                    Spacer()
                        .frame(height: 12)
                    
                    controlsSection
                        .padding(.horizontal, glassPadding)
                    
                    Spacer()
                        .frame(height: 16)
                }
            }
        }
    }
    
    private func glassContainer(width: CGFloat, height: CGFloat, glassWidth: CGFloat, glassHeight: CGFloat, glassPadding: CGFloat, liquidHeight: CGFloat) -> some View {
        ZStack {
            GlassEffectContainer {
                VStack(spacing: 0) {
                    headerSection
                    
                    Spacer()
                    
                    liquidSection(glassWidth: glassWidth, liquidHeight: liquidHeight)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(width: glassWidth, height: glassHeight)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            
            ForEach(0..<3, id: \.self) { index in
                CoffeeDrop(
                    delay: Double(index) * 0.5,
                    isOverflowing: isOverflowing,
                    overflowAmount: fillRatio - 1.0
                )
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("~\(Int(caffeineLevel))mg at bedtime")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            statusIndicator
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.6), radius: 4)
            
            Text(statusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private func liquidSection(glassWidth: CGFloat, liquidHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            let currentLiquidHeight = liquidHeight * min(fillRatio, 1.0)
            
            if currentLiquidHeight > 0 {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(coffeeGradient)
                        .frame(height: currentLiquidHeight)
                    
                    waveSurface(width: glassWidth - 16, liquidHeight: currentLiquidHeight)
                    
                    foamLayer(width: glassWidth - 20, height: 30)
                    
                    bubblesView(height: currentLiquidHeight)
                }
                .frame(height: currentLiquidHeight)
            }
            
            if isOverflowing {
                overflowEffect()
            }
        }
        .frame(height: liquidHeight)
    }
    
    private func waveSurface(width: CGFloat, liquidHeight: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            Canvas { context, size in
                var path = Path()
                let waveHeight: CGFloat = 4
                let frequency: CGFloat = 0.03
                let speed = time * 2
                
                path.move(to: CGPoint(x: 0, y: size.height))
                
                for x in stride(from: 0, through: size.width, by: 1) {
                    let relativeX = x / size.width
                    let wave1 = sin(x * frequency + speed) * waveHeight
                    let wave2 = sin(x * frequency * 1.5 - speed * 0.7) * waveHeight * 0.5
                    let y = size.height - 15 + wave1 + wave2
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                
                context.fill(path, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.77, green: 0.63, blue: 0.45).opacity(0.9),
                        Color(red: 0.45, green: 0.28, blue: 0.15).opacity(0.7),
                        Color(red: 0.35, green: 0.18, blue: 0.08)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
            }
        }
    }
    
    private func foamLayer(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(foamGradient)
                    .frame(width: CGFloat.random(in: 8...18), height: CGFloat.random(in: 8...18))
                    .offset(
                        x: CGFloat.random(in: -(width/2 - 15)...(width/2 - 15)),
                        y: CGFloat.random(in: -8...8)
                    )
                    .blur(radius: 1)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }
    
    private func bubblesView(height: CGFloat) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Bubble()
                    .offset(y: CGFloat.random(in: 20...height - 20))
            }
        }
    }
    
    private func overflowEffect() -> some View {
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                let overflowAmount = (fillRatio - 1.0) * 20
                
                for i in 0..<Int(overflowAmount) {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...30)
                    let radius = CGFloat.random(in: 3...8)
                    
                    context.fill(
                        Circle().path(in: CGRect(x: x - radius/2, y: y, width: radius, height: radius)),
                        with: .color(Color(red: 0.35, green: 0.18, blue: 0.08))
                    )
                }
            }
            .frame(height: 40)
            .blendMode(.plusLighter)
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 10) {
            doseListSection
            
            HStack(spacing: 12) {
                Button(action: onAddDose) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Dose")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                
                Button(action: onOptimize) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Optimize")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .orange.opacity(0.4), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var doseListSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DOSE PLAN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 4)
            
            if doses.isEmpty {
                Text("No doses scheduled")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(doses) { dose in
                            DoseRow(
                                dose: dose,
                                beverage: beverages[safe: dose.beverageIndex] ?? beverages[0],
                                onTimeChange: { newTime in
                                    onUpdateDose(dose, newTime, dose.beverageIndex)
                                },
                                onBeverageChange: { newIndex in
                                    onUpdateDose(dose, dose.time, newIndex)
                                },
                                onRemove: {
                                    onRemoveDose(dose)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }
    
    private var statusTitle: String {
        if caffeineLevel <= safeLimit * 0.5 {
            return "Sleep Ready"
        } else if caffeineLevel <= safeLimit {
            return "Okay"
        } else {
            return "Too Much!"
        }
    }
    
    private var statusText: String {
        if caffeineLevel <= safeLimit * 0.5 {
            return "Low"
        } else if caffeineLevel <= safeLimit {
            return "Safe"
        } else {
            return "Over limit"
        }
    }
    
    private var statusColor: Color {
        if caffeineLevel <= safeLimit * 0.5 {
            return Color(red: 0.3, green: 0.85, blue: 0.4)
        } else if caffeineLevel <= safeLimit {
            return Color(red: 1.0, green: 0.8, blue: 0.2)
        } else {
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }
}

struct DoseRow: View {
    let dose: ConfigManager.UserDose
    let beverage: Beverage
    let onTimeChange: (Date) -> Void
    let onBeverageChange: (Int) -> Void
    let onRemove: () -> Void
    
    @State private var selectedTime: Date
    @State private var selectedBeverageIndex: Int
    
    init(dose: ConfigManager.UserDose, beverage: Beverage, onTimeChange: @escaping (Date) -> Void, onBeverageChange: @escaping (Int) -> Void, onRemove: @escaping () -> Void) {
        self.dose = dose
        self.beverage = beverage
        self.onTimeChange = onTimeChange
        self.onBeverageChange = onBeverageChange
        self.onRemove = onRemove
        self._selectedTime = State(initialValue: dose.time ?? Date())
        self._selectedBeverageIndex = State(initialValue: dose.beverageIndex)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .colorScheme(.dark)
                .frame(width: 70)
                .onChange(of: selectedTime) { _ in
                    onTimeChange(selectedTime)
                }
            
            Picker("", selection: $selectedBeverageIndex) {
                ForEach(0..<10, id: \.self) { index in
                    Text("\(beverage.icon) \(beverage.name)")
                        .tag(index)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedBeverageIndex) { _ in
                onBeverageChange(selectedBeverageIndex)
            }
            
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct Bubble: View {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0.6
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 4, height: 4)
            .blur(radius: 1)
            .offset(x: CGFloat.random(in: -30...30), y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: Double.random(in: 2...4)).repeatForever(autoreverses: false)) {
                    offset = -100
                    opacity = 0
                }
            }
    }
}

struct CoffeeDrop: View {
    let delay: Double
    let isOverflowing: Bool
    let overflowAmount: CGFloat
    
    @State private var yOffset: CGFloat = -10
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1
    
    var body: some View {
        Circle()
            .fill(Color(red: 0.35, green: 0.18, blue: 0.08))
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .offset(y: yOffset)
            .opacity(isOverflowing ? opacity : 0)
            .onAppear {
                guard isOverflowing else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeIn(duration: 0.6)) {
                        yOffset = 80
                        opacity = 0
                        scale = 0.5
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.7) {
                        yOffset = -10
                        opacity = 1
                        scale = 1
                    }
                }
            }
    }
}

struct GlassEffectContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(.ultraThinMaterial)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    LiquidCoffeeGlassView(
        caffeineLevel: 35,
        safeLimit: 50,
        doses: [],
        beverages: [],
        onAddDose: {},
        onOptimize: {},
        onRemoveDose: { _ in },
        onUpdateDose: { _, _, _ in }
    )
    .frame(width: 340, height: 600)
}
