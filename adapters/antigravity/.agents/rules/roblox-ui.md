---
trigger: model_decision
description: "Apply for any Roblox UI request: screenshots from the owner, phone layout fixes, new menus, toasts, cards, text size."
---

# Roblox UI work

- "DON'T CHANGE THE DESIGN": phone/fit fixes change size, position, scale, wrap, Phone* attributes only. Never colours,
  fonts, studs, strokes, gradients, art or copy.
- Exact studded recipe (layer stack, palette, component sizes, text rule, phone fit): `docs/STUDDED_UI_GUIDE.md`;
  insertable example: `assets/ui/reference/StuddedUI_Reference.rbxmx`.
- New UI = clone the closest existing styled template from `ReplicatedStorage.UITemplates` and change content.
- Find elements with `grep -n "<Name>" ui-map.md` before searching the place. Regenerate the map after UI builds.
- Check PC 1920x1080 and phone 667x375 (`tools/rig/shot.sh <place> <name> open=<Menu>`); look at both PNGs. Watch the
  thumbstick (bottom-left), jump button (bottom-right), menu headers/X, notch insets.
- Text: TextScaled requires TextWrapped; ≥ 12 px effective on phone; long text wraps to 2 lines with "…" (`MaxChars`).
- Popups: never add one that wasn't asked for; removed popups stay as hidden templates with `@Enabled=false`.
- Report: shots first, "rig shots only, not on a real device" unless Studio/device checked it, and the attribute the
  owner can edit in Studio.
- Windows (PowerShell): `.\tools\rig\shot.ps1 <place> <name> open=<Menu>` (docs/windows.md).
