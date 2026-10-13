# 3D previews in UI (ViewportFrame) that actually show up

Shop/Index/Upgrade cards with a spinning 3D model are a cheap way to make UI feel premium. They were blank in the
reference game for a whole version. Root cause and the working pattern:

## Why they were blank
- **Camera instances never replicate server -> client.** The UI lived in StarterGui; the server clones it into each
  PlayerGui. The `Camera` saved inside each ViewportFrame did not arrive on the client, so the client's fit step found no
  camera and returned early. `CurrentCamera` stayed nil = empty frame.
- Lune can't save `ViewportFrame.CurrentCamera` either: the write is silently accepted and unreadable afterwards.
- The pipeline's screenshot rig draws ViewportFrames as placeholders, so tests and shots looked fine.

## Working pattern
1. Preview **models** are real, editable instances: `ReplicatedStorage.Previews/{Swords,Furnaces,Hammers}/<Name>`
   (clones of the game assets with scripts, emitters and lights stripped). The owner can swap or tweak them in Studio.
2. Each card holds `Preview` (ViewportFrame) -> `WorldModel`. Keep a saved `Cam` for Studio editing only.
3. The **client** creates `ClientCam` per viewport (the one place `Instance.new` of a visual-adjacent object is
   unavoidable; say so in the notes and in the Studio-first guard's allow-list), clones the model into the WorldModel,
   frames it on the bounding box, and orbits it (`SpinSpeed` attribute).
4. Locked entries = silhouette: `Ambient`, `LightColor` and `ImageColor3` black plus a "?" label. Found = lit, light tinted
   ~30% toward the rarity colour (`Preview@TintAmount`).
5. Upgrade cards show the **next** tier's model by cloning from `Previews` at runtime (fallback: the game asset folder).
6. Tunables as attributes: `SpinSpeed`, `Roll`, `Tilt`, `Fit` (framing), camera `FieldOfView` (~30).

Example client: `scripts/viewport/ViewportPreviewClient.client.luau`.

## Framing math
```lua
local cf, size = model:GetBoundingBox()
local radius = size.Magnitude / 2 * (vp:GetAttribute("Fit") or 1.1)
local dist = radius / math.tan(math.rad(cam.FieldOfView) / 2)
cam.CFrame = CFrame.new(cf.Position + dir * dist, cf.Position)   -- dir = rotated unit vector (Tilt/Roll/spin)
```

## Checks
- Test on a real client (Studio Play or MCP), not only the rig: confirm `vp.CurrentCamera ~= nil` and the WorldModel has
  one model for every card.
- Don't put models directly under the ViewportFrame if you need physics-free `PivotTo`/animation; use a WorldModel.
- Same rule anywhere else: cutscene/forge cameras, cutaways and preview cameras are always made on the client.
