# Studded UI guide: the exact recipe

This is how our studded Roblox UI is built: chunky panels, tiled LEGO-style studs, thick dark outlines, heavy white
outlined text. Any model (Claude, GPT, Gemini, a local 7B) should be able to rebuild it from this page alone. Every
number here was read from the shipped game (*ForgeTax*, `StarterGui.ForgeUI`, Oct 2026). *Don't Wake the Pumpkin King*
uses the same build with an orange/purple Halloween palette (§11).

**Working example:** [`assets/ui/reference/`](../assets/ui/reference/). `StuddedUI_Reference.rbxmx` is a panel with
a header, close X, tabs, card, buttons, toast, tooltip, a side button column and a working LocalScript. Insert it into
StarterGui and press Play. `build_reference.luau` is the generator that wrote it, so the whole recipe is also there as
code you can read.

---

## 0. The six rules (read these if you read nothing else)

1. **Every visual is a real instance saved in the place.** The owner must be able to click it in Studio and change it.
2. **Runtime scripts never call `Instance.new` for visuals.** They only clone a template, show/hide it, fill in
   Text/Image, tween it and read attributes. (Build-time Lune patch scripts may create instances, because their output
   gets saved into the place file.)
3. **New UI is a clone of existing UI.** Copy the closest panel or button that is already in the game, then change the
   text, size and position. Don't restyle it, and don't redraw it from memory.
4. **Text:** `TextScaled = true` + `TextWrapped = true` + a `UITextSizeConstraint` with `MinTextSize >= 12`, outlined with
   a `UIStroke`. Never use TextStroke.
5. **Phones fit through attributes** (`PhoneSize`, `PhonePosition`, `PhoneAnchorPoint`, a `DeviceScale` UIScale), never by
   redesigning. Check against a 667×375 phone and a 1920×1080 PC.
6. **Tunables and state colours are attributes** on the instance they control, never Lua constants.

---

## 1. Anatomy: the five layers of every studded surface

Every studded surface (panel, header, button, card, chip, toast) is the same stack:

```
<Surface>  Frame / ImageButton    BackgroundColor3 = #FFFFFF (coloured) or dark hex (dark), BackgroundTransparency 0, BorderSizePixel 0
├─ UICorner                       CornerRadius (0, 8)          ← Roblox default; on every layer that has a corner
├─ UIGradient                     coloured: top→bottom theme colours, Rotation 90 | dark: named "Shade", #FFFFFF→#9696A0, Rotation 90
├─ UIStroke                       Thickness 2.5–4, dark colour of the theme, ApplyStrokeMode Contextual
├─ Studs  CanvasGroup             Size {1,0},{1,0}, BackgroundTransparency 1, GroupTransparency 0, same ZIndex as surface
│  ├─ UICorner                    (0, 8)  ← the CanvasGroup exists ONLY to clip the tiles to the rounded corner
│  └─ STUDS ImageLabel            Size {1,0},{1,0}, BackgroundTransparency 1, ScaleType Tile,
│                                 TileSize {0,42},{0,32} (small parts: {0,28},{0,21}),
│                                 ImageTransparency 0.5 on coloured surfaces, 0.6 on dark surfaces
└─ …content (labels, icons, children)
```

Why each layer is there:
- **White background + UIGradient:** a UIGradient *multiplies* the background colour, so a white background shows
  the gradient's true colours. To recolour, change the gradient. Don't touch the background.
- **Studs over the gradient:** the tile is white highlights and a soft shadow on a transparent background, so it picks
  up whatever colour is underneath. One studs texture works for every theme.
- **CanvasGroup:** a tiled ImageLabel ignores its parent's UICorner and would poke out at the corners. The CanvasGroup
  with its own UICorner clips it.
- **Contextual UIStroke:** the outline follows the rounded shape. On a TextLabel the same mode outlines the glyphs.

