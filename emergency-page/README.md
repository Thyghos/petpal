# Petpal Emergency Profile Page (GitHub Pages)

This static page displays emergency pet contact info when someone scans a Petpal QR code. No backend or database required.

## Setup

1. **Create a GitHub repo** named `petpal-emergency` (or any name).

2. **Enable GitHub Pages**:
   - Repo → Settings → Pages
   - Source: Deploy from a branch
   - Branch: `main` (or `master`), folder: `/ (root)` or `/docs` if you put files in `docs/`

3. **Add these files** to the repo root (or `docs/` if using that):
   - `index.html`

4. **Update the app** with your GitHub Pages URL:
   - In `Models.swift`, change `emergencyPageBaseURL` to your URL, e.g.:
   - `https://YOUR_GITHUB_USERNAME.github.io/petpal-emergency/`
   - Trailing slash required.

## URL format

The app encodes the emergency profile as base64 in the URL fragment:
`https://yoursite.github.io/petpal-emergency/#BASE64DATA`

When scanned, the page decodes and displays the info.
