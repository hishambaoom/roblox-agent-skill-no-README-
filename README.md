# roblox-agent-skill

**A drop-in skill that lets any AI coding agent build, test, screenshot and publish a Roblox game that the owner can
still fully edit in Studio.**

It is the rulebook, scripts and worked examples behind two Roblox games built with AI agents: *Don't Wake the Pumpkin
King* (190+ published versions: events, boss variants, badges, anti-cheat) and *ForgeTax* (a forging
tycoon taken from the owner's Studio save to six published versions in one day by a swarm of 20+ parallel agents). It
works with Claude Code, Codex CLI, Cursor, OpenCode, Google Antigravity, Gemini CLI and chat-only assistants
(ChatGPT / Claude projects), on any frontier model.

**New (ForgeTax v22-v25):** [model import pipeline](docs/model-import-pipeline.md), [VFX pack rules + budgets](docs/vfx-packs.md),
[core-loop QoL](docs/forging-qol.md), [economy pacing sims](docs/economy-simulation.md) and [limited items](docs/limited-items.md).

**Previous update:** a model-agnostic [studded UI guide](docs/STUDDED_UI_GUIDE.md) with exact values plus an
insertable example panel (`assets/ui/reference/`), a patch-lane / parallel-contract section in
[docs/workflow.md](docs/workflow.md) with ForgeTax learnings (limited-item shop, single ProcessReceipt router,
settings + music, streaming-safe cutscenes). Earlier: swarm builds with a serial integration chain, organize-last with a reference checker that proves
nothing broke, ViewportFrame previews that actually render, a Lune 0.10 gotcha list, a 3-phase anti-cheat, economy and
event scaling patterns, ChatGPT + Blender model prompt templates, and reusable scripts in `scripts/`.

## What it gives your agent
- **Owner-first rules.** Everything visible is a real, editable Studio instance (scripts only clone, show, fill and
  tween), tunables are attributes, UI clones existing templates, "don't change the design", the owner's game design is
  final, and never claim a playtest you didn't run.
- **A 5-second loop.** Edit a build hook → `tools/rig/go.sh` builds the `.rbxl` with [Lune](https://github.com/lune-org/lune)
  (~2 s), renders PC + phone screenshots (~1 s), runs guard tests (~3 s) and publishes through Open Cloud only if they pass.
- **A gameplay lane.** Tests that must fail on the base build, full-suite comparison against base, parallel workers plus
  an independent verifier.
- **Swarm builds.** A contract of shared names, one `apply.luau` per agent chained serially onto the owner's save, organize
  last, a regression harness that proves the organize pass changed only paths.
- **Lessons from real bugs**: weak Instance-keyed tables, `TextScaled` without `TextWrapped`, Lune meshes that don't
  render, `SoundId` writes silently dropped in Lune 0.10, Lune's wrong `CFrame.lookAt`, cameras that never replicate
  (blank viewports), Deferred signals racing the client, the 31-Highlight cap, Studio edits wiped by pipeline publishes…
- **Playbooks** for live events, economy scaling, anti-cheat, mobile performance, reward "juice", AI-made models and
  sounds, and launch marketing.
- **Assets and generators**: thumbnail/icon exporters, a CTR sim, a rebirth-curve designer, prompt packs, original SFX,
  and a studded UI kit (`assets/`).

## Any AI model: plain steps (Claude, GPT, Gemini, local models)
You don't need a specific agent product. Give the model these files and these steps; a model with no shell can still
follow them by telling you what to click and paste.

1. **Read the rules first:** [AGENTS.md](AGENTS.md) (rules, loop, report format). Short on context? Read §1 only.
2. **Pick the doc for the task** from the table in [SKILL.md](SKILL.md). For any UI, read
   [docs/STUDDED_UI_GUIDE.md](docs/STUDDED_UI_GUIDE.md). It's self-contained: layers, palette, sizes, text rule, phone fit.
3. **Find what already exists** before building: grep the UI map (`ui-map.md`) or list the place's `StarterGui`. Pick
   the closest existing panel/button to clone.
4. **Make the smallest change as real Studio instances.** Either use a Lune patch (`IN=… OUT=… tools/lune10 run apply.luau`,
   idempotent) or, without a shell, give the exact Studio hierarchy with property values (or a one-time Command Bar
   snippet run in Edit mode). Runtime scripts only clone / show / fill / tween.
5. **Check it:** text rule (TextScaled + TextWrapped + Min 12), no runtime `Instance.new` visuals, PC 1920×1080 and phone
   667×375 screenshots (`tools/rig/shot.sh`), tests that fail on the old build and pass on the new one.
6. **Ship only when allowed:** publish through Open Cloud with the key in the environment, read back `versionNumber`.
7. **Report in 3–6 lines:** version, what changed, screenshots, and Verified / Automated-only / Unverified.

Small local models: paste `AGENTS.md` §1 + the one doc you need. The UI guide's §0 and §12 (a ready-made prompt) fit
in a small context.

## Quick start (TL;DR)
1. Easiest: tell your agent *"Install the Roblox skill from https://github.com/hishambaoom/roblox-agent-skill-no-README- into this folder by following its INSTALL_FOR_AGENTS.md"*. Or `git clone` this repo and run `adapters/install.ps1` (Windows) or `install.sh` into your game folder.
2. The installer downloads Lune (0.8.9 + 0.10.5) into `tools/` for you; tell your agent to read `AGENTS.md`.
3. Ask for a change. The agent builds with Lune, tests, screenshots, and publishes only when you set the Open Cloud env.
4. Big feature or new game? Have it write a contract (`scripts/swarm/CONTRACT.template.md`) and chain agent patches
   (`scripts/apply-template.luau`), organize last ([docs/swarm-integration.md](docs/swarm-integration.md)).


### 1. Install into your game repo (30 seconds)
```bash
git clone https://github.com/hishambaoom/roblox-agent-skill-no-README- ~/roblox-agent-skill
bash ~/roblox-agent-skill/adapters/install.sh /path/to/your-game claude codex antigravity cursor opencode
```
Windows (PowerShell 7 or 5.1):
```powershell
git clone https://github.com/hishambaoom/roblox-agent-skill-no-README- $HOME\roblox-agent-skill
& $HOME\roblox-agent-skill\adapters\install.ps1 C:\path\to\your-game claude codex antigravity cursor opencode
```
The installer copies `AGENTS.md`, `SKILL.md`, `docs/`, `tools/`, `scripts/`, `assets/` and the adapters you name (never
overwrites unless `FORCE=1`), downloads Lune 0.8.9 + 0.10.5 into `tools/` (`NO_LUNE=1` skips; `tools/get-lune.ps1` /
`get-lune.sh` re-runs it), and creates `QUEUE.md` / `PROJECT.md` stubs and `.gitignore` entries.
On Windows, if scripts are blocked: `powershell -ExecutionPolicy Bypass -File $HOME\roblox-agent-skill\adapters\install.ps1 . codex`.
Agents can follow [INSTALL_FOR_AGENTS.md](INSTALL_FOR_AGENTS.md) step by step.

### 2. Requirements
- Lune: `tools/lune` (0.8.x) and `tools/lune10` (0.10.x, needed for files saved by current Studio);
  on Windows `tools\lune.exe` / `tools\lune10.exe`. The installer fetches both (`tools/get-lune.ps1`).
- bash **or** PowerShell (native Windows: [docs/windows.md](docs/windows.md)) · Python 3 + Pillow (screenshots)
- Publishing: an Open Cloud API key with `universe-places:write` in `ROBLOX_API_KEY`, plus `UNIVERSE_ID` and `PLACE_ID`
  in your environment (never in files).
- Optional: Roblox Studio MCP (built into Studio) for live checks.

### 3. Try the loop (no key needed)
```bash
export GAME_DIR=tools/example-game BASE=path/to/your-place.rbxl
BUILD_OUT=work/x/t1.rbxl tools/lune run tools/example-game/build.luau      # build: base + example hook
tools/rig/fast.sh work/x/t1.rbxl example_feature_test                      # guard + feature tests
tools/rig/shot.sh work/x/t1.rbxl t1                                        # work/rig/out/t1_pc.png, t1_phone.png
DRY_RUN=1 tools/rig/go.sh t2 example_feature_test                          # whole fast lane, publish rehearsed
```
PowerShell:
```powershell
$env:GAME_DIR = 'tools\example-game'; $env:BASE = 'path\to\your-place.rbxl'
$env:BUILD_OUT = 'work\x\t1.rbxl'; .\tools\lune.exe run tools\example-game\build.luau; Remove-Item Env:BUILD_OUT
.\tools\rig\fast.ps1 work\x\t1.rbxl example_feature_test
.\tools\rig\shot.ps1 work\x\t1.rbxl t1
$env:DRY_RUN = '1'; .\tools\rig\go.ps1 t2 example_feature_test; Remove-Item Env:DRY_RUN
```
Then point `GAME_DIR` at your own game folder (its `build.luau`, hooks and tests), copy `tools/rig/dump.example.luau`
to `tools/rig/dump.luau` and adapt its boot section to your client scripts, and set the publish env vars.

### 4. Patch an existing place (no build.luau needed)
```bash
cp scripts/apply-template.luau games/mygame/work/myfeature/apply.luau        # edit scope + MARK
IN=place.rbxl OUT=work/x/out.rbxl tools/lune10 run games/mygame/work/myfeature/apply.luau
IN=work/x/out.rbxl OUT=work/x/out2.rbxl tools/lune10 run games/mygame/work/myfeature/apply.luau   # must report 0 changes
```

### 5. Which file each agent reads
| Agent | Reads | Setup |
|---|---|---|
| Claude Code | `CLAUDE.md` (`@AGENTS.md`), `.claude/skills/roblox-dev/`, `.claude/agents/*`, `.mcp.json` | docs/model-setup.md |
| Codex CLI | `AGENTS.md`, `.agents/skills/roblox-dev/`, `~/.codex/config.toml` | docs/model-setup.md |
| Antigravity | `AGENTS.md`, `.agents/rules/*.md`, `.agents/skills/`, `.agents/workflows/` | docs/model-setup.md |
| Cursor | `AGENTS.md`, `.cursor/rules/*.mdc` | docs/model-setup.md |
| OpenCode | `AGENTS.md`, `opencode.json` | docs/model-setup.md |
| Chat-only (ChatGPT, Claude.ai, Gems) | paste `adapters/chat-only/system-prompt.md`, upload `AGENTS.md` + `docs/` | docs/model-setup.md |

## Doc index
| Topic | Doc |
|---|---|
| Start here: rules, loop, decisions, report format | [AGENTS.md](AGENTS.md), [SKILL.md](SKILL.md) |
| Fast lane, gameplay lane, patch lane, parallel contract | [docs/workflow.md](docs/workflow.md) |
| Everything editable in Studio | [docs/studio-first-rule.md](docs/studio-first-rule.md) |
| Lune builds and patches | [docs/build-pipeline-lune.md](docs/build-pipeline-lune.md), [docs/lune10-gotchas.md](docs/lune10-gotchas.md) |
| Tests, publishing, live Studio | [docs/testing.md](docs/testing.md), [docs/publishing-open-cloud.md](docs/publishing-open-cloud.md), [docs/studio-mcp-bridge.md](docs/studio-mcp-bridge.md) |
| Parallel agents | [docs/subagents.md](docs/subagents.md) (small batches), [docs/swarm-integration.md](docs/swarm-integration.md) (whole game) |
| Organizing a place safely | [docs/organize-and-refcheck.md](docs/organize-and-refcheck.md) |
| Studded UI recipe (exact values) + example panel | [docs/STUDDED_UI_GUIDE.md](docs/STUDDED_UI_GUIDE.md), [assets/ui/reference/](assets/ui/reference/) |
| UI, 3D previews, juice | [docs/ui-conventions.md](docs/ui-conventions.md), [docs/viewport-previews.md](docs/viewport-previews.md), [docs/juice.md](docs/juice.md) |
| Focus modes, cameras, held tools | [docs/interaction-patterns.md](docs/interaction-patterns.md) |
| Events, economy, badges, boss variants | [docs/live-events.md](docs/live-events.md), [docs/economy-and-events.md](docs/economy-and-events.md) |
| Security and anti-cheat | [docs/security.md](docs/security.md), [docs/anti-cheat.md](docs/anti-cheat.md) |
| Performance on phones | [docs/performance.md](docs/performance.md) |
| Models, prompts, audio | [docs/models-and-audio.md](docs/models-and-audio.md), [docs/model-prompts.md](docs/model-prompts.md) |
| Money and launch | [docs/monetization.md](docs/monetization.md), [docs/marketing-launch.md](docs/marketing-launch.md), [docs/launch-checklist.md](docs/launch-checklist.md) |
| Model imports, VFX packs, core-loop QoL | [docs/model-import-pipeline.md](docs/model-import-pipeline.md), [docs/vfx-packs.md](docs/vfx-packs.md), [docs/forging-qol.md](docs/forging-qol.md) |
| Economy sims, limited items | [docs/economy-simulation.md](docs/economy-simulation.md), [docs/limited-items.md](docs/limited-items.md) |
| Every bug that cost a build | [docs/lessons-learned.md](docs/lessons-learned.md) |
| Agent setup, Windows, references | [docs/model-setup.md](docs/model-setup.md), [docs/windows.md](docs/windows.md), [docs/resources.md](docs/resources.md) |

## Folder map
```
AGENTS.md              main instructions: persona, standing rules, loop, decision table, report format  ← start here
SKILL.md               Agent-Skills entry point (frontmatter) → which doc to open for which task
docs/
  STUDDED_UI_GUIDE.md    exact studded UI recipe (any model) workflow.md            fast/gameplay/patch lane, contract
  studio-first-rule.md   everything editable in Studio
  build-pipeline-lune.md Lune .rbxl builds and patches        testing.md             rig tests, guard, base comparison
  publishing-open-cloud.md  publish + version checks          studio-mcp-bridge.md   live Studio via MCP + tunnel fixes
  ui-conventions.md      phone fit, text, popups              monetization.md        passes, products, receipts
  live-events.md         timed/admin events, scaled rewards   performance.md         Highlights cap, streaming, low gfx
  juice.md               reward feedback ("dopamine")          models-and-audio.md    prompt packs, AI rigs, AudioContent
  marketing-launch.md    discovery, thumbnails, badges, promo security.md            remotes, data, free models
  launch-checklist.md    readiness audit                      lessons-learned.md     every bug that cost a build
  swarm-integration.md   contract + serial chain for 20 agents organize-and-refcheck.md  organize last, prove it
  lune10-gotchas.md      Lune 0.10 traps, idempotent apply    viewport-previews.md   3D UI previews that render
  interaction-patterns.md focus mode, cameras, held tools     economy-and-events.md  income-scaled rewards, variants, badges
  anti-cheat.md          3-phase server anti-cheat            model-prompts.md       ChatGPT + Blender prompt templates
  model-import-pipeline.md  owner .rbxm -> held/display/preview vfx-packs.md           pack FX, budgets, Low gfx
  forging-qol.md         hold/stop-at/confirm/bag tools       economy-simulation.md  Monte Carlo pacing before publish
  limited-items.md       cash/Robux limiteds, pedestals
  subagents.md thinking.md project-state-template.md model-setup.md windows.md resources.md
  examples/              5 worked sessions: request → plan → commands → output → report
scripts/               apply-template.luau, organize/ (template, refcheck, check, reverse, test_chain.sh),
                       viewport/ (preview client), swarm/ (contract template) — scripts/README.md
adapters/              claude-code/ codex/ antigravity/ cursor/ opencode/ chat-only/ + install.sh / install.ps1
tools/rig/             go, shot, fast, run_all, compare_runs, publish, prices, retention, config (.sh + .ps1 twins),
                       render.py (screenshot renderer), dump.example.luau (layout dumper)
tools/uimap/           grep-able map of every UI element and its look
tools/mcp/             Studio MCP HTTP client + example UI probe
tools/example-game/    example build.luau + hook + tests (feature, studio-rule guard, text size) + rbxsim.luau
assets/                icons, thumbnails, badges, CTR sim, rebirth curves, model prompt packs, SFX, UI kit (assets/README.md)
```

## Examples: what to ask your agent
| You say | The agent does |
|---|---|
| "The shop cards overlap the jump button on phone." | fast lane: fit via `Phone*` attributes, PC + phone shots, publish, 2-line report |
| "Free steal every 120 s, paid cooldown 30 s." | tunable change in Config attributes, test, publish, one "your call" if risky |
| "Players lose their bag order on rejoin." | gameplay lane: root cause, saved field + migration, test that fails on base |
| "Add a meteor shower event I can start from admin." | event playbook: Config, Studio models, scheduler, admin rows that stack ([docs/live-events.md](docs/live-events.md)) |
| "The game lags on my phone." | read-only perf audit, ranked fixes, owner picks ([docs/performance.md](docs/performance.md)) |
| "Make a new shop panel in our studded style." | clone the closest panel, recipe from [docs/STUDDED_UI_GUIDE.md](docs/STUDDED_UI_GUIDE.md), PC + phone shots |
| "Make the cash popup more dopamine." | juice an existing template: pop, count-up, shine, pitch, shake ([docs/juice.md](docs/juice.md)) |
| "Make new thumbnails." | thumbnail rules + CTR sim ([docs/marketing-launch.md](docs/marketing-launch.md), `assets/ctr_sim/`) |
| "Are we ready to launch?" | read-only audit, verdict, ordered blockers ([docs/launch-checklist.md](docs/launch-checklist.md)) |
Full transcripts: [docs/examples/](docs/examples/).

## Troubleshooting
| Problem | Fix |
|---|---|
| Lune can't open a place/model saved by current Studio | use `tools/lune10` (0.10.x) |
| New sound ID "set" but the old sound still plays | Lune 0.10: `s.AudioContent = roblox.Content.fromUri("rbxassetid://…")`, not `SoundId`; read it back |
| Text tiny in game but fine in tests | `TextScaled` needs `TextWrapped = true` + `UITextSizeConstraint` (min ≥ 12) |
| Mesh placed by Lune invisible in game | keep a primitive fallback visible until checked in Studio |
| Outlines vanish at random | over 31 Highlights: one shared Highlight per group ([docs/performance.md](docs/performance.md)) |
| Owner's Studio edits disappeared after a publish | pipeline published over unsynced Studio work: owner saves to file → new BASE |
| Publish 409 / "server busy" | place open with Collaborative Editing: back off and retry, then ask the owner to close it |
| Studio MCP tunnel says `Forbidden` / 403 | stale quick-tunnel URL or restarted gateway: restart both, send the new URL ([docs/studio-mcp-bridge.md](docs/studio-mcp-bridge.md)) |
| `list_roblox_studios` is empty | enable "Studio as MCP server" in Assistant → Manage MCP Servers, reopen the place |
| Promo posts silently removed, account locked | fresh accounts mass-posting get filtered: one post at a time from aged accounts ([docs/marketing-launch.md](docs/marketing-launch.md)) |
| PowerShell won't run the scripts | execution policy and env-var notes in [docs/windows.md](docs/windows.md) |
| 3D previews in UI cards are blank | cameras don't replicate: make the camera on the client ([docs/viewport-previews.md](docs/viewport-previews.md)) |
| Lune-built camera/stand faces the wrong way | Lune's `CFrame.lookAt` is wrong: use `CFrame.fromMatrix` ([docs/lune10-gotchas.md](docs/lune10-gotchas.md)) |
| Client effect fires before the object exists | Deferred signals: `task.defer` the `FireAllClients` after the server builds it |
| Welded parts snap to the centre in Studio | Lune-written `WeldConstraint`s have identity offsets: use classic `Weld`s with `C0` |
| Organizing the place broke scripts | organize in transactional groups + refcheck ([docs/organize-and-refcheck.md](docs/organize-and-refcheck.md)) |
More: [docs/lessons-learned.md](docs/lessons-learned.md).

## Safety
No secrets, keys, account details, emails or place files are in this repo. Keys live in your environment only.
Experience, place, badge and asset IDs are written as placeholders (`<UNIVERSE_ID>`, `<BADGE_ID>`); use your own.

## License
MIT, see [LICENSE](LICENSE). Asset licensing per file: [assets/README.md](assets/README.md).
