# PawPal → Petpal Rebranding Guide

## 🎯 Complete Rebranding Checklist

This guide will help you change all instances of "PawPal" to "Petpal" throughout your project.

---

## Why Petpal?

**Benefits of Petpal:**
- ✅ Broader appeal (all pets, not just pawed animals)
- ✅ Includes birds, fish, reptiles naturally
- ✅ Easier to pronounce
- ✅ More memorable
- ✅ Better for App Store search (pet > paw)

---

## 📋 Files to Update

### 1. Xcode Project Files

**Project Name:**
1. Open Xcode
2. Select project in Navigator
3. Click project name (top of file list)
4. Rename: `PawPal` → `Petpal`
5. Xcode will ask to rename scheme - Click "Rename"

**Display Name:**
1. Select target (Petpal)
2. General tab
3. Display Name: `Petpal`
4. Bundle Name: `Petpal`

**Bundle Identifier:**
- Old: `com.thyghos.pawpal`
- New: `com.thyghos.petpal`

**Important:** If you've already registered the bundle ID in App Store Connect, you may need to create a new app listing.

---

### 2. Swift Source Files

**Files to update (search for "PawPal" or "pawpal"):**

- All `.swift` files
- `Info.plist` strings
- Asset catalog names
- Scheme names

**Find & Replace in Xcode:**
1. Press `Cmd + Shift + F` (Find in Project)
2. Find: `PawPal`
3. Replace: `Petpal`
4. Click "Replace All" (be careful!)

**Also search for lowercase:**
- Find: `pawpal`
- Replace: `petpal`

---

### 3. Documentation Files

**Update these markdown files:**

- [ ] `README.md`
- [ ] `PRIVACY_POLICY_TEMPLATE.md`
- [ ] `APP_STORE_SUBMISSION_GUIDE.md`
- [ ] `SUBMISSION_CHECKLIST.md`
- [ ] `MODERN_DESIGN_GUIDE.md`
- [ ] `CUSTOMIZATION_GUIDE.md`
- [ ] `PRESET_FEATURES.md`
- [ ] `BEFORE_AFTER_VISUAL.md`
- [ ] `IMPLEMENTATION_SUMMARY.md`
- [ ] `ULTRA_QUICK_START.md` *(and other `.md` guides you keep)*
- [ ] All other `.md` files in your repo

**Quick way to update:**
1. Open each file
2. Find & Replace: `PawPal` → `Petpal`
3. Find & Replace: `pawpal` → `petpal`
4. Save

---

### 4. Privacy Policy (Critical!)

**Update your GitHub Pages:**

1. Go to: https://github.com/thyghos/pawpal-privacy
2. **Rename repository:**
   - Settings → Repository name
   - Change: `pawpal-privacy` → `petpal-privacy`
   - Click "Rename"

3. **Update index.html:**
   - Click `index.html`
   - Click pencil (Edit)
   - Find & Replace: `PawPal` → `Petpal`
   - Commit changes

4. **New URL will be:**
   - https://thyghos.github.io/petpal-privacy/

5. **Update App Store Connect:**
   - Change privacy policy URL to new URL

---

### 5. User-Facing Text

**In your app, update:**

- Welcome screens
- Onboarding text
- Settings screens
- About page
- Error messages
- Alert titles
- Navigation titles
- Tab bar titles
- Any hardcoded "PawPal" strings

**Example changes:**
```swift
// Before
Text("Welcome to PawPal")

// After
Text("Welcome to Petpal")
```

```swift
// Before
.navigationTitle("PawPal")

// After
.navigationTitle("Petpal")
```

---

### 6. Assets & Media

**App Icon:**
- If your icon says "PawPal", redesign with "Petpal"

**Screenshots:**
- Retake screenshots with new "Petpal" branding
- Update any text overlays

**Marketing Materials:**
- Update any graphics, banners, etc.

---

### 7. External Services

**GitHub Repository:**
- Consider renaming: `pawpal` → `petpal`
- Settings → Repository name → Rename

**Domain Names (if purchased):**
- Register: `petpal.com` (if planning to)
- Update DNS if needed

**Social Media:**
- Update handles if you've created any
- Twitter/X: @petpal
- Instagram: @petpalapp

---

## 🔍 Search Terms to Find

Use Xcode's Find in Project (`Cmd + Shift + F`) to search for:

