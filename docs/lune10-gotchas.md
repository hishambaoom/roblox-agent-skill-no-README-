# Lune 0.10 gotchas (place patching outside Studio)

Every row below shipped a build that "succeeded" and was wrong. Rule zero: **read every changed property back from the
OUT file** in the test, never trust the write.

| Gotcha | Symptom | Do instead |
|---|---|---|
| `Sound.SoundId` writes are lost | new sound "wired", old one keeps playing (file stores `AudioContent`) | `s.AudioContent = roblox.Content.fromUri("rbxassetid://<id>")`; read back |
| `CFrame.lookAt` returns wrong rotations | cameras/stands face the wrong way; a plain case gave dot -0.78 | build rotations with `CFrame.fromMatrix(pos, right, up, back)`; in sim tests check position, or compare against Lune's own lookAt |
| `ViewportFrame.CurrentCamera` can't be saved | write accepted, unreadable, blank viewport | client creates the camera (docs/viewport-previews.md) |
| `Attachment.Position` not saved | attachments snap to the part centre | set `Attachment.CFrame` |
| `ScreenGui.IgnoreGuiInset` not saved | UI shifted under the top bar | use `ScreenInsets` |
| `WeldConstraint` written by Lune has identity `CFrame0` | in Studio, welded parts snap onto the main part's centre (hammer head in the middle of the stick) | use classic `Weld` with explicit `C0`/`C1`, or `Motor6D` |
| Number attributes > 2^31 truncated | badge/asset IDs wrong | store as **string** attributes or `IntValue` (64-bit); `tonumber()` at runtime |
| `game:GetService("X")` adds a missing service | analysis scripts change the saved place | `game:FindFirstChildOfClass("X")` in read-only tools |
| Lune 0.8 can't parse current Studio files | parse errors on new saves/.rbxm | `tools/lune10` (0.10.x) for anything from current Studio |
| MeshParts created by Lune may have no render data | invisible in game | clone existing MeshParts; keep a primitive fallback until seen in Studio |
| Output md5 changes every run | "did my patch change anything?" by hash fails | compare instance dumps / sources, not file hashes |
| Model scale only in sim | `Model:ScaleTo` is a no-op in rbxsim | assert the attribute/intent; check the real size in Studio |

## Patching script sources
- **Never put `--` comments inside a single-line table literal in a gsub/insert patch.** `{ a = 1, -- note b = 2 }` on
  one line comments out the rest of the table; it broke a balance module once (caught by its test). Put notes on their
  own line or use `--[[ ]]`.
- Anchor patches: find the exact old text, assert it occurs **exactly once**, replace, and add a marker comment
  (`-- [agentname]`) so a second run is a no-op. Error out loudly on a missing anchor; never half-apply.
- Assert the base: if a patch replaces a whole module, compare the current source with the saved copy it was written
  against and refuse on mismatch (`Security` must equal `Security_v138.luau`).
- Escape Lua patterns when you build them from names (`[%^%$%(%)%%%.%[%]%*%+%-%?]`).

## Idempotent apply.luau with IN / OUT
Template: `scripts/apply-template.luau`. Shape:
```
IN=<place> OUT=<out> tools/lune10 run games/<game>/work/<agent>/apply.luau
```
- `FindFirstChild` before create; existing instances (the owner may have edited them) are left alone; only script
  `Source` is refreshed each run. `FORCE=1` re-applies geometry.
- Attribute defaults are set only when nil (`setDefault`), so the owner's Studio values survive re-runs.
- Print one summary line per area (`ForgeCore: 5 new edit(s)`), and the second run must report 0.
- Chain by pointing `IN` at the previous step's `OUT`. Rebase = re-run with a newer `IN`.

## Engine behaviour the sim won't show you
- **Deferred signals**: places with `SignalBehavior = Deferred` run connections later than you think. An Fx remote fired
  right after creating an object reached clients before the object-building handler ran. Fire client events with
  `task.defer(function() Fx:FireAllClients(...) end)` after the server builds what the client will look for.
- Cameras never replicate server -> client.
- `StreamingEnabled`: client code must expect parts to be missing and to stream out and back in (`WaitForChild` with a
  timeout, re-bind on `ChildAdded`, set critical models `ModelStreamingMode = Atomic` or `Persistent`).
