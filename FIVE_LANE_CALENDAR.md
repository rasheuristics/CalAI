# Five-Lane Calendar Layout

**Date**: 2025-10-21
**Status**: ✅ **Implemented**

---

## 🎯 Change Summary

Upgraded the calendar from **3 lanes** to **5 lanes** for event positioning, while keeping the event card width constant.

---

## 📊 What Changed

### Before: 3 Lanes
- Events could be positioned in 3 columns (lanes 0, 1, 2)
- Each event took up 1/3 of the width
- Maximum 3 overlapping events could be displayed side-by-side

### After: 5 Lanes
- Events can be positioned in 5 columns (lanes 0, 1, 2, 3, 4)
- Each event still takes up ~1/3 of the width (same card size)
- Maximum 5 overlapping events can be displayed side-by-side
- **Events will overlap more**, but have finer positioning control

---

## 🔧 Technical Changes

### 1. Lane Positioning (CalendarTabView.swift:2384-2391)

**Before**:
```swift
let maxLanes = 3
let laneWidth = width / CGFloat(maxLanes)
let offsetX = CGFloat(lane) * laneWidth
let cardWidth = min(laneWidth - 4, width - offsetX - 4)
```

**After**:
```swift
let maxLanes = 5  // Now 5 lanes for more precise positioning
let laneWidth = width / CGFloat(maxLanes)  // Width per lane (for positioning)
let offsetX = CGFloat(lane) * laneWidth

// Keep card width constant (same as before with 3 lanes)
let originalMaxLanes: CGFloat = 3
let originalLaneWidth = width / originalMaxLanes
let cardWidth = min(originalLaneWidth - 4, width - offsetX - 4)
```

**Key insight**:
- `laneWidth` is now 1/5 of screen width (for positioning)
- `cardWidth` still uses 1/3 of screen width (for size)
- Events positioned at 1/5 intervals but sized at 1/3 width → **overlap is expected**

### 2. Lane Assignment Cap (CalendarTabView.swift:2925)

**Before**:
```swift
result.append((event: event, lane: min(assignedLane, 2))) // Max 3 lanes
```

**After**:
```swift
result.append((event: event, lane: min(assignedLane, 4))) // Max 5 lanes (0-4)
```

### 3. Visual Indicator (CalendarTabView.swift:2971-2979)

**Before**:
```swift
// 3 dots
HStack(spacing: 2) {
    ForEach(0..<3) { index in
        Rectangle()
            .fill(index == lane ? eventColor : Color.clear)
            .frame(width: 3, height: 20)
    }
}
.frame(width: 24)
```

**After**:
```swift
// 5 dots (smaller and tighter spacing)
HStack(spacing: 1) {
    ForEach(0..<5) { index in
        Rectangle()
            .fill(index == lane ? eventColor : Color.clear)
            .frame(width: 2, height: 16)
    }
}
.frame(width: 14)
```

---

## 📐 Layout Math

### Screen Width Example: 390px (iPhone 14)

#### 3-Lane System (Before):
```
Lane width: 390 / 3 = 130px
Card width: 130 - 4 = 126px

Lane 0: Offset 0px,   Card width 126px  (0-126px)
Lane 1: Offset 130px, Card width 126px  (130-256px)
Lane 2: Offset 260px, Card width 126px  (260-386px)

No overlap - events fit perfectly side-by-side
```

#### 5-Lane System (After):
```
Lane width (positioning): 390 / 5 = 78px
Card width (size): 390 / 3 = 126px (kept constant!)

Lane 0: Offset 0px,   Card width 126px  (0-126px)
Lane 1: Offset 78px,  Card width 126px  (78-204px)   ← Overlaps lane 0
Lane 2: Offset 156px, Card width 126px  (156-282px)  ← Overlaps lane 1
Lane 3: Offset 234px, Card width 126px  (234-360px)  ← Overlaps lane 2
Lane 4: Offset 312px, Card width 126px  (312-386px)  ← Overlaps lane 3

Overlap is expected and intentional!
```

### Visual Representation:

**3 Lanes (Before)**:
```
|-------Lane 0-------|-------Lane 1-------|-------Lane 2-------|
|     Event A        |     Event B        |     Event C        |
```

**5 Lanes (After)**:
```
|---L0---|---L1---|---L2---|---L3---|---L4---|
|  Event A  |        |        |        |        |
|     |  Event B  |        |        |        |
|     |     |  Event C  |        |        |
|     |     |     |  Event D  |        |
|     |     |     |     |  Event E  |
```

Events A & B overlap, B & C overlap, etc. This is expected!

---