1. `PawPal` (capital P, capital P)
2. `pawpal` (all lowercase)
3. `Pawpal` (capital P, lowercase p)
4. `PAWPAL` (all caps - unlikely but check)
5. `paw pal` (with space - shouldn't exist but check)

---

## 📝 Content Updates

### App Store Description

**Update from:**
> "Keep your pet healthy with PawPal..."

**To:**
> "Keep your pet healthy with Petpal..."

### Tagline/Subtitle

**Options:**
- "Petpal - Your Pet's Health Companion"
- "Petpal - Pet Care Made Easy"
- "Petpal - All Pets, One App"

### Keywords

**Update from:**
> pawpal,pet,dog,cat,health...

**To:**
> petpal,pet,dog,cat,health...

---

## 🎨 Branding Considerations

### Visual Identity

**Keep:**
- 🐾 Paw print icon (still works!)
- Color scheme (Orange, Blue, Purple)
- Modern design system
- Glassmorphism effects

**Update:**
- Text "PawPal" → "Petpal" everywhere
- App name display

### Voice & Tone

**Emphasize:**
- "Petpal works for ALL pets"
- "Whether you have a dog, cat, bird, rabbit, or reptile..."
- "Your pet's companion" (not just "paw pets")

---

## ⚠️ Important: App Store Connect

### If You Haven't Submitted Yet:

1. **Create new app listing with:**
   - Name: Petpal
   - Bundle ID: com.thyghos.petpal
   - Privacy URL: https://thyghos.github.io/petpal-privacy/

### If You Already Started Submission:

**Option A: Delete and Start Fresh**
- Delete the PawPal app listing
- Create new Petpal listing
- Pros: Clean start
- Cons: Lose any prep work

**Option B: Keep PawPal**
- Continue with PawPal branding
- Pros: No extra work
- Cons: Stuck with PawPal name

**Recommendation:** Since you haven't submitted yet, go with Option A - fresh start with Petpal!

---

## 🔄 Step-by-Step Rebranding Process

### Day 1: Core Project Files

- [ ] Rename Xcode project to Petpal
- [ ] Update bundle identifier
- [ ] Update display name
- [ ] Find & Replace in all Swift files
- [ ] Update Info.plist strings
- [ ] Test that app still builds

### Day 2: Documentation

- [ ] Rename GitHub repository
- [ ] Update privacy policy repository name
- [ ] Update privacy policy content
- [ ] Find & Replace in all .md files
- [ ] Update README

### Day 3: User-Facing Content

- [ ] Update all in-app text
- [ ] Update onboarding screens
- [ ] Update settings screens
- [ ] Update about page
- [ ] Test app thoroughly

### Day 4: Marketing Assets

- [ ] Update app icon if needed
- [ ] Retake screenshots
- [ ] Update app description
- [ ] Update keywords

### Day 5: Final Checks

- [ ] Search for any remaining "PawPal"
- [ ] Test app end-to-end
- [ ] Verify new privacy policy URL works
- [ ] Update App Store Connect

---

## 🧪 Testing Checklist

After rebranding, test:

- [ ] App launches successfully
- [ ] All screens show "Petpal"
- [ ] Navigation titles updated
- [ ] About screen shows "Petpal"
- [ ] Settings screen updated
- [ ] Health tips mention "Petpal"
- [ ] Privacy policy link works
- [ ] No "PawPal" in UI anywhere

---

## 📞 Updated Contact Information

**Old:**
- App: PawPal
- Privacy URL: https://thyghos.github.io/pawpal-privacy/
- Repository: pawpal

**New:**
- App: Petpal
- Privacy URL: https://thyghos.github.io/petpal-privacy/
- Repository: petpal
- Bundle ID: com.thyghos.petpal

---

## 🎯 Benefits of Rebranding Now

**Perfect timing because:**
- ✅ Haven't submitted to App Store yet
- ✅ No existing users to confuse
- ✅ No reviews/ratings to lose
- ✅ Privacy policy easy to update
- ✅ Marketing materials haven't launched

**This is the BEST time to rebrand!**

---

## 💡 Pro Tips

1. **Use Git:**
   ```bash
   git commit -m "Rebrand from PawPal to Petpal"
   ```
   So you can revert if needed.

2. **Case-Sensitive Search:**
   Make sure to check:
   - PawPal
   - pawpal
   - Pawpal

3. **Test on Device:**
   After rebranding, test on real device to see app name on home screen.

4. **Update Everywhere:**
   Don't forget comments in code, documentation, etc.

---

## 📋 Quick Reference

| Item | Old | New |
|------|-----|-----|
| **App Name** | PawPal | Petpal |
| **Bundle ID** | com.thyghos.pawpal | com.thyghos.petpal |
| **Privacy URL** | thyghos.github.io/pawpal-privacy/ | thyghos.github.io/petpal-privacy/ |
| **Repository** | pawpal | petpal |
| **Display Name** | PawPal | Petpal |

---

## 🚀 Next Steps After Rebranding

1. **Complete the rebrand** (use checklist above)
2. **Test thoroughly**
3. **Continue with App Store submission**
4. **Launch as Petpal!**

---

## ⚡ Quick Commands

**Find all occurrences in Xcode:**
```
Cmd + Shift + F
Search: PawPal
Replace: Petpal
Replace All
```

**Rename Xcode project:**
```
1. Click project name in Navigator
2. Click again to edit
3. Type "Petpal"
4. Press Enter
5. Confirm rename scheme
```

**Rename GitHub repo:**
```
1. Repository Settings
2. Rename to: petpal
3. Update local clone:
   git remote set-url origin https://github.com/thyghos/petpal.git
```

---

🎉 **Petpal is a great name! Let's make it official!**

This rebrand will make your app more inclusive and appealing to all pet owners, not just those with pawed pets. Birds, fish, and reptile owners will feel included too!

**Ready to start? Begin with Day 1 tasks and work through the checklist!**

Would you like me to help you update specific files first?
