# Koffee UI/UX Fix Plan

Based on BRUTAL_REVIEW.md - All issues to fix.

---

## P0 - MUST FIX (Critical)

### 1. Typography Scale
**Current:** 8-10pt labels, 11-12pt body
**Fix:** Establish consistent type scale
```
Typography Scale:
- Section Labels (BODY, SCHEDULE): 14pt semibold
- Field Labels (kg, Wake, Sleep): 12pt regular  
- Body Text (Add, Optimize): 14pt medium
- Input Values (weight, time): 16pt bold
- Meter Status: 18pt bold
- Meter Detail: 14pt regular
```

### 2. Meter Size - MAKE IT THE HERO
**Current:** arcRadius: 50, total ~110px
**Fix:** Double the size
```
arcRadius: 100
Meter total height: ~200px
Status text: 18pt
Detail text: 14pt
```

### 3. Consistent Spacing - 8pt Grid
**Current:** Random spacing (2, 4, 6, 10px)
**Fix:** 8pt grid system
```
Padding:
- XS: 4px
- S: 8px  
- M: 12px
- L: 16px
- XL: 24px

Section spacing: 16px
Element spacing: 8px
Label-to-content: 8px
```

### 4. Touch Targets - Minimum 44pt
**Current:** 20-26px buttons
**Fix:**
```
Sensitivity buttons: 44x36pt (L/M/H)
Remove button: 32x32pt minimum
Add button: full width, 44pt height
Optimize button: full width, 48pt height, more prominent
```

---

## P1 - SHOULD FIX (Important)

### 5. Color Consistency
**Current:** Meter uses different RGB values than status text
**Fix:** Use same color definitions
```
Green: #4CAF50 (0.298, 0.686, 0.314)
Yellow: #FFC107 (1.0, 0.757, 0.027)
Red: #F44336 (0.957, 0.263, 0.208)
Orange accent: #FF9800
```

### 6. Accessibility Labels
**Fix:** Add to all interactive elements
```
Weight field: "Your weight in kilograms"
Sensitivity: "Caffeine sensitivity: Low, Medium, or High"
Wake time: "When you wake up"
Sleep time: "When you go to sleep"
Optimize: "Calculate optimal caffeine doses"
```

### 7. Make Optimize Button Prominent
**Current:** Same glass treatment as everything else
**Fix:**
```
Optimize button:
- Background: Orange (#FF9800)
- Text: White, 16pt bold
- Height: 48pt
- Corner radius: 8pt
- Shadow: subtle drop shadow
```

### 8. Animations
**Fix:**
```
- Meter needle: animate(to:) with 0.5s ease-out
- Adding doses: spring animation
- Button press: scale(0.95) effect
- Section appearance: opacity fade
```

---

## P2 - NICE TO HAVE

### 9. Empty State
**Fix:** When no doses, show helpful text
```
"No doses planned yet
Tap 'Add' or 'Optimize' to start"
```

### 10. Validation
**Fix:**
```
- Weight: min 30kg, max 200kg
- Prevent negative values
- Show inline warnings
```

### 11. Keyboard Shortcuts
**Fix:**
```
⌘O: Optimize
⌘N: Add dose
⌘+: Add dose
⌘-: Remove selected dose
```

### 12. Dynamic Type Support
**Fix:** Use `.dynamicTypeSize()` modifier where appropriate

---

## Layout Restructure

### New Window Size
**Current:** 340x820px
**Fix:** 380x680px (wider for dose pickers, fits 3 doses)

### New Layout Order
```
┌─────────────────────────────────┐
│ Title Bar                       │ 28px
├─────────────────────────────────┤
│ BODY                            │ 20px label
│ [Weight 70kg] [Sensitivity L M H]│ 48px
├─────────────────────────────────┤
│ SCHEDULE                        │ 20px label  
│ [Wake 07:00]    [Sleep 23:00]  │ 48px
├─────────────────────────────────┤
│ ┌───────────────────────────┐  │
│ │      ╭─────────────╮      │  │ 200px
│ │      │   ARC      │      │  │ (HERO)
│ │      ╰─────────────╯      │  │
│ │      Sleep well            │  │
│ │      ~35mg                 │  │
│ └───────────────────────────┘  │
├─────────────────────────────────┤
│ DOSE PLAN                      │ 20px label
│ [07:30] [Espresso    ] [−]   │ 48px
│ [12:00] [Brewed      ] [−]   │ 48px
│ [+ Add dose                   ]│ 44px
├─────────────────────────────────┤
│ [    ✨ Optimize Now    ]      │ 48px (ORANGE)
└─────────────────────────────────┘
```

### Total: ~540px + padding = 600px

---

## Implementation Order

1. Fix typography scale (establish constants)
2. Fix color definitions (single source of truth)
3. Make meter THE HERO (2x size)
4. Fix touch targets (minimum 44pt)
5. Make Optimize button orange and prominent
6. Fix spacing to 8pt grid
7. Add accessibility labels
8. Add animations
9. Add validation
10. Add empty state
