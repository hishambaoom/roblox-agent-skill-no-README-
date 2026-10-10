# Build pipeline (Lune → .rbxl)

The place file is **built**, not hand-merged: a Lune script reads a base place, applies source + numbered hooks, and
writes a new `.rbxl`. Every build is reproducible and every change has a file you can diff.

## Why Lune (and not only Rojo)
- [Lune](https://github.com/lune-org/lune) reads/writes binary `.rbxl` with its `@lune/roblox` library: you can bake UI,
  models, attributes and script sources into a real place — exactly what the Studio-first rule needs.
- The owner syncs with Studio through the Studio MCP server, not Rojo. Rojo is fine for code-only projects (see
  docs/resources.md); this pipeline also bakes instances.

Versions in the reference project: **Lune 0.8.9** (`tools/lune`, builds + tests) and **Lune 0.10.5** (`tools/lune10`)
for place files saved by a recent Studio that 0.8.9 can't deserialize. Pin both binaries in `tools/`; check with
`tools/lune --version`.

## Layout
```
games/<game>/
  build.luau              main build: base place → cleanup → remotes → src/ → hooks → settings → write
  build_<scope>.luau      hooks, one owner each, run in a FIXED order (list in build.luau)
  src/                    Luau sources copied into script Source
  tests/                  Lune tests + rbxsim.luau (Roblox stand-in)
  build/game.rbxl         canonical = what is LIVE (publish.sh copies here)
work/x/<vN>.rbxl          scratch builds (BUILD_OUT); retention: newest + 3 older
QUEUE.md                  version log (docs/project-state-template.md)
```

## build.luau skeleton
```lua
local roblox = require("@lune/roblox"); local fs = require("@lune/fs"); local process = require("@lune/process")
local ROOT = "games/my-game"
local OUT = process.env.BUILD_OUT or (ROOT .. "/build/game.rbxl")
local game = roblox.deserializePlace(fs.readFile(process.env.BASE or "work/base/template.rbxl"))
local log = {}; local function note(s) table.insert(log, s); print(s) end
-- 1. cleanup (tracer scripts, template junk) · 2. remotes · 3. sources from src/ · 4. hooks · 5. settings
local ctx = { roblox = roblox, game = game, note = note, find = find, shared = {}, ROOT = ROOT, OUT = OUT,
              GameSettings = ensureConfig(game) --[[ ReplicatedStorage.Config.GameSettings ]] }
for _, name in { "build_theme", "build_hud", "build_store", "build_organize" } do   -- FIXED order; organize LAST
    if fs.isFile(ROOT .. "/" .. name .. ".luau") then require("./" .. name)(ctx) end
end
fs.writeFile(OUT, roblox.serializePlace(game))
fs.writeFile(OUT .. ".log.txt", table.concat(log, "\n"))
```
Full runnable example: `tools/example-game/build.luau` + `tools/example-game/hooks/build_example_ui.luau`.

## Hook contract
- `return function(ctx) … end`. One agent owns one hook file. Nobody edits `build.luau` casually.
- **Idempotent:** `FindFirstChild` before creating; destroy and rebuild only the subtree you own; seed attributes only
  when missing.
- One summary `ctx.note("<scope>: …")` line with units.
- Pass data to later hooks via `ctx.shared.<scope>_<name>`, never globals.
- Order matters: theme first (bakes colours others copy), organize last (moves folders, rewrites paths).

## Two ways to change a script
1. **Own source in `src/`** → edit the file; build copies it.
2. **Template script you don't own (no src file)** → *anchor patch* in a hook:
```lua
local function patch(scr, edits, MARK)
    local src = scr.Source
    if src:find(MARK, 1, true) then return end          -- already patched (idempotent)
    for i, e in ipairs(edits) do
        local a, b = src:find(e[1], 1, true)
        assert(a, scr.Name .. " anchor " .. i .. " not found")
        assert(not src:find(e[1], b + 1, true), scr.Name .. " anchor " .. i .. " matches twice")
        src = src:sub(1, a - 1) .. e[2] .. src:sub(b + 1)
    end
    scr.Source = src
end
```
A changed template fails the build loudly instead of shipping unpatched.

## Patch-on-a-place builds (fast iterations)
For small follow-ups you can patch the last LIVE file directly: `IN=work/x/v93.rbxl OUT=work/x/v94.rbxl tools/lune run
work/v94a/build.luau`. Record the chain in QUEUE (`v94 = v93 + v94a + v93b`). Periodically fold patches back into the
hook/src so a clean build reproduces LIVE.

## Gotchas
- Lune writes integer attributes as 32-bit: store big numbers in a scaled unit (`@Unit 1000000`, values in millions).
- MeshParts created/placed by Lune may have no render data → invisible in game. Keep a primitive fallback visible until
  verified in Studio (real case: pedestal mesh didn't render → block parts made visible again).
- `TextScaled` without `TextWrapped` renders at TextSize in the live engine; the sim doesn't render text at all.
- Keep `Players.MaxPlayers`/server size consistent with plot count; the live Open Cloud setting wins.
- Never ship place files of other people's games/templates in a public repo.
