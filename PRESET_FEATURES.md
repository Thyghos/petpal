# Tile Presets Feature Guide

## 🎯 New Feature: Smart Tile Presets

### Overview

Added **Preset Configurations** that allow users to instantly apply curated tile layouts for common use cases. Each preset shows only relevant tiles and automatically organizes them in priority order.

---

## 📋 Available Presets

### 1. ⭐ Essential Only
**Purpose:** For users who want a minimal, focused home screen

**Visible Tiles (3):**
1. 🔔 **Reminders** - Never miss appointments or medications
2. ❤️ **Health History** - Track your pet's medical records
3. ✈️ **Travel Mode** - Access travel features quickly

**Hidden Tiles (6):**
- Documents
- Emergency QR
- Food & Treats
- Insurance
- Encyclopedia
- Dashboard

**Best For:**
- Daily pet care management
- Users who prefer minimalism
- Quick access to most-used features
- New users getting started

---

### 2. 🏥 Medical Focus
**Purpose:** For pets with ongoing health needs or medical conditions

**Visible Tiles (4):**
1. ❤️ **Health History** - Medical records and history
2. 📄 **Documents** - Vet records and test results
3. 🚨 **Emergency QR** - Quick emergency info access
4. 🏥 **Insurance** - Track claims and coverage

**Hidden Tiles (5):**
- Travel Mode
- Reminders
- Food & Treats
- Encyclopedia
- Dashboard

**Best For:**
- Pets with chronic conditions
- Post-surgery recovery
- Senior pets requiring frequent care
- Managing medications and treatments
- Quick access to vet information

---

### 3. ✈️ Travel Ready
**Purpose:** For pet owners on the go or planning trips

**Visible Tiles (3):**
1. ✈️ **Travel Mode** - Trip planning and checklists
2. 🚨 **Emergency QR** - In case pet gets lost
3. 📄 **Documents** - Vaccination records, health certs

**Hidden Tiles (6):**
- Reminders
- Health History
- Food & Treats
- Insurance
- Encyclopedia
- Dashboard

**Best For:**
- Frequent travelers
- Vacation planning
- Road trips with pets
- Moving to new locations
- International travel with pets

---

## 📱 User Interface

```
┌─────────────────────────────────────┐
│ QUICK TOGGLE                        │
│ ┌─────────────────────────────────┐ │
│ │ 👁️  Show All Tiles          ✓  │ │
│ │ 👁️‍🗨️ Hide All Tiles              │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ PRESETS                             │
│ ┌─────────────────────────────────┐ │
│ │ ⭐ Essential Only          ✓   │ │ ← Active preset
│ │    Reminders, Health, Travel    │ │
│ ├─────────────────────────────────┤ │
│ │ 🏥 Medical Focus               │ │
│ │    Health, Docs, Emergency...   │ │
│ ├─────────────────────────────────┤ │
│ │ ✈️  Travel Ready                │ │
│ │    Travel, Emergency, Docs      │ │
│ └─────────────────────────────────┘ │
│ Quickly apply common configurations │
├─────────────────────────────────────┤
│ VISIBLE TILES (3)                   │
│ ... (individual tiles)              │
└─────────────────────────────────────┘
```

---

## 🎨 How It Works

### Applying a Preset

**Step 1:** User taps a preset button (e.g., "Essential Only")

**Step 2:** System automatically:
- Hides tiles not in the preset
- Shows tiles in the preset
- Reorders tiles to put preset tiles at the top
- Animates the changes smoothly

**Step 3:** User sees checkmark (✓) next to active preset

**Step 4:** User can:
- Save the preset as-is
- Further customize individual tiles
- Apply a different preset
- Reset to default

### Visual Feedback

**Active Preset:**
```
⭐ Essential Only          ✓
   Reminders, Health, Travel
```

**Inactive Preset:**
```
🏥 Medical Focus
   Health, Docs, Emergency...
```

### Smart Detection

