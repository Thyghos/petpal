# App Store submission walkthrough — Phases 2–10

**Status:** Phases **1–4** done for most teams with TestFlight + **My Apps**. **Phase 5** = listing copy + URLs — use **`APP_STORE_LISTING_DRAFT.md`**. URLs: **`APP_STORE_CONTACT_INFO.md`**.

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

**Already done?** If **My Apps** lists **Petpal** (or your store name), you already completed Phase 4. Confirm **bundle ID** matches Xcode: **`com.thyghos.petpalapp`** (see **`APP_STORE_CONTACT_INFO.md`**).

**If you still need to create it:**

1. Open [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps**.
2. Click **+** (top left) → **New App**.
3. **Platforms:** **iOS** (and others only if you ship them).
4. **Name:** App Store display name (e.g. **Petpal**).
5. **Primary language:** e.g. **English (U.S.)**.
6. **Bundle ID:** choose the App ID you registered in the Developer portal — must match Xcode (**`com.thyghos.petpalapp`**). If it’s not listed, create the identifier in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) first, then return here.
7. **SKU:** any unique internal string (e.g. `petpal-ios-001`). Users never see it.
8. **User access** (if shown): **Full Access** for yourself unless you use a limited role.
9. **Create** → open the app → **Distribution** / **App Store** tab to manage versions.

**Phase 4 done when:** the app appears in **My Apps**, the **bundle ID** matches Xcode, and you can open the **iOS** version you’re preparing for the App Store.

---

## Phase 5 — URLs & basic store info

**Single source of copy:** paste from **`APP_STORE_LISTING_DRAFT.md`** (subtitle, description, keywords, promotional text, What’s New, categories, copyright).

1. **Distribution** → **iOS** → your **version** → **English (U.S.)** (or primary locale).
2. **Support URL** → `https://thyghos.github.io/petpal/support.html`
3. **Marketing URL** *(optional)* → `https://thyghos.github.io/petpal/terms.html`
4. **Privacy Policy URL** — same as **App Privacy**: `https://thyghos.github.io/petpal/privacy.html` (see **`APP_STORE_CONTACT_INFO.md`**).
5. **Primary / Secondary category** — e.g. **Lifestyle** + **Travel** (or adjust per listing draft).
6. **Name**, **Subtitle**, **Description** (includes medical + optional AI disclaimer), **Keywords**, **Promotional Text**, **What’s New**, **Copyright** as in the draft.
7. **Save**; fix any Connect validation errors (length limits, keyword format).

**Phase 5 done when:** listing text and URLs are filled, saved, and match your privacy policy and actual app behavior.

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
