# Travel Mode - UI Overview

## What You'll See

### 1. Map View (Tab 1)
```
┌─────────────────────────────────────┐
│  Search: "Search location..."       │
├─────────────────────────────────────┤
│ [Map] [Hotels] [Dining] [Parks]     │
├─────────────────────────────────────┤
│                                     │
│         📍 Your Location            │
│                                     │
│      🏥 Happy Tails Vet             │
│                                     │
│      🏨 Kimpton Hotel               │
│      (Google)                       │
│                                     │
│      🍽️ Barking Dog Cafe           │
│      (BringFido)                    │
│                                     │
│      🌳 Dog Park                    │
│                                     │
│      🗺️ Route shown in blue        │
│                                     │
├─────────────────────────────────────┤
│ [🏥 Nearest Vet          →]        │
│ [📍 My Location          →]        │
└─────────────────────────────────────┘
```

### 2. Hotels Tab
```
┌─────────────────────────────────────┐
│ Kimpton Pet-Friendly Hotel          │
│ Hotel                  ⭐ 4.8       │
│ 🌐 Google              1.2 mi       │
│                                     │
│ [Pet Beds] [Dog Park] [Pet Spa]    │
│                                     │
│ [🗺️ View Map] [➡️ Directions] [📞] │
├─────────────────────────────────────┤
│ La Quinta Inn & Suites              │
│ Hotel                  ⭐ 4.5       │
│ 🍎 Apple Maps          2.3 mi       │
│                                     │
│ [Pet Beds] [No Fee] [Welcome]      │
│                                     │
│ [🗺️ View Map] [➡️ Directions] [📞] │
├─────────────────────────────────────┤
│ The Pawington Hotel                 │
│ Hotel                  ⭐ 4.9       │
│ 🐾 BringFido           3.1 mi       │
│                                     │
│ [Dog Park] [Pet Spa] [Sitting]     │
│                                     │
│ [🗺️ View Map] [➡️ Directions] [📞] │
└─────────────────────────────────────┘
```

### 3. Dining Tab
```
┌─────────────────────────────────────┐
│ The Barking Dog Cafe                │
│ Restaurant             ⭐ 4.7       │
│ 🐾 BringFido           0.8 mi       │
│                                     │
│ [Outdoor] [Water Bowls] [Menu]     │
│                                     │
│ [🗺️ View Map] [➡️ Directions] [📞] │
├─────────────────────────────────────┤
│ Pawsitive Dining                    │
│ Restaurant             ⭐ 4.6       │
│ 🌐 Google              1.5 mi       │
│                                     │
│ [Patio] [Treats] [Water Bowls]     │
│                                     │
│ [🗺️ View Map] [➡️ Directions] [📞] │
└─────────────────────────────────────┘
```

### 4. Parks Tab
```
┌─────────────────────────────────────┐
│ Wagging Tails Dog Park              │
│ Park                   ⭐ 4.9       │
│ 🍎 Apple Maps          0.5 mi       │
│                                     │
│ [Off-Leash] [Water] [Agility]      │
│                                     │
│ [🗺️ View Map] [➡️ Directions]      │
├─────────────────────────────────────┤
│ Bark Central Park                   │
│ Park                   ⭐ 4.8       │
│ 🌐 Google              1.2 mi       │
│                                     │
│ [Off-Leash] [Small Dog] [Benches]  │
│                                     │
│ [🗺️ View Map] [➡️ Directions]      │
└─────────────────────────────────────┘
```

