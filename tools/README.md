# tools/

Run everything from your game repo root. Settings: `tools/rig/config.sh` (override by env).

**Windows:** every `rig/*.sh` has a PowerShell twin `rig/*.ps1` (pwsh 7 / Windows PowerShell 5.1) with the same
arguments, env vars, output and exit codes - e.g. `.\tools\rig\go.ps1 v145 open=ShopFrame`, settings in
`tools\rig\config.ps1`, Lune at `tools\lune.exe`. Set env vars with `$env:NOPUBLISH='1'` instead of `NOPUBLISH=1 cmd`.
Setup and troubleshooting: [docs/windows.md](../docs/windows.md). Python tools: `py -3 tools\uimap\uimap_build.py …`.

| Script | What | Typical time |
|---|---|---|
| `rig/go.sh <name> [open=Menu] [tests…]` | build → PC+phone shots → fast tests → publish if green → ui-map refresh. `NOPUBLISH=1` holds, `DRY_RUN=1` rehearses publish | ~2–13 s |
| `rig/shot.sh <place> <name> [open=Menu]` | rig screenshots `work/rig/out/<name>_{pc,phone}.png` (approximate, NOT Studio) | ~1 s |
| `rig/fast.sh <place> [tests…]` | STRICT guard tests + named tests in parallel, one-line summary | ~0.5–3 s |
| `rig/run_all.sh <place> <logdir>` | full suite, `rc.txt` + one log per test | ~25 s on a big game |
| `rig/compare_runs.sh <base logs> <new logs>` | rc changes + FAIL-count changes | instant |
| `rig/publish.sh <place>` | Open Cloud publish (409 retry), prints versionNumber; `DRY_RUN=1` | ~3–5 s |
| `rig/prices.sh pass|product <id> <price>` | Open Cloud price PATCH (owner's number only) | instant |
| `rig/retention.sh [keep]` | keep newest + 3 older builds and the LIVE file; `DRY=1` | instant |
| `rig/*.ps1` | PowerShell twins of all of the above (`go.ps1 shot.ps1 fast.ps1 run_all.ps1 compare_runs.ps1 publish.ps1 prices.ps1 retention.ps1 config.ps1`) | same |
| `uimap/uimap_build.py <place> [out]` | regenerate ui-map.md (edit SECTIONS for your game) | ~2 s |
| `mcp/mcpc.py tools | call <tool> '<json>' | lua <file> [Edit|Client|Server]` | Studio MCP over HTTP tunnel | per call ≤ 30 s |
| `example-game/build.luau` | example build: `BASE=… BUILD_OUT=…` | ~1 s |
| `example-game/tests/*.luau` | example feature test, studio-rule guard, text-size guard; `rbxsim.luau` Roblox stand-in | |

Environment: `GAME_DIR` (default games/my-game), `LUNE` (tools/lune), `TESTS` ($GAME_DIR/tests), `XDIR` (work/x),
`RIG_OUT` (work/rig/out), `CANON` ($GAME_DIR/build/game.rbxl), `FAST_TESTS` ("studio_rule_test text_size_test"),
`ROBLOX_API_KEY`, `UNIVERSE_ID`, `PLACE_ID`, `VERSION_TYPE` (Published|Saved), `OPEN_CLOUD_BASE` (only to point publish/prices
at a local mock server when testing the rig), `PYTHON` (.ps1: which Python), `RIG_FONT` (render.py font; default DejaVu/Arial Bold).

Guard tests adopt an existing game gently: the first run writes a baseline (`$TESTS/data/*.json`); `STRICT=1` then
fails only on **new** violations. Re-baseline deliberately with `BASELINE=1`.

`rig/dump.example.luau` boots the reference game's client controllers inside rbxsim to lay out every ScreenGui — copy it
to `rig/dump.luau` and change the boot section (which controllers to require, which menus to open) for your game.
Lune binaries are not included: download from https://github.com/lune-org/lune/releases.
