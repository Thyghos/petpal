# Petpal — Day 1 App Store checklist (do this today)

## ✅ Your live details (use in App Store Connect)

| | |
|--|--|
| **Privacy policy** | https://thyghos.github.io/petpal-privacy/ |
| **Support email** | ealecci@gmail.com |

See also **`APP_STORE_CONTACT_INFO.md`**.

---

Your main guides in this folder:
- **`ULTRA_QUICK_START.md`** — fastest path (privacy HTML, Day 1–7 outline)
- **`PAWPAL_APP_STORE_ACTION_PLAN.md`** — full 7-day plan (name is legacy; content is Petpal)

---

## Task 1 — Privacy policy ✅ (done)

Your policy is live: **https://thyghos.github.io/petpal-privacy/**  
Paste that exact URL into App Store Connect when asked for the privacy policy.

---

## Task 2 — Support email ✅

Use **`ealecci@gmail.com`** in App Store Connect (support contact).

---

## Task 3 — Info.plist privacy strings (already added in Xcode)

These are now in your **Petpal** target in Xcode (Debug + Release) so iOS shows proper permission dialogs for **Petpal**:

| Permission | Why |
|------------|-----|
| Photo library | Pet profile photos |
| Photo library (add) | Saving QR / images |
| Camera | Optional pet photos |
| Location | Not used in the current app (omit or remove key if unused) |
| User notifications | Reminders (if you add notifications later) |

To **edit the wording**: Xcode → select the **Petpal** target → **Build Settings** → search **“Privacy”** or **“INFOPLIST_KEY_NS”**.

---

## After Day 1

Open **`PAWPAL_APP_STORE_ACTION_PLAN.md`** and follow **Day 2** (testing), then icon, screenshots, App Store Connect, archive, submit.

**Costs:** Apple Developer Program **$99/year** (required to ship on the App Store).

---

## Mini HTML (copy if you don’t have the file open)

Same as `ULTRA_QUICK_START.md` — use repo name **`petpal-privacy`** and site URL **`.../petpal-privacy`**.
