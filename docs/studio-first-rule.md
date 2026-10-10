# The Studio-first rule

> Owner, 2026-10-07: *"don't keep things like UIs in scripts, I want them in Studio so I can manually edit them if
> needed"* — widened the same day to *"everything! not just ui, models and more, zones and lighting and more"*.
> Short form, the TOP RULE: **"I WANNA BE ABLE TO CHANGE AND EDIT ANYTHING I WANT."**

The owner must be able to open the place in Studio, click any visible thing and change it — without reading code.

## What lives where

| Thing | Lives as | Example path |
|---|---|---|
| Screen UI | ScreenGui baked in `StarterGui` (`ResetOnSpawn = false`) | `StarterGui.MainUI.LeftButtons.ShopButton` |
| Repeated UI (cards, rows, toasts, tiles) | Template in `ReplicatedStorage.UITemplates`, cloned at runtime | `UITemplates.SideCard`, `UITemplates.Toast` |
| World props, zones, signs, lights | Real instances in `Workspace` | `Workspace.Map.BossThrone`, `Workspace.MapDecor.GroundScatter` |
| Spawnable models | Templates in `ReplicatedStorage.Assets` / `ServerStorage` | `Assets.Guards.Boss`, `ServerStorage.MapModels` |
| Effects | Templates (ParticleEmitter, Highlight, Beam) | `Assets.Fx.LootFX.Legendary`, `Assets.LootBlink` |
| Sounds | `SoundService.SFX.<Name>` | `SFX.Footsteps` |
| Lighting per area | `Lighting.ZonePresets.<Area>` | |
| Game-wide tunables | Attributes on a `Configuration` | `ReplicatedStorage.Config.GameSettings@StealCooldownSeconds` |
| Per-instance tunables | Attributes on that instance | `UITemplates.Toast@Duration`, `RightSide@PhoneMaxWidth` |
| State colours | `Color<State>` attributes on the coloured instance | `UIStroke@ColorOn / @ColorOff` |
| Data (names, prices, rarities, balance tables) | ModuleScripts in `ReplicatedStorage.Config` | `Config.GameConfig`, `Config.Balance` |
| Human docs | A `README` ModuleScript in ReplicatedStorage | `ReplicatedStorage.README` |

## What scripts may do at runtime

Allowed: `Clone`, parent/move, `PivotTo`; `Visible`/`Enabled`/`Parent` toggles; set `Text`, `Image`, values; tween
transparency/scale/position/brightness; read attributes.

Not allowed: `Instance.new` of UI, world/visual or remote classes; writing Size, Position, colours, Font, TextSize,
stroke, corner, padding, Material or Lighting properties on Studio instances — except behind an attribute gate.

Allowlist (runtime-only by nature): `Camera` inside ViewportFrames, `Weld`/`WeldConstraint`/`Motor6D`, `BindableEvent`,
`GetTextBoundsParams`, a preview `Model` copy, per-sound `Attachment` for positional audio.

Opt-outs must carry a reason the guard test can see:
```lua
local cam = Instance.new("Camera") -- studio-rule: allow (ViewportFrame camera, runtime-only)
--!studio-rule: build-only        -- whole module only runs under Lune at build time
```

## Attribute gates (letting the owner override a layout script)

| Attribute | On | Meaning |
|---|---|---|
| `AutoLayout` (bool, default true) | any frame a script measures/resizes | `false` → script leaves the frame exactly as set in Studio. A parent with `false` disables children too. |
| `Phone*` (`PhoneSize`, `PhonePosition`, `PhoneAnchorPoint`, `PhoneTextWrapped`…) | element with a phone layout | applied by the layout script on touch/small screens, only when AutoLayout ≠ false |
| `EmojiFit` (bool) | emoji icon labels | fit-to-box workaround can be turned off |
| `NoStrokeFix` (bool, never baked true) | UIStroke or ancestor | owner ticks it to stop stroke rescaling |
| `Enabled` (bool) | optional feature templates | e.g. `UITemplates.Juice.HaulCard@Enabled=false` turns a popup off without code |

Runtime pattern:
```lua
local function autoLayoutOn(inst)
    local p = inst
    while p and p:IsA("GuiBase") do
        if p:GetAttribute("AutoLayout") == false then return false end
        p = p.Parent
    end
    return true
end
if autoLayoutOn(frame) then
    frame.Size = isPhone and (frame:GetAttribute("PhoneSize") or frame.Size) or frame.Size
end
```

## Tunables pattern

Build time (hook) — seed only if missing so the owner's edits survive rebuilds of a saved place:
```lua
local function seed(inst, name, value) if inst:GetAttribute(name) == nil then inst:SetAttribute(name, value) end end
seed(ctx.GameSettings, "StealCooldownSeconds", 120)      -- seconds, paid steal only
seed(ctx.GameSettings, "FreeStealCooldownSeconds", 300)  -- seconds
ctx.note("steal: GameSettings StealCooldownSeconds=120 s, FreeStealCooldownSeconds=300 s")
```
Runtime — client and server read the same attribute so they always agree:
```lua
local gs = ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameSettings")
local cooldown = gs:GetAttribute("StealCooldownSeconds") or GameConfig.StealCooldownSeconds
```
Naming: `<System><Thing>` PascalCase (`BossChaseSpeed`, `SellIncomeSeconds`); record the unit in the build note. Never
write a GameSettings attribute at runtime.

## Missing template = loud failure
```lua
local tpl = UITemplates:FindFirstChild("Toast")
if not tpl then warn("[Alerts] UITemplates.Toast missing - toasts disabled"); return end
```
Never build a fallback UI in code.

## The guard test
`tests/studio_rule_test.luau` scans every script `Source` in the built place for `Instance.new("<visual class>")`,
`new("…")` helpers and style writes; compares per-file counts with a baseline; `STRICT=1` fails on any non-allowlisted
creation. It runs in every fast lane. Example in `tools/example-game/tests/studio_rule_test.luau`.

## Organizing for the owner
Make the place browsable: `ServerScriptService.Systems.<System>.<Module>`, all tunables in `ReplicatedStorage.Config`,
and a README ModuleScript (plus a copy in ServerStorage named "📖 README") that says where everything is.
