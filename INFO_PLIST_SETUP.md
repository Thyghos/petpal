# Info.plist Configuration Example

Add these entries to your `Info.plist` file to configure API keys:

## Method 1: Using Xcode's Info Tab

1. Select your project in the Project Navigator
2. Select your app target
3. Click the "Info" tab
4. Click the "+" button to add new entries
5. Add these keys:

```
Key: GOOGLE_PLACES_API_KEY
Type: String
Value: YOUR_ACTUAL_GOOGLE_API_KEY_HERE
```

```
Key: BRINGFIDO_API_KEY
Type: String  
Value: YOUR_ACTUAL_BRINGFIDO_KEY_HERE
```

## Method 2: Editing Info.plist XML Directly

Open `Info.plist` as source code and add inside the `<dict>` tag:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Your existing keys... -->
    
    <!-- Add these new keys: -->
    <key>GOOGLE_PLACES_API_KEY</key>
    <string>AIzaSyD_EXAMPLE_KEY_REPLACE_WITH_YOUR_KEY</string>
    
    <key>BRINGFIDO_API_KEY</key>
    <string>YOUR_BRINGFIDO_KEY_HERE</string>
    
    <!-- Rest of your Info.plist... -->
</dict>
</plist>
```

## Important Security Notes

### DO NOT commit these keys to version control!

Add this to your `.gitignore`:

```gitignore
# API Keys - DO NOT COMMIT
**/Info.plist

# If you need to track Info.plist structure, use a template:
# Info.plist.template
```

### Alternative: Use Configuration Files

Create separate files for different environments:

**Info-Debug.plist** (for development)
```xml
<key>GOOGLE_PLACES_API_KEY</key>
<string>AIzaSyD_DEV_KEY_HERE</string>
```

**Info-Release.plist** (for production)
```xml
<key>GOOGLE_PLACES_API_KEY</key>
<string>AIzaSyD_PROD_KEY_HERE</string>
```

Then configure your build settings to use different files per configuration.

## Verification

To verify your keys are configured correctly, add this to your app:

```swift
// In your AppDelegate or a test view
func verifyAPIConfiguration() {
    if let googleKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String {
        print("✅ Google API Key configured: \(String(googleKey.prefix(10)))...")
    } else {
        print("❌ Google API Key not found")
    }
    
    if let bringFidoKey = Bundle.main.object(forInfoDictionaryKey: "BRINGFIDO_API_KEY") as? String {
        print("✅ BringFido API Key configured: \(String(bringFidoKey.prefix(10)))...")
    } else {
        print("❌ BringFido API Key not found")
    }
}
```

## Quick Start Without Keys

You can test the feature without any API keys:

1. **Option 1 - Mock Data:**
   ```swift
   // In TravelModeView.swift
   private let useMockData = true
   ```

2. **Option 2 - Apple Maps Only:**
   ```swift
   // In TravelModeView.swift
   private let useMockData = false
   // Don't add any keys to Info.plist
   ```

The app will automatically use only Apple Maps if no external API keys are configured.

## Getting API Keys

### Google Places API Key

1. Go to https://console.cloud.google.com/
2. Create a new project (or select existing)
3. Enable the "Places API"
4. Go to "Credentials" → "Create Credentials" → "API Key"
5. Copy your key
6. (Recommended) Click "Restrict Key":
   - Application restrictions: iOS apps
   - Add your bundle ID: `com.yourcompany.pawpal`
   - API restrictions: Places API only

### BringFido API Key

1. Visit https://www.bringfido.com/business/
2. Contact their partnership team
3. Explain your app and use case
4. They will provide API access and documentation
5. Note: May require business partnership agreement

## Testing Your Configuration

After adding keys, test with:

```swift
import SwiftUI

struct APITestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("API Configuration Test")
                .font(.headline)
            
            HStack {
                Image(systemName: APIConfiguration.useGooglePlaces ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(APIConfiguration.useGooglePlaces ? .green : .red)
                Text("Google Places")
            }
            
            HStack {
                Image(systemName: APIConfiguration.useBringFido ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(APIConfiguration.useBringFido ? .green : .red)
                Text("BringFido")
            }
            
            if APIConfiguration.appleMapsFallbackOnly {
                Text("Using Apple Maps only")
                    .foregroundStyle(.orange)
            }
        }
        .padding()
    }
}
```

---

Last Updated: March 2026
