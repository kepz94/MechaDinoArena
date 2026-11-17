# Victory Titles v1.0 — plan

Kepu 2026-11-16: "I rather have what cod does at the end of b/r games where people get assigned roles based on their
performance" → mockup docs/mockups/victory_titles_v0.1.html (8 titles, real dino models, hand-keyed animations) → 19:00
"Oh my gosh these are so good. Let's implement them".

## What it is
After the VICTORY / DEFEAT banner, instead of the MVP / SVP cards, everyone in the match watches the winning team's show:
each winning player (up to 4, best score first) gets one title and plays its animation (about 5.5 s each) on a showcase
stage, with a lower-third card (name, dino, title, caption, stat). Then the scoreboard as today.

Titles (handed out in this order; each goes to the best teammate who earns it and has no title yet; anyone left gets the
title they came closest to):

| # | Title | Earned by | Counted |
|---|---|---|---|
| 1 | APEX PREDATOR | most kills on the team, at least 3 | today (k) |
| 2 | KING OF THE HILL | most time on the point, at least 30 s | today (pt) |
| 3 | UNKILLABLE | 0 deaths and (1+ kill or 30+ s on the point) | today (d) |
| 4 | MEDIC | most HP healed on teammates, at least 100 | new (heal) |
| 5 | BUTTON MASHER | most abilities used, at least 20 | new (ab) |
| 6 | EXTINCT | most deaths on the team, at least 4 | today (d) |
| 7 | CARRIED | lowest score on the team, under half of the best teammate's | today (MatchAwards score) |
| 8 | PACIFIST | 0 kills | today (k) |

A draw has no winning team: no show, the MVP / SVP cards as today.

## Tasks
1. **VictoryTitles 1.0** (pure module, ServerStorage.DinoArcade, src/shared/VictoryTitles.luau) + spec test: assign(rows,
   winner, cfg) -> ordered list {id, title, stat}. Thresholds = attributes passed in cfg. Logic test.
2. **HardpointServer 1.9**: "stat" takes fields "heal" / "ab" and an amount; board rows carry heal / ab; at results:
   titles -> HpTitles JSON, display models of each title holder -> ReplicatedStorage.VictoryTitleModels (clone of the
   live character / bot, else the bare dino from its ModelData), results length = RESULTS + extra for the show
   (HpResultsLen). Switch HardpointTitlesEnabled.
3. **VictoryTitlesServer 1.0** (new): ServerStorage BindableEvent VictoryHealReport (healer model, HP) -> "stat" heal (not
   self-heals); ability start stamps on every player character and bot (the GameSounds 1.7 list) -> "stat" ab.
4. **TrooMovesServer / MedStationServer**: one added report line each where HP is added to a teammate (switch on each).
5. **VictoryTitlesAnim 1.0** (client module: the mockup's engine + 8 titles ported to Motor6D.Transform) and
   **VictoryTitles 1.0** (LocalScript): stage in the sky, local clones of VictoryTitleModels, scripted camera, lower third,
   flash / plaster / counter overlay, PC + phone. Test hook: player attribute VictoryTitlesTest = "<title>,<species>".
6. **HardpointHUD 1.14**: results length from HpResultsLen; while HpTitles has entries, the spot beat is the show
   (dim / cards hidden, tap skips one title).
7. Studio install, Play test every title on 3+ dinos, docs (VERSIONS, ATTRIBUTES), commit. Publish only on "Publish".

## Do not touch
Hardpoint scoring / rotation, MatchAwards XP, ArenaRecord saving, the board beat, KillFeed.

## Red-team (accepted)
- A winning player who left: no model -> their title is skipped (show gets shorter).
- Squash / stretch from the mockup can't be done on a Roblox model (no non-uniform scale): replaced by body bobs; the
  Carried shrink uses Model:ScaleTo.
- Longer results screen (4 titles ≈ +16 s): HardpointTitleSec attribute; tap skips a title.
