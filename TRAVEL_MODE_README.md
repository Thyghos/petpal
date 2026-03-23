# PawPal Travel Mode - Pet-Friendly Places Integration

## Overview

The Travel Mode feature integrates multiple data sources to provide comprehensive pet-friendly location information:

- **Apple Maps** (Built-in, no API key required)
- **Google Places API** (Optional, requires API key)
- **BringFido API** (Optional, requires partnership)

## Features

### Multi-Source Data Aggregation
- Combines results from Apple Maps, Google Places, and BringFido
- Removes duplicates automatically
- Sorts by distance from user location
- Shows data source badge on each listing

### Place Types Supported
- 🏥 Veterinary Clinics
- 🏨 Pet-Friendly Hotels
- 🍽️ Pet-Friendly Restaurants
- 🌳 Dog Parks
- 🛍️ Pet Stores
- ✂️ Pet Grooming
- 🏠 Pet Daycare

### Smart Features
- Real-time location-based search
- Automatic deduplication across sources
- Distance calculation and sorting
- Route planning and turn-by-turn directions
- Direct calling integration
- "View on Map" quick navigation

## Setup Instructions

### 1. Google Places API (Recommended)

Google Places provides excellent pet-friendly filtering and comprehensive business data.

#### Steps:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Places API**:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Places API"
   - Click "Enable"

4. Create an API Key:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Copy your key

5. (Recommended) Restrict the API Key:
   - Click on your key to edit
   - Under "Application restrictions", select "iOS apps"
   - Add your app's bundle identifier
   - Under "API restrictions", select "Restrict key"
   - Choose "Places API"
   - Save

6. Add to your project:
   - Open `Info.plist`
   - Add a new row:
     ```xml
     <key>GOOGLE_PLACES_API_KEY</key>
     <string>YOUR_ACTUAL_API_KEY_HERE</string>
     ```

#### Pricing:
- Google offers $200 free credit per month
- Places Nearby Search: $32 per 1000 requests
- Most users will stay within free tier

### 2. BringFido API (Optional, Best Pet-Specific Data)

BringFido specializes in pet-friendly travel and has the most accurate pet amenity information.

#### Steps:
1. Visit [BringFido Business Solutions](https://www.bringfido.com/business/)
2. Contact their team for API access (may require partnership)
3. Once approved, you'll receive an API key
4. Add to `Info.plist`:
   ```xml
   <key>BRINGFIDO_API_KEY</key>
   <string>YOUR_BRINGFIDO_KEY</string>
   ```

**Note:** BringFido API access typically requires a business partnership agreement.

### 3. Alternative: Apple Maps Only (No Setup Required)

If you don't configure external APIs, the app will work with Apple Maps data only:
- No setup required
- No API costs
- Good basic functionality
- Limited pet-specific filtering

## Usage

### In Code

The service is automatically configured in `TravelModeView`:

```swift
@StateObject private var placesService = PetFriendlyPlacesService(
    googleAPIKey: APIConfiguration.googlePlacesAPIKey,
    bringFidoAPIKey: APIConfiguration.bringFidoAPIKey
)
```

### Searching for Places

```swift
// Search for pet-friendly hotels within 10km
await placesService.searchNearby(
    location: userLocation,
    type: .hotel,
    radius: 10000
)

// Access results
for place in placesService.places {
    print("\(place.name) - \(place.source)")
}
```

### Available Place Types

```swift
enum PlaceType {
    case veterinary
    case hotel
    case restaurant
    case park
    case petStore
    case grooming
    case daycare
}
```

## Security Best Practices

### ⚠️ IMPORTANT: Protecting Your API Keys

1. **Never commit API keys to version control**
   ```bash
   # Add to .gitignore
   **/Info.plist
   APIConfiguration.swift
   ```

2. **Use environment-specific configurations**
   - Development keys for testing
   - Production keys for release
   - Different keys per environment

3. **Consider a backend proxy** (Production apps)
   - Create a backend service that calls these APIs
   - Your iOS app calls your backend
   - Backend handles API keys securely
   - Prevents key exposure and abuse

4. **Enable API key restrictions**
   - Restrict to specific bundle IDs
   - Limit to required APIs only
   - Monitor usage in Google Cloud Console

5. **Use Xcode configuration files**
   ```swift
   // Debug.xcconfig
   GOOGLE_PLACES_API_KEY = dev_key_here
   
   // Release.xcconfig  
   GOOGLE_PLACES_API_KEY = prod_key_here
   ```

## Alternative Data Sources

If BringFido API is not available, consider:

### Yelp Fusion API
- Free tier: 5000 calls/day
- Has "dogs_allowed" attribute
- Excellent restaurant/business data
- [Get Started](https://www.yelp.com/developers)

### Foursquare Places API
- Free tier: 100,000 calls/month
- Good venue categorization
- [Documentation](https://developer.foursquare.com/)

### TripAdvisor Content API
- Requires partnership
- Excellent travel-related data
- [Contact TripAdvisor](https://www.tripadvisor.com/developers)

## Architecture

### Data Flow

```
User Location
    ↓
PetFriendlyPlacesService
    ├── Apple Maps Search
    ├── Google Places Search (if API key)
    └── BringFido Search (if API key)
    ↓
Combine & Deduplicate Results
    ↓
Sort by Distance
    ↓
Display in UI
```

### Models

```swift
struct PetFriendlyPlace {
    let id: String
    let name: String
    let type: PlaceType
    let coordinate: CLLocationCoordinate2D
    let amenities: [String]
    let rating: Double?
    let distance: Double?
    let source: PlaceSource // Apple, Google, or BringFido
}
```

## Testing

### Test without API Keys
The app works perfectly with Apple Maps only - just don't configure any keys.

### Test with Mock Data
```swift
// In development, you can inject mock service
let mockService = PetFriendlyPlacesService(
    googleAPIKey: nil,
    bringFidoAPIKey: nil
)
mockService.places = mockPlaces
```

### Monitor API Usage
- Check Google Cloud Console for usage
- Set up budget alerts
- Monitor for unusual patterns

## Troubleshooting

### "No results found"
- Check location permissions
- Verify API keys are correct
- Check API is enabled in Google Cloud
- Verify budget/billing in Google Cloud
- Check console logs for error messages

### "Places not showing on map"
- Ensure markers are tagged correctly
- Check `selectedPlace` binding
- Verify coordinate conversion

### "API errors"
- Check network connectivity
- Verify API key restrictions
- Check API quotas
- Review error messages in console

## Future Enhancements

- [ ] Cache results locally for offline use
- [ ] Add user reviews and ratings
- [ ] Photo galleries from APIs
- [ ] Booking integration for hotels
- [ ] Real-time availability
- [ ] User-submitted places
- [ ] Social features (share favorites)
- [ ] Trip planning with multiple stops

## Support

For issues with:
- **Google Places API**: [Google Support](https://console.cloud.google.com/support)
- **BringFido API**: Contact BringFido directly
- **App Issues**: Check console logs and verify configuration

---

Last Updated: March 2026