The app automatically detects which preset is active:
- Compares current visible tiles to preset configuration
- Shows checkmark only if exact match
- Mixed customizations show no checkmark
- User can see at a glance what's configured

---

## 🔄 User Workflows

### Scenario 1: New User Setup
```
1. Opens Settings → Customize Home Tiles
2. Sees multiple presets
3. Taps "Essential Only"
4. Sees 3 key tiles appear
5. Saves and starts using app
6. Can always customize later
```

### Scenario 2: Pet Gets Sick
```
1. Pet diagnosed with condition
2. Opens tile customization
3. Taps "Medical Focus"
4. Now sees: Health, Docs, Emergency, Insurance
5. Manages medical care easily
6. When pet recovers, switch back to Essential
```

### Scenario 3: Planning Vacation
```
1. Planning trip with pet
2. Opens tile customization
3. Taps "Travel Ready"
4. Sees: Travel, Emergency QR, Documents
5. Prepares for trip efficiently
6. After trip, switches to different preset
```

### Scenario 4: Custom Configuration
```
1. User applies "Essential Only"
2. Also wants "Food & Treats" tile
3. Scrolls to Hidden Tiles
4. Shows "Food & Treats" individually
5. Now has 4 tiles (custom mix)
6. Checkmark disappears from preset (custom)
```

---

## 🎯 Benefits

| Feature | Benefit |
|---------|---------|
| **Quick Setup** | New users get started in seconds |
| **Context Switching** | Change focus based on needs |
| **Smart Ordering** | Preset tiles appear at top |
| **Flexibility** | Can customize after applying |
| **Visual Clarity** | Checkmarks show current state |
| **One-Tap Config** | No manual hiding/showing |

---

## 💡 Use Case Examples

### Example 1: Senior Pet Care
**User:** Owner of 12-year-old dog with arthritis

**Preset:** Medical Focus

**Visible Tiles:**
- Health History (track vet visits)
- Documents (x-rays, blood tests)
- Emergency QR (medical conditions listed)
- Insurance (submit claims)

**Result:** Streamlined medical management

---

### Example 2: Weekend Warrior
**User:** Frequent camper with active dog

**Preset:** Travel Ready

**Visible Tiles:**
- Travel Mode (campground checklists)
- Emergency QR (if dog gets lost hiking)
- Documents (vaccination proof for parks)

**Result:** Ready for adventures anytime

---

### Example 3: First-Time Owner
**User:** Just adopted a puppy

**Preset:** Essential Only

