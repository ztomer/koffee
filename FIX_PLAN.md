# Koffee UI Issues - Fix Plan

## Current Issues

### 1. Arc, Needle, Dot Alignment
- **Status**: Almost perfect
- **Issue**: Need to move dot and needle slightly down
- **Fix**: Adjust `centerY` offset in `NeedleView` and dot offset in `CaffeineMeterView`

### 2. Window Width
- **Status**: Too wide
- **Issue**: Current width is ~280px, needs to be ~45% narrower (~155px)
- **Fix**: Change window width to ~155px and adjust content padding

### 3. Spacing Between "Okay" Text and "Optimize" Button
- **Status**: Gap is back
- **Issue**: The ScrollView + fixed button layout created extra spacing
- **Fix**: Return to VStack layout with proper spacing

### 4. Lost Glass Effects
- **Status**: Missing
- **Issue**: `.ultraThinMaterial` not applied to cards/buttons
- **Fix**: Re-apply `.ultraThinMaterial` to GlassCard, DoseEditorView, buttons

### 5. Duplicate Titlebars
- **Status**: Two titlebars showing
- **Issue**: Native titlebar + custom titlebar both visible
- **Fix**: Keep native titlebar with `titlebarAppearsTransparent = true` and `titleVisibility = .hidden`

---

## Fix Plan

### Step 1: Fix Titlebar (Issue #5)
```swift
// In main.swift AppDelegate:
window.styleMask = [.titled, .closable, .miniaturizable]
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden
// REMOVE custom TitleBarView from MainView
```

### Step 2: Fix Window Width (Issue #2)
```swift
// In main.swift:
contentRect: NSRect(x: 0, y: 0, width: 155, height: 600)
```

### Step 3: Re-apply Glass Effects (Issue #4)
```swift
// In ContentView.swift:
struct GlassCard -> .background(.ultraThinMaterial)
DoseEditorView -> .background(.ultraThinMaterial)
optimizeButton -> .background(.ultraThinMaterial)
recommendationSection -> .background(.ultraThinMaterial)
```

### Step 4: Fix Layout Spacing (Issue #3)
```swift
// Return to VStack instead of ScrollView + fixed button
VStack(spacing: 6) {
    bodySection
    scheduleSection
    meterSection
    dosesSection
    recommendationSection
    optimizeButton
}
.padding(horizontal: 8)
.padding(vertical: 6)
```

### Step 5: Fine-tune Meter Alignment (Issue #1)
```swift
// In CaffeineMeterView.swift:
// Move needle and dot down by ~5px
let centerY = geometry.size.height / 2 + 5  // was ~15% of height
Circle().offset(y: arcRadius * 0.3 + 5)  // increase offset
```
