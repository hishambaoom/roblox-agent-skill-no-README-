# Core-loop QoL: forging, shatter, bag

From ForgeTax v22 + v23. Patterns for any "hit / risk / sell" loop. Each is Config-gated so the old behaviour is one
untick away.

## Forging
- **Hold to act**: hold the button / key / pointer on your station = repeat at `HitCooldown + HoldHitPad` after
  `HoldHitDelay`. Stop on release, at the target, at the warn level, on fail/max.
- **STOP AT +N** stepper (cloned buttons, saved as a setting): the server refuses hits at/after the target too.
- **Warn level** (`WarnLevel` 20): risk % turns red + pulses, first tap arms ("AGAIN!"), second tap within
  `DoubleTapWindow` confirms. Server refuses an unconfirmed risky hit once per item; a confirm tap never starts a hold.
- **Auto re-start** after SELL / RACK while in the mode (`AutoResmelt`), never during the tutorial; if nothing can
  start, behave as before.
- **Stay in the mode on failure**: `ExitOnShatter=false` keeps the player at the station after a shatter; after
  `ShatterResmeltDelay` (1 s, so the shatter FX plays on an empty anvil) auto re-smelt; if impossible, stay with an
  empty station instead of leaving. `true` = old exit behaviour exactly. Keep EXIT key, distance/death watchdog.

## Bag / storage
- **Padlock** per item (saved): locked items refused by every bulk/quick sell path, kept when moved to racks.
- **RACK BEST** (server: best N by value onto racks, weakest back to bag, locks kept), **SELL < RARITY** with a
  second-press confirm (`SellBelowConfirmSeconds` 3, label "SURE? $X"), **SORT** (Value / Rarity / Newest), saved.

## Phone + settings
- Settings rows as saved clones of an existing row ("Others' hits", "Anvil clinks", "Cam shake"); rows in a
  ScrollingFrame when they no longer fit.
- Tap targets >= 58 px tall, even gaps; tutorial pill hides while any centred window is open on phone.

## Checklist
- [ ] every feature behind a Config flag  - [ ] server enforces what the client UI promises
- [ ] tutorial excluded  - [ ] test reproduces the old behaviour on the base (fails) and the new one (passes)
