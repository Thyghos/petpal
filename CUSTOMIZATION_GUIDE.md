# Petpal - Customizable Home Screen & Health Tips Guide

## Overview

PawPal now features a fully customizable home screen with draggable tiles and personalized health tips tailored to your pet's species!

## Features Implemented

### 1. Customizable Home Tiles

**Location**: Settings → Customize Home Tiles

Users can now:
- ✅ **Reorder tiles** by dragging them in the customization screen
- ✅ **Hide/Show tiles** using the eye icon toggles
- ✅ **Reset to default** order and visibility
- ✅ Tiles are saved and persist between app sessions

**Available Tiles**:
1. Travel Mode
2. Documents
3. Reminders (with overdue badge)
4. Emergency QR
5. Health History
6. Food & Treats
7. Insurance
8. Encyclopedia
9. Dashboard

### 2. Health Tips of the Day/Week

**Location**: Home screen (when enabled)

Users receive personalized health tips based on:
- 🐶 **Pet Species**: Dog, Cat, Bird, Rabbit, or All Pets
- 📅 **Frequency**: Daily or Weekly (user configurable)
- 📚 **Categories**: Nutrition, Exercise, Grooming, Health, Safety, Training, Dental Care, Mental Health

**Features**:
- Tips automatically update based on frequency
- Expandable tip cards with "Read More" functionality
- Dismiss button to hide tip until next scheduled time
- Category badges for quick identification
- Beautiful gradient design matching app theme

**Tip Examples**:
- **Dogs**: Daily exercise needs, toxic food alerts, dental care
- **Cats**: Litter box hygiene, hydration tips, indoor enrichment
- **Birds**: Mental stimulation, fresh food guidelines
- **Rabbits**: Unlimited hay importance, exercise time
- **Universal**: Emergency preparedness, ID tags, temperature safety

### 3. Settings View

**Location**: Settings button in home header

New settings include:
- 🎨 **Customize Home Tiles** - Reorder and hide/show tiles
- 💡 **Health Tips Toggle** - Enable/disable tips
- ⏰ **Tip Frequency** - Choose daily or weekly
- ⚠️ **Disclaimer Controls** - Show/hide disclaimer banners
- ℹ️ **About Petpal** - App information and version
- ⭐ **Rate Petpal** - Link to App Store

## Technical Implementation

### New Models

1. **TilePreferences** (SwiftData)
   - Stores tile order and visibility
   - Persists user customization
   - Auto-initializes with default settings

2. **HealthTipPreferences** (SwiftData)
   - Tracks tip frequency and last shown date
   - Stores current tip index
   - Updates based on pet species

3. **HealthTip** (Struct)
   - Contains 30+ pre-written tips
   - Species-specific filtering
   - Category-based organization

### New Views

1. **SettingsView**
   - Main settings interface
   - List-based with sections
   - Integrates with existing disclaimers

2. **TileCustomizationView**
   - Drag-to-reorder interface
   - Toggle visibility controls
   - Real-time preview of changes

3. **HealthTipCard**
   - Expandable tip display
   - Gradient design matching app theme
   - Category badges and icons

4. **AboutView**
   - App information
   - Feature highlights
   - Version information

### Updated Views

**HomeView**:
- Added Settings button in header
- Integrated health tip card
- Dynamic tile rendering based on preferences
- Tile action handling system

## User Experience Flow

### Customizing Tiles

1. Tap Settings icon (gear) in home header
2. Select "Customize Home Tiles"
3. Tap "Edit" to enable drag-to-reorder
4. Drag tiles to desired position
5. Tap eye icons to hide/show tiles
6. Tap "Save" to apply changes

### Managing Health Tips

1. Tap Settings icon in home header
2. Toggle "Health Tips" on/off
3. Choose frequency (Daily/Weekly)
4. Tips appear on home screen automatically
5. Tap "X" to dismiss current tip
6. Tip updates based on frequency setting

### Viewing Health Tips

1. Tip appears on home screen between pet card and features
2. Read the preview (first 3 lines)
3. Tap "Read More" to expand full tip
4. View category badge for tip type
5. Tap "X" button to dismiss and mark as read

## Data Persistence

- **Tile Preferences**: Saved to SwiftData, persist between sessions
- **Health Tip State**: Last shown date and index saved
- **Settings**: Synchronized with AppStorage for quick access
- **Species Updates**: Tips automatically update when pet species changes

## Benefits

✨ **Personalization**: Users see only the tiles they use most
📱 **Efficiency**: Quicker access to frequently-used features
🎓 **Education**: Regular pet care tips improve pet health
🐾 **Species-Specific**: Relevant tips for each type of pet
⚡ **Performance**: Only visible tiles are rendered

## Future Enhancements

Potential additions:
- [ ] Drag-to-reorder directly on home screen
- [ ] Custom tile colors
- [ ] Push notifications for health tips
- [ ] User-submitted tips
- [ ] Favorite tips collection
- [ ] Share tips with friends
- [ ] More pet species (hamster, guinea pig, etc.)
- [ ] Seasonal tips (summer safety, winter care)

## Code Files

**New Files**:
- `TilePreferences.swift` - Tile data model and definitions
- `HealthTipPreferences.swift` - Health tip model and service
- `SettingsView.swift` - Settings interface
- `HealthTipCard.swift` - Tip display component

**Updated Files**:
- `HomeView.swift` - Integrated customization features
- `PetpalApp.swift` - Added new models to container

## Testing

To test the features:

1. **Tile Customization**:
   - Launch app → Tap Settings → Customize Home Tiles
   - Drag tiles to reorder
   - Hide some tiles
   - Save and verify home screen reflects changes
   - Close and reopen app to test persistence

2. **Health Tips**:
   - Go to Settings → Enable Health Tips
   - Choose Daily frequency
   - Return to home screen
   - Verify tip appears
   - Tap "Read More" to expand
   - Tap "X" to dismiss
   - Change pet species and verify tip updates

3. **Species-Specific Tips**:
   - Edit pet profile → Change species
   - View health tip → Should match species
   - Try Dog, Cat, Bird, Rabbit

---

**Made with ❤️ for pet parents!**
