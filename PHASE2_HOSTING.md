# Phase 2 — Finish hosting (Petpal)

You need **three HTTPS URLs** with no login: **Privacy**, **Terms** (strongly recommended), **Support**.

## What’s ready in this repo

- Source: **`PRIVACY_POLICY.md`**, **`TERMS_OF_SERVICE.md`**
- Built site folder: **`app-store-legal-site/`** (`python3 build.py` generates `privacy.html` + `terms.html`; `support.html` is edited by hand)

## Option A — GitHub Actions (this repo)

1. Push **`main`** to GitHub (include `.github/workflows/deploy-legal-pages.yml`).
2. Open **Actions** → run **Deploy legal pages** (or push a change under `app-store-legal-site/` or the two markdown files).
3. **Settings → Pages**: source **Deploy from a branch** → branch **`gh-pages`**, folder **`/(root)`**.
4. Your URLs will look like:

   `https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/privacy.html`  
   `https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/terms.html`  
   `https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/support.html`

5. In **Safari Private** mode, open each URL and confirm they load.

## Option B — Keep using `petpal-privacy` only

If you only host a single `index.html` there today, add **`terms.html`** and **`support.html`** (copy from `app-store-legal-site/` after running `build.py`) into that repo, enable Pages, then use:

- Privacy Policy URL → your policy page  
- Support URL → `.../support.html`  
- (Link to terms from the policy page or App Review notes if needed.)

## App Store Connect (Phase 5)

Paste **Privacy Policy URL** and **Support URL** in App Store Connect. Keep the three URLs in **`APP_STORE_CONTACT_INFO.md`** (update the table after you know the live paths).

## Phase 2 done when

- [x] Privacy, Terms, and Support pages load over **https://**
- [x] No sign-in required
- [ ] Copy on pages matches **`PRIVACY_POLICY.md` / `TERMS_OF_SERVICE.md`** (re-run `build.py` after legal edits) — re-check whenever you change the Markdown
- [x] URLs saved — see **`APP_STORE_CONTACT_INFO.md`**