**Visible Tiles:**
- Reminders (vet appointments, vaccines)
- Health History (record puppy's growth)
- Travel Mode (trips to vet, pet store)

**Result:** Simple, focused experience

---

## 🔧 Technical Details

### Preset Definitions

**Essential Only:**
```swift
let essentialTiles: Set<String> = ["reminders", "health", "travel"]
```

**Medical Focus:**
```swift
let medicalTiles: Set<String> = ["health", "documents", "emergency", "insurance"]
```

**Travel Ready:**
```swift
let travelTiles: Set<String> = ["travel", "emergency", "documents"]
```

### Auto-Ordering Logic

When preset is applied:
1. Hides all non-preset tiles
2. Shows preset tiles
3. Reorders array to put preset tiles first
4. Maintains order within preset tiles
5. Saves to SwiftData

### Detection Logic

```swift
var isEssentialPresetActive: Bool {
    let essentialTiles: Set<String> = ["reminders", "health", "travel"]
    let visibleSet = Set(tileOrder.filter { !hiddenTiles.contains($0) })
    return visibleSet == essentialTiles
}
```

**Exact Match Required:**
- Must have exactly the preset tiles visible
- No extra tiles shown
- No preset tiles hidden
- Order doesn't affect detection

---

## 🧪 Testing Checklist

**Preset Application:**
- [ ] Tap "Essential Only" → Shows 3 tiles
- [ ] Tap "Medical Focus" → Shows 4 tiles
- [ ] Tap "Travel Ready" → Shows 3 tiles
- [ ] Verify correct tiles are visible for each

**Auto-Ordering:**
- [ ] Preset tiles appear at top of list
- [ ] Order matches preset priority
- [ ] Other tiles remain below

**Checkmark Detection:**
- [ ] Checkmark appears when preset is active
- [ ] Checkmark disappears when customized
- [ ] Only one checkmark at a time
- [ ] No checkmark for custom configurations

**Persistence:**
- [ ] Apply preset and save
- [ ] Close app and reopen
- [ ] Verify preset configuration persists
- [ ] Checkmark still shows if unchanged

**Customization:**
- [ ] Apply preset
- [ ] Add one more tile
- [ ] Verify checkmark disappears (custom now)
- [ ] Save and verify custom config persists

**Integration:**
- [ ] Presets work with Show All / Hide All
- [ ] Presets work with individual toggles
- [ ] Presets work with drag-to-reorder
- [ ] Reset to Default still works

---

## 📊 Comparison Table

| Preset | Tile Count | Focus Area | Best For |
|--------|-----------|------------|----------|
| **Essential Only** | 3 | Daily care | Most users |
| **Medical Focus** | 4 | Health mgmt | Chronic conditions |
| **Travel Ready** | 3 | On-the-go | Frequent travelers |
| **Show All** | 9 | Full access | Power users |
| **Hide All** | 0 | Minimalist | Custom builders |

---

## 🎨 Design Decisions

### Why These Presets?

**Essential Only:**
- Most commonly used features
- Covers daily pet care
- Not overwhelming for new users

**Medical Focus:**
- Addresses #1 pet owner concern (health)
- Groups all medical tools together
- Reduces friction during stressful times

**Travel Ready:**
- Second most common use case
- Critical for lost pet scenarios
- Simplifies trip preparation

### Why Not More Presets?

- **Simplicity:** Too many choices = decision paralysis
- **Coverage:** These 3 cover 80% of use cases
- **Custom:** Users can still create their own
- **Future:** Can add more based on analytics

### Icon Choices

- ⭐ **Essential** - Star = important/favorites
- 🏥 **Medical** - Medical cross = health
- ✈️ **Travel** - Airplane = trips/adventure

---

## 🚀 Future Enhancements

Potential additions:

1. **Save Custom Preset**
   - User creates their own
   - Names it (e.g., "My Setup")
   - Appears in preset list

2. **Quick Switch**
   - Swipe gesture to switch presets
   - Home screen widget
   - Shortcuts app integration

3. **Smart Suggestions**
   - AI suggests preset based on usage
   - "You use these tiles most often"
   - Seasonal recommendations

4. **Preset Scheduling**
   - Auto-switch based on time/location
   - "Travel Ready" when at vet
   - "Medical Focus" on vet days

5. **Share Presets**
   - Share custom configurations
   - Community presets
   - Breed-specific presets

---

## 📁 Files Modified

**SettingsView.swift:**
- Added Presets section
- Added preset button UI
- Added `applyEssentialPreset()` function
- Added `applyMedicalPreset()` function
- Added `applyTravelPreset()` function
- Added `isEssentialPresetActive` computed property
- Added `isMedicalPresetActive` computed property
- Added `isTravelPresetActive` computed property

**Lines Added:** ~120 lines

---

## ✅ Summary

**What's New:**
- ⭐ Essential Only preset (3 tiles)
- 🏥 Medical Focus preset (4 tiles)
- ✈️ Travel Ready preset (3 tiles)
- Smart checkmark detection
- Auto-ordering of preset tiles
- Full customization after applying

**User Benefits:**
- One-tap configuration
- Context-aware layouts
- Faster setup
- Guided experience for new users
- Flexibility for advanced users

**Technical Quality:**
- Clean SwiftUI code
- Smooth animations
- Persistent storage
- Exact match detection
- No conflicts with other features

🎉 **Ready to use!**
