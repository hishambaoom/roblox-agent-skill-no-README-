#!/bin/bash
# Shared settings for the rig scripts. Source it; override any value from the environment.
# Run every rig script from your game repo root (the folder that holds tools/ and games/).
#
#   export ROBLOX_API_KEY=...   # Open Cloud key with universe-places:write (NEVER commit it)
#   export UNIVERSE_ID=<your-universe-id> PLACE_ID=<your-place-id>
#
: "${GAME_DIR:=games/my-game}"                 # the game folder: build.luau, build_*.luau hooks, src/, tests/
: "${LUNE:=tools/lune}"                        # Lune binary used for builds + tests (0.8.9 in the reference project)
: "${LUNE_NEW:=tools/lune10}"                  # newer Lune (0.10.x) for place files saved by a recent Studio
: "${TESTS:=$GAME_DIR/tests}"                  # Lune test folder
: "${XDIR:=work/x}"                            # scratch builds: work/x/<name>.rbxl
: "${RIG_OUT:=work/rig/out}"                   # screenshots + fast-test logs
: "${CANON:=$GAME_DIR/build/game.rbxl}"        # canonical "what is live" copy written by publish.sh
: "${FAST_TESTS:=studio_rule_test text_size_test}"  # always-run guard tests (STRICT)
: "${PHONE_W:=667}" ; : "${PHONE_H:=375}"      # iPhone SE/8 landscape: the smallest common phone; if it fits here it fits everywhere
: "${PC_W:=1920}"   ; : "${PC_H:=1080}"
export GAME_DIR LUNE LUNE_NEW TESTS XDIR RIG_OUT CANON FAST_TESTS PHONE_W PHONE_H PC_W PC_H
