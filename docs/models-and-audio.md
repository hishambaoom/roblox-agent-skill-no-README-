# Models, rigs and audio (AI-assisted, owner-editable)

## Models from prompts -> one .rbxm -> the build swaps them in
1. Write one prompt per model with a shared **style line** so everything matches
   (`stylized cartoon Roblox game asset, chunky simple shapes, smooth glossy materials, bright saturated colours, low poly,
   single object, centred, no base, no text`) plus hex colours per model. Templates: `assets/prompts/`.
2. Owner generates them (Studio Assistant / Cube 3D, Meshy, Tripo), renames each to the exact `MODEL NAME`, puts them in a
   folder, right-click **Save to File** -> `models.rbxm`, sends it.
3. The build reads the .rbxm with Lune (**use Lune 0.10.x** for files from recent Studio; 0.8 fails to parse them) and
   swaps each named model in; anything missing keeps the block fallback.
4. Budgets: small pickups <= ~2k triangles, props <= ~3k, hero props <= ~6k. No glow baked in; the game adds lights.
5. Scale and orient from the mesh, not guesses: measure the mesh bounds/front face (dump vertices if needed) before placing
   decals or emblems (an emblem landed on the back of a vault mesh until the front was measured as -Z).

## Character / boss body from AI 3D
- Image-to-3D tools give 100k-500k triangle meshes. Decimate to < 20k for a MeshPart, **merge UV seams before decimating**
  (or you get cracks), bake colours to a texture atlas.
- Skin to R15-named bones (HumanoidRootPart, Lower/UpperTorso, Head, arms, legs; extra cape bones are fine), author
  Walk / Run / Idle, validate the glTF, then upload model + animations through Open Cloud.
- Runtime import (`InsertService:LoadAsset`) must keep the imported hierarchy **intact**: re-parenting bones or deleting
  the root skin joint gave a T-pose. Drive the mesh root from the template root with a `Motor6D`, keep a fallback bone
  driver, and expose `FlipInvert` / `HeadOffsetY` / `AnimMode` attributes, because "facing backwards / leaning back /
  head too high" are tuned live by the owner.
- Ship such things as an admin-only **test spawn** first; never replace the live boss until the owner has seen it.
- Free-tier gotchas: many tools paywall the export or hit daily GPU quotas; captcha loops block automation. Budget for that.

## Audio
- **Lune 0.10 + new place files: set `Sound.AudioContent = roblox.Content.fromUri("rbxassetid://<id>")`.**
  Writing `Sound.SoundId` is silently lost when the place stores `AudioContent`; the build "succeeds" and the old sound
  stays. Verify by reading the property back from the output file.
- Make original SFX (synthesised or recorded) rather than grabbing library sounds you can't license; keep them short
  (whistle ~1.6 s, thud ~1.2 s), mono, normalised. Examples: `assets/sfx/`.
- Upload via Open Cloud Assets API (`assetType Audio`); new uploads sit in moderation ("Reviewing") before they play.
  Bake the returned IDs into the build.
- 3D sounds: parent to a part/attachment, `RollOffMinDistance`/`MaxDistance` (e.g. 40..400), route through a SoundGroup
  so a volume setting covers them. Pitch-vary repeated sounds (footsteps, hits) by a few percent.
- If the owner says "skip that sound", leave the slot empty rather than wiring a substitute.
