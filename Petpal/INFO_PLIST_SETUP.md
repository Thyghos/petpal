# Info.plist notes (Petpal)

Petpal does **not** use Google Places, BringFido, or Geoapify keys. Optional **Vet AI** configuration lives in code (see `APIConfiguration.swift`) or your own secure setup—do not commit API secrets to the repository.

## Adding custom keys in Xcode

1. Select the project in the Project Navigator, then your app **target**.
2. Open the **Info** tab (or edit `Petpal/Info.plist` as source).
3. Use **+** to add keys your build needs (e.g. custom URL schemes or feature flags you add yourself).

## Security

- Prefer **xcconfig** or local untracked files for secrets, not committed plist values.
- If you paste keys into plist for local testing, keep them out of git (see `.gitignore` patterns you maintain for your team).
