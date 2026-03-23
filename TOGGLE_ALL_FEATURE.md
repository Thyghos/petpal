# Toggle All Tiles Feature - Update

## 🎯 New Feature: Show All / Hide All Tiles

### What's New?

Added **Quick Actions** section to the Tile Customization screen that lets you:

- ✅ **Show All Tiles** - Make all tiles visible with one tap
- ✅ **Hide All Tiles** - Hide all tiles from home screen with one tap
- ✅ **Visual Feedback** - Checkmarks show current state
- ✅ **Counter Badges** - See how many tiles are visible/hidden

### UI Layout

```
┌─────────────────────────────────────┐
│ Cancel  Customize Tiles  Edit  Save│
├─────────────────────────────────────┤
│ QUICK ACTIONS                       │
│ ┌─────────────────────────────────┐ │
│ │ 👁️  Show All Tiles          ✓  │ │
│ │    Make all tiles visible       │ │
│ ├─────────────────────────────────┤ │
│ │ 👁️‍🗨️ Hide All Tiles              │ │
│ │    Hide all tiles from home     │ │
│ └─────────────────────────────────┘ │
│ Quickly toggle all tiles on or off. │
│                                     │
│ VISIBLE TILES (9)                   │
│ ┌─────────────────────────────────┐ │
│ │ ☰ ✈️  Travel Mode          👁️‍🗨️│ │
│ │ ☰ 📄  Documents            👁️‍🗨️│ │
│ │ ☰ 🔔  Reminders            👁️‍🗨️│ │
│ │ ... (drag to reorder)           │ │
│ └─────────────────────────────────┘ │
│ Drag to reorder. Tap eye to hide.  │
│                                     │
│ HIDDEN TILES (0)                    │
│ (appears when tiles are hidden)     │
└─────────────────────────────────────┘
```

### How It Works

**Show All Tiles Button:**
- Taps the button → All tiles become visible
- Checkmark appears when all tiles are shown
- Green color indicates "show" action

**Hide All Tiles Button:**
- Taps the button → All tiles become hidden
- Checkmark appears when all tiles are hidden
- Orange color indicates "hide" action
- Home screen will show no feature tiles

**Counters:**
- "Visible Tiles (9)" - Shows how many tiles are currently visible
- "Hidden Tiles (3)" - Shows how many tiles are hidden
- Updates in real-time as you toggle tiles

### Use Cases

**1. Minimalist Mode**
- Tap "Hide All Tiles"
- Home screen shows only pet card and health tip
- Perfect for users who prefer a clean interface

**2. Start Fresh**
- Tap "Hide All Tiles" 
- Individually show only tiles you need
- Customize from scratch

**3. Reset Everything**
- Tap "Show All Tiles"
- See all available features
- Then customize as needed

**4. Quick Switch**
- Hide all tiles for distraction-free mode
- Show all tiles when you need full functionality
- One-tap toggle between modes

### Benefits

✨ **Speed** - Toggle all tiles in one tap vs. individual toggles  
🎨 **Flexibility** - Start with all on or all off  
📱 **Clean Interface** - Easily create minimalist home screen  
🔄 **Quick Reset** - Return to full view anytime  

### Code Changes

**File:** `SettingsView.swift`

**Added:**
- Quick Actions section at the top
- "Show All Tiles" button
- "Hide All Tiles" button
- Tile counters in section headers
- Visual checkmarks for current state

**Features:**
```swift
// Show all tiles
Button {
    withAnimation {
        hiddenTiles = []
    }
}

// Hide all tiles
Button {
    withAnimation {
        hiddenTiles = tileOrder
    }
}

// Visual feedback
if allTilesVisible {
    Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(Color("BrandGreen"))
}
```

### Visual States

**All Tiles Visible:**
- Show All button: ✓ (green checkmark)
- Hide All button: (no checkmark)
- Visible Tiles: (9)
- Hidden Tiles: Section doesn't appear

**All Tiles Hidden:**
- Show All button: (no checkmark)
- Hide All button: ✓ (orange checkmark)
- Visible Tiles: (0)
- Hidden Tiles: (9)

**Mixed State:**
- Show All button: (no checkmark)
- Hide All button: (no checkmark)
- Visible Tiles: (5)
- Hidden Tiles: (4)

### User Experience Flow

```
1. User opens Settings → Customize Home Tiles
   ↓
2. Sees Quick Actions at the top
   ↓
3. Taps "Hide All Tiles"
   ↓
4. All 9 tiles move to Hidden section
   ↓
5. Home screen updates (no feature tiles shown)
   ↓
6. User taps "Show All Tiles"
   ↓
7. All tiles move back to Visible section
   ↓
8. Home screen shows all 9 tiles again
```

### Testing

To test the new feature:

1. ✅ Open Settings → Customize Home Tiles
2. ✅ Tap "Show All Tiles" → All tiles visible
3. ✅ Verify checkmark appears on Show All
4. ✅ Tap "Hide All Tiles" → All tiles hidden
5. ✅ Verify checkmark appears on Hide All
6. ✅ Save and check home screen → No tiles shown
7. ✅ Go back, tap "Show All Tiles"
8. ✅ Save and verify all tiles reappear on home
9. ✅ Verify counters update correctly
10. ✅ Test with mixed state (some visible, some hidden)

### Edge Cases Handled

- ✅ Empty home screen when all tiles hidden
- ✅ Smooth animations with `withAnimation`
- ✅ Real-time counter updates
- ✅ Checkmarks show correct state
- ✅ Hidden Tiles section only appears when tiles are hidden
- ✅ Individual eye buttons still work alongside Quick Actions

### Integration with Existing Features

**Works with:**
- Individual hide/show buttons
- Drag-to-reorder
- Reset to Default
- Save/Cancel functionality
- Data persistence

**Doesn't interfere with:**
- Tile ordering
- Individual preferences
- Edit mode
- Other settings

---

## Summary

**What changed:**
- Added "Quick Actions" section with Show All / Hide All buttons
- Added counters to section headers
- Added checkmark indicators for current state
- Improved user experience for bulk operations

**Files modified:**
- `SettingsView.swift` - TileCustomizationView

**Lines added:**
- ~80 lines of new UI code

**User benefit:**
- One-tap control over all tiles
- Faster customization
- More flexible workflows
- Better visual feedback

🎉 **Feature complete and ready to use!**
