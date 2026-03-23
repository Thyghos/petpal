# App Store submission walkthrough — Phases 2–10

**Status:** Phase 1 (Apple Developer account) is done. Resume here when you’re ready.

---

## Phase 2 — Host legal & support links

App Store Connect needs **working public URLs** (not only files in the repo).

**In this repo:** pages live in **`app-store-legal-site/`**. Legal text is filled in **`PRIVACY_POLICY.md`** and **`TERMS_OF_SERVICE.md`**; run `python3 build.py` there to refresh **`privacy.html`** / **`terms.html`**. **`support.html`** uses your support email.

**Step-by-step to finish:** see **`PHASE2_HOSTING.md`**.

1. **Privacy policy** — e.g. `https://…/privacy.html`
2. **Terms of service** — e.g. `https://…/terms.html` (host alongside privacy; link from policy or review notes)
3. **Support** — e.g. `https://…/support.html` (required URL in Connect)
4. **Deploy** — GitHub Actions workflow **Deploy legal pages** (publishes folder to **`gh-pages`**) or upload the folder to any static HTTPS host — details in **`PHASE2_HOSTING.md`**
5. **Verify** — Open each URL in Safari **Private** mode (no login)

**Phase 2 complete when:** all three URLs work on **https://**, and you’ve saved them for Phase 5 (see **`APP_STORE_CONTACT_INFO.md`**).

---

## Phase 3 — Xcode project checks

1. Open the **Petpal** project in Xcode
2. Select that app target → **Signing & Capabilities**: Team + unique bundle ID
3. **General** → **Version** (e.g. 1.0.0) and **Build** (e.g. 1)
4. **Info.plist**: usage strings for camera, photos, location, etc. (anything the app uses)
5. **Product → Archive** — fix errors until archive succeeds

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
