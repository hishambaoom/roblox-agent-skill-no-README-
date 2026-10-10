# UI conventions

## The look is the owner's
The game has one visual language (in the reference game: orange/purple gradients, a tiled **stud** texture inside a
CanvasGroup, thick dark UIStrokes, heavy white text with thick dark outlines, a dark "3D lip" strip under buttons).
Every new UI is a **clone of an existing styled template** with new content. Owner rule, Oct 7: alarm toast, Bonk
button, steal timer and every migrated menu *"get cloned from your existing studded templates: same orange and purple
studs, gradient, and heavy white outlined text"*. A verifier compares new UI shots against the reference menu and fails
anything that doesn't match.

## The UI map (`ui-map.md`)
A generated, grep-able file: one line per important instance with its look and attributes, so no agent re-searches the
place. Regenerate after every UI build (`python3 tools/uimap/uimap_build.py <place>`; `go.sh` does it in background).

Format (real lines):
```
- `LeftButtons.ShopButton` [ImageButton] — **STORE — reference button; all 7 share: face img Fit + gradient + CanvasGroup>STUDS + Name label + 3D shadow strip** · bg #FFFFFF · img 99254050060562 Fit · corner 0,8 · stroke 3 #612C00 · grad #FF7300 r90 · CanvasGroup>STUDS: studs 109343709323318 ts 0.08,0,0.25,0 t0.5 · label[Name] GothamSSm/Heavy #FFFFFF +stroke 2.5 #5A2900 · @{Menu=ShopFrame Type=Menu}
  - `UITemplates.SideCard.ItemName` [TextLabel] stroke[Orange] 3.47 #5A2900 · text GothamSSm/Heavy #FFFFFF "NAME" · @{PhoneSize=0.96,0,0.42,0 PhoneTextWrapped=true}
```
Legend: `bg #hex/tN` background/transparency · `img id [ScaleType]` · `grad[Name] a→b rDeg` (`,off` disabled) ·
`corner scale,offset` · `stroke[Name] thickness #hex [border]` · `studs id ts TileSize tTransparency` ·
`label[Child] Font/Weight #colour "text" +stroke` · `@{…}` attributes. Header lists shared asset IDs and fonts.

## Phone fit (without changing the design)
- Reference phone: **667×375 landscape** (smallest common). Also sanity-check 360×640 portrait if the game allows it,
  plus PC 1920×1080. Owner-requested device sweep for big UI batches: iPhone SE, iPhone 14, small Android, iPad.
- Tools: `Phone*` attributes (`PhoneSize`, `PhonePosition`, `PhoneAnchorPoint`, `PhoneTextWrapped`, `PhoneScale`…),
  a `DeviceScale` UIScale with `MinScale/PcFactor/TouchFactor` attributes, `AutoLayout` gate. All editable in Studio.
- Allowed in a phone fix: size, position, scale, wrap, hiding non-essential HUD while a menu is open, folding side
  columns behind a ☰ tab. Not allowed: colours, fonts, studs, strokes, art, copy.
- Watch the touch controls: thumbstick bottom-left, jump bottom-right, top-bar/notch insets. Left buttons/toasts over
  the stick and side cards over jump were real bugs.
- Notches/cutouts: centre HUD against the same reference as the hotbar (a separate inset-free probe drifted ~130 px on
  an Android cutout). Expose a nudge attribute (`CentreOffsetX`).

## Text
- `TextScaled = true` **requires** `TextWrapped = true`, otherwise the live engine draws it at `TextSize` (clamped by
  UITextSizeConstraint). This shipped as microscopic store text once; the sim can't see it — the text-size test models it.
- Effective text ≥ **12 px** on the phone viewport. Prices/titles bigger. Colour emoji in a TextScaled label also render
  at TextSize → fit emoji labels to box height (`EmojiFit`).
- Outline with a Contextual `UIStroke` (2–3.5 px dark), not TextStroke, matching neighbours.
- Long text: wrap to 2 lines + "…" with a `MaxChars` attribute rather than shrinking below 12 px.

## Popups and toasts
- One shared toast template (`UITemplates.Toast`) for everything; kinds toggle accents (`ToastKind` Error/Rare/Mythic).
- Attributes: `Duration`, `FadeOut`, `PopIn`, `DedupeSeconds`, `MaxStack`, `MaxChars`.
- Never over a menu header/X, never over the thumbstick; dedupe repeats; owner decides which popups exist (they held
  all new popups pending a plan once — respect HOLD lines).
- A removed popup keeps its template hidden with `@Enabled=false` so the owner can bring it back.

## Screenshots
- Rig (`shot.sh`): approximate, instant, PC + phone. Good for overlap/size/position. Icons/3D are placeholders.
- Studio (MCP): real. Captures may be stale → measure `AbsoluteSize/AbsolutePosition` too (`tools/mcp/probe_ui.luau`).
- Always send shots **first** in a UI report.
