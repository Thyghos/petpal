// APIConfiguration.swift
// Petpal - API Configuration

import Foundation

/// Configuration for external API services
struct APIConfiguration {
    
    // MARK: - API Keys
    
    /// Google Places API Key
    /// Get your key from: https://console.cloud.google.com/google/maps-apis/credentials
    /// Enable: Places API
    static let googlePlacesAPIKey: String? = {
        // Option 1: Load from Info.plist (recommended for security)
        if let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String,
           !key.isEmpty,
           !key.hasPrefix("YOUR_") {
            return key
        }
        
        // Option 2: Fallback to hardcoded value (not recommended for production)
        // Replace with your actual key or set in Info.plist
        return nil // Replace with your key: "YOUR_ACTUAL_GOOGLE_API_KEY"
    }()
    
    /// BringFido API Key
    /// Contact BringFido for API access: https://www.bringfido.com/
    /// Note: BringFido may require partnership agreement for API access
    static let bringFidoAPIKey: String? = {
        // Option 1: Load from Info.plist
        if let key = Bundle.main.object(forInfoDictionaryKey: "BRINGFIDO_API_KEY") as? String,
           !key.isEmpty,
           !key.hasPrefix("YOUR_") {
            return key
        }
        
        // Option 2: Fallback to hardcoded value (not recommended for production)
        return nil // Replace with your key: "YOUR_ACTUAL_BRINGFIDO_KEY"
    }()

    /// Geoapify Places API Key
    /// Free tier: 3,000 requests/day. Get key: https://myprojects.geoapify.com/
    /// Supports native dogs.yes / dogs.leashed conditions for pet-friendly filtering
    static let geoapifyAPIKey: String? = {
        if let key = Bundle.main.object(forInfoDictionaryKey: "GEOAPIFY_API_KEY") as? String,
           !key.isEmpty,
           !key.hasPrefix("YOUR_") {
            return key
        }
        return nil
    }()
    
    // MARK: - Feature Flags
    
    /// Enable Google Places integration
    static var useGooglePlaces: Bool {
        googlePlacesAPIKey != nil
    }
    
    /// Enable BringFido integration
    static var useBringFido: Bool {
        bringFidoAPIKey != nil
    }

    /// Enable Geoapify integration (native dog-friendly filter)
    static var useGeoapify: Bool {
        geoapifyAPIKey != nil
    }
    
    /// Fallback to Apple Maps only if no API keys are configured
    static var appleMapsFallbackOnly: Bool {
        !useGooglePlaces && !useBringFido && !useGeoapify
    }

    // MARK: - AI (Vet assistant)

    /// Anthropic API key in **Info.plist** (Build Settings → Info.plist File; path is often `Petpal/Info.plist` in this project), key `Claude_API_Key`.
    /// Also accepts `Claude_API-Key` if Xcode auto-formatted the name with a hyphen.
    static let anthropicAPIKey: String? = {
        plistString("Claude_API_Key") ?? plistString("Claude_API-Key")
    }()

    /// Google Gemini API key (`GEMINI_API_KEY` in Info.plist). Free tier: https://aistudio.google.com/apikey
    static let geminiAPIKey: String? = {
        plistString("GEMINI_API_KEY")
    }()

    private static func plistString(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("YOUR_") else { return nil }
        return trimmed
    }
}

/*
 SETUP INSTRUCTIONS:
 
 1. For Google Places API:
    a. Go to https://console.cloud.google.com/
    b. Create a new project or select existing
    c. Enable "Places API" 
    d. Go to Credentials and create an API key
    e. (Optional) Restrict the key to iOS apps with your bundle ID
    f. Add to Info.plist:
       <key>GOOGLE_PLACES_API_KEY</key>
       <string>YOUR_ACTUAL_KEY_HERE</string>
 
 2. For Geoapify (pet-friendly places with native dogs filter):
    a. Sign up at https://myprojects.geoapify.com/ (free, no credit card)
    b. Create a project and copy the API key
    c. Add to Info.plist:
       <key>GEOAPIFY_API_KEY</key>
       <string>YOUR_ACTUAL_KEY_HERE</string>
 
 3. For BringFido:
    a. Visit https://www.bringfido.com/
    b. Contact their business development team for API access
    c. Once you have a key, add to Info.plist:
       <key>BRINGFIDO_API_KEY</key>
       <string>YOUR_ACTUAL_KEY_HERE</string>
 
 4. SECURITY NOTE:
    - Never commit API keys to version control
    - Add Info.plist to .gitignore if it contains keys
    - Use environment variables or a secure configuration service
    - For production apps, consider using a backend service to proxy API calls
 
 ALTERNATIVE SERVICES:
 
 If BringFido API is not available, consider these alternatives:
 - Yelp Fusion API (has "dogs_allowed" filter)
 - Foursquare Places API
 - TripAdvisor Content API
 - Custom scraping (with permission and rate limiting)
 
 5. GEMINI (AI Vet — recommended free tier):
    a. Open https://aistudio.google.com/apikey and sign in with Google.
    b. Create an API key (Google AI Studio / Gemini API).
    c. In Xcode: select the Petpal app target → Info → Custom iOS Target Properties, add or edit:
       Key: GEMINI_API_KEY  |  Type: String  |  Value: (paste your key)
       Or edit Info.plist: <key>GEMINI_API_KEY</key><string>YOUR_KEY</string>
    d. Do not commit real keys to git. If both Claude_API_Key and GEMINI_API_KEY are set, the app uses Claude first.
    e. If you see model-not-found errors, update the model id in VetAIView.swift (callGeminiAPI) to a current name from:
       https://ai.google.dev/gemini-api/docs/models
 */
