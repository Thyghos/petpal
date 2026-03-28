# Privacy Policy for Petpal

**Last Updated: March 28, 2026**

## Introduction

Welcome to Petpal ("we," "our," or "us"). We are committed to protecting your privacy and the privacy of your pets. This Privacy Policy explains how we collect, use, store, and protect your information when you use the Petpal mobile application for iPhone and iPad.

## Summary (current version)

In this release, **Petpal does not use your location** for any feature you can reach from the home screen. **Travel Mode** (maps and nearby-place search) is **not offered** in the main app flow. Data you enter stays on your device and, if you use iCloud, in **your** Apple iCloud account via CloudKit—we do not run our own database for your pet records.

Optional **Vet AI** sends only the text you type to AI providers you configure (or a proxy). **In-app purchases** (subscriptions and tips) are processed by **Apple**.

---

## Information You Provide

You may store the following in the app (all optional except where a feature needs it):

- **Pet profiles**: Name, species, breed, weight, units, date of birth, photo, activity flag, care contacts (vet, groomer), microchip fields
- **Reminders**: Titles, schedules, categories, notes, linked pet
- **Health history**: Visit logs, notes, and related fields you add
- **Vet documents**: Files and metadata you attach in the health / vet document flows
- **Certificates**: Titles, type, expiration, notes, and file attachments (images/PDFs)
- **Insurance**: Policy and claim-related fields you choose to enter
- **Pet sitter instructions**: Feeding, medications, emergency contacts, and similar notes you enter
- **Emergency / QR profile**: Information you choose to include for emergency sharing (and optional links to a hosted emergency page you control)
- **Weight tracker**: Dated weight entries per pet
- **Tile and tip preferences**: Home layout and health-tip settings stored in the app database
- **Vet AI**: Only the messages you send in the chat (and any context the app attaches for that request, such as a short pet summary you have enabled)—not your full database as a bulk upload

## Information We Do **Not** Collect (this release)

- **Location**: The home screen does not include Travel Mode or map-based search. Petpal **does not request GPS/location** for normal use in this version. (Legacy code or permission strings may remain for a possible future update; if we turn location features on again, we will update this policy and App Store disclosures **before** collecting location.)
- **We do not sell** your data, **do not use** it for third-party advertising, and **do not** embed ad or cross-app tracking SDKs in Petpal.

## Automatically Collected / Device-Related

- **Notifications**: If you allow notifications, the system may show local reminders you create in the app. We do not send marketing push notifications from our servers for Petpal.
- **Photos / camera / library**: Used only when you pick or take a pet photo, save a shared image, or attach a document, as described in the system permission prompts.
- **Apple diagnostics**: Apple may provide **aggregated** crash and App Store analytics to the developer (for example via Xcode and App Store Connect). That is governed by Apple’s policies.

## How We Use Your Information

- Provide pet profiles, reminders, health and certificate storage, weight tracking, emergency QR, insurance and sitter notes, and related UI
- Schedule **local** notifications for reminders you create
- If enabled, call **optional** AI APIs with your Vet AI prompts
- If enabled, complete **in-app purchases** through Apple’s StoreKit

## Data Storage and Sync

### On your device (SwiftData)

Pet profiles, reminders, health data, certificates, attachments, weight entries, preferences, and similar content are stored in an on-device database using Apple’s **SwiftData**. We do not copy that database to our own servers.

### iCloud (CloudKit)

If you are signed in to **iCloud** and CloudKit sync is active, that same app data can sync to Apple’s **private** CloudKit database for your **Apple ID** across your devices. Apple operates that infrastructure; see [Apple’s Privacy Policy](https://www.apple.com/legal/privacy/). Sync can take time—open the app on Wi‑Fi or cellular occasionally. If iCloud is unavailable, Petpal continues with **local** storage on that device.

### Backup export / import

You may export selected categories to **JSON** or **ZIP** and share the file (Mail, AirDrop, Files, etc.). Anyone with the file can read it. Import can merge, update, or replace data depending on the option you choose.

## Network / Third-Party Services

These apply **only** when you use the relevant feature or sign in:

| Service | Purpose |
|--------|---------|
| **Apple iCloud / CloudKit** | Optional sync of your app data between your devices |
| **Apple StoreKit** | Optional subscriptions (e.g. Vet AI plans) and optional in-app tips; payment handled by Apple |
| **Anthropic / Google (Gemini)** | Optional Vet AI responses when you configure API keys or use supported flows in the app |
| **Cloudflare Worker (or similar) proxy** | Optional: may relay Vet AI requests if a proxy URL is configured—only request content you send, not your full pet database |
| **Hosted emergency page** | If you use the optional static emergency page feature, that page is served from infrastructure you configure (e.g. GitHub Pages); visitors only see what you put on that page |

**Not used in the current home-screen experience** (no user-facing entry in this build): map-based Travel Mode, **Apple MapKit**-driven nearby search, **Geoapify**, Google Places, and BringFido API flows that depended on device location. If we ship those again, we will update this policy and product disclosures.

Opening **external websites** (for example insurance resources or App Store links) is governed by those sites’ policies.

## Data Sharing

We do **not**:

- Sell your personal information  
- Share your pet health records with advertisers  
- Use your data for cross-app tracking  

AI providers and Apple receive only what is necessary for the feature you use (e.g. prompt text for AI; purchase tokens for IAP), as described above.

## Purchases

Subscriptions and tips are processed by **Apple**. We do not receive your full credit card number. See Apple’s terms and privacy notice for purchases.

## Your Rights and Controls

- **Access / edit / delete** data inside the app  
- **Export** via Backup & restore  
- **Opt out of AI** by not using Vet AI or not adding keys  
- **iCloud**: Manage sync via your Apple ID / iCloud settings  
- **Notifications**: Change in iOS Settings for Petpal  
- **Contact**: See below for privacy questions  

## Data Retention

Data remains on device (and in your **iCloud private database** if sync is on) until you delete it or replace it via import. Deleting the app removes the **local** copy on that device; iCloud data may remain until you delete content in-app or manage iCloud storage. Backup files you keep elsewhere are your responsibility.

## Children’s Privacy

Petpal is not directed at children under 13. The app is intended for pet owners who can lawfully consent to processing.

## Security

We rely on Apple’s platform security for on-device storage and TLS for network requests where applicable. No method of storage or transmission is 100% secure.

## Changes to This Policy

We may update this Privacy Policy. Material changes will be reflected in the **Last Updated** date and, when appropriate, in app release notes or the hosted policy page.

## Medical Disclaimer

Petpal is for informational purposes only and is not a substitute for professional veterinary care.

## Contact

**Operator**: Emilio Alecci (Florida, United States)  
**Email (privacy & support)**: ealecci@gmail.com  
**Policy URL**: https://thyghos.github.io/petpal-privacy/

## Consent

By using Petpal, you agree to this Privacy Policy.

---

**Effective date**: March 28, 2026

We treat your pet’s information as sensitive and do not sell it.
