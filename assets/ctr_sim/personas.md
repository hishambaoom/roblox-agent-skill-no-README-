# CTR sim personas (step 2)

Show the feed sheet (`feed_sheet.py`) to a vision model once per persona, in separate chats so answers don't leak.
Prompt: *"You are <persona>. You are scrolling Roblox Home on <device>. Which ONE tile do you tap first, which do you
skip, and why? Answer in 3 lines, as that person."* Then a judge prompt with all five answers: *"Rank the tiles by likely
play-through rate for this game's real audience and name the one change that would lift the weakest candidate."*

| Persona | Device | Cares about |
|---|---|---|
| 9-year-old, plays with siblings | phone | big funny character, bright colours, "I get to do that" |
| 13-year-old simulator grinder | PC | numbers going up, rare loot, upgrades |
| 15-year-old horror fan | PC | tension, a scary boss, being chased |
| Friend-group player | phone | something to do together, chaos |
| Parent glancing over a shoulder | tablet | looks safe, clear what the game is |

Reference run (Oct 2026, 8 tiles = 3 new candidates + 5 older ones): the clean "sneaking past the sleeping boss, 99% meter"
tile won; text-heavy and crowded tiles lost; an old "HE'S AWAKE!" chase scene still did well with player personas.
`feed_sheet_example.jpg` is that sheet.
