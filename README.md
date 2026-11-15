# Expose Plus

Menu-bar utility that adds keyboard actions to macOS Mission Control. Open Mission Control, hover a window, press (defaults; every shortcut can be changed in **Settings…** from the menu-bar icon):

| Key | Action |
|-----|--------|
| W | Close window |
| ⌥W | Close all windows of the app |
| M | Minimize window |
| H | Hide app |
| ⌥H | Hide all other apps |
| Q | Quit app |
| ⌥Q | Force quit app |

Icons live in `Resources/` (regenerate with `swift Scripts/make_icon.swift <outdir>` then `iconutil -c icns`).

Hover a window in Mission Control and a small ✕ appears on its top-left corner (can be switched off in Settings).

Created by Small Tools Studio. Released under the MIT License (see `LICENSE`).

Settings (menu-bar icon → Settings…): change each action's shortcut and an optional alternate key (modifiers ⌃⌥⇧⌘ allowed), switch actions on/off, reset to defaults, and show/hide the ✕. Also in the menu: Launch at Login, About, Show Log.

## Build & run
```bash
./Scripts/build_app.sh
open build/ExposePlus.app
```
Grant **Accessibility** (and Input Monitoring if prompted) in System Settings → Privacy & Security.

## Notes
- Hit-testing reads the Dock's accessibility tree while Mission Control is open. If it stops finding windows on a new macOS version, run `build/ExposePlus.app/Contents/MacOS/ExposePlus --dump-mc` from Terminal, open Mission Control within 5s, and adjust `MissionControl.swift`.
- Windows with empty titles can't be matched to a real window; windows on other Spaces may not be closable via Accessibility.