### 5. Route Details Sheet
```
┌─────────────────────────────────────┐
│ Route Details               [Done]  │
├─────────────────────────────────────┤
│ Destination                         │
│ ━━━━━━━━━━                          │
│ Happy Tails Veterinary Clinic       │
│ 123 Main Street, San Francisco      │
│ 📞 (555) 123-4567                   │
│                                     │
│ Route Information                   │
│ ━━━━━━━━━━━━━━━━━                   │
│ Distance:        2.3 mi             │
│ Travel Time:     8 min              │
│                                     │
│ Actions                             │
│ ━━━━━━━                             │
│ 🗺️ Open in Apple Maps               │
│                                     │
│ Directions                          │
│ ━━━━━━━━━━                          │
│ 1. Head north on Oak St - 0.2 mi   │
│ 2. Turn right onto Main St - 1.5mi │
│ 3. Destination on left - 0.6 mi    │
└─────────────────────────────────────┘
```

## Color Coding

### Map Markers
- 📍 **Blue**: Your location
- 🏥 **Brand Blue**: Veterinary
- 🏨 **Purple**: Hotels
- 🍽️ **Brand Orange**: Restaurants
- 🌳 **Brand Green**: Parks
- 🛍️ **Pink**: Pet Stores
- ✂️ **Cyan**: Grooming
- 🏠 **Indigo**: Daycare

### Source Badges
- 🍎 **Apple Maps**: Gray text
- 🌐 **Google**: Secondary text
- 🐾 **BringFido**: Secondary text

### Action Buttons
- **Blue**: Map/Navigation actions
- **Green**: Directions/Route
- **Orange**: Call/Contact

## Loading States

### While Searching
```
┌─────────────────────────────────────┐
│        ⏳ Searching for             │
│     pet-friendly hotels...          │
└─────────────────────────────────────┘
```

### No Results
```
┌─────────────────────────────────────┐
│          🏨                         │
│      No Hotels Found                │
│                                     │
│  Try searching in a different area  │
└─────────────────────────────────────┘
```

## Interactive Elements

### Tap Actions
1. **Place Card → View Map**: Switches to map tab, centers on location
2. **Place Card → Directions**: Calculates route, shows route sheet
3. **Place Card → Call**: Opens phone dialer
4. **Map Marker**: Selects place, zooms to location
5. **Search Bar → Submit**: Searches all sources for text
6. **Quick Action → Nearest Vet**: Finds and shows closest vet
7. **Quick Action → My Location**: Centers map on user

### Navigation Flow
```
Hotels Tab
   ↓ [View Map]
Map Tab (centered on hotel)
   ↓ [Directions]
Route Sheet
   ↓ [Open in Maps]
Apple Maps App
```

## Data Sources Display

Each place shows its source with an icon:

| Source | Icon | Display |
|--------|------|---------|
| Apple Maps | 🍎 | "Apple Maps" |
| Google Places | 🌐 | "Google" |
| BringFido | 🐾 | "BringFido" |

## Smart Features

### Automatic Behaviors
1. **Auto-switch to Map**: When finding nearest vet, automatically switches to map tab
2. **Auto-zoom**: Selecting a place zooms map to show it clearly
3. **Route fitting**: When planning route, map adjusts to show entire path
4. **Distance sorting**: All results sorted by closest first
5. **Deduplication**: Same place from different sources shown once

### Contextual Actions
- **Vet Search**: Shows all vets with emergency care highlighted
- **Hotel Cards**: Include phone for booking
- **Restaurant Cards**: Focus on outdoor seating amenities
- **Park Cards**: No phone number (typically don't call parks)

## Responsive Design

### iPhone
- Full-screen map
- Scrollable place lists
- Bottom sheet for routes

### iPad
- Side-by-side map and list (future)
- Larger cards with more info
- Split view support

---

## Example User Journey

1. User opens Travel Mode
2. Taps "Hotels" tab
3. Sees loading indicator
4. Results appear sorted by distance
5. User taps "View Map" on a hotel
6. Switches to map tab, sees hotel pin
7. Taps "Nearest Vet" for peace of mind
8. Map shows all nearby vets
9. Taps "Directions" on closest vet
10. Route sheet appears with turn-by-turn
11. Taps "Open in Apple Maps"
12. Navigates to vet with full directions

Total time: ~30 seconds to find everything needed! 🎉
