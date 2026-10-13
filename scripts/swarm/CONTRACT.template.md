# <GAME> build contract (swarm v1, <DATE>)
Root R=<repo root>. Design: R/<design doc>. BASE place: R/games/<game>/build/<game>_v0.rbxl (the owner's Studio save; never edit it).
NEVER touch other games' files/places. Publish target: universe <UNIVERSE_ID> / place <PLACE_ID> (only the integrator publishes).
Tooling: R/tools/lune10 (0.10.x). Patch = R/games/<game>/work/<agent>/apply.luau reading env IN, writing env OUT
(start from scripts/apply-template.luau). Test = R/games/<game>/work/<agent>/test.luau run on OUT. Never write a renderer.
INTEGRATION ORDER (chained serially onto BASE): 1 core, 2 fx, 3 plots, 4 <system>, 5 ui, ... organize LAST.
Your apply must work on BASE AND on BASE + earlier agents (only touch your own scope; FindFirstChild before create; idempotent).

## THE OWNER'S RULES (hard, copied verbatim)
- Every visual (UI, models, particles, lights, sounds) is a REAL instance saved in the place. Scripts only clone / move / show /
  hide / fill text / tween / enable emitters. Never Instance.new visuals at runtime; never override the owner's sizes, colours, fonts.
  Tunables = attributes or Config module values.
- Style: <one paragraph + reference image paths>. TextScaled needs TextWrapped + UITextSizeConstraint MinTextSize >= 12. Phone must fit.
- Luau, server-authoritative, pcall DataStores, no require(assetId) / loadstring / getfenv. <theme do's and don'ts>.

## Existing assets in BASE (verify every path before sending this)
Workspace.<Map> (...). Workspace.<Assets>/<Category>/<Model> (...). ServerStorage.<Tools> (...).
Asset lookup in code: local A = ReplicatedStorage:FindFirstChild("<Assets>") or workspace:FindFirstChild("<Assets>")

## Shared names (everyone codes against these)
ReplicatedStorage.<Game>Shared.Config (ModuleScript, owned by core):
  <Items> = ordered list {Name, Model, BaseValue, Color}, ...
  <Rarities> = {Name, MinLevel, Color} ...; Config.RarityForLevel(l)
  <Formulas>: ValueFor(item, level), FailChance(level) (anchor values + interpolate) ...
  <Upgrades>[1..N] = {Cost, ...}; Rebirth = {Cost, CashMult}
ReplicatedStorage.<Game>Remotes (Folder, owned by core; core creates ALL RemoteEvents even if handled by others):
  <Action1>, <Action2> ... (core handles); <Action3>(args) (<agent> handles);
  Fx (server->client: FireAllClients(kind, data)); Notify (server->client: text, colorName).
Fx kinds: "<Kind>"{player, ...}, ...
Player attributes (server sets, client reads): Cash, Rebirths, <...>.
Server modules (ServerScriptService.<Game>Server): PlayerData (core: Get(player) -> table {...}, AddCash(player, n), Save(player);
  DataStore "<Game>V1"), PlotService (plots: GetPlot(player) -> Model, GetOwner(plot)), ...
Runtime models: Workspace.Plots.Plot1..N (attributes OwnerUserId, PlotIndex, Color; children ...). Prompts: ...

## Report back (<= 15 lines)
Files changed, apply path, test result (N checks), what the owner can edit in Studio (paths + attributes), open issues,
where you sit in the chain, anything the integrator must do (NOTES.md beside your apply.luau).
