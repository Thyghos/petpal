# Build Errors Fix Guide

## Errors to Fix

1. ✅ **Cannot find type 'EmergencyProfile' in scope** - FIXED
2. ⚠️ **Multiple commands produce .stringsdata** - Follow steps below
3. ⚠️ **Invalid redeclaration of 'PetpalApp'** - Follow steps below

---

## Fix 1: Multiple Commands Produce .stringsdata

This error occurs when Xcode has duplicate file references or the same file is being compiled multiple times.

### Step-by-Step Solution:

1. **Clean Build Folder**
   - In Xcode menu: `Product > Clean Build Folder` (⇧⌘K)
   - This removes all cached build artifacts

2. **Check for Duplicate String Files**
   - In Xcode's Project Navigator (left sidebar), search for:
     - `Localizable.strings`
     - `InfoPlist.strings`
     - Any `.strings` files
   
   - If you find duplicates:
     - Select the duplicate file
     - Press Delete
     - Choose "Move to Trash" (not just "Remove Reference")

3. **Remove Duplicate Build Phase Entries**
   - Click on your project in the Project Navigator (blue icon at top)
   - Select your app target (under TARGETS)
   - Go to "Build Phases" tab
   - Expand "Copy Bundle Resources"
   - Look for duplicate entries of the same file
   - If you see any `.strings` files listed twice, select the duplicate and click the minus (−) button

4. **Check Localization Settings**
   - Select your project (blue icon)
   - Go to the "Info" tab
   - Under "Localizations", check if there are duplicate entries
   - Remove any duplicates

5. **Rebuild**
   - Press ⌘B to build
   - The .stringsdata error should be resolved

---

## Fix 2: Invalid Redeclaration of 'PetpalApp'

This error means there are multiple `@main` entry points or duplicate struct definitions.

### Step-by-Step Solution:

1. **Search for Duplicate App Files**
   - Press ⌘⇧F (Find in Project)
   - Search for: `@main`
   - You should only see ONE result in `PetpalApp.swift`
   - If you see multiple results:
     - Note which files have `@main`
     - Keep only `PetpalApp.swift` with `@main`
     - Remove `@main` from any other files

2. **Search for Duplicate PetpalApp Definitions**
   - Press ⌘⇧F (Find in Project)
   - Search for: `struct PetpalApp`
   - You should only see ONE result
   - If you see multiple:
     - One might be named `PawPalApp` (note the 'w')
     - Delete or rename the duplicate file

3. **Check for These Common Duplicate Files:**
   - `PawPalApp.swift` (note: different spelling)
   - `App.swift`
   - `main.swift`
   - `[YourAppName]App.swift`
   
   If any exist and have `@main` or `struct PetpalApp`:
   - Either delete them
   - Or remove the `@main` attribute from all except `PetpalApp.swift`

4. **Verify Your Target Membership**
   - Select `PetpalApp.swift` in Project Navigator
   - Open the File Inspector (right sidebar, first tab)
   - Under "Target Membership", make sure only ONE target is checked
   - If multiple targets are checked, uncheck the extras

5. **Clean and Rebuild**
   - Press ⇧⌘K (Clean Build Folder)
   - Press ⌘B (Build)

---

## Fix 3: Remove Unused Template Files (Optional but Recommended)

The default Xcode template created `Item.swift` and `ContentView.swift` which you're not using.

### Option A: Delete Them Completely
1. In Project Navigator, select `Item.swift`
2. Press Delete, choose "Move to Trash"
3. Repeat for `ContentView.swift` if you're not using it
4. Build the project

### Option B: Keep Them But Remove from Target
1. Select `Item.swift` in Project Navigator
2. Open File Inspector (right sidebar)
3. Under "Target Membership", uncheck your app target
4. Repeat for `ContentView.swift`

---

## Quick Checklist

Use this checklist to verify your fixes:

- [ ] Only ONE file has `@main` attribute
- [ ] Only ONE file defines `struct PetpalApp`
- [ ] No duplicate `.strings` files in Project Navigator
- [ ] No duplicate files in Build Phases > Copy Bundle Resources
- [ ] Cleaned build folder (⇧⌘K)
- [ ] Built successfully (⌘B)

---

## Still Having Issues?

If errors persist after following all steps:

1. **Check the Exact Error Message**
   - The error panel shows exactly which files are conflicting
   - Look for the file paths in the error details
   - Those are the files you need to fix

2. **Nuclear Option: Reset Derived Data**
   ```
   1. Quit Xcode
   2. Open Finder
   3. Press ⇧⌘G (Go to Folder)
   4. Enter: ~/Library/Developer/Xcode/DerivedData
   5. Delete the folder that matches your project name
   6. Restart Xcode
   7. Open your project
   8. Clean Build Folder (⇧⌘K)
   9. Build (⌘B)
   ```

3. **Check Build Errors Panel**
   - Click on the error in Xcode's Issue Navigator
   - It will show you exactly which files are causing the conflict
   - Share the complete error message if you need more help

---

## What I've Already Fixed

✅ **EmergencyProfile Model** - Created in Models.swift  
✅ **EmergencyProfileEditor** - Created new file  
✅ **Model Container** - Updated PetpalApp.swift to include EmergencyProfile  
✅ **ContentView.swift** - Removed broken Item reference  

---

## Expected Result

After following these steps, you should be able to:
- Build the project without errors (⌘B shows "Build Succeeded")
- Run the app in simulator or on device
- Access the Emergency QR feature without crashes
- Create and edit emergency profiles

Good luck! 🍀
