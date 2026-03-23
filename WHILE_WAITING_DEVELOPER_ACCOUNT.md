# Petpal — Do this while your Developer account activates (~48 hrs)

Your account is **pending**. You **cannot** use App Store Connect, create the app record, or upload a build until Apple finishes enrollment.

**You can still do almost everything else.** When the account goes active, you’ll only need to paste info, upload screenshots, pick a build, and submit.

---

## Already done ✅

- [x] Privacy policy live: **https://thyghos.github.io/petpal-privacy/**
- [x] Support email: **ealecci@gmail.com**
- [x] Info.plist permission strings (photo, camera, location, notifications)
- [x] See **`APP_STORE_CONTACT_INFO.md`** and **`APP_STORE_LISTING_DRAFT.md`**

---

## Do in the next 48 hours (in order)

### 1. Test the app (1–3 hours)
Run on **Simulator** and a **real iPhone** if you have one:

| Check | Notes |
|-------|--------|
| Add / edit / delete pet | Photos, weight, species |
| My Pets, active pet | |
| Home tiles | Open each screen; placeholders are OK |
| Emergency QR | Create profile, see QR |
| Travel Mode | Location permission, map loads |
| Settings | Tile order, health tip prefs |
| Disclaimers | Accept once, re-open from settings if needed |
| Kill app & relaunch | Data still there (SwiftData) |
| Airplane mode | App doesn’t crash |

Fix any crashes or blockers you find.

---

### 2. App icon — 1024×1024 (30–90 min)
Apple **requires** a 1024×1024 PNG (no transparency, square — iOS rounds it).

1. Design in Canva, Figma, or hire on Fiverr.
2. Xcode → **Assets.xcassets** → **AppIcon** → drag the 1024 image into the **iOS** slot (or single universal slot).

---

### 3. Screenshots (1–2 hours)
**When your account is active**, Apple needs screenshots. Capture them **now** so you’re ready.

1. Xcode → Simulator → **iPhone 16 Pro Max** (or **15 Pro Max**) — 6.7" display.
2. Run app (**⌘R**), go to each screen, **⌘S** (saves to Desktop).
3. Take **at least 3**, ideally **5–8**: Home, My Pets, Emergency QR, Travel Mode, Settings, Health tip, etc.

Optional: later add frames/text in [App Store Screenshot](https://appscreenshotmaker.com/) or similar.

---

### 4. Listing copy (15 min)
Open **`APP_STORE_LISTING_DRAFT.md`**. Tweak subtitle, description, keywords. When App Store Connect opens, you’ll **copy-paste**.

---

### 5. Code cleanup (optional, 30–60 min)
- Build (**⌘B**) → fix **yellow warnings** in the Issues navigator.
- Search project for **`print(`** — remove or wrap in `#if DEBUG` before you ship (there are several in **TravelModeView** and **LocationManager**).

---

### 6. Read Apple’s checklist (15 min)
Skim **`PAWPAL_APP_STORE_ACTION_PLAN.md`** Day 2–5 so you know what’s next after enrollment.

---

## When the account is active (Day 0 of “real” submit)

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) — sign in, accept agreements.
2. **My Apps** → **+** → **New App** (bundle ID must match Xcode: `com.thyghos.Petpal.Petpal`).
3. Paste **privacy URL**, **support email**, listing text from **`APP_STORE_LISTING_DRAFT.md`**.
4. Upload screenshots.
5. **Xcode** → **Product → Archive** → **Distribute App** → App Store Connect.
6. In Connect, select the build → **Submit for review**.

---

## Summary

| Now (waiting) | After account active |
|---------------|----------------------|
| Test, icon, screenshots, listing draft | Create app, paste URLs/text |
| Fix bugs & warnings | Upload build, submit |

You’re not behind — use the wait time for **testing + icon + screenshots**; that’s usually what takes longest anyway.
