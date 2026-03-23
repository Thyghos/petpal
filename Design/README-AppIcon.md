# Petpal app icon

## 1024×1024 file (for App Store / drag into Xcode)

- **`Design/Petpal-AppIcon-1024x1024.png`** (on-disk filename) — exact **1024×1024** px, blue + white heart + orange paw for **Petpal**.  
- Same image as **`Assets.xcassets/AppIcon.appiconset/AppIcon-ios-1024.png`** (regenerated whenever you run the script below).

---

## Fixing “scrunched” dock icon

## Why it looked scrunched (especially on Mac)

The Xcode target uses **`Assets.xcassets`** at the **project root** (not `Petpal/Assets.xcassets`).

That catalog includes **macOS** icon slots (16px → 1024px). If those slots were **empty**, Xcode scaled whatever it had (often only an iOS 1024 image) into each size — and **non-square or missing assets** can produce a **stretched / squeezed** icon in the Dock.

## What we did

1. **Filled every App Icon slot** with a **square** PNG at the exact pixel size Xcode expects.
2. **`Design/generate_app_icon.py`** draws the heart + paw in code so every size is truly **N×N** pixels.

Regenerate anytime:

```bash
cd /path/to/Petpal
python3 Design/generate_app_icon.py
```

(Requires `pip3 install Pillow` if needed.)

Then in Xcode: **Product → Clean Build Folder** (Shift+Cmd+K), build, and run again.

## Colors

- Background `#4A90D9` (Brand Blue)  
- Heart `#FFFFFF`  
- Paw `#F4845F` (Brand Orange)
