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
| `SoundId` writes lost in Lune 0.10 | new uploads "wired" by setting `SoundId`; the place stores `AudioContent`, so the old sounds kept playing | `s.AudioContent = roblox.Content.fromUri(uri)`; read it back from the output file |
| Stacked events past the Highlight cap | 10 ghosts + 6 doors + vault + clock + rarity outlines > 31 → outlines vanished at random | One shared Highlight per group Model; client outline budget = cap − reserve − live event Highlights (docs/performance.md) |
| Plots `Persistent` for everyone | ~5k always-loaded instances per phone | `PersistentPerPlayer` + `AddPersistentPlayer(owner)`; `ModelStreamingBehavior = Improved` |
| Event model fell through the map | spawn pivot computed against a streamed-out floor | Raycast to the real floor on the server, anchor everything, streaming-safe client snap |
| Sprinting skipped touch pads | player crosses a small centre radius between physics steps | client swept check per Heartbeat + server speed lead (capped); radius as attribute |
| Fit script looped 80× | refit writes sizes → `AbsoluteSize` changed → refit again | settle on `Heartbeat:Once`, cap passes (3), no re-entrancy |
| Phone buttons 36×25 px | owner's visual size too small to tap | keep visuals, add invisible ≥ 44 px hit pads |
| CollectionService tag without its attribute | a purchase-button tag on an object with no `Product` attribute errored | skip nil attributes and non-PlayerGui instances in tag handlers |
| Flat event rewards | `$5,000` meaningless after a few rebirths | pay `max(base × rebirthMult, income/s × N s)`, N per event as attribute (docs/live-events.md) |
| Milestone re-paid after rebirth | "every 3 filled pedestals" paid again because loot stayed placed | decide and test what rebirth resets for every once-only reward |
| `--` comment inside a one-line table in a gsub patch | commented out the rest of the table; broke a balance module (caught by its test) | notes on their own line or `--[[ ]]` (docs/lune10-gotchas.md) |
| Blank 3D previews in UI cards | the Camera saved in each ViewportFrame never reached the client (UI copied server → PlayerGui) | client makes `ClientCam` per viewport (docs/viewport-previews.md) |
| Lune `CFrame.lookAt` | cameras/stands built in Lune faced the wrong way | `CFrame.fromMatrix`; check camera feel in Studio |
| Deferred signals | an Fx remote reached clients before the server-side handler built the object it described | `task.defer` the `FireAllClients` |
| Sword sank into the anvil after the first hit | a bounce tween returned to the raw anchor pivot, undoing another script's lift | store `RestPivot` when placing; every tween returns there (docs/interaction-patterns.md) |
| Hammer head in the middle of the handle | Lune-written `WeldConstraint`s have identity offsets; Studio snaps parts together | classic `Weld`s with explicit `C0`, pivot at the grip, size baked |
| Function called before its `local function` line | nil call inside a ChildAdded handler, silent; the feature never ran | forward-declare; tests that exercise the connection |
| Badge IDs wrong after a Lune build | number attributes over 2^31 truncated | IDs as string attributes or `IntValue` |
| Stale ban cache | player unbanned on another server kept getting kicked | re-read the ban store on join; cache only on read failure (docs/anti-cheat.md) |
| Hold check bypass | one real prompt hold let later instant `fireproximityprompt` calls pass | consume the hold record on success |
| High-ping noclip false positive | frozen phone reappeared round a wall corner = "through the wall" | skip the wall test on the first sample after a high-ping freeze |
| Lists saved longer than the new cap | old servers saved 5 daily quests after the cap dropped | trim on load in a fixed priority (claimed, started, rest) |

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
| Two runs published the same content (v156 then v157) | Check the live version number right before publishing; QUEUE line first, publish second |
| A live version appeared that no run recorded | Read `versionNumber` + the QUEUE before every publish; never assume you know what is live |
| Full suite run in parallel got memory-killed (half the logs FAIL) | Run the full suite serially, or compare only against a base run made the same way |
| Saying "fixed" before the owner saw it (pedestal bug "fixed" twice: anchors v141, mesh v142, real cause v144) | Say "fixed in build, please check X" until confirmed; mark RESOLVED only after confirmation |
| 20+ agents on one new game | Contract of shared names, serial chain onto the owner's save, one integrator publishes (docs/swarm-integration.md) |
| Organizing the place broke script paths | Organize LAST, in transactional groups checked by refcheck; reverse + test_chain prove it (docs/organize-and-refcheck.md) |
| Older agent tests flagged newer agents' legit changes ("Workspace changed") | Narrow exempt lists; run those tests with IN = the place right before the newer agent |
| Two agents put the same data in two places (boss Secret loot) | The contract names one owner per path; the merger picks one and records it |

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
- Extras the owner might not like (big banners, extra toasts) go behind a GameSettings boolean, so turning them off is a tick.
- "Admin abuse" is a real play pattern: admin event starts must start *now* and stack (docs/live-events.md).
- Balance numbers the owner gives are orders, not suggestions ("thief 25% slower" = multiply by 0.75, nothing else).
- Promotion: one post at a time from aged accounts; fresh accounts mass-posting get filtered and banned (docs/marketing-launch.md).
