# iOS Simulator Setup Guide for PawPal

## 🚨 Important: Setting Up Location in Simulator

The iOS Simulator **does not have a real GPS**, so you need to manually set a location for testing. This is why your "My Location" and "Nearest Vet" buttons weren't working!

## Method 1: Set Location via Xcode (Recommended)

### While Running the App:

1. **Run your app** in the simulator
2. In Xcode menu bar, click **Debug > Simulate Location**
3. Choose one of the preset locations:
   - **Apple** (Cupertino, CA - good for testing, lots of vets nearby)
   - **City Bicycle Ride** (simulates movement)
   - **City Run** (simulates running)
   - **Freeway Drive** (simulates driving)
   - Or choose **Custom Location...** to enter specific coordinates

### Custom Location Example:
1. Select **Debug > Simulate Location > Custom Location...**
2. Enter coordinates:
   - **Latitude**: `37.7749` (San Francisco)
   - **Longitude**: `-122.4194`
3. Click **OK**

## Method 2: Set Default Location in Simulator

### Before Running the App:

1. **Launch the iOS Simulator** (without your app)
2. In the Simulator menu bar, click **Features > Location**
3. Choose from:
   - **Apple** ✅ (Recommended for testing)
   - **City Bicycle Ride**
   - **City Run**
   - **Freeway Drive**
   - **Custom Location...** (enter your own coordinates)
   - **None** (no location - useful for testing error cases)

## Method 3: Use GPX File (Advanced)

Create a GPX file with custom routes:

1. Create a file called `TestLocation.gpx`:
```xml
<?xml version="1.0"?>
<gpx version="1.1" creator="Xcode">
    <wpt lat="37.7749" lon="-122.4194">
        <name>San Francisco</name>
    </wpt>
</gpx>
```

2. Add to your Xcode project
3. Run app and select **Debug > Simulate Location > TestLocation**

## 📱 Verify Location is Set

After setting a location, you should see in the Xcode console:

```
📍 LocationManager initialized
📍 Requesting location authorization and updates...
📍 Current authorization: 3
💡 SIMULATOR: Make sure to set a location via:
   Debug > Location > Custom Location (in Xcode)
   or Features > Location > Apple (in Simulator menu)
📍 Authorization changed to: 3
   ✅ Authorized when in use
✅ Location updated: 37.7749, -122.4194
   Accuracy: 5.0m
```

## 🧪 Testing the Buttons

### Test "My Location" Button:

1. Set simulator location (see methods above)
2. Run your app and navigate to Travel Mode
3. Click **"My Location"** quick action button
4. Console should show:
   ```
   📍 centerOnUserLocation() called
   📍 Location manager status: 3
   ✅ Centering on location: 37.7749, -122.4194
   ```
5. Map should center on that location

### Test "Nearest Vet" Button:

1. Make sure location is set
2. Click **"Nearest Vet"** (in toolbar menu or quick action)
3. Console should show:
   ```
   🏥 findNearestVet() called
   🏥 Location manager status: 3
   ✅ Using location: 37.7749, -122.4194
   🔍 Starting vet search at location: 37.7749, -122.4194
   🔍 Starting search for Veterinary near 37.7749, -122.4194
   📍 Searching Apple Maps...
   📍 Apple Maps query: 'veterinarian' within 10000m
   📍 Apple Maps returned 15 raw results
   ✅ Search complete. Found 15 places
   ✅ Nearest vet: Pet Hospital at 245.0m away
   ```
4. Map should show vet markers and zoom to nearest one

## 🔍 Check Info.plist Permissions

Make sure your **Info.plist** contains:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>PawPal needs your location to find nearby veterinarians and pet-friendly places.</string>
```

To add in Xcode:
1. Open **Info.plist**
2. Right-click and select **Add Row**
3. Choose **Privacy - Location When In Use Usage Description**
4. Set value: `PawPal needs your location to find nearby veterinarians and pet-friendly places.`

## 🐛 Troubleshooting

### Issue: Console shows "User location not available"

**Solutions:**
1. ✅ Set simulator location using Method 1 or 2 above
2. ✅ Wait 1-2 seconds after app launch for location to be acquired
3. ✅ Check that location permission dialog appeared and you tapped "Allow While Using App"
4. ✅ If you accidentally denied permission:
   - In simulator: Settings > Privacy & Security > Location Services
   - Find your app and enable it

### Issue: Permission dialog doesn't appear

**Solutions:**
1. ✅ Check Info.plist has `NSLocationWhenInUseUsageDescription` key
2. ✅ Clean build folder: Product > Clean Build Folder
3. ✅ Delete app from simulator and reinstall
4. ✅ Reset simulator: Device > Erase All Content and Settings...

### Issue: "No vets found in search results"

**Solutions:**
1. ✅ Try a different location (urban areas have more results)
2. ✅ Use **"Apple"** location preset (Cupertino has many vets)
3. ✅ Check console for Apple Maps error messages
4. ✅ Try enabling mock data:
   ```swift
   // In TravelModeView.swift
   private let useMockData = true
   ```

### Issue: Console shows "Location temporarily unknown"

**Solution:**
- This is normal for first location update
- Wait 1-2 seconds and try again
- Location should update automatically

## 🎯 Recommended Testing Locations

| Location | Latitude | Longitude | Good For |
|----------|----------|-----------|----------|
| Apple HQ (Cupertino) | 37.3346 | -122.0090 | Testing (has many vets) |
| San Francisco | 37.7749 | -122.4194 | Urban area testing |
| New York City | 40.7128 | -74.0060 | Dense urban testing |
| Austin, TX | 30.2672 | -97.7431 | Medium city testing |
| Rural area | 36.0000 | -95.0000 | Sparse results testing |

## 📝 Quick Checklist

Before testing, make sure:
- [ ] Info.plist has location usage description
- [ ] Simulator location is set (Debug > Simulate Location > Apple)
- [ ] App has location permission (check on first run)
- [ ] You're looking at console output (Cmd+Shift+Y)
- [ ] You wait 1-2 seconds after app launch before clicking buttons

## 🎉 Expected Behavior

When everything is working:

1. **App launches** → Location permission dialog appears
2. **Tap "Allow While Using App"** → Console shows "✅ Authorized when in use"
3. **Location updates** → Console shows coordinates
4. **Click "My Location"** → Map centers on your simulated location
5. **Click "Nearest Vet"** → Search runs, markers appear, map zooms to nearest vet
6. **See markers on map** → Tap to view details, get directions

Now try it! The detailed console logging will show you exactly what's happening at each step.
