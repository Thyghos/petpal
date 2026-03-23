# Petpal

Petpal is an iOS app for pet owners: multiple pet profiles, care-oriented home experience, pet-friendly places, travel mode, emergency/QR-style flows, and optional Vet AI assistance (presented with clear disclaimers — not a substitute for a veterinarian).

## Open and run

1. Open `Petpal.xcodeproj` in Xcode.
2. Select an iPhone simulator or device.
3. Build and run the **Petpal** scheme.

Deployment target and signing are configured in the Xcode project; adjust team and bundle identifier for your Apple Developer account before App Store submission.

## Repository layout (high level)

| Path | Purpose |
|------|--------|
| `Petpal.xcodeproj` | Main iOS app |
| `app-store-legal-site/` | Static privacy, terms, and support pages (built for GitHub Pages) |
| `emergency-page/` | Standalone emergency landing page assets |
| `PantryVision/` | Separate Xcode project (not required to run Petpal) |

## App Store and compliance

- Submission overview: `START_HERE_APP_STORE.md`
- Hosting privacy/terms/support (Phase 2): `PHASE2_HOSTING.md`
- Canonical legal source (Markdown): `PRIVACY_POLICY.md`, `TERMS_OF_SERVICE.md`

The legal site can regenerate HTML from those Markdown files; see `app-store-legal-site/README.md`.

## License

All rights reserved unless you add an explicit license file.
