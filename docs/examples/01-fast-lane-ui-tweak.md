# Example 1 — Fast-lane UI tweak (screenshot → live in minutes)

Based on the reference game's side-card and gift-card tweaks. Command output below is the format the rig prints
(real runs of the shipped tools; timings from the reference machine).

## Owner
> [screenshot] the gift icon on the right is way bigger than the other cards, make it same

## Agent — orient (silent, < 1 min)
```
$ tail -n 3 QUEUE.md
- DONE 19:08 Oct 9: LIVE = work/v75.rbxl = v74 + v75a + v75b (gift card = RightSide.PlaytimeGift clone of SleepOffer …). BASE next: work/v75.rbxl.
$ grep -n "PlaytimeGift\|SleepOffer.Icon" ui-map.md
  - `RightSide.PlaytimeGift.GiftIcon` [ImageLabel] … size 0,56,0,56
  - `RightSide.SleepOffer.Icon` [ImageLabel] … size 0,40,0,40
$ grep -ln "PlaytimeGift" games/*/build_*.luau
games/pumpkin-king/build_v75b_gift.luau
```
Plan (internal): *GiftIcon 56 → 40 px in build_v75b_gift.luau. Nothing else. Fast lane, auto-publish rule applies.*

## Agent — change
```lua
-- build_v75b_gift.luau
icon.Size = UDim2.fromOffset(40, 40) -- was 56; match SleepOffer.Icon (owner, 20:00 Oct 9)
ctx.note("v76 gift: PlaytimeGift.GiftIcon 56 -> 40 px")
```

## Agent — build, shots, tests, publish (one command)
```
$ tools/rig/go.sh v76
fast PASS: 3 pass / 0 fail | studio_rule_test:ok text_size_test:ok gift_card_test:ok  (2.6 s, logs work/rig/out/fast)
shots: work/rig/out/v76_pc.png work/rig/out/v76_phone.png   <- LOOK at both before reporting
published (Published) versionNumber=125
total 13 s
```
Looks at both PNGs: icon now matches Lullaby/Flying Broom cards on PC and phone; nothing overlaps the jump button.

## Agent — log
```
- DONE 20:00 Oct 9: LIVE = work/v76.rbxl (version 125) = v75 + build_v75b (RightSide.PlaytimeGift.GiftIcon 56→40 px). BASE next: work/v76.rbxl.
```

## Agent → owner
> Version 125 is live, so rejoin now. The gift icon is 40 px, same as the other cards.
> [v76_pc.png] [v76_phone.png]
> Rig shots only, not checked on a real phone. Edit in Studio: MainUI.RightSide.PlaytimeGift.GiftIcon (Size).

## Why this is right
- One file, one value, no design change, shots first, version number from the API, 4-line report.
- Wrong versions of this session: writing a new screenshot script; "while I was there" restyling the card; saying
  "verified on phone"; replying with the build log.

(Version numbers in this example are illustrative; always use the `versionNumber` your publish returns.)