**Studs texture:** the shipped games use a Roblox-hosted tile. This repo writes asset IDs as placeholders
(`<STUDS_IMAGE_ID>`). Upload `assets/ui/reference/studs_tile.png` (168×128, one stud, transparent) or your own tile as
a Decal/Image, then put its ID in every `STUDS.Image`. With the generator:
`STUDS_ID=<id> tools/lune10 run assets/ui/reference/build_reference.luau`. If you change the tile, every studded part
changes with it.

---

## 2. Palette

### Coloured themes (UIGradient top → bottom, Rotation 90; UIStroke = the dark edge)

| Theme | Top | Bottom | Stroke (button + its label) | Used for |
|---|---|---|---|---|
| green  | `#82FF46` | `#28BE1E` | `#0E500A` | BUY / confirm, cash chips, green panel headers |
| blue   | `#50B4FF` | `#1E64E6` | `#0A286E` | tabs, Index, info, blue headers |
| orange | `#FFAA3C` | `#EB640A` | `#642800` | main action (Smelt), Upgrades, orange card heads |
| purple | `#C86EFF` | `#8228E6` | `#320A64` | Rebirth, premium, Collect, progress fill |
| gold   | `#FFE150` | `#EBA000` | `#6E3C00` | SELL, secondary actions, option buttons |
| red    | `#FF4646` | `#BE0F0F` | `#460000` | close X, EXIT, danger, notification badge (`#BE0F0F` flat + white 2.5 stroke) |
| brown  | `#AA7846` | `#6E4623` | `#0A286E` | Bag / Settings side buttons |

### Dark surfaces (flat BackgroundColor3 + `Shade` gradient `#FFFFFF→#9696A0` rot 90)

| Surface | Background | Stroke | Studs transparency |
|---|---|---|---|
| Panel body, HUD chips, toast, event pill | `#2B2D34` | `#0E0E12` 4 px (chips: theme stroke 3 px) | 0.6 |
| Card, tooltip, list tile | `#3C3F48` | `#16161C` 2.5–3 px | 0.6 |
| 3D stage, empty slot, locked cell | `#1C1D22` | `#464850` 2.5 px (pips 1.5) | 0.6 |
| Progress track | `#191A1E` | `#16161C` 2.5 px | 0.6 |

### Text colours (all FredokaOne, all outlined)

| Role | Colour | Outline |
|---|---|---|
| Normal text on dark | `#FFFFFF` | `#14141A`, 2–3 px |
| Text on a coloured button/header | `#FFFFFF` | the theme's stroke colour, 2.5–3 px |
| Price / cost | `#FFE150` | `#14141A` 2.5 |
| Sell value | `#FFD646` | `#14141A` 2 |
| Positive / income / reward | `#78FF78` or `#6EEB6E` | `#14141A` 2–2.5 |
| Muted note / hint | `#C8C8D2` | `#14141A` 2 |

### Rarity colours (cards, tags, tooltip rarity line)
Common `#B4B4B4` · Uncommon `#50DC50` · Rare `#3C8CFF` · Epic `#AA46FF` · Legendary `#FFBE1E` · Mythic `#FF3C78`
(Mythic tags in the game use a spinning rainbow gradient `#FF3C3C→#DC46FF`). Keep them in **one** place, either a
Config module or a `Palette`/`RarityStyles` attribute folder, and read them from there.

### Fonts
- **FredokaOne Regular** for everything (`FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")`). ForgeTax has
  485 FredokaOne labels and 1 exception.
