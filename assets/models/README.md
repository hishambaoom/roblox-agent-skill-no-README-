# assets/models/

Ready-to-insert Roblox models (`.rbxm`) from the two reference games. In Studio: right-click a service or folder in
the Explorer, **Insert from File...**, pick the `.rbxm`. Everything stays editable instances (Studio-first rule).

- `pumpkin-king/` - *Don't Wake the Pumpkin King*: the boss (5 King variants with controller, animation player and
  head slots), vault, loot pickups, candy collectibles, map props, ground detail scatter, event models, cauldron.
- `forgetax/` - *ForgeTax*: shop + limited hammers, Lv7/Lv8 furnaces, Dragon Shop island with ShopKeeper, Dragon Flight
  upgrade rig, Forge event pack (Dragon Vault, MasterSmith R15 rig, Lucky Shrine), giant swords, studded stones.
- `vfx-pack/` - particle / beam / aura effects (94 effects) used for hits, auras and rarity feedback.

Meshes point at asset IDs uploaded by the repo owner. If a mesh shows blank in your place, re-upload the source
mesh (or replace the `MeshId`) under your own account; how to wire models into a game: `docs/model-import-pipeline.md`.
Animations inside the rigs must be re-uploaded by whoever owns the place (Roblox animation permissions).

## Contents (top-level children)

| File | What is inside |
|---|---|
| `forgetax/DragonFlightUpgrade.rbxm` | Rig, Effects, Wing_Right_Statue_Obsidian_Black, Wing_Left_Statue_Obsidian_Black, Wing_Right_Statue_Metallic_Gold, Wing_Left_Statue_Metallic_Gold, Dragon_Flight_Root_Statue_Metallic_Gold, Head_Statue_Metallic_Gold, Dragon_Flight_Root_Statue_Obsidian_Black, Wing_Right_Statue_Wing_Black, Wing_Left_Statue_Wing_Black, Eye_Blink_R_Dragon_Glow_Amber, Eye_Blink_L_Dragon_Glow_Amber, Ankle_Rear_R_Statue_Metallic_Gold, +32 more |
| `forgetax/DragonShop.rbxm` | Decor, DragonAltar, EntranceArch, HammerPedestal_01, HammerPedestal_02, HammerPedestal_03, HammerPedestal_04, HammerPedestal_05, HammerPedestal_06, Island, LimitedBanner, ShopKeeper, ShopSign, Spawn, +1 more |
| `forgetax/ForgeEventPack.rbxm` | DragonVault, MasterSmith, LuckyShrine |
| `forgetax/GiantShatteredSwords.rbxm` | GiantSword_Obsidian, GiantSword_Iron, GiantSword_Crystal, GiantSword_Gold, FloatingShards |
| `forgetax/LimitedHammers.rbxm` | Hammer_Sakura, Hammer_Ember |
| `forgetax/ShopHammersAndFurnaces.rbxm` | Hammer_Pumpkin, Furnace_Lv7_Abyss, Hammer_Void, Hammer_Galaxy, Hammer_Magma, Furnace_Lv8_Celestial, Hammer_Wyrmfang, Hammer_Celestial |
| `forgetax/StuddedStones.rbxm` | Stone_Moss_Tall, Stone_Moss_Medium, Stone_Small, Stone_Moss_Large, Stone_Medium, Stone_Large, Stone_Moss_Small, Stone_Tall |
| `pumpkin-king/CandyCollectibles.rbxm` | The Pumpkin King's Heart, Midnight Clock Candy, Phantom Crown Jelly, Blood Moon Gobstopper, Witch's Potion Lollipop, Skeleton Key Licorice, Haunted Mirror Cookie, Vampire Bat Bonbon |
| `pumpkin-king/Cauldron.rbxm` | body |
| `pumpkin-king/DetailModels.rbxm` | DeadGrassTuft, TallGrassClump, PurpleGrassTuft, SwampReeds, FallenLeavesPile, MossPatch, GlowMushrooms, TinyPumpkins, BonePile, Pebbles |
| `pumpkin-king/EventModels.rbxm` | TrickDoor, Ghost, GoldenGhost, GhostCrate, BloodMoon, MidnightClock |
| `pumpkin-king/KingVariants.rbxm` | 04_ArcaneWarden, 06_FrostTitan, 05_ChaosRoyal, 04_RoyalIndigo, 05_ArcaneRoyal, 08_EclipseRegent |
| `pumpkin-king/King_RoyalIndigo_Green.rbxm` | Left Leg, Right Arm, Left Arm, Right Leg, HumanoidRootPart, Head, Humanoid, Configuration, HeadSkins, HeadSlot, Animations, AnimationPlayer, KingController, AnimationMarker, +52 more |
| `pumpkin-king/KingsVault.rbxm` | body_geom |
| `pumpkin-king/LootModels.rbxm` | PumpkinKingHead, CandyCorn, GummyWorms, Wrapped, AppleSlice, LicoriceBat, Lollipop, MarshmallowGhost, CandyCaneBone, Bar, GumballSkull, Apple, CottonCandy, JawbreakerEye, +17 more |
| `pumpkin-king/MapModels.rbxm` | Pumpkin, JackOLantern, Gravestone, DeadTree, LanternPost, SpookyFence, CandyCauldron, CauldronLantern, Signpost, Pedestal, CandyMarketStall, PlotGate, HayBale, Scarecrow, +22 more |
| `pumpkin-king/PumpkinClub.rbxm` | Body |
| `vfx-pack/vfx.rbxm` | Charge-01, Blood-02, Blood-01, Smoke-01, Slashes-01, Blood-Punch-01, Shiny-01, Lighting-02, Lighting-01, ForceField-Break-01, ForceField-01, Water-01, Water-02, Slash-01, +80 more |

## License
Pumpkin King and ForgeTax models: the repo owner's own models (made with AI mesh tools), MIT like the rest of the repo;
please don't republish the Pumpkin King or ForgeTax characters/branding as your own game.
`vfx-pack/vfx.rbxm`: collected effects pack, original author not recorded here. Treat it as reference only and check
its license before shipping it in a commercial game.
