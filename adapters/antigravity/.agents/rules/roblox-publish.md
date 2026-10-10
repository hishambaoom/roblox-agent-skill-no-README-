---
trigger: model_decision
description: "Apply when publishing a Roblox place, changing game pass / developer product prices, or deciding whether a build may go live."
---

# Publishing a Roblox build

1. Only publish if the owner's standing rule allows it (fast-lane tweaks after tests pass) or the owner said go. Never
   while a `HOLD` line in QUEUE.md covers the change, never with a newly failing test.
2. Check QUEUE.md `BASE next`. If your build started from an older base, re-apply your patch on the new base and
   re-test first — otherwise you undo someone else's live work.
3. Never publish the pipeline build over edits that exist only in the owner's Studio (MCP edits, owner edits). Ask the
   owner to File → Save to File and send the .rbxl; it becomes the new base.
4. `tools/rig/publish.sh <place>` (env `ROBLOX_API_KEY`, `UNIVERSE_ID`, `PLACE_ID`; `DRY_RUN=1` to rehearse). 409 → it
   retries with backoff. "Scope not authorized" → key needs universe-places Write for this experience.
5. Read `versionNumber` from the response; that is the number you tell the owner ("Version N is live, so rejoin now").
6. Append the QUEUE.md `DONE` line (`LIVE = <file> (version N) = <base> + <patch>. BASE next: <file>`), run
   `tools/rig/retention.sh`.
7. Prices: `tools/rig/prices.sh pass|product <id> <price>` with the owner's exact number only; report old → new.
