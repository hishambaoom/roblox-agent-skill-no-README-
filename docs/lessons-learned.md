# Lessons learned (each one cost a real build)

## Engine / runtime
| Lesson | What happened | Do instead |
|---|---|---|
| **Never weak Instance-keyed tables** | `setmetatable({}, {__mode="k"})` keyed by parts lost the saved originals → upper-floor pedestals invisible + unclickable (v144). Lune sim doesn't GC → tests green | Store originals as attributes on the instance (`FloorHid_T`…) |
| `TextScaled` needs `TextWrapped` | Store text drew at 8–14 px live while tests passed (sim doesn't render text) | Always wrap; text-size test models the live rule; ≥ 12 px |
| Colour emoji in TextScaled labels | rendered at TextSize | Fit label TextSize to box height (EmojiFit) |
| Cameras don't replicate | server-side camera changes did nothing | Set camera on the client (cutaways, viewports) |
| Lune-placed MeshParts may not render | pedestal mesh invisible in game → pedestals "gone" | Keep primitive fallback visible until seen in Studio; renders can't draw meshes → ask owner to look |
| CanQuery=false adornee | SurfaceGui buttons on it can't be clicked | Restore CanQuery when showing |
| Prompt anchors | cloned floors kept prompt attachments on floor 1 → prompts stacked | Re-anchor per floor; test world positions; keep > reach distance apart |
| Screen captures stale | MCP `screen_capture` showed old frame | Measure AbsoluteSize/Position/Visible; close menus first |
| HUD centring on cutouts | inset-free probe origin differs on Android cutout → meter 130 px off | Centre against the same reference as the hotbar; nudge attribute |
| Highlights cap | > ~31 Highlights stop rendering randomly, each costs a pass | Budget nearest K on client |
| Template text on the ground / signs too big | world labels mis-sized | Size SurfaceGuis by PixelsPerStud, set MaxDistance |

## Pipeline / process
| Lesson | Do instead |
|---|---|
| Agents writing their own screenshot/test tools (~20 copies) made tweaks take 10+ min | One shared rig; never write a new renderer for a tweak |
| Parallel builds from the same base undo each other on publish | QUEUE `BASE next`; rebase + re-apply anchor patches before publishing; mark stale builds |
| A parallel run overwrote another's patch dir with a near-identical patch | One owner per patch dir; QUEUE decides what's live; don't rebuild from someone else's scratch |
| Studio-only edits (via MCP or by the owner) wiped by a pipeline publish | Owner saves to file → new BASE; never publish over unsynced Studio work |
| Pasted IDs in Studio overwritten by next publish | Bake IDs in the build |
| Retried upload skipped a version number | Read `versionNumber` from the response |
| Stale tests after design changes look like regressions | Compare against base run; cite the decision line |
| Teleport-style tests trip carry-speed checks | Walking test variants |
| Integers > 2^31 as attributes from Lune | Store scaled units (millions + `@Unit`) |
| Saying "fixed" before the owner saw it (pedestal bug "fixed" twice: anchors v141, mesh v142, real cause v144) | Say "fixed in build, please check X" until confirmed; mark RESOLVED only after confirmation |

## Owner / product
- The owner's design is final: *"no dont make the king more forgiving or slower! or fewer trips"* — an agent had added
  "more forgiving King" to a balance pass on its own. Never soften risk.
- *"DON'T CHANGE THE DESIGN"* during phone fixes: fit only.
- Owner hates slow: shots first, report short, small things done directly instead of handed off.
- Popups are sensitive: the owner removed whole popups and held all new ones pending a plan. Never add a popup that
  wasn't asked for; keep removed ones as disabled templates.
- Ask before naming confusing buttons, but implement first if the request was explicit (e.g. "EQUIP BEST" vs "PLACE
  BEST" — shipped, then asked).
- When uploads/images fail, ask for a one-line description instead of guessing what the screenshot showed.
