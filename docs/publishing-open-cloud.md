# Publishing with Open Cloud

## Place publishing
```
POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published
Headers: x-api-key: $ROBLOX_API_KEY
         Content-Type: application/octet-stream   (.rbxl)   |  application/xml (.rbxlx)
Body:    the place file bytes
200 →    {"versionNumber": 145}
```
- `versionType=Saved` uploads a version without making it live (safe staging).
- Script: `tools/rig/publish.sh <place>` (copies to the canonical build path, retries **409** up to 3× with 5/10/15 s
  backoff, prints `versionNumber`).
- 409 = another publish/save is in progress (often a parallel agent or Studio) → wait and retry, never spam.
- "server busy" / 409 also happens while the place is open in Studio (especially with Collaborative Editing on): retry,
  then ask the owner to close it.
- "Scope not authorized" = the key lacks `universe-places` **Write** for that experience (add `universe` Write too if
  you set titles/descriptions). Editing a key's permissions keeps the same key — no need to resend it.
- 401/403 = key wrong/expired/missing scope `universe-places:write` / IP restriction. 404 = universe/place mismatch.
- Docs: https://create.roblox.com/docs/cloud/guides/usage-place-publishing

## API key hygiene
- Create in Creator Hub → Open Cloud → API Keys. Scope: `universe-places:write` restricted to this universe (plus
  game-pass/developer-product write if you change prices). Optionally restrict IPs, set an expiry.
- Keep it in the environment (`export ROBLOX_API_KEY=…`, a local `.env` that is git-ignored, or your agent's secret
  store). Never in code, hooks, logs, commits, chat or screenshots. If leaked: revoke in Creator Hub immediately.
- Docs: https://create.roblox.com/docs/cloud/auth/api-keys

## Prices (game passes / developer products)
```
PATCH https://apis.roblox.com/game-passes/v1/universes/{universeId}/game-passes/{gamePassId}
PATCH https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products/{productId}
Content-Type: multipart/form-data   fields: price=<int>, isForSale=<bool>   (also name, description, imageFile …)
```
`tools/rig/prices.sh pass 123 199`. **Only with the owner's explicit number.** Report old → new and remind that the
in-game label must match (labels come from the live price or from config — check which).
References: https://create.roblox.com/docs/cloud/reference/features/game-passes ·
https://create.roblox.com/docs/cloud/reference/features/developer-products

## Things a key can't do
Create a new experience, create badges (refused for us), download the live place. Ask the owner to do it in Creator
Hub, send IDs, and bake the IDs into the build (Studio-pasted IDs get overwritten by your next publish).

## When to publish
| Situation | Publish? |
|---|---|
| Standing rule "fast-lane fixes ship after tests pass" | yes, then report |
| Owner said "show me first" / HOLD in QUEUE | no — `NOPUBLISH=1`, send shots |
| Gameplay change, tests green, not playtested | per standing rule; label NOT playtested |
| Any test newly failing | never |
| Your build is based on an old BASE | rebase first |

## After publishing
1. QUEUE line: `- DONE <time>: LIVE = <file> = <base> + <patch/hook>. BASE next: <file>.` (+ versionNumber)
2. `tools/rig/retention.sh` (newest + 3 older builds; never deletes LIVE).
3. Report with version number. Live servers keep the old version until they restart: say "new servers get it now;
   use *Restart servers* in Creator Hub if you want everyone on it" when it matters.
