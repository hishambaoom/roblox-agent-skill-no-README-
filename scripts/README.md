# scripts/: reusable patch, organize and swarm tools

All of these run with Lune 0.10.x (`tools/lune10`) on `.rbxl` files outside Studio. Nothing here needs keys or IDs.

| File | What it is | Doc |
|---|---|---|
| `apply-template.luau` | Idempotent `IN`/`OUT` place patch: get-or-create, attribute defaults that keep Studio edits, anchor patches with markers (unique-anchor asserts), string IDs, `AudioContent` sounds. Copy to `games/<game>/work/<agent>/apply.luau`. | docs/lune10-gotchas.md |
| `organize/organize-template.luau` | Organize pass framework: transactional move groups that undo themselves if any script lookup breaks; `OrganizedFrom*` attributes; rename rewrites. Edit the MAPS section. | docs/organize-and-refcheck.md |
| `organize/refcheck.luau` | Static reference checker module: resolves every `:WaitForChild` / `:FindFirstChild` / dot chain in every script. | same |
| `organize/check.luau` | CLI: `IN=<place> [BEFORE=<place>] tools/lune10 run scripts/organize/check.luau` (exit 1 on regressions). | same |
| `organize/reverse.luau` | Rebuilds the pre-organize layout from an organized file so old tests run unchanged (test helper only). | same |
| `organize/test_chain.sh` | Regression harness: each agent test on baseline, on reverse(organize(place)) and on organize(place). | same |
| `viewport/ViewportPreviewClient.client.luau` | 3D previews in UI cards with a client-made camera (cameras don't replicate). | docs/viewport-previews.md |
| `swarm/CONTRACT.template.md` | The contract every parallel agent reads first: BASE, chain order, owner rules, shared names. | docs/swarm-integration.md |

## Quick use
```bash
# one agent patch, chained
IN=build/game_v0.rbxl OUT=work/int1/s_core.rbxl tools/lune10 run games/game/work/core/apply.luau
IN=work/int1/s_core.rbxl OUT=work/int1/s_fx.rbxl  tools/lune10 run games/game/work/fx/apply.luau
# organize last + prove it
IN=work/int1/s_fx.rbxl OUT=work/int1/v1.rbxl tools/lune10 run games/game/work/organize/apply.luau
IN=work/int1/v1.rbxl BEFORE=work/int1/s_fx.rbxl tools/lune10 run scripts/organize/check.luau
LUNE=tools/lune10 TESTS=games/game/work ORGANIZE=scripts/organize APPLY=games/game/work/organize/apply.luau \
  bash scripts/organize/test_chain.sh work/int1/s_fx.rbxl v1 "core:SELF fx ui"
```
`organize-template.luau` does `require("./refcheck")`: keep it next to `refcheck.luau` (or copy both).
