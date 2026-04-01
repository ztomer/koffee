# Weight TextField Input Blockage - Diagnostic Plan

## Things that DIDN'T work (ruled out)

1. ✅ `.textFieldStyle(.plain)` - didn't help
2. ✅ Changed from value-based binding to text-based binding - didn't help
3. ✅ Added `@FocusState` - didn't help
4. ✅ Increased drag gesture minimumDistance from 1 to 20 - didn't help
5. ✅ Removed drag gesture entirely - didn't help
6. ✅ Changed weightControl background from `.ultraThinMaterial` to simple Color - didn't help
7. ✅ Removed `.background(.ultraThinMaterial)` from body level - didn't help
8. ✅ Removed `.clipShape()` from body level - didn't help
9. ✅ Removed `.overlay()` from body level - didn't help
10. ✅ Added Edit menu and main menu - didn't help
11. ✅ Set window to transparent (`isOpaque = false`) - didn't help
12. ✅ Moved TextField outside ZStack to top of VStack - TextField visible but still can't type
13. ✅ Replaced SwiftUI TextField with NSTextField via NSViewRepresentable - STILL CAN'T TYPE
14. ✅ Added window configuration (fullSizeContentView, titlebarAppearsTransparent, etc) - didn't help
15. ✅ **FIXED: Custom NSWindow subclass with canBecomeKey = true and canBecomeMain = true**

---

## Hypotheses

### H1: NSWindow configuration missing keyboard enablement
- Window created programmatically without proper configuration
- Missing: `window.acceptsMouseMovedEvents`, `window.initialFirstResponder`
- Could also be missing `styleMask` options like `.fullSizeContentView`

### H2: NSHostingView configuration issue
- NSHostingView may need additional configuration
- Possible missing: `allowsVibrancy`, view hierarchy setup

### H3: AppDelegate missing critical setup
- The app uses custom AppDelegate with manual NSWindow creation
- Missing critical app lifecycle setup that SwiftUI @main provides automatically

### H4: Event routing issue at window level
- Window not properly configured to route keyboard events to content view
- Could be related to `makeFirstResponder` timing or configuration

### H5: Missing window collection behavior
- Window may need specific `collectionBehavior` or other macOS window flags

---

## Test Plan

### Test 1: Window configuration
```swift
// Add these to window setup:
window.acceptsMouseMovedEvents = true
window.collectionBehavior = [.fullScreenPrimary]
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden
```

### Test 2: Try NSWindowController
Instead of creating NSWindow directly in AppDelegate, use NSWindowController to manage the window properly.

### Test 3: Test with SwiftUI @main instead of AppDelegate
Convert the app to use standard SwiftUI @main and WindowGroup to see if that works.

### Test 4: Add key event monitoring at window level
```swift
override func keyDown(with event: NSEvent) {
    debugLog("KEY_DOWN: \(event.characters)")
    super.keyDown(with: event)
}
```

### Test 5: Check if window becomes key
- Add logging to verify window actually receives key status
- Could be that another window is intercepting events