# Performance and mobile (what actually mattered)

Most players are on phones. A read-only audit of a ~2,200-part place with 6 plots found these, in order of payoff.
Measure first (a Lune probe over the place file + MicroProfiler on a real phone), then fix one thing per build.

## Read-only audit with Lune (no Studio needed)
Count from the place file: BaseParts / MeshParts / unique meshes, `CastShadow` parts (multiply plot templates by
MaxPlayers!), lights and which cast shadows, enabled Fire/Particles, Textures, Highlights, SurfaceGuis with
`MaxDistance = 0`, `ModelStreamingMode` of big models, and per-second remote/replica writes in server loops.
Lune cannot read `CollisionFidelity`; give the owner a one-line command-bar snippet for that instead.

## The list
| # | Problem | Fix | Owner sign-off? |
|---|---|---|---|
| 1 | **Highlights over the cap.** Roblox renders at most **31** Highlights at once; past that, random ones vanish. Stacked events (10 ghosts + 6 doors + vault + clock) plus client rarity outlines blew past it. | One shared `Highlight` per group: put it in a group Model and parent every member into that model (one Highlight outlines all descendants). Tag event Highlights (`EventHighlight`); client outline budget = `min(HighlightMax, HighlightCap(31) - HighlightReserve - live event Highlights)`. | no |
| 2 | **Plots always streamed in for everyone.** `ModelStreamingMode = Persistent` on a plot template x 6 plots = ~5k instances every phone keeps. | `PersistentPerPlayer` on plots + `Model:AddPersistentPlayer(owner)` on assign / `RemovePersistentPlayer` on release; `Workspace.ModelStreamingBehavior = Improved`. Give must-exist models (boss rig, hub anchors) an explicit `Persistent`/`Atomic`. Harden client scripts for parts streaming out and back in. | no |
| 3 | **Mesh streaming / LoDs** | Studio toggle `MeshStreaming` / improved LoDs (owner flips it; agents can't from Lune reliably). | yes |
| 4 | **Shadows** from hundreds of small decor/pedestal parts | `CastShadow = false` on small and repeated parts (keep hero props). | yes (visible) |
| 5 | **Replication spam**: one replica write per occupied pedestal per second (24/s per player) | batch into one write per plot per tick. | no |
| 6 | **SurfaceGuis with infinite `MaxDistance`** | 60-120 studs for signs/labels, `PixelsPerStud` sized to the part. | no |
| 7 | **Low Graphics toggle that did nothing** | see below | no |

### Making `PersistentPerPlayer` safe (what had to change in client scripts)
Ten client scripts assumed every plot existed on every client. After the switch: find your own plot by attribute
(`OwnerUserId`) and re-bind on `ChildAdded` (other plots stream in and out), `WaitForChild` with timeouts, never cache
parts of other plots, mark must-exist models `Atomic`/`Persistent`. Ask for a phone test of: own plot handlers on join,
other plots streaming, zone gates, memory.

## Low Graphics that works
- Client module switches off ParticleEmitter, Fire, Sparkles, Smoke, Beam, Trail, lights, Highlights, `GlobalShadows`,
  Bloom/SunRays/DoF, and takes Atmosphere out of Lighting (it has no `Enabled`). Also catches things spawned later
  (`DescendantAdded`).
- Store each original on the instance as an attribute (`LowGfxOrig`), never in a weak table, so OFF restores exactly.
- Opt-out: `KeepInLowGfx = true` on the instance or any ancestor (gameplay-critical cues: the boss, stolen-loot outline,
  objective beams, event outlines). Never hide information players need to play.
- Auto-on once for weak phones (touch-only + saved graphics level <= 3, or automatic graphics on a short side < 500 px),
  remembered with a saved flag so the player's own choice wins afterwards.
- Phones that look too dark: a Brightness setting (Normal/Bright/Brighter, Auto = Bright on touch) multiplying
  `Lighting` values from attributes; route zone atmosphere changes through the same boost.

## Phone UI cost and fit
- Thousands of hidden GuiObjects are cheap; animating hidden menus every frame is not (gate loops on visibility).
- Fit scripts must not re-enter: a refit that writes sizes which fire `AbsoluteSize` changes which queue another refit can
  loop 80x. Settle with a capped number of passes on `Heartbeat:Once`, no re-entrancy.
- Touch targets >= 44 px: keep the owner's visual size and add an invisible hit pad (`ImageButton`) around small buttons.
