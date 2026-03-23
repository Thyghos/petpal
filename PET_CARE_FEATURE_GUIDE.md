# Pet Care Services Feature Guide

## Overview

The new **Pet Care** tab in Travel Mode helps you find trusted dog walkers, pet sitters, and boarding facilities near your location.

## Features

### What's Included

The Pet Care section searches for:
- 🚶 **Dog Walking Services** - Professional dog walkers for daily exercise
- 🏠 **Pet Sitting** - In-home pet care while you're away
- 🛏️ **Overnight Boarding** - Facility-based pet boarding
- 📍 **Drop-in Visits** - Quick check-ins for your pets
- 📱 **GPS Tracking** - Services that offer real-time walk tracking
- ✅ **Insured & Bonded** - Licensed and insured professionals

### Icon & Color

- **Icon**: `figure.walk` (person walking symbol)
- **Color**: Teal
- **Display Name**: "Dog Walking & Pet Sitting"

## How to Use

### 1. Access Pet Care Tab

```
1. Open PawPal app
2. Navigate to Travel Mode
3. Tap the "Pet Care" tab (5th tab)
```

### 2. View Results

The tab will automatically search for pet care services within 10km of your location and display:
- Service name
- Distance from your location
- Rating (if available)
- Available amenities
- Contact information

### 3. Interact with Results

For each pet care service, you can:
- **View on Map** - See location on the map tab
- **Get Directions** - Plan route to the facility
- **Call** - Contact them directly (if phone number available)

## Example Services

The system searches for services like:
- Rover Dog Walking
- Wag! Pet Care
- Fetch! Pet Services
- Pawsitive Walks
- Trusted Tails Pet Sitting
- Happy Paws Pet Care
- The Dog Butler
- PetSitters Plus

## Search Terms

The feature searches Apple Maps, Google Places (if configured), and BringFido (if configured) using these terms:
- "dog walker pet sitter"
- "pet boarding"
- Related pet care services

## Amenities Displayed

Common amenities shown for pet care services:
- Dog Walking
- Pet Sitting
- Overnight Boarding
- Drop-in Visits
- GPS Tracking
- Insured & Bonded
- Background Checked
- Reviews & References

## Technical Details

### Service Integration

**Apple Maps Search:**
- Query: "dog walker pet sitter"
- Radius: 10km (configurable)

**Google Places API:**
- Type: `pet_store` (general pet services)
- Keyword: "pet friendly"

**BringFido API:**
- Category: "boarding"

### Mock Data for Testing

When `useMockData = true`, the system generates realistic test data including:
- 8 sample pet care services
- Random locations within search radius
- Sample amenities and ratings
- Mock contact information

## User Interface

### Header Card

A teal-themed information card displays:
```
🚶 Dog Walking & Pet Sitting
   Professional pet care services

Find trusted dog walkers, pet sitters, and 
boarding facilities near you.
```

### Service Cards

Each service shows:
```
┌─────────────────────────────────────┐
│ Service Name            ⭐ 4.8      │
│ Pet Care               📍 0.5 mi    │
│                                     │
│ 🏷️ [Dog Walking] [Pet Sitting]     │
│                                     │
│ [View on Map] [Directions] [📞]    │
└─────────────────────────────────────┘
```

### Empty State

If no services are found:
```
🚶 No Pet Care Services Found

Try searching in a different area 
or check back later

        [Search Again]
```

## Best Practices

### For Users

1. **Set Location**: Make sure location services are enabled
2. **Urban Areas**: More results in cities
3. **Check Reviews**: Look for high-rated services
4. **Call Ahead**: Contact services to verify availability
5. **Book Early**: Popular services fill up quickly

### For Developers

1. **API Keys**: Configure Google Places API for better results
2. **Mock Data**: Use for testing without location services
3. **Error Handling**: Service handles missing location gracefully
4. **Caching**: Consider caching results for better performance

## Code Integration

### Adding Pet Care Type

The new `petCare` case was added to `PlaceType` enum:

```swift
enum PlaceType: String, CaseIterable {
    // ... existing cases
    case petCare = "Pet Care"
    
    var icon: String {
        case .petCare: return "figure.walk"
        // ... other cases
    }
    
    var displayName: String {
        case .petCare: return "Dog Walking & Pet Sitting"
        // ... other cases
    }
}
```

### Service Implementation

Search query for pet care:

```swift
case .petCare:
    return "dog walker pet sitter"
```

Default amenities:

```swift
case .petCare:
    return ["Dog Walking", "Pet Sitting", "Overnight Boarding", "Drop-in Visits"]
```

## Future Enhancements

Potential improvements:
- [ ] Filter by service type (walking vs sitting vs boarding)
- [ ] Booking integration
- [ ] Calendar availability
- [ ] Direct messaging with providers
- [ ] Review and rating system
- [ ] Background check verification display
- [ ] Price comparison
- [ ] Favorite providers list
- [ ] Recurring service scheduling
- [ ] Payment integration

## Troubleshooting

### No Results Found

**Causes:**
- Not enough pet care services in your area
- Location services disabled
- Search radius too small

**Solutions:**
- Try a different location
- Increase search radius in code
- Use mock data for testing
- Enable location services

### Services Not Loading

**Checks:**
1. Location permission granted?
2. Simulator location set?
3. Console showing search logs?
4. Try enabling mock data

### Map Integration

All pet care services appear on the Map tab with:
- Teal-colored markers
- `figure.walk` icon
- Tappable for details

## Related Files

- `PetFriendlyPlacesService.swift` - Service logic
- `TravelModeView.swift` - UI implementation
- `MockPetFriendlyData.swift` - Test data
- `APIConfiguration.swift` - API key configuration

## Testing Checklist

- [ ] Pet Care tab appears in picker
- [ ] Tapping tab loads results
- [ ] Services display correctly
- [ ] Can view service on map
- [ ] Can get directions
- [ ] Can call service (if phone available)
- [ ] Empty state shows when no results
- [ ] Mock data works when enabled
- [ ] Teal color scheme applied
- [ ] Icon displays correctly

## Example Usage

```swift
// Load pet care services
await loadPetCare()

// Filter for pet care places
let petCareServices = placesService.places.filter { $0.type == .petCare }

// Display with appropriate color
let color = colorForPlaceType(.petCare) // Returns .teal
```

---

**Pro Tip**: Enable mock data during development for instant testing without needing actual location or API results!
