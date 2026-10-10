# Security

## Server authority
The client asks, the server decides. Cash, loot, prices, cooldowns, carry speed, steal rules, rebirth costs: computed
and checked on the server. Client values are display only.

## Every remote
```lua
local last = {}
Remotes.Sell.OnServerInvoke = function(player, slotIndex)
    local now = os.clock()
    if (last[player] or 0) + (GS:GetAttribute("SellMinSeconds") or 0.2) > now then return false, "slow down" end
    last[player] = now
    if typeof(slotIndex) ~= "number" or slotIndex ~= slotIndex or slotIndex % 1 ~= 0 then return false end  -- type, NaN, int
    if slotIndex < 1 or slotIndex > MAX_SLOTS then return false end                                          -- range
    -- ownership: does this player own this slot/item? server-side cost check, then act
end
Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
```
Checklist per remote: type + NaN + range checks, ownership, server-side cost, per-player rate limit (attribute-tunable),
idempotent where retried, cleanup on leave. Read-only remotes still get a throttle (cached snapshot). Admin remotes:
one gate (`IsAdmin` = configured user IDs + owner), rate-limited, Studio-only debug flags off in live.

## Movement / exploit guards
Speed budgets for carrying (teleport/fly → loot returned), no flight gear while carrying stolen loot, server checks
distance for prompts. Note: a teleport-based test can trip your own speed check — write tests that walk.

## Data (never lose progress)
- ProfileStore (session-locked) or a careful DataStore wrapper. All calls in `pcall` with retry; kick on load failure
  rather than play on default data; `BindToClose` saves every profile (wait ≤ 25 s).
- `DATA_VERSION` + `Migrate → Reconcile → Sanitize` on load; clamp numbers; drop unknown keys; grandfather old saves
  when rules change (e.g. keep wings already unlocked).
- Every saved-field change gets a test with an old save fixture.
- Dupe classes to test: victim leaves mid-steal, leave with purchase prompt open then rejoin, two fast grabs beating a
  cap check (use an atomic cap), receipt replay.

## Imported code and models
- Never use free models/templates with backdoors. Before importing anything: grep every script for
  `require(%d+)`, `require(<number>)`, `loadstring`, `getfenv`, `setfenv`, `HttpService` to unknown hosts,
  `MarketplaceService:PromptPurchase` of unknown IDs, obfuscated strings, `_G` writes, and scripts named oddly or
  starting with `_!` (tracer/watermark). Remove them in the build's cleanup step and log each removal.
- Remove template-author Animation IDs and sample leaderboards with other people's names; use Roblox default animations.
- Strip unused remotes (fewer attack surfaces).

## Secrets
API keys only in environment / secret stores. Never in place files (scripts are readable by exploiters if replicated),
never in repo, logs, commits, screenshots or chat. Rotate on any leak.

Reference: https://create.roblox.com/docs/scripting/security/security-tactics
