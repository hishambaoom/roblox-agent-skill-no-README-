# Template maps and assets (script-free)

Maps, models and UI pulled from 20 public Roblox game templates, with **every script removed** (Script, LocalScript, ModuleScript) and PackageLinks dropped. They are meant as a starting point: open them in Studio, then reskin or rebuild them (by hand or with an AI agent) into your own game.

Each folder holds up to three files:
- `map.rbxm`: everything that was in Workspace (Terrain and Camera excluded, since Terrain can't be saved in a model file).
- `assets.rbxm`: models, meshes, effects, sounds and UI kept in ReplicatedStorage and ServerStorage.
- `ui.rbxm`: the StarterGui screens (layout only, no scripts).

Insert one in Studio: right-click Workspace (or the service you want) > Insert from File.

| Folder | Files | Size |
|---|---|---|
| `build-a-plane/` | assets.rbxm, map.rbxm, ui.rbxm | 1.0 MB |
| `build-your-base/` | assets.rbxm, map.rbxm, ui.rbxm | 4.4 MB |
| `climb-for-brainrots/` | assets.rbxm, map.rbxm, ui.rbxm | 0.6 MB |
| `dont-wake-up/` | assets.rbxm, map.rbxm, ui.rbxm | 0.4 MB |
| `escape-tsunami-for/` | assets.rbxm, map.rbxm, ui.rbxm | 0.2 MB |
| `find-the/` | assets.rbxm, map.rbxm, ui.rbxm | 1.5 MB |
| `find-the-button/` | assets.rbxm, map.rbxm, ui.rbxm | 0.5 MB |
| `jump-for-cars/` | assets.rbxm, map.rbxm, ui.rbxm | 0.2 MB |
| `mine-a/` | assets.rbxm, map.rbxm, ui.rbxm | 2.2 MB |
| `mutate-or-lose/` | assets.rbxm, map.rbxm, ui.rbxm | 0.7 MB |
| `my-fishing/` | assets.rbxm, map.rbxm, ui.rbxm | 0.3 MB |
| `my-garden/` | assets.rbxm, map.rbxm, ui.rbxm | 0.3 MB |
| `my-lucky-block/` | assets.rbxm, map.rbxm, ui.rbxm | 1.0 MB |
| `plants-vs/` | assets.rbxm, map.rbxm, ui.rbxm | 0.8 MB |
| `royale/` | assets.rbxm, map.rbxm, ui.rbxm | 1.5 MB |
| `run-for-cars/` | assets.rbxm, map.rbxm, ui.rbxm | 0.2 MB |
| `shoot-a-brainrot/` | assets.rbxm, map.rbxm, ui.rbxm | 1.2 MB |
| `steal-a/` | assets.rbxm, map.rbxm, ui.rbxm | 1.1 MB |
| `survive-lava-for-cars/` | assets.rbxm, map.rbxm, ui.rbxm | 0.2 MB |

## Not included
- **Don't Steal From Brainrots [ CMDR ]**: excluded. It carries a multi-stage backdoor (remote `require` of asset IDs, hidden in attributes and fake weld scripts).

## Third-party, use at your own risk
These builds were made by other creators and are shared here **without a verified license**. Mesh, image, sound and animation IDs still point at their uploads on Roblox. Some came from decompiled/ripped places (Find The, Royale, Plants Vs). Change the maps and replace the assets before publishing anything commercial, and remove any file here if its owner asks.
