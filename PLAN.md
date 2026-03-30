# Koffee Development Plan

## Issues to Fix

### 1. Bubbles Animation Too Fast
- **Problem**: Bubbles cycle every 4 seconds with wobble `sin(time * 3)` - too frantic
- **Fix**: 
  - Increase cycle time from 4s to 20s
  - Reduce wobble frequency from `time * 3` to `time * 0.5`
  - Reduce wobble amplitude from 3 to 1

### 2. Change "Auto" Button Text to "Optimize"
- **Location**: Line 301 in main.swift
- **Fix**: Change "Auto" to "Optimize"

### 3. Crash When All Doses Removed
- **Problem**: Likely caused by empty doses array handling or invalid beverage index
- **Fix**:
  - Add safe array access in `updateCaffeineLevel()` with bounds check
  - Add safety check for `beverageIndex` before accessing `beverages` array

## Implementation Order
1. Fix bubbles animation (slow down)
2. Change "Auto" to "Optimize" 
3. Fix crash on empty doses
4. Build and test
