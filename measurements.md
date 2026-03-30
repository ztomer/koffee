# UI Element Measurements (Updated with larger fonts)

## Width Calculations
- DatePicker (compact, hour:minute): 70px
- Picker (max beverage ~24 chars × 8px char width): 192px
- Remove button: 24px
- Button padding: 6px × 2 = 12px
- HStack spacing: 6px
- DoseEditorView padding: 8px × 2 = 16px
- ContentView padding: 10px × 2 = 20px
- Width subtotal: 70 + 192 + 24 + 12 + 6 + 16 + 20 = 340px

## Height Calculations (per element) - NEW FONTS

### 1. Title Bar
- Native macOS title bar: 28px

### 2. bodySection (NEW SIZES)
- Label "BODY": 14px (10pt font)
- VStack spacing: 2px
- GlassCard:
  - "kg" label: 11px (9pt font)
  - TextField: 14pt font = ~20px
  - GlassCard padding: 6px × 2 = 12px
  - VStack spacing: 2px
  - GlassCard total: 11 + 2 + 20 + 12 = 45px
- Sensitivity GlassCard:
  - "Sensitivity" label: 11px
  - Button: 24px + padding
  - GlassCard total: 11 + 2 + 26 + 12 = 51px
- bodySection total: 14 + 2 + 45 + 6 + 51 = 118px

### 3. scheduleSection (NEW SIZES)
- Label "SCHEDULE": 14px
- GlassCard (wake/sleep):
  - Label: 11px
  - DatePicker: 26px
  - GlassCard padding: 12px
  - GlassCard total: 11 + 2 + 26 + 12 = 51px
- scheduleSection total: 14 + 2 + 51 + 6 + 51 = 124px

### 4. meterSection (NEW SIZES)
- ZStack height: 55px
- Status text: 16px (12pt font)
- VStack spacing: 4px
- mg text: 12px (10pt font)
- VStack spacing: 4px
- meterSection total: 55 + 4 + 16 + 4 + 12 = 91px

### 5. dosesSection (NEW SIZES)
- Label "DOSE PLAN": 14px
- VStack spacing: 4px
- DoseEditorView (per dose):
  - DatePicker: 26px
  - Picker: 26px
  - Remove button: 24px
  - HStack spacing: 6px
  - Padding: 16px
  - DoseEditorView total: 26 + 26 + 24 + 6 + 16 = 98px
- For 2 doses: 2 × 98px = 196px
- Add button: 14px text + 12px padding = 26px
- dosesSection total (2 doses): 14 + 4 + 196 + 26 = 240px

### 6. optimizeButton (NEW SIZES)
- Text "✨ Optimize": 13px (11pt font)
- Padding vertical: 8px × 2 = 16px
- optimizeButton total: 13 + 16 = 29px

### 7. VStack Spacing
- 4 spacings between: 4 × 6px = 24px

### 8. ContentView padding
- 10px × 2 = 20px

## Total Height Calculation (2 doses)
- Title bar: 28px
- ContentView padding: 20px
- bodySection: 118px
- scheduleSection: 124px
- meterSection: 91px
- dosesSection: 240px
- optimizeButton: 29px
- VStack spacing: 24px

Total (2 doses): 28 + 20 + 118 + 124 + 91 + 240 + 29 + 24 = 674px
With 5% buffer: 708px

## Recommended Window Size
- Default: 720px (accommodates 2-3 doses)
