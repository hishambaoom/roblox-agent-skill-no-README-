# Marketing and launch (icon, thumbnails, badges, promotion)

What a solo dev with no budget learned launching a Halloween game in October 2026. Discovery facts come from Roblox's
own docs (linked); everything marked *anecdotal* is community folklore.

## How discovery works (official, mid-2026)
- Recommendations rank on players who arrived **organically from Home**. Ads, links and social traffic only get a game
  into the candidate pool. https://create.roblox.com/docs/discovery
- Top signals, per user: **play-through rate** (plays / Home impressions: icon, thumbnail, title), **first-play bounce**
  (< 60 s and 61-180 s), **play days** (D1, D2-7, D8-28), playtime (capped 60 min/day); then co-play with friends and spend
  days. The first minute decides more than any feature.
- Games whose metadata and place files closely resemble existing games are de-prioritized: if you start from a template,
  make the icon, thumbnails, description and visible content your own before launch.
- New experiences may be limited to age-checked 16+ players until eligibility requirements are met
  (https://create.roblox.com/docs/production/publishing/kids-and-select). Check the current rules before planning a launch.
- Each update can trigger a fresh test wave of players: ship visible updates every few days and refresh thumbnails with them.

## Icon and thumbnails
Rules distilled from six top-performing thumbnails the owner picked:
1. No headline text. Only in-world numbers (`99%`, `1.6M`); the title carries the hook.
2. Glossy 3D Roblox look (blocky shapes, soft light), not 2D comic art with thick outlines.
3. A classic default-avatar hero, grinning or determined.
4. One hero + one HUGE thing (scale contrast), max 2-3 subjects.
5. Bright, saturated, high contrast; blue/teal against orange stands out on Roblox's dark UI. All-dark-purple blends in.
6. Diagonal motion, mid-action.
7. Show the core loop literally (steal the candy, run from the boss).
Workflow: generate 3-5 candidates (1920x1080 thumbs, 1024 icon, export 512), run a **CTR sim** (below), upload the best
3-5 and turn on **thumbnail personalization**; don't restart that test within 7 days. Keep key art away from the bottom
edge (player-count overlay). Generators and examples: `assets/thumbnails/`, `assets/icons/`, `assets/ctr_sim/`.

## CTR sim (cheap pre-test before real impressions)
Compose candidates into a mock dark "Home feed" grid next to competitor-style tiles (`assets/ctr_sim/feed_sheet.py`),
then ask 5 different player personas (8-year-old on phone, teen sim grinder, horror fan, friend-group player, parent) which
tile they'd tap and why, plus a judge pass. In the reference run the clean "sneak, 99% meter" scene won and a busy
text-heavy chase lost. It is a sanity check, not data: the real number is PTR in Creator Dashboard analytics.

## Badges
- Badges are created in Creator Hub (free up to a daily limit); Open Cloud place keys can't create them. Ask the owner for
  the IDs and **bake them into the build** (a `GameSettings.Badges` Configuration). Pasting IDs in Studio is overwritten by
  the next pipeline publish.
- Badge icons are shown in a **circle**: design full-bleed circular art (512x512) with nothing important in the corners.
  New icons can sit in moderation for a while.
- Good early set: Welcome, First <core action>, Survived <boss>, First Rebirth, Found a Mythic; one limited-time event badge.

## Promotion: what failed and what to do instead
- **Fresh accounts posting the same link fast get filtered, locked, then banned.** A new Reddit account (1 karma) posting
  in 3 subs within ~20 min was silently filtered everywhere, locked, then banned. A new Discord account joining many
  servers hit the join throttle and a re-verification gate.
- Rules that would have worked: post **one at a time**, from an **aged account with history**, read each community's rules
  first (many dev subs ban direct ads; dev forums need a trust level), devlog tone with a GIF, never repeat the same text.
- Self-promo channels are walls of other devs' ads: ~0 replies. ~9 placements produced +1 visit.
- The levers with real upside are free: short gameplay clips (10-25 s, hook in the first 2 s, 1/day), a launch session with
  4-6 friends in one server, a Roblox group with update shouts, Experience Events for scheduled admin events, the friend
  referral system.
- Privacy: game embeds show the creator name. If the owner wants anonymity, move the game to a group before promoting.
- Never spend (ads, boosts, Robux) without the owner's explicit go; the reference owner set "free only".

## Launch-week plan (template)
1. Uniqueness pass (icon, thumbs, description) + check the dashboard for a reduced-exposure notice.
2. First-60-seconds pass: first reward within ~30 s, no wall of UI on join; funnel events
   (`AnalyticsService:LogOnboardingFunnelStepEvent`) for each step.
3. Reasons to return: daily reward, offline earnings shown on join, timed events, a limited quest chain.
4. Stockpile clips, schedule admin events (weekend peak), update log in-game.
5. Read D1, session length, bounce, PTR; fix the worst drop-off; update; repeat.
