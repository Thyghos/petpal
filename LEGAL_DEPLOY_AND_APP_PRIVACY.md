# Legal site deploy, App Store description & App Privacy (Petpal)

Use this when submitting or updating the app. Canonical URLs match **`APP_STORE_CONTACT_INFO.md`**.

---

## Part 1 — Deploy the legal site (GitHub Pages)

### One-time GitHub setup

1. Open your repo on GitHub (**Petpal**).
2. **Settings → Pages**
   - **Build and deployment**: **Deploy from a branch**
   - **Branch**: `gh-pages` → **/ (root)**  
   - Save.  
   (First deploy must create `gh-pages`; the workflow below does that.)

3. **Settings → Actions → General**  
   - **Workflow permissions**: allow **Read and write** (needed for `peaceiris/actions-gh-pages` to push `gh-pages`).

### Every time you change legal copy

1. Edit **`PRIVACY_POLICY.md`** and/or **`TERMS_OF_SERVICE.md`** (and **`app-store-legal-site/index.html`** or **`support.html`** if needed).

2. Regenerate HTML from the repo root:

   ```bash
   cd app-store-legal-site && python3 build.py
   ```

   This overwrites **`privacy.html`** and **`terms.html`** — do not edit those by hand.

3. Commit and push **`main`**. The workflow **`.github/workflows/deploy-legal-pages.yml`** runs when these paths change:
   - `app-store-legal-site/**`
   - `PRIVACY_POLICY.md`
   - `TERMS_OF_SERVICE.md`

   Or run it manually: **Actions → Deploy legal pages → Run workflow**.

4. Wait for the green checkmark on the workflow, then verify in a **private window** (no cache):

   | Page    | URL |
   |--------|-----|
   | Privacy | https://thyghos.github.io/petpal/privacy.html |
   | Terms   | https://thyghos.github.io/petpal/terms.html   |
   | Support | https://thyghos.github.io/petpal/support.html |
   | Hub     | https://thyghos.github.io/petpal/index.html   |

5. In **App Store Connect**, set **Privacy Policy URL** and **Support URL** to the **privacy** and **support** links above (same as **`APP_STORE_LISTING_DRAFT.md`**).

**If URLs 404:** Pages source must be **`gh-pages`** branch **root**, not `main` / `docs`, unless you intentionally host elsewhere.

---

## Part 2 — App Store Connect: listing text (paste as-is)

**Where:** App Store Connect → your app → **Distribution** → **iOS** → select the **version** → **App Store** tab → **English (U.S.)** (or your locale).

| Field | Value |
|--------|--------|
| **Name** | Petpal |
| **Subtitle** (30 chars max) | `Pet care, reminders & QR` |
| **Privacy Policy URL** | `https://thyghos.github.io/petpal/privacy.html` |
| **Support URL** | `https://thyghos.github.io/petpal/support.html` |
| **Marketing URL** (optional) | `https://thyghos.github.io/petpal/terms.html` |
| **Copyright** | `2026 Emilio Alecci` |

### Promotional text (170 characters max)

```
Profiles, reminders, emergency QR, and health tools for your pets. Customizable home screen. Optional Vet assistant for education only—not a vet.
```

### Description (paste entire block)

```
Everything for your pets in one place—profiles, reminders, emergency info, and everyday care tools. Petpal is for pet parents who want less chaos and more peace of mind.

WHAT YOU CAN DO

• Pet profiles — name, breed, photo, weight, birthday, and more. Switch between pets anytime.
• Emergency QR — keep critical info handy if your pet is lost; easy to share from your phone.
• Reminders — vet visits, medications, and care tasks so nothing slips through the cracks.
• Certificates & documents — vaccines, licenses, and paperwork with attachments.
• Weight tracking — simple history per pet.
• Your home screen, your way — show, hide, and reorder tiles for the features you use most.
• Health tips — optional daily or weekly tips based on your pet's species (dog, cat, bird, rabbit, or all).
• Optional Vet assistant — general, educational Q&A only; not medical advice. If you use it, your questions are processed by third-party AI as described in our Privacy Policy.
• Pet Deals (optional) — shortcuts to pet retailers, memberships, and supplies we use on the road. Some links are affiliate or partner links; Petpal may earn a commission at no extra cost to you. The app shows a short disclosure on that screen; purchases happen on third-party sites, not inside Petpal.
• Privacy-minded — pet data stays on your device (and your iCloud, if you use sync) unless you use network features such as the optional assistant or opening external links. See our Privacy Policy for details.

IMPORTANT

Petpal is not a substitute for professional veterinary care. Always consult your veterinarian for medical decisions. Any informational or AI-assisted features are for general guidance only. Pet Deals and Insurance links are for convenience only; we do not endorse third-party products as veterinary advice.

Terms: https://thyghos.github.io/petpal/terms.html

Need help? Use the Support link on this App Store page or email ealecci@gmail.com.
```

### Keywords (100 characters max, commas only, no spaces after commas)

```
dog,cat,pet,reminder,vet,emergency,QR,lost,profile,health,schedule,puppy,kitten,weight
```

### What’s New (pick one)

**If this update adds Pet Deals / removes travel:**

```
Pet Deals: optional partner links for supplies and travel (with in-app affiliate disclosure). Travel/map tab removed—Petpal stays focused on health, reminders, and QR. Bug fixes and polish.
```

