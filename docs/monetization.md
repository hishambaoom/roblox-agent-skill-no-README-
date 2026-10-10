# Monetization

## Products
| Kind | Use | Owned how |
|---|---|---|
| Game pass | permanent perk (2x Cash, VIP, bigger bag) | `MarketplaceService:UserOwnsGamePassAsync` + `PromptGamePassPurchaseFinished` |
| Developer product | consumable (cash pack, skip timer, paid steal, +1 slot) | `ProcessReceipt` |

Config: one table (e.g. `Config.GameConfig.Monetization`) with `Id`, `SuggestedPrice`, handler key. Product art and
cards come from Studio templates; prices shown in UI come from the live product info or config — keep them in sync
(a "9 R$ shown, 99 R$ charged" mismatch was a real bug).

## ProcessReceipt rules (non-negotiable)
```lua
MarketplaceService.ProcessReceipt = function(info)
    local profile = Profiles[info.PlayerId]
    if not profile or not profile:IsActive() then return Enum.ProductPurchaseDecision.NotYetGranted end
    local done = profile.Data.ProcessedPurchases
    if done[info.PurchaseId] then return Enum.ProductPurchaseDecision.PurchaseGranted end   -- dedupe
    if inFlight[info.PurchaseId] then return Enum.ProductPurchaseDecision.NotYetGranted end
    inFlight[info.PurchaseId] = true
    local ok, err = pcall(Handlers[info.ProductId], info, profile)
    inFlight[info.PurchaseId] = nil
    if not ok then warn("receipt", info.ProductId, err); return Enum.ProductPurchaseDecision.NotYetGranted end
    done[info.PurchaseId] = os.time(); trimOld(done)
    return Enum.ProductPurchaseDecision.PurchaseGranted
end
```
- Grant only after the data is written; NotYetGranted when the profile isn't loaded.
- A receipt that lands during a cooldown is **still granted** (never eat a purchase); then restart the cooldown.
- Purchase-in-progress locks expire (`StealPurchaseStaleSeconds`) so a closed prompt can't block a player forever.
- Snapshots of what a pending purchase will grant expire (`PendingStealMaxAgeSeconds`) — prevents leave/rejoin dupes.

## Prices
- Prices are the owner's decision. Propose a table, wait for "yes", then set them via Open Cloud
  (`tools/rig/prices.sh`) and report old → new. Sale badges (`-50%`) and old-price strikes are UI only; the charged
  price is the product price.
- Creating products/passes in bulk needs the owner's list approval first (real flow: proposed 16 at given prices → owner
  yes → created with icons → IDs baked into config).

## Things to check before launch
All product IDs non-zero, belong to this universe, `IsForSale`, every ID has a handler, receipt dedupe saved in the
profile, prompts only from client → server validated, no Robux-for-advantage that breaks the owner's intended risk.
Badges: create in Creator Dashboard (an API key couldn't), bake IDs, award with retry ×3 then give up quietly.

Docs: https://create.roblox.com/docs/production/monetization/developer-products ·
https://create.roblox.com/docs/production/monetization/game-passes
