---
description: Fast-lane Roblox UI/value tweak - find, edit hook, build, PC+phone shots, fast tests, publish if green, log, short report.
---

1. Read the last `DONE` line and any `HOLD`/`CLAIM` lines in QUEUE.md. Stop and tell the owner if a HOLD covers this.
2. `grep -n "<element or attribute>" ui-map.md` and find the build hook that bakes it.
3. Edit only that hook (size/position/attribute value). Keep the design.
4. Run `tools/rig/go.sh v<next> open=<MenuName>` (use `NOPUBLISH=1` if the owner wants to look first).
5. Open `work/rig/out/v<next>_pc.png` and `work/rig/out/v<next>_phone.png` and check them.
6. Append to QUEUE.md: `- DONE <time>: LIVE = work/x/v<next>.rbxl (version <N>) = <base> + <hook> (<change>). BASE next: work/x/v<next>.rbxl.`
7. Reply: "Version <N> is live, so rejoin now. <change>." + both shots + "rig shots only" + the Studio attribute to edit.

Windows (PowerShell): `.\tools\rig\go.ps1 v<next> open=<MenuName>` (hold with `$env:NOPUBLISH='1'`; docs/windows.md).
