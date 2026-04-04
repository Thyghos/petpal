# Phase 2 — Host legal & support pages (Petpal)

App Store Connect needs **HTTPS URLs** that anyone can open (try **Safari Private** mode).

## What’s here

| File | Purpose |
|------|--------|
| `index.html` | Hub + sanity check |
| `privacy.html` | Generated — do not edit by hand |
| `terms.html` | Generated — do not edit by hand |
| `support.html` | Edit support email addresses here |
| `styles.css` | Shared styling |
| `build.py` | Builds `privacy.html` / `terms.html` from `../PRIVACY_POLICY.md` and `../TERMS_OF_SERVICE.md` |

Regenerate after changing the markdown:

```bash
cd app-store-legal-site
python3 build.py
```

## Before you publish

1. Fill in **`[INSERT DATE]`**, **`[Your Company Name]`**, **`[Your State/Country]`**, **`[Your Jurisdiction]`**, **`[your website]`**, and AI provider names in **`PRIVACY_POLICY.md`** and **`TERMS_OF_SERVICE.md`**, then run `build.py` again.
2. Update **`support.html`** with real `mailto:` links and visible addresses.

## Deploy (pick one)

### GitHub Pages (simple)

1. Push the repo to GitHub.
2. Repo **Settings → Pages**: source **Deploy from a branch** (usually `main`), folder **`/` (root)**.
3. If you keep this site under **`app-store-legal-site/`**, your URLs will be:  
   `https://YOUR_USERNAME.github.io/REPO_NAME/app-store-legal-site/privacy.html`  
   (and the same path prefix for `terms.html` / `support.html`).  
   Alternatively, copy these files into a **`docs/`** folder and set Pages to **`/docs`** so paths are shorter.
4. Use the **full https URLs** in App Store Connect (Phase 5).

### Any other host

Upload the folder contents to your web server or static host (Netlify, Cloudflare Pages, etc.). Keep `privacy.html`, `terms.html`, `support.html`, and `styles.css` together.

## Automated deploy (GitHub)

This repo includes **`.github/workflows/deploy-legal-pages.yml`**. After you push to **`main`**, enable **Pages** from the **`gh-pages`** branch (see **`PHASE2_HOSTING.md`** in the project root).

## Phase 2 checklist

- [ ] `python3 build.py` run after any change to `PRIVACY_POLICY.md` / `TERMS_OF_SERVICE.md`
- [ ] Site deployed; pages load over **https://**
- [ ] No login required
- [ ] Privacy + Support URLs ready to paste in App Store Connect (Phase 5); Terms URL saved for linking or review notes

See **`PHASE2_HOSTING.md`** for the full close-out steps.
