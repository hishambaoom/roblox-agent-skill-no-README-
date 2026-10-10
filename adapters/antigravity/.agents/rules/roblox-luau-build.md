---
trigger: glob
globs: "*.luau, *.lua, **/build*.luau"
description: "Rules for editing Roblox Luau sources and Lune build hooks (Studio-first, attributes, idempotent hooks)."
---

# Roblox Luau + build hooks

- AGENTS.md at the workspace root is the source of truth; this rule is a reminder for Luau files.
- Runtime scripts may only Clone, parent/move, PivotTo, toggle Visible/Enabled, fill Text/Image/values, tween, and read
  attributes. No `Instance.new` of UI/world/visual/remote classes; no runtime writes of Size/Position/colours/Font/
  TextSize/stroke/corner/Material/Lighting on Studio instances (except behind an attribute gate such as `AutoLayout`).
  Opt-out needs a reason: `-- studio-rule: allow (<reason>)`.
- Tunables: attributes seeded at build time only when missing; runtime reads `inst:GetAttribute("X") or <fallback>`.
- Hooks (`build_*.luau`): `return function(ctx) ... end`, one owner, idempotent (FindFirstChild first), one
  `ctx.note(...)` summary with units. Don't edit `build.luau` unless asked.
- Patching template scripts: exact-anchor replacement that asserts the anchor matches exactly once.
- Never key a table by Instance with weak keys (`__mode = "k"`); store originals as attributes on the instance.
- `TextScaled = true` always with `TextWrapped = true`; effective text ≥ 12 px on a 667x375 phone.
- Server-authoritative; validate types/NaN/range/ownership and rate-limit every remote; `pcall` DataStore/ProfileStore;
  idempotent ProcessReceipt.
- After editing: build → `tools/rig/fast.sh <place> <tests>` → `tools/rig/shot.sh` for UI → report honestly.
