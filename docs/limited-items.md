# Limited items (limited hammers pattern)

From ForgeTax lham17 / shop17 / v24 / v25. Special items sold for big cash **or** Robux, kept through rebirth.

## Config (ReplicatedStorage Config module, data only)
```lua
Config.LimitedHammers = {
  { Id = "Pumpkin", Price = 50e6, RobuxPrice = 99, ProductId = 0, ShatterMult = 0.62,
    IncomeBonus = 0.15, DoubleChance = 0, Pedestal = 3, Featured = false },
  ...
}
Config.LimitedShatterBestOf = true  -- equipped limited uses min(limited, shop item): a paid item never gets worse
```
Helpers in Config: `GetLimited`, `EquippedLimitedOf`, `EffectiveShatterMult`, `LimitedIncomeBonus`, `LimitedDoubleChance`.

## Server
- Service API: `Grant / Revoke / Owns / Equip(id|nil) / List / Sync`. Profile saves `{[Id]=true}` + `Equipped`
  (unknown ids kept, equip only if owned). Rebirth and resets don't touch them.
- Player attrs for UI: `LimitedOwned "A,B"`, `EquippedLimited`, `LimitedIncomeBonus`.
- Equip remote: string <= 32, must be owned, rate limit, toast.
- Perks hook into the existing formulas (shatter, double hit capped below max level, rack income); sell price unchanged.
- **Receipts**: one ProcessReceipt router for the whole game (`monetization.md`); grant then return
  PurchaseGranted; idempotent by PurchaseId. Create products via Open Cloud and fill `ProductId` in Config.

## Shop presentation
- Pedestals = display copies + cloned ShopPrompt, face shows "$50M | R$99". One `Featured` item on a bigger stand.
- Empty pedestals show **COMING SOON** (saved sign), so new limiteds slot in without layout work.
- Admin: grant/revoke row for testing; Index/Bag cards cloned from existing ones.

## Checklist
- [ ] perks simulated (`economy-simulation.md`)  - [ ] best-of rule decided with the owner
- [ ] cash and Robux paths tested  - [ ] owned items survive rebirth + rejoin  - [ ] real purchase listed as unverified