**If first release:**

```
Welcome to Petpal! Organize pet profiles, reminders, emergency QR, and everyday care tools—and customize your home screen. We’d love your feedback—use Support on this listing.
```

---

## Part 3 — App Privacy questionnaire (App Store Connect)

**Where:** App Store Connect → your app → **App Privacy** (left sidebar). Answer for **this version** of Petpal. Wording on Apple’s form changes slightly over time—match the **intent** below to the closest option.

### Sign in to share health data?

Usually **No** (you are not using HealthKit to read/write the Apple Health app for the user’s own health record). If you do not integrate HealthKit, answer **No**.

### Do you or your third-party partners collect data from this app?

**Yes** — the app processes user-generated content and media on device; some features send data to third parties **only when the user uses those features** (Vet AI, iCloud sync via Apple, IAP via Apple). You are not operating your own pet database server, but Apple’s form still expects disclosure of relevant types.

### Data types to declare (aligned with `PRIVACY_POLICY.md`)

For each type below, Apple will ask whether data is **linked to the user’s identity**, **used for tracking**, and **why** (e.g. App Functionality). Use:

- **Linked to user**: **Yes** (data is tied to the user’s account/device context; iCloud is under their Apple ID).
- **Used for tracking**: **No** — you do not use Petpal to track users across other companies’ apps/websites for advertising (no ad SDKs; Pet Deals opens Safari; you do not receive cross-app tracking data from merchants).

---

#### 1. Photos or videos

- **Collected**: Yes  
- **Linked to user**: Yes  
- **Tracking**: No  
- **Purposes**: **App functionality** (profile photos, certificate attachments, saving QR images per your policy)

Matches: photo library + camera usage in **`Info.plist`**.

---

#### 2. Other user content

- **Collected**: Yes  
- **Linked to user**: Yes  
- **Tracking**: No  
- **Purposes**: **App functionality**  

Include: pet profiles, reminders, health history, notes, insurance fields, sitter instructions, emergency QR text, weight entries, documents user attaches, home tile / tip preferences, and **text sent to optional Vet AI** (and optional proxy) when the user uses that feature.

If Apple splits “emails or messages” vs “other user content,” put Vet AI prompts where it fits best (often **Other User Content** or **Emails or Text Messages** for chat-style content—choose the option that matches their definitions).

---

#### 3. Purchase history (or “Payment Info” / IAP — follow Apple’s labels)

- **Collected**: Only as handled by **Apple** for subscriptions/tips.  
- In Connect, Apple often provides guidance: if **you** do not receive credit card data and only Apple processes IAP, many apps answer that **purchase-related** collection is not applicable to the developer beyond what Apple discloses—or select the minimal category Apple suggests for IAP-only apps.  
- **Tracking**: No  

If the questionnaire has **“Do you collect purchase history?”** and you only use StoreKit with no server-side receipt logging of your own, answer consistently with **no direct collection by you**; follow Apple’s helper text.

---

#### 4. Diagnostics (optional)

- If you use **only** Apple’s aggregated crash/analytics from App Store Connect / Xcode and **no** third-party crash SDK (Firebase Crashlytics, Sentry, etc.) **in the Petpal target**, you typically **do not** add a separate third-party diagnostics category.  
- If you add a crash reporter later, update App Privacy **before** shipping that build.

---

### Data types you should **not** need (verify for your build)

| Type | Petpal (current policy) |
|------|-------------------------|
| **Location** | **No** — no GPS / map features in this version |
| **Contacts** (iOS Contacts framework) | **No** — unless you request Contacts access (typed-in vet info is not the same as “Contacts”) |
| **Browsing history** | **No** — you do not collect browsing history; Safari handles sites opened from Pet Deals |
| **Identifiers** for cross-app tracking | **No** — no ad / attribution SDK in Petpal |

### Third-party partners on the form

- **Apple** (iCloud, StoreKit, platform): Apple may appear automatically or you add as partner where Connect asks.  
- **AI providers** (e.g. Anthropic, Google): add **only if** the shipped app sends user text to them when Vet AI is used. If keys are empty and feature is off by default, it’s still honest to list them as **optional** processors when the user enables the feature.  
- **Do not** list every Pet Deals merchant as “partners” in App Privacy unless Apple asks for specific SDKs—you’re opening URLs in Safari, not embedding their SDKs.

### Privacy Policy URL (again)

Must match the live page: **`https://thyghos.github.io/petpal/privacy.html`**

---

## Final checklist before submit

- [ ] `python3 build.py` run; **`privacy.html` / `terms.html`** committed **or** generated only on CI (workflow runs `build.py` on push).  
- [ ] Workflow succeeded; all three URLs load over HTTPS.  
- [ ] Listing description and **What’s New** mention Pet Deals / affiliates if that’s in this build.  
- [ ] App Privacy answers match this doc and **`PRIVACY_POLICY.md`**.  
- [ ] No placeholder emails or wrong dates in **`support.html`**.

This is operational guidance for App Store Connect, not legal advice. If anything in the app changes (new analytics, HealthKit, location), update **`PRIVACY_POLICY.md`**, rerun **`build.py`**, redeploy, and revise **App Privacy** before release.
