# UI assets (Pumpkin King style kit)

Reusable Halloween "studded" UI from *Don't Wake the Pumpkin King*: orange/purple studded buttons and cards, sale pills, toasts, cash/claim popups, side offer cards. Everything here is meant to be **real, editable Studio instances**. Scripts in a game should only clone, show/hide, fill text and tween these; they should never build visuals with `Instance.new`.

## templates/ (`.rbxm`, scripts stripped)

| File | What it is | Parent it under |
|---|---|---|
| `LeftButtons_MenuGrid.rbxm` | Left menu grid (STORE, INDEX, GEAR, BAG, UPGRADE, REBIRTH, DAILY, QUESTS): studded face buttons with gradient, UIStroke, label stroke, 3D shadow strip, UIGridLayout + phone overrides | `StarterGui.<YourScreenGui>` |
| `DropButton.rbxm` | Big action button (gradient + studs CanvasGroup + icon + 3D strip) | a ScreenGui |
| `SideCard.rbxm` | Right-side offer card. `Theme` attribute = `Orange` or `Magenta` picks which UIGradient/UIStroke children are enabled; `Burst` spins (`Speed` attr) | `ReplicatedStorage.UITemplates` (clone source) |
| `StoreCards.rbxm` | Store game-pass / product card templates (price row, strike-through old price) | `ReplicatedStorage.UITemplates` |
| `SalePills.rbxm` | Sale pill tags (-50%, BEST VALUE, countdown) | `ReplicatedStorage.UITemplates` |
| `Toast.rbxm` | Compact studded toast | `ReplicatedStorage.UITemplates` |
| `ReadyToast.rbxm` | "Ready!" style toast with icon | `ReplicatedStorage.UITemplates` |
| `JuiceFx.rbxm` | Cash-claimed / collect "juice": big +$ number, coin spray, burst pieces | `ReplicatedStorage.UITemplates` |
| `OfflineClaimFx.rbxm` | Welcome-back offline-cash claim popup pieces (coin shower, cha-ching) | `ReplicatedStorage.UITemplates` |
| `MilestoneFx.rbxm` | Milestone / progress celebration pieces | `ReplicatedStorage.UITemplates` |
| `LootLabel.rbxm` | Floating loot name/rarity/price BillboardGui | `ReplicatedStorage.UITemplates` |
| `BuyAmountToggle.rbxm`, `FoldToggle.rbxm` | x1/x5/x10 buy toggle, collapse arrow | `ReplicatedStorage.UITemplates` |
| `ButtonFx.rbxm` | Configuration whose attributes tune button hover/press squish | `ReplicatedStorage.UITemplates` |

Insert: Studio > right-click the parent > **Insert from File...** > pick the `.rbxm`.

## reference/ (start here if you are an AI or new to the style)

| File | What it is |
|---|---|
| `StuddedUI_Reference.rbxmx` | A complete ScreenGui: side button column, panel (green header, red X, blue tabs, card with orange head + 3D stage + green BUY, gold secondary, purple primary), toast container + template, tooltip, `Palette` attributes, and a working `StuddedUIClient` LocalScript. Insert into **StarterGui** and press Play. |
| `build_reference.luau` | The Lune generator that writes the `.rbxmx`; the whole recipe as readable code. `STUDS_ID=<id> tools/lune10 run assets/ui/reference/build_reference.luau` bakes your studs texture. |
| `StuddedUIClient.luau` | Reference runtime script: DeviceScale + Phone* attributes, press feel, panel open/close pop, tabs, toasts, tooltip, shine. No `Instance.new`. |
| `studs_tile.png` | 168×128 transparent one-stud tile (original). Upload it as an image and use its ID for every `STUDS` ImageLabel. |

The `.rbxmx` ships with `rbxassetid://0` as the studs image (the repo keeps asset IDs as placeholders), so studs are
blank until you set your own. Exact values and rules: [docs/STUDDED_UI_GUIDE.md](../../docs/STUDDED_UI_GUIDE.md).

## previews/ (PNG)

`*_pc.png` (1920x1080) and `*_phone.png` (667x375) layout previews of the HUD, Store, Rebirth, Daily and Inventory menus, plus crops (`crop_menu_buttons`, `crop_store_pass_cards_sale_pills`, `crop_side_offer_cards`, `crop_sale_banner`). They are **approximate renders** from the repo's offline rig (geometry and colours from the place file; icons and 3D are grey placeholders), not Studio screenshots.

## How the look is built (rebuild or restyle in Studio)

- **Face:** ImageButton/ImageLabel with a white background, a face image (`ScaleType Fit`), `UICorner` and a `UIGradient` (orange `#FF7300`, purple `#A005FF`, magenta-to-orange `#B439FF`->`#E97210`, rotation 90).
- **Studs:** a `CanvasGroup` (same corner) holding a tiled `STUDS` ImageLabel, TileSize about `(0.08,0,0.25,0)`, ImageTransparency 0.5. Change the tile image or its transparency to restyle every button at once.
- **Outline:** a real `UIStroke` (about 3 px, dark brown `#612C00` / dark purple `#350055`). Labels use GothamSSm Heavy, white, with their own UIStroke (about 2.5 px). Prices use FredokaOne, buy buttons Montserrat Heavy.
- **3D:** a `threedimensional` Frame (black, transparency 0.8) under the face.
- **Themes:** keep two UIGradient/UIStroke children named `Orange` and `Magenta` and toggle `Enabled` from a `Theme` attribute instead of recolouring in code.
- **Phones:** put `PhoneSize`, `PhonePosition`, `PhoneAnchorPoint` (and grid `PhoneCellSize`) attributes on the instance and let a small fit script apply them on touch devices. Fit only; don't redesign.
- **Text:** `TextScaled` must have `TextWrapped = true` and a `UITextSizeConstraint` with `MinTextSize >= 12`, or Roblox draws it at plain `TextSize`.

## Images and license

Image textures (`rbxassetid://...`) are Roblox-hosted. If one doesn't load in your game (asset permissions), upload your own studs and face images and swap the IDs. Game-pass, product, badge and other account-tied attributes have been stripped to 0. The layout, templates and previews are the repo owner's own work, under the repo's license.
