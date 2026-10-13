# Model prompts for ChatGPT + Blender (owner-made models, game-ready on import)

In the second reference game the owner made every model himself by pasting prompts into ChatGPT, which wrote and ran
Blender Python and exported FBX/OBJ. 15 swords, 6 furnaces, an anvil, a display rack, 5 hammers and a plot base came out
consistent because every prompt shared one style block and one export spec. See `docs/models-and-audio.md` for other
generators (Meshy, Studio Assistant) and audio.

## The shared blocks (paste into every prompt)
**Style**
```
Style: chunky Roblox brick look with real raised round studs (actual geometry, not a texture) on flat top surfaces,
bold readable silhouette, bright saturated colours, smooth plastic material, low poly, no text, no logos.
Game: <one line about the game>. Must read clearly from a 3/4 top-down camera at 30 studs.
```
**Export spec**
```
Units: 1 Blender unit = 1 Roblox stud. Origin: bottom-centre (props) / <grip point> (held items). Forward = -Y, up = +Z.
Triangles: <budget, e.g. under 4,000>. Apply all transforms. One object per model unless listed below.
Separate objects (named exactly): Glow_* for anything that should be Neon (fire, lava, gems, runes, eyes), Fx_* for parts
that move or orbit. Name the root exactly "<MODEL_NAME>".
Export: FBX + OBJ/MTL per model, textures beside them, a preview PNG, and a JSON with triangle count and bounds.
Re-import each FBX and verify triangle count and bounds before saying done.
```
Separate glow parts were the most useful line: Studio can set Neon/lights per part and the game can toggle them in Low
Graphics.

## Templates
**A tiered set (same object, rising power)**
```
Make <N> <objects> for a progression from weakest to strongest, in this order: <tier list>.
Same footprint <W x D> studs, heights rising from <a> to <b>. Each tier must have a NEW silhouette element, not just a
recolour: <tier>: <feature>; ... Top tier: <hero feature>.
Colours per tier (hex): <list>.
[Style] [Export spec]
```
**A fix pass on a finished set** (after looking at the preview sheet)
```
Keep every model byte-for-byte except: <Model A> and <Model B> look like twins -> make <A> <difference>.
<Model C> reads brown, not gold -> brighter yellow-gold #FFC83D with white specular. <Model D> is dull -> <change>.
Re-export only the changed models with the same names, origin and scale.
```
**A functional prop with gameplay points**
```
Make <PROP> as an empty <size> studs base. Include invisible marker parts named exactly: <PointA>, <PointB>, ... at
<positions>, each a 1x1x1 part, so the game can place things there. <Recolourable parts> are separate objects
(Border, Flag) so the game can tint them per player.
[Style] [Export spec]
```
**A held item**
```
Make <N> <held items> ~<length> studs long. Origin at the centre of the grip (where the palm goes). Handle along +Z.
Head/blade a separate object; no hidden helper objects.
```

## Import checklist (agent side)
1. Owner imports, names each model exactly, File -> Save to File; agent reads the place/.rbxm with Lune 0.10.
2. Measure bounds and the front face from the mesh before placing anything on it.
3. Replace any Lune-written `WeldConstraint` with classic `Weld`s (docs/lune10-gotchas.md); `PrimaryPart` = the real
   main part, pivot at the grip/bottom-centre; bake the in-hand size instead of scaling at runtime.
4. Effects that came with the models as scripts creating particles at runtime: replace with real saved emitters.
5. Render a preview sheet of the whole set at the same scale; send it to the owner before wiring gameplay.