## 🎨 Visual Changes

### Lane Indicator
- **Before**: 3 larger dots (3px × 20px), 24px wide
- **After**: 5 smaller dots (2px × 16px), 14px wide, tighter spacing

Example for event in lane 2:
```
Before: [ ][ ][■]        (3 dots)
After:  [ ][ ][■][ ][ ]  (5 dots)
```

---

## 🎯 Use Cases

### Scenario 1: Few Overlaps (1-3 events)
**Before & After**: Similar experience
- Events spread across available lanes
- No significant difference

### Scenario 2: Many Overlaps (4-5 events)
**Before**: 4th and 5th events forced into existing lanes, stacked
**After**: Each of 5 events gets its own lane
- Better visual distinction
- Cards will overlap but each has unique position

### Scenario 3: Heavy Overlaps (6+ events)
**Before**: All events squeezed into 3 lanes
**After**: All events squeezed into 5 lanes
- Slight improvement in positioning variety
- Still lots of overlap (unavoidable)

---

## 🧪 Testing Scenarios

### Test 1: Two Overlapping Events
**Setup**: Meeting A (2-3 PM), Meeting B (2:30-3:30 PM)

**Expected**:
- Meeting A → Lane 0 (leftmost)
- Meeting B → Lane 1 (offset by 1/5 screen width)
- Both events same width (~1/3 screen)
- **Slight overlap expected** ✓

### Test 2: Five Overlapping Events
**Setup**: 5 meetings all from 2-3 PM

**Expected**:
- Events in lanes 0, 1, 2, 3, 4
- Each offset by 1/5 screen width
- All same width (~1/3 screen)
- **Significant overlap expected** ✓
- Lane indicator shows which lane each event is in

### Test 3: Six Overlapping Events
**Setup**: 6 meetings all from 2-3 PM

**Expected**:
- First 5 events → lanes 0-4
- 6th event → forced back to an earlier lane (overlap algorithm decides)
- **Heavy overlap unavoidable** ✓

---

## ⚠️ Important Notes

### Overlap is Expected!
With 5 lanes but card width of ~1/3 screen:
- **This is by design per user request**: "event card width stays as it is now"
- Events positioned at 1/5 intervals but sized at 1/3 width = overlap
- Overlap percentage: ~40% (126px card at 78px intervals)

### Why This Design?
1. **Finer positioning**: 5 positions instead of 3
2. **Consistent card size**: Users familiar with current event card width
3. **More flexibility**: Better for drag-and-drop to specific lanes
4. **Visual distinction**: Lane indicator clearly shows which lane

### Alternative (Not Implemented)
If you want **no overlap**, event cards would need to be narrower:
```swift
// This would prevent overlap but make cards very narrow:
let cardWidth = laneWidth - 4  // Would be 390/5-4 = 74px (too narrow!)
```

---

## 📁 Files Modified

### CalendarTabView.swift
**Location**: `/Users/btessema/Desktop/CalAI/CalAI/CalAI/Features/Calendar/Views/CalendarTabView.swift`

**Changes**:
1. **Lines 2384-2391**: Updated lane positioning to use 5 lanes, kept card width at 1/3 screen
2. **Line 2925**: Increased max lane from 2 to 4 (lanes 0-4 = 5 lanes)
3. **Lines 2971-2979**: Updated lane indicator to show 5 dots instead of 3

---

## 🎉 Summary

### What Changed
- ✅ Calendar now has 5 lanes (0-4) instead of 3 (0-2)
- ✅ Event card width remains the same (~1/3 screen width)
- ✅ Events positioned at 1/5 screen width intervals
- ✅ Lane indicator updated to 5 dots
- ✅ Up to 5 overlapping events can each have unique lane

### Trade-offs
- ✅ **Pro**: More precise positioning (5 positions vs 3)
- ✅ **Pro**: Better for drag-and-drop to specific columns
- ⚠️ **Con**: Events will overlap more than before
- ⚠️ **Con**: Visual density increased with overlaps

### How to Verify
1. Rebuild app in Xcode
2. Create 5 events at the same time (e.g., all 2-3 PM)
3. Observe:
   - Each event positioned at different horizontal offset
   - Lane indicator shows 5 dots with one highlighted per event
   - Events overlap (expected behavior)
   - Each event still ~1/3 screen width

---

**Status**: ✅ **Complete and Ready for Testing**
**Date**: 2025-10-21
**Impact**: Medium - Changes visual layout behavior
**Lines Changed**: ~10 lines in CalendarTabView.swift

🎊 **Calendar now supports 5 lanes with consistent card width - overlap is expected and by design!**