- Pumpkin King variant: GothamSSm Heavy for UI labels, FredokaOne for prices and passes, Montserrat Heavy for buy buttons.
- Set `FontFace`, not the legacy `Font` enum. `TextSize = 8` on scaled labels (it doesn't matter, but see §4).

---

## 3. Components (exact values)

ZIndex rule: a component's parts stack upward from its base Z. On a surface at Z: Studs = Z, Shine = Z+1,
Label/Icon = Z+2, Dim = Z+3. A panel sits at Z 2, its Body at Z 3, its Top header at Z 6, and the header's title and
close button at Z 8. Toasts are at Z 20, tooltips at Z 40. Use `ZIndexBehavior = Sibling` on the ScreenGui and
`ResetOnSpawn = false`.

### 3.1 Panel (menu window)
```
ExamplePanel  Frame   Size {0,460..680},{0,300..520}  Position {0.5,0},{0.52,0}  AnchorPoint (0.5,0.5)
                      Bg #2B2D34  ZIndex 2  Visible false
  UICorner (0,8) · UIStroke 4 #0E0E12 · Studs (42×32, t0.6) · Shade gradient
  DeviceScale UIScale  @MinScale 1  @MaxScale 1.2  @PcFactor 1  @TouchFactor 0.8
  @PhoneSize {0,W,0,H≤360}  @PhonePosition {0.5,0},{0.5,10..26}
  Top   (header, §3.2)
  Body  Frame  Size {1,-20},{1,-54}  Position {0.5,0},{0,44}  AnchorPoint (0.5,0)  BackgroundTransparency 1  ZIndex 3
```
Shipped sizes: Rebirth 460×300 · Settings 440×344 · Inventory 520×372 · Limited shop 540×330 · Upgrades 580×336 ·
Index 680×520 (phone 680×360). Small popups such as Welcome Back are 380×230 (phone 330×196).

### 3.2 Header bar (`Top`) and title
```
Top    Frame  Size {1,6},{0,44}  Position {0.5,0},{0,-6}  AnchorPoint (0.5,0)  Bg #FFFFFF  ZIndex 6
       → 3 px wider than the panel on each side and 6 px above it, so it reads as a lip
  UICorner · UIGradient (theme: green/blue/orange…) · UIStroke 4 <theme stroke> · Studs (42×32, t0.5)
  Title  TextLabel  Size {0.5,0},{0.8,0}  Position {0,14},{0.5,0}  AnchorPoint (0,0.5)  ZIndex 8
         FredokaOne #FFFFFF  TextScaled+Wrapped  UITextSizeConstraint 12..34  UIStroke 3 #14141A
  Count  (optional, e.g. "0/90")  Size {0,120},{0,32}  Position {1,-58},{0.5,0}  AnchorPoint (1,0.5)  max 28
  Close  (§3.3)
```
Header colour = the colour of the button that opens the panel (Upgrades → green, Index/Inventory → blue).

### 3.3 Close X
A red button (§3.5) sized `{0,44},{0,36}` at Position `{1,-6},{0.5,0}`, AnchorPoint (1,0.5), ZIndex 8, small studs
(28×21). Its Label is "X", UITextSizeConstraint 12..28. The client calls `hidePanel` on Activated.

### 3.4 Card / tile
```
ItemCard  Frame  Bg #3C3F48  UICorner · UIStroke 2.5 #16161C · Studs t0.6 · Shade
  Head    Frame  Size {1,0},{0,38}  Bg #FFFFFF  UIGradient <theme>  UIStroke 2.5 <theme stroke>  Studs t0.5  ZIndex +1
    Title TextLabel Size {1,-12},{0.78,0} centred, max 26, UIStroke = theme stroke
  Stage   Frame  Size {1,-20},{0,92..102}  Position {0.5,0},{0,46}  AnchorPoint (0.5,0)  Bg #1C1D22  UIStroke 2.5 #464850
          → holds a ViewportFrame (3D preview, see viewport-previews.md) or an ImageLabel
  Line1 / Level  TextLabel  Size {1,-12},{0,24..30}  white, max 22..28
  Price   TextLabel  #FFE150
  Buy     button (§3.5)  Size {1,-20},{0,44..50}  Position {0.5,0},{1,-8}  AnchorPoint (0.5,1)   ← always pinned to the bottom
```
Small grid tiles (inventory/index cards) use the same recipe at 1.5–2.5 px strokes. Rarity is shown by the tile
background colour (rarity hex) or a rarity-coloured line of text, never by a new style.

### 3.5 Buttons (primary, secondary, danger, side)
```
<Name>  ImageButton  Bg #FFFFFF  BackgroundTransparency 0  Image none  ImageTransparency 1  ScaleType Stretch  AutoButtonColor false
        @Theme "green|blue|orange|purple|gold|red"   (a label for humans and tools; the children decide the colour)
  UICorner (0,8) · UIGradient <theme> · UIStroke 3 <theme stroke>
  Studs   CanvasGroup → STUDS 42×32 t0.5 (buttons ≤ 36 px tall: 28×21)
  Press   UIScale 1                ← the client tweens this (§5)
  Label   TextLabel Size {0.86,0},{0.72,0} Position {0.5,0},{0.5,0} AnchorPoint (0.5,0.5) ZIndex +2
          FredokaOne #FFFFFF TextScaled+Wrapped, UITextSizeConstraint Min 12 / Max ≈ 0.6 × button height,
          UIStroke 2.5 (big buttons 3) <theme stroke>
  Dim     Frame Size {1,0},{1,0} Bg #000000 BackgroundTransparency 0.5 ZIndex +3 Visible false, own UICorner
          → "can't afford / out of range / not selected". The client only toggles Visible.
  Shine   (primary only) Frame Size {1,0},{1,0} Bg #FFFFFF ZIndex +1, UICorner, child UIGradient "ShineGradient"
          Rotation 20, Transparency keypoints 0:1, 0.42:1, 0.5:0.45, 0.58:1, 1:1, Offset (-1,0)
          → the client sweeps Offset -1 → 1 every ScreenGui@ShineEvery (2.5 s)
```
| Kind | Theme | Typical size |
|---|---|---|
| Primary (the one main action on a panel) | green (buy), purple (rebirth/collect), orange (main loop action) + Shine | 246–280 × 50–62 |
| Secondary | gold | 150–246 × 34–44 |
| Danger / close | red | close 44×36, exit 132–150 × 52–58 |
| Option toggle (settings rows) | gold, `Dim` = not picked | 66 × 34 |
| Side menu button | per menu (Upgrades orange, Index blue, Rebirth purple, Bag brown) | 60 × 60 |

**Side menu button (60×60):** the same recipe, plus an `Icon` ImageLabel at Size `{0.58,0},{0.5,0}`, Position
`{0.5,0},{0.33,0}`, ScaleType Fit, with the label moved to Size `{0.96,0},{0.3,0}`, Position `{0.5,0},{0.8,0}`, max
18. Add a `Badge` Frame (20×20 at `{0,-4},{0,-4}`, `#BE0F0F`, UIStroke 2.5 white, label "!", hidden). Add an
attribute `Panel = "<PanelName>"` that the client reads to open the panel. The buttons sit in a column Frame with
`UIListLayout` (Padding 6) and its own DeviceScale, on the right edge at `{1,-6},{0.5,0}`, AnchorPoint (1,0.5),
PhonePosition `{1,-4},{0.4,0}`.

### 3.6 Tabs
A row Frame `{1,0},{0,36}` with a horizontal `UIListLayout`, Padding 10. Each tab is a blue button (§3.5), 150×34,
label max 26, with attribute `Tab = "<Name>"`. **Active tab: `Dim.Visible = false`. Every other tab: `Dim.Visible =
true`.** The body stores the current tab in its own `Tab` attribute. The content under the tabs moves down 40 px. To
add tabs to a panel, clone the Index panel's tabs. Don't make a new tab style.

### 3.7 Tooltip
```
Tooltip  Frame  Size {0,184},{0,74..94}  Bg #3C3F48  UIStroke 3 #16161C  Studs t0.6  Shade  ZIndex 40  Visible false
  DeviceScale (TouchFactor 0.8)
  NameLabel  {1,-10},{0,20} at y 6, max 18 · RarityLabel {1,-10},{0,16} y 27, max 14, rarity colour
  IncomeLabel #6EEB6E max 16 · SellLabel #FFD646 max 16
```
On PC it follows the mouse while hovering (offset +16, −20). On a phone it appears next to the tapped card, and a
second tap hides it. Always clamp it 4 px inside the viewport. It's one shared instance that gets moved and refilled.
Never clone one per card.

### 3.8 Toasts
```
Toasts   Frame (container)  Size {0,270},{0,64}  Position {0.5,0},{1,-190}  AnchorPoint (0.5,1)  ZIndex 20  transparent
         UIListLayout Padding 4 · DeviceScale (TouchFactor 0.8) · @PhonePosition {0.5,0},{1,-128}
         @MaxToasts 2 @Seconds 1.5 @RepeatIgnoreSeconds 2
         @White @Green @Red @Gold @Blue @Purple @Orange = Color3 attributes (the toast's stroke + text colour)
Templates.Toast  Frame 270×30  Bg #2B2D34  UIStroke 3 (colour from the attribute)  Studs 28×21 t0.6  Shade  ZIndex 20  hidden
  Pop    UIScale (0.6 → 1 Back pop on show, → 0 on hide)
  Label  {1,-14},{0.84,0} centred, max 16, UIStroke 2.5 #14141A, slides in from +40 px
```
Rules: one shared template for every message. The same text inside RepeatIgnoreSeconds is ignored (the visible one
just stays up longer). Keep at most MaxToasts and destroy the oldest. Never put a toast over a panel header/X or over
the thumbstick. The owner decides which popups exist.

### 3.9 HUD chips (cash, income, rebirths)
A dark chip (`#2B2D34`, 156×36 / 104×36 / 96×36, UIStroke 3 in the theme's stroke colour, studs t0.6, Shade) with a
30×30 coloured `IconBox` at `{0,3},{0.5,0}` (theme gradient, stroke 2.5) holding a glyph ("$", "R"), and a `Value`
label at `{0,39}`, size `{1,-44},{0.76,0}`, max 26. The chips sit in a top-centre row (`UIListLayout` horizontal,
Padding 6, DeviceScale TouchFactor 0.595, PhonePosition y −38 to sit in the top-bar row). Numbers count up over 0.35 s,
and a gain "punches" the chip (a `Punch` UIScale).

### 3.10 Progress bar
A track Frame (`#191A1E`, stroke 2.5 `#16161C`, studs t0.6, Shade) holding a `Fill` Frame (white + purple/green
gradient + studs t0.5 + stroke 2.5 `#14141A`, Size `{p,0},{1,0}` tweened over 0.12 s) and a centred `Label` ("$0 / $1M",
max 24) on top.

---

## 4. Text sizing rule (the bug that shipped microscopic text)

```
TextScaled = true
TextWrapped = true            ← REQUIRED. Without it the live engine draws the label at TextSize (8 px!)
UITextSizeConstraint          MinTextSize = 12 (never lower), MaxTextSize = about 0.6–0.8 × the label's pixel height
UIStroke                      Contextual, 2–3 px, dark (never TextStrokeTransparency)
```
- The rig's simulator doesn't reproduce the missing-TextWrapped bug, so a test must check it (`text_size_test`).
- The smallest effective text on a 667×375 phone is **12 px**. When text is too long, give it more space or wrap it to
  2 lines with "…". Don't shrink it.
- Colour-emoji labels render at TextSize even when scaled: set the box height and TextSize to match (`EmojiFit`).
- Max sizes in the game: panel title 34, big button 32–38, card title 26–28, body line 22–24, tab 26, side-button
  label 18, toast 16, tooltip 14–18, note 18.

---

## 5. Motion (all tweens on saved instances)

| What | How |
|---|---|
| Button hover | `Press.Scale` → 1.04 (attribute `HoverScale`), Quad Out 0.12 s |
| Button down / up | → 0.88 (0.12 s) / back to 1 or hover with **Back Out 0.22 s** (the "pop") |
| Panel open | close every other panel; Position starts 40 px low, DeviceScale ×0.85 → Back Out 0.22 s to rest |
| Panel close | DeviceScale → ×0.85 and slide 30 px down (Quad Out 0.12 s), then `Visible = false` and reset |
| Toast | Pop 0.6 → 1 (Back), label slides in from +40 px, Pop → 0 after `Seconds` |
| Shine | ShineGradient Offset −1 → 1 over 0.6 s every `ShineEvery`, only on visible buttons |
| Disabled | `Dim.Visible = true` (no colour change in code) |

Reference implementation: [`assets/ui/reference/StuddedUIClient.luau`](../assets/ui/reference/StuddedUIClient.luau).

---

## 6. Mobile fit rules

- **Phone detection:** `(TouchEnabled and not KeyboardEnabled) or min(viewport.X, viewport.Y) < 500`.
- **DeviceScale UIScale** on every top-level panel, column and container:
  `Scale = lerp(MinScale, MaxScale, clamp((viewportY − 320) / 760, 0, 1)) × (TouchFactor on phone | PcFactor on PC)`.
  Defaults: Min 1, Max 1.2, PcFactor 1, TouchFactor 0.8 (HUD row 0.595). Store the result in a `Base` attribute so the
  open/close tweens scale relative to it.
- **Phone\* attributes:** `PhoneSize`, `PhonePosition`, `PhoneAnchorPoint` (grids: `PhoneCellSize`). On a phone the
  client copies them in and keeps the PC value in `PcSize`/`PcPosition`/`PcAnchorPoint`, so you can switch back and forth
  freely. Values go on the instance in Studio, where the owner sees them in the Attributes panel.
- **Allowed in a phone fix:** size, position, scale, wrap, hiding non-essential HUD while a menu is open, folding a
  side column behind a ☰ tab. **Not allowed:** colours, fonts, studs, strokes, art, copy.
- **Keep clear of:** the thumbstick (bottom-left), the jump button (bottom-right), the top bar and notch. Bottom panels on
  phone are anchored bottom-right at `{1,-97},{1,-8}` so they don't cover the stick. Put a fifth side button in a left
  column instead, because on the right it collides with jump.
- **Check sizes:** PC 1920×1080, phone 667×375 landscape. For big batches also check iPhone SE, iPhone 14, a small
  Android and an iPad. A tutorial pill that overlaps every centred panel on phone counts as a real bug. Report it.

---

## 7. Clone-template rule (how new panels get made)

New UI is always an existing styled instance, cloned and then edited. Real examples from the v17 batch:

| New thing | Cloned from | Then changed |
|---|---|---|
| Limited Shop popup | `RebirthPanel` | name, size 540×330 + PhoneSize, removed `Body.Progress`, renamed/moved labels (Shatter/Perk/Price), `RebirthBuy` → `Buy`, title text; added a `Stage` cloned from `UpgradesPanel.Body.HammerCard.Stage` |
| Settings panel | `InventoryPanel` | cleared Body, title "Settings", 6 rows: label = clone of `RebirthPanel.Body.Note`, option buttons = clones of `InventoryPanel.Body.Actions.Store` (66×34, `Dim` = not picked) |
| Left button column + Settings button | `RightButtons` (emptied) + `RightButtons.InventoryButton` | position (0,10,0,84) under the admin crown, PhonePosition, `Panel = SettingsPanel`, label/icon text |
| Bag tabs | Index panel tabs | names SWORDS/HAMMERS, `Tab` attribute; grid moved down 40 px |
| Bag hammer card | the bag's sword card | its Equip button is a clone of the Sell button |
| Tooltip | card look (`#3C3F48` + stroke + studs) | labels, ZIndex 40, own DeviceScale |
| Shop price faces in the world | the plot `OwnerGui` SurfaceGui | text |

How to do it in a Lune patch (`apply.luau`, IN/OUT env, idempotent):
```lua
local G = game:GetService("StarterGui"):FindFirstChild("ForgeUI") or error("ForgeUI missing")
if not G:FindFirstChild("LimitedShopPanel") then               -- idempotent: skip if already there
    local P = (G:FindFirstChild("RebirthPanel") or error("RebirthPanel missing")):Clone()
    P.Name = "LimitedShopPanel"; P.Visible = false
    P.Size = UDim2.fromOffset(540, 330)
    P:SetAttribute("PhoneSize", UDim2.fromOffset(540, 330))
    P:SetAttribute("PhonePosition", UDim2.new(0.5, 0, 0.5, 10))
    P:SetAttribute("Note", "[shop17] Dragon Shop popup. Clone of RebirthPanel.")   -- tell the owner what it is
    P.Body.Progress:Destroy()                                   -- remove what you don't need
    P.Top.Title.Text = "SAKURA HAMMER"
    -- keep the rule on every label you touch:
    for _, l in P:GetDescendants() do if l:IsA("TextLabel") then
        l.TextScaled = true; l.TextWrapped = true
        local c = l:FindFirstChildOfClass("UITextSizeConstraint"); if c then c.MinTextSize = math.max(c.MinTextSize, 12) end
    end end
    P.Parent = G
end
```
At runtime, the client registers the panel in its `PANELS` table, so it opens through the same `openPanel` function
(that closes the other panels and does the pop). Clear copied attributes that don't apply anymore (`clearAttrs`). Keep
`Theme` if it does apply.

**Transparent layout helpers** (an invisible row Frame, a UIListLayout) may be created in a *build-time* patch,
because they get saved into the place. They must not be created by a runtime script.

---

## 8. No Instance.new visuals (what runtime code may do)

| Allowed at runtime | Not allowed at runtime |
|---|---|
| `template:Clone()`, parent/move, `PivotTo` | `Instance.new` of any Gui object, UIStroke/UICorner/UIGradient, Part, ParticleEmitter, Light, Sound |
| `Visible` / `Enabled` / `Parent` toggles | Writing Size, Position, colours, Font, TextSize, stroke, corner or padding on saved instances |
| Filling `Text`, `Image`, values | …except through attribute gates (`Phone*`, `Color<State>` attributes, `AutoLayout`) |
| Tweening Scale, Position, Transparency, Offset, Brightness | Building a fallback UI in code when a template is missing |
| Reading attributes | |

Runtime-only exceptions: a Camera inside a ViewportFrame, Weld/WeldConstraint/Motor6D, BindableEvent. A missing
template means you `warn` once and skip the feature. A one-line exception needs a reason in a comment:
`-- studio-rule: allow (<reason>)`. The guard test (`studio_rule_test`) scans every script and fails STRICT builds on
new `Instance.new` visuals.

State colours (ready/busy, on/off) live as attributes on the instance they colour (`ColorReady`, `ColorBusy`), or as
two baked children you toggle (`Orange`/`Magenta` UIGradients, the `Dim` frame).

---

## 9. Do / don't

| Do | Don't |
|---|---|
| Clone the closest existing panel/button and edit it | Draw a new style from memory or "improve" the look |
| White bg + UIGradient for colour | Set BackgroundColor3 to the theme colour (the gradient tints it twice) |
| Put studs in a CanvasGroup with a UICorner | Put a Tile ImageLabel directly on a rounded frame (square corners poke out) |
| One UIStroke per surface, Contextual | Stack strokes or use TextStroke |
| TextScaled + TextWrapped + Min 12 | TextScaled alone; MinTextSize below 12; a fixed TextSize |
| Phone fit with Phone\*/DeviceScale attributes | Change colours/fonts/art/copy to "make it fit" |
| One shared Toast / Tooltip template | A new popup style per feature |
| `Dim` frame for disabled/unselected | Recolouring the button in code |
| A `Note` attribute on new instances explaining them | Unnamed "Frame"/"TextLabel" instances |
| Keep a removed popup's template hidden (`@Enabled=false`) | Delete UI the owner might want back |

---

## 10. Verify before you report

1. **Static checks (Lune):** every TextLabel/TextButton has TextScaled → TextWrapped plus a constraint with Min ≥ 12
   (`text_size_test`). No runtime `Instance.new` visuals (`studio_rule_test` STRICT). The new panel exists, is hidden,
   and has PhoneSize/PhonePosition and a DeviceScale.
2. **Rig screenshots:** `tools/rig/shot.sh <place> <tag> open=<PanelName>` renders `<tag>_pc.png` (1920×1080) and
   `<tag>_phone.png` (667×375). Open both. Check that nothing overlaps (thumbstick, jump, header/X, tutorial pill),
   nothing is off-screen, and text is ≥ 12 px. The rig's geometry and colours are close, but icons and 3D are grey
   placeholders, and a client script it can't find won't get its phone attributes applied. Make sure the shot script
   finds your UI client.
3. **Studio (if a live Studio is connected via MCP):** read `AbsoluteSize`/`AbsolutePosition`, because captures can be
   stale (`tools/mcp/probe_ui.luau`).
4. **Report:** shots first, then one line on what changed. Say exactly what you didn't verify ("hover feel, real
   phone, tooltip vs real top-bar inset: not checked in Studio").
5. Regenerate the UI map (`tools/uimap/`) so the next agent can `grep` the new instance instead of searching for it.

---

## 11. Pumpkin King variant (same build, different skin)

- Left menu grid of studded face buttons (UIGridLayout + Phone\* overrides + DeviceScale Min .64 / Pc .85 / Touch .7):
  ImageButton with a face image (ScaleType Fit), UICorner (0,8), UIStroke 3 `#612C00` (purple `#350055`), UIGradient
  orange `#FF7300`, purple `#A005FF→#9E00FF`, magenta→orange `#B439FF→#E97210`, rot 90, CanvasGroup>STUDS TileSize
  **scale** `{0.08,0},{0.25,0}` t0.5, label GothamSSm Heavy white + UIStroke 2.5 `#5A2900`, and a `threedimensional`
  Frame (black, t0.8) under the face as a 3D lip.
- Menu bodies use a second studs texture at t0.7, and menu tops a third at t0.
- Theme switching: two UIGradient/UIStroke children named `Orange` and `Magenta`. A `Theme` attribute enables one and
  disables the other.
- The templates are in `assets/ui/templates/*.rbxm`, with previews in `assets/ui/previews/`. Details are in
  [ui-conventions.md](ui-conventions.md).

TileSize in **offset** (42×32 px, ForgeTax) keeps studs the same size on every surface, so bigger panels just get more
studs. TileSize in **scale** (Pumpkin King) keeps the same number of studs per button. Pick one per game and stick to it.

---

## 12. Prompt you can give any model

> Build `<thing>` for my Roblox game in the studded style described in `docs/STUDDED_UI_GUIDE.md`. Clone the closest
> existing panel/button in `StarterGui.<MyUI>` (or `assets/ui/reference/StuddedUI_Reference.rbxmx`). Don't create
> visuals with Instance.new at runtime. Every label: TextScaled + TextWrapped + UITextSizeConstraint Min 12 + UIStroke.
> Add PhoneSize/PhonePosition and a DeviceScale UIScale. Give me the Studio hierarchy with exact property values, the
> client code (clone/show/fill/tween only) and what you checked on PC 1920×1080 and phone 667×375.
