# 🚨 DUPLICATE FILES - URGENT FIX

## The Problem

Your errors show **"is ambiguous for type lookup"** - this means you have **DUPLICATE** files defining the same types!

Looking at your screenshot, the "Invalid redeclaration of 'TilePreferences'" error in the **Models** section confirms this.

---

## 🎯 IMMEDIATE FIX

### Step 1: Find Duplicate Models.swift Files

1. **In Xcode Project Navigator** (left sidebar):
   - Press ⌘F to search
   - Type: `Models.swift`
   - You'll likely see **TWO or MORE** Models.swift files!

2. **Common duplicate locations:**
   - `Models.swift` (in root)
   - `Petpal/Models.swift`
   - `PawPal/Models.swift` (note the different spelling)
   - `Models/Models.swift`
   - Or similar variations

### Step 2: Delete ALL Duplicate Models Files

1. **Keep ONLY ONE Models.swift**
2. **Delete the others:**
   - Right-click on each duplicate
   - Choose "Delete"
   - Choose "Move to Trash" (NOT "Remove Reference")

### Step 3: Verify You Have Just ONE Models.swift

The ONE Models.swift you keep should contain ALL these types:
- `Pet`
- `PetReminder`
- `TilePreferences`
- `EmergencyProfile`
- `HealthTipPreferences`
- `TipFrequency` (enum)
- `HomeTile` (struct)
- `HealthTip` (struct)
- `HealthTipService` (struct)
- `HapticManager` (class)

---

## 🔍 Alternative: Use Xcode's File Search

1. **In Xcode menu:** Edit > Find > Find in Workspace (⇧⌘F)
2. **Search for:** `final class TilePreferences`
3. **You should see only ONE result**
4. **If you see multiple:**
   - Note which files they're in
   - Those are your duplicate files
   - Delete all but one

---

## ✅ After Deleting Duplicates

1. **Clean Build Folder:** ⇧⌘K
2. **Delete Derived Data:**
   ```bash
   # In Terminal:
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. **Restart Xcode**
4. **Build:** ⌘B

---

## 🎯 What About Other Duplicates?

You might also have:

### Duplicate App Files
- Search for `@main` (⌘⇧F)
- Keep only `PetpalApp.swift`
- Delete:
  - `PawPalApp.swift` (different spelling)
  - Any other files with `@main`

### Duplicate View Files
Common duplicates:
- `HomeView.swift` (might have multiple)
- `HealthTipCard.swift`
- `SettingsView.swift`

**For each view:**
1. Search for the filename (⌘F in Project Navigator)
2. If you see multiples, keep the newest/best one
3. Delete the rest

---

## 🚀 Quick Terminal Command

If you want to find all Swift files with the same name:

```bash
cd ~/path/to/your/Petpal/project
find . -name "Models.swift" -type f
```

This will show you the paths to ALL Models.swift files.

---

## Why This Happened

Common causes:
1. **Renamed the app** from PawPal to Petpal (or vice versa)
2. **Accidentally duplicated files** by copying folders
3. **Merged code** from different branches
4. **Xcode template confusion** when creating new files

---

## Expected Result

After deleting duplicates:

✅ Only ONE `Models.swift` file  
✅ Only ONE `PetpalApp.swift` file  
✅ Only ONE of each view file  
✅ No more "ambiguous" errors  
✅ Build succeeds (⌘B)  

---

## Screenshot Check

In your screenshot, look for:
- ❌ "Invalid redeclaration of 'TilePreferences'" in **Models**
- This means Models.swift has duplicate definitions **inside it** OR there are multiple Models.swift files

**If it's INSIDE one Models.swift:**
- Open Models.swift
- Search for `class TilePreferences`
- You'll find it defined TWICE
- Delete one of the duplicate definitions

---

## Need Help?

If you can't find the duplicates:

1. **Show file paths in Project Navigator:**
   - Right-click in Project Navigator
   - Choose "Show File Inspector"
   - Select each Models.swift
   - Look at "Full Path" in inspector

2. **Or use Terminal:**
   ```bash
   cd ~/path/to/Petpal
   find . -name "*.swift" | sort | uniq -d
   ```
   This shows duplicate filenames.

---

## After Fix

Once you've deleted all duplicates:

1. **Verify with search:**
   - ⌘⇧F for `final class TilePreferences`
   - Should see exactly ONE result
   - ⌘⇧F for `@main`
   - Should see exactly ONE result

2. **Build:**
   - ⌘B should succeed
   - All "ambiguous" errors should be gone

3. **Test the app!**

Good luck! 🍀
