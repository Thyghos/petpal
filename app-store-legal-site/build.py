#!/usr/bin/env python3
"""Generate privacy.html and terms.html from repo-root markdown. Run from app-store-legal-site/."""

from __future__ import annotations

import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = Path(__file__).resolve().parent


def inline_fmt(line: str) -> str:
    parts = line.split("**")
    out: list[str] = []
    for i, p in enumerate(parts):
        if i % 2 == 0:
            out.append(html.escape(p))
        else:
            out.append("<strong>" + html.escape(p) + "</strong>")
    return "".join(out)


def md_to_body(md: str) -> str:
    lines = md.splitlines()
    chunks: list[str] = []
    in_ul = False

    def close_ul() -> None:
        nonlocal in_ul
        if in_ul:
            chunks.append("</ul>\n")
            in_ul = False

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            close_ul()
            i += 1
            continue

        if stripped == "---":
            close_ul()
            chunks.append("<hr />\n")
            i += 1
            continue

        if stripped.startswith("# "):
            close_ul()
            chunks.append(f"<h1>{inline_fmt(stripped[2:])}</h1>\n")
            i += 1
            continue

        if stripped.startswith("## "):
            close_ul()
            chunks.append(f"<h2>{inline_fmt(stripped[3:])}</h2>\n")
            i += 1
            continue

        if stripped.startswith("### "):
            close_ul()
            chunks.append(f"<h3>{inline_fmt(stripped[4:])}</h3>\n")
            i += 1
            continue

        if stripped.startswith("- "):
            if not in_ul:
                chunks.append("<ul>\n")
                in_ul = True
            chunks.append(f"<li>{inline_fmt(stripped[2:])}</li>\n")
            i += 1
            continue

        close_ul()
        para_lines = [stripped]
        i += 1
        while i < len(lines):
            n = lines[i]
            ns = n.strip()
            if not ns or ns.startswith("#") or ns.startswith("- ") or ns == "---":
                break
            para_lines.append(ns)
            i += 1
        chunks.append("<p>" + inline_fmt(" ".join(para_lines)) + "</p>\n")

    close_ul()
    return "".join(chunks)


def wrap_page(title: str, body: str, active: str) -> str:
    nav = f"""<nav class="nav"><a href="index.html">Home</a><a href="privacy.html"{" class=\"active\"" if active == "privacy" else ""}>Privacy</a><a href="terms.html"{" class=\"active\"" if active == "terms" else ""}>Terms</a><a href="support.html"{" class=\"active\"" if active == "support" else ""}>Support</a></nav>"""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{html.escape(title)} — Petpal</title>
  <link rel="stylesheet" href="styles.css" />
</head>
<body>
  <header class="site-header">
    {nav}
    <p class="app-name">Petpal</p>
  </header>
  <main class="content">
    <article class="legal">
{body}
    </article>
  </main>
  <footer class="site-footer"><p>Petpal · App Store legal pages</p></footer>
</body>
</html>
"""


def brand_fix(s: str) -> str:
    """Normalize legacy names to Petpal for generated HTML."""
    return s.replace("PawPal", "Petpal").replace("PAWPAL", "PETPAL")


def main() -> None:
    privacy_md = (ROOT / "PRIVACY_POLICY.md").read_text(encoding="utf-8")
    terms_md = (ROOT / "TERMS_OF_SERVICE.md").read_text(encoding="utf-8")

    privacy_body = md_to_body(brand_fix(privacy_md))
    terms_body = md_to_body(brand_fix(terms_md))

    (SITE / "privacy.html").write_text(
        wrap_page("Privacy Policy", privacy_body, "privacy"), encoding="utf-8"
    )
    terms_body = terms_body.replace(
        "See our full Privacy Policy at: [privacy policy URL]",
        'See our full <a href="privacy.html">Privacy Policy</a>.',
    )

    (SITE / "terms.html").write_text(
        wrap_page("Terms of Service", terms_body, "terms"), encoding="utf-8"
    )
    print("Wrote privacy.html and terms.html")


if __name__ == "__main__":
    main()
