# App Store submission walkthrough — Phases 2–10

**Status:** Phases **1–3** done if you already have **successful TestFlight builds** (that implies signing + archive + upload worked). Next focus: **Phases 5–7** (store listing, screenshots) and **Phase 8** (attach build to App Store version) → **9–10** (review notes, export compliance, submit). Live URLs: **`APP_STORE_CONTACT_INFO.md`**.

---

## Phase 2 — Host legal & support links

**Done.** Public pages: `https://thyghos.github.io/petpal/privacy.html`, `terms.html`, `support.html`.

App Store Connect needs **working public URLs** (not only files in the repo).

**In this repo:** pages live in **`app-store-legal-site/`**. Legal text is filled in **`PRIVACY_POLICY.md`** and **`TERMS_OF_SERVICE.md`**; run `python3 build.py` there to refresh **`privacy.html`** / **`terms.html`**. **`support.html`** uses your support email.

**Step-by-step to finish:** see **`PHASE2_HOSTING.md`**.

1. **Privacy policy** — `https://thyghos.github.io/petpal/privacy.html`
2. **Terms of service** — `https://thyghos.github.io/petpal/terms.html`
3. **Support** — `https://thyghos.github.io/petpal/support.html` (required URL in Connect)
4. **Deploy** — GitHub Actions workflow **Deploy legal pages** (publishes folder to **`gh-pages`**) or upload the folder to any static HTTPS host — details in **`PHASE2_HOSTING.md`**
5. **Verify** — Open each URL in Safari **Private** mode (no login)

**Phase 2 complete when:** all three URLs work on **https://**, and you’ve saved them for Phase 5 (see **`APP_STORE_CONTACT_INFO.md`**).

---

## Phase 3 — Xcode project checks

1. Open **`Petpal.xcodeproj`** in Xcode.
2. Select the **Petpal** app target → **Signing & Capabilities**: your **Team**, **Automatically manage signing** on, and bundle ID **`com.thyghos.petpalapp`** (must match App Store Connect).
3. **General** → **Version** (e.g. `1.0.0`) and **Build** (e.g. `1`); bump **Build** for each upload.
4. **Info** / **Info.plist**: confirm usage strings exist for **location**, **camera**, **photo library**, **Bluetooth** (and anything else the target requests). This project uses the main **`Info.plist`** at the repo root (paths vary — check **Build Settings → Info.plist File**).
5. **Destination**: **Any iOS Device** (or generic iOS device), then **Product → Archive**. Fix compile/signing errors until the archive completes.

**Phase 3 done when:** a clean **Archive** succeeds and you’re ready to distribute to App Store Connect (Phase 8) after Connect metadata (Phases 4–7) is far enough along.

---

## Phase 4 — Create app in App Store Connect

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**
2. **iOS**, display name, language, bundle ID (match Xcode), **SKU** (e.g. `petpal-ios-001`)
3. Create → open the app’s **App Store** tab

---

## Phase 5 — URLs & basic store info

1. **Privacy Policy URL**
2. **Support URL**
3. **Category** (e.g. Health & Fitness if accurate)
4. **Subtitle** + **Description** (include medical/AI disclaimer block per your compliance guide)

---

## Phase 6 — App Privacy (nutrition label)

Must match real behavior (especially **Vet AI** → Claude/Gemini, **photos**, **location** for Travel Mode, analytics if any).

1. App → **App Privacy**
2. Declare collected data types, linked to user or not, third-party sharing as applicable
3. Save

---

## Phase 7 — Screenshots (and optional preview)

1. Open the version row (e.g. 1.0) in App Store Connect
2. Capture **real** UI for each **required device size** Connect lists
3. Upload screenshots; optional app preview video

---

## Phase 8 — Upload build

1. Xcode: **Product → Archive** → **Distribute App** → **App Store Connect** → upload
2. Wait for processing
3. In Connect, attach the build to your version when it appears

---

## Phase 9 — Version details & review notes

1. Select build on the version
2. **What’s New**
3. **App Review Information**: phone, email, **Notes** (no login, where disclaimers live, API keys in Info.plist if relevant, etc.)

---

## Phase 10 — Export compliance & submit

1. Answer **encryption / export** questions accurately
2. **Advertising identifier** — usually No without IDFA
3. **Submit for Review** when complete

---

*Companion: high-level checklist in `APP_STORE_READY_SUMMARY.md` and `APP_STORE_COMPLIANCE_GUIDE.md`.*
