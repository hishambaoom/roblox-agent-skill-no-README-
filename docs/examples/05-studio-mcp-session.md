# Example 5 — Working in the owner's live Studio over MCP (and syncing back)

Real flow from Oct 8: the owner had another AI add a quest system directly in Studio; the agent connected through
the built-in Studio MCP server + supergateway + a Cloudflare quick tunnel.

## Owner
> [tunnel link] the quest pills resize when I hover them and the rows look washed out. fix in my studio

## Agent — connect and look (measure, don't trust captures)
```
$ export STUDIO_MCP_URL=https://<words>.trycloudflare.com/mcp
$ python3 tools/mcp/mcpc.py call list_roblox_studios '{}'
[{"name":"[🎃 HALLOWEEN] Don't Wake the Pumpkin King!","studio_id":"…","place_id":124463173231636}]
$ STUDIO_ID=… python3 tools/mcp/mcpc.py call script_grep '{"pattern":"QuestPill","studio_id":"…"}'
$ STUDIO_ID=… python3 tools/mcp/mcpc.py lua probe_quests.luau Client      # in Play
{"pill":{"absSize":[212,30],"hoverAbsSize":[236,34]},"rows":3}
```
(First attempts failed on parameter format — read the tool schema from `tools`/`tools/list` before calling.)

## Agent — change (template only, design kept)
- Hover tween scaled the pill → locked pill width to the button grid; text fits without clipping.
- Rows: deeper blue stud gradient on the **row template** so they stand out; outline, text, bars, rewards,
  LOCKED/DONE buttons unchanged.
- Had to stop the owner's playtest to edit — said so.

## Agent → owner
> Both done in your live Studio. Hovering and clicking the quest pills no longer resizes them, and the Daily Quests
> rows are a deeper blue. Save, then publish from Studio. Mine would overwrite the quest system (my build copy doesn't
> have it).

## The sync rule (the important part)
Later that night the Studio link dropped and the owner asked the agent to publish admin fixes:
> I can't use the old way as it stands. It publishes our local copy, and that copy is missing everything done in Studio
> tonight: the quest system, colours, Settings, hotbar, loot fix and Admin panel. A publish would wipe all of it, and my
> key can't download your live place. Fix: in Studio, File → Save to File, then drop the .rbxl here.

Owner sent the file → it became the new BASE (`QUEUE: BASE next = <saved file>`), all 166 scripts loaded without errors
in the sim, fixes applied as anchor patches, tests, publish from the pipeline again.

## Owner's verdict, recorded in PROJECT.md
*MCP is better for editing (real Studio, real playtest, can see other AIs' work); the pipeline wins on tests and
publishing. Routine: edit through MCP → save .rbxl → pipeline tests → publish.*

## Checklist for an MCP session
1. `list_roblox_studios` → `studio_id`. `get_studio_state` before Play-only probes.
2. Probes return one short JSON string; < 30 s per call.
3. Measure UI (`AbsoluteSize`, `AbsolutePosition`, `TextBounds`), close menus before clicking/capturing.
4. Edit templates, not clones; keep the design; tell the owner where the change lives.
5. End: owner saves + publishes from Studio, or saves to file for the pipeline. Never publish the pipeline over it.
6. Tunnel down → continue with the rig and say "NOT playtested"; ask for a fresh link.

---
*Facts (numbers, versions, quotes) come from the reference project's version log and chat; command output is abbreviated and reformatted to the shipped rig's format.*
