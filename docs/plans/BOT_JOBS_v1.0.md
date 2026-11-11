# Mecha Dino Arena — practice bots: jobs by dino + team brain, no T-Rex bots (v1.0)

**Goal:** practice bots play like a team with different playstyles: tough dinos hold the point, fast melee dinos find 1v1s,
ranged dinos guard the point's edge, and the team moves dinos between jobs when it needs to. No bot is ever a T-Rex.
**Kepu 2026-11-11 13:21:** "stop having the t-Rex be selected. Also let's rework the bots playstyle ... simplifying bots to
certain actions ... For example the pachy play objective while other Dino's look for 1v1 matchups"; 13:25 picks "C" (each dino
has a preferred job, the team brain changes it when the team needs it) and "1" (practice bots never pick the T-Rex).
Research: docs/research/BOT_PLAYSTYLE_v0.1.md (Killzone 2 commander -> squad -> bot; Dota 2 desires; TF2 class jobs; attack
slots so bots don't gang up; fair beats smart). No UI change, so no mockup; the 3 shapes (A by dino / B by need / C both) were
the options.

## What's live (v671) and why it plays badly
- PracticeRules 1.0 `assignRoles`: cap, cap, def, hunt, esc, shuffled at match start (not by dino); a bot that refills a slot
  gets "cap". Roles only change `goalFor` (where to walk when no enemy is seen).
- PracticeBrain 1.0 `step`: every bot fights the best visible enemy (scoreTarget = dist − 60 on point + 30 x hp; sight Easy 70
  / Normal 90 / Hard 110, cone 120°), so all bots chase the nearest enemy and several pile onto one.
- PracticeRules.SPECIES has all 8 dinos; rollBot picks one at random, so about 1 in 8 bots is a T-Rex.
- Attack reach (PracticeBrain ATTACK): Troodon 55, Dilo 40, Pachy 30, Raptor 18, Herrera 10, Therizino 6, Teno 5, T-Rex 5.

## Global constraints
- Additive; every number a rules constant or attribute; every change behind a switch; versions + VERSIONS / ATTRIBUTES.
- Practice match only (Sandbox). The Arena, BotServer bots and free roam are not touched.
- Do-not-touch: HardpointServer / HardpointRules (spawns, scoring), PracticeBots (bodies, collisions), every attack server and
  BotUse, the lost-bot rule, the lobby, the 1.0 roles (kept for the switch-off path), sight / reaction / aim error rules.

## Rules
**Preferred job by dino** (PracticeRules JOB_OF)
| Job | Dinos | What it does |
|---|---|---|
| hold | Pachy, Teno | Goes onto the current point and stays. Fights an enemy only if that enemy is within HOLD_FIGHT 60 studs of the point centre, or within SELF_DEFENSE 20 studs of itself. Keeps the 1.0 "hold below" for points it can't climb. |
| duel | Raptor, Herrera, Therizino (and T-Rex if one is ever forced) | Picks a visible enemy that no teammate is already dueling (one duelist per enemy). No free enemy in sight -> walks the flank spot (the 1.0 "hunt" spot: 120 behind the point from its team's side, 80 to the side) to find one. Doesn't chase further than DUEL_LEASH 250 from the point. |
| guard | Dilo, Troodon | Stands GUARD_RING 45 studs from the point centre on its team's side. Fights visible enemies within GUARD_ZONE 110 of the point; never walks further than GUARD_LEASH 90 from the point. |
| run | (given by the team brain only) | In the last 10 s of a point, heads to the next point (the 1.0 "esc" rule). Fights only within SELF_DEFENSE 20. |

**Team brain** (each team, every TEAM_EVERY 1 s; also when a bot respawns)
- Every bot starts on its dino's job.
- Holders wanted: 2 when the point isn't yours (HpOcc not your team), 1 when you hold it. A human of your team standing on the
  point counts as one holder. Too few living holders -> the living non-holder nearest the point becomes "hold" (why "fill:
  point"), guards before duelists. A filled holder goes back to its own job when it's no longer needed, but not sooner than
  FILL_MIN 5 s after it was filled (no flip-flopping).
- Runner: in the last NEXT_SHOWN 10 s of a point, the living duelist (else guard) nearest the next point becomes "run" (why
  "run: next"); at rotation everyone goes back to their own job (then the holder rule above).
- No ganging up: at most MAX_ON_ONE 2 bots of a team take the same enemy as their target. A bot whose best target is full
  takes the next one; none left -> it does its job's walk. Holders ignore the cap for an enemy that is on the point.
- Retreat (1.0 shouldRetreat) and the attack itself (wantsAttack, aimError, abilities) stay as they are.

**No T-Rex bots**
- PracticeServer picks each bot's dino from PracticeRules.BOT_SPECIES (the 7 dinos without the T-Rex) and passes it to rollBot;
  rollBot itself is unchanged. Switch script attribute PrBotNoTRex (default true; false = 1.2: any of the 8).

**Switch:** PracticeServer attribute PrJobsEnabled (default true, read per tick; false = 1.2 roles + 1.0 brain).
**Diagnostics:** per bot BotJob ("hold" / "duel" / "guard" / "run"), BotJobWhy ("dino" / "fill: point" / "run: next");
PracticeServer PrJobsA / PrJobsB ("hold 2 duel 2 guard 1"), PrMaxOnOne (largest number of one team's bots on one enemy in the
last tick).

## Deterministic map
| State | Trigger | End state |
|---|---|---|
| off | PrJobsEnabled false | 1.2 roles + 1.0 brain, unchanged |
| dino job | bot spawned / point rotated / fill released | job = JOB_OF[species], why "dino" |
| fill: point | living holders + your humans on the point < wanted (2 not held / 1 held) | nearest non-holder (guard first) -> hold, filledAt = now |
| fill released | holders enough again and now − filledAt >= 5 s | back to its dino job |
| run: next | into >= POINT_TIME − 10 and no runner yet | nearest duelist (else guard) to the next point -> run |
| rotation | HpIndex changed | runners back to dino jobs; holder rule re-runs |
| target full | 2 teammates already target that enemy (not an on-point enemy for a holder) | next best target, else job walk |
| out of leash | target beyond the job's leash (hold 60 from the point / guard 110 zone / duel 250) | drop target, job walk |
| dead / respawn | bot dies / respawns | job re-dealt at respawn by the rules above |

## Tasks
### Task 1 — PracticeRules 1.1 + spec · Logic (MDA-429)
Add (keep 1.0 API): BOT_SPECIES (7, no TRex), JOB_OF, HOLD_FIGHT 60, SELF_DEFENSE 20, DUEL_LEASH 250, GUARD_RING 45,
GUARD_ZONE 110, GUARD_LEASH 90, TEAM_EVERY 1, FILL_MIN 5, MAX_ON_ONE 2, HOLD_WANT_OPEN 2, HOLD_WANT_HELD 1, RUN_WINDOW 10;
`jobOf(species) -> job`; `dealJobs(bots, ctx) -> {[id] = {job, why, filledAt?}}` with bots = {{id, species, alive, dPoint,
dNext, job, why, filledAt}}, ctx = {held, humansOnPoint, into, pointTime, now, rotated}; `canTarget(job, info) -> bool` with
info = {dist, dPoint, onPoint, takenBy, isMine}; `jobGoal(job, centre, nextCentre, home) -> Vector3`.
Spec tools/tests/PracticeJobs.spec.luau: every map row; 1.0 spec still passes.

### Task 2 — PracticeServer 1.3 · Wired (MDA-430)
No T-Rex (PrBotNoTRex) in rollPool and botForSlot; team brain every 1 s and at spawn (PrJobsEnabled); ctx gets jobs, held,
taken counts; diagnostics PrJobsA / PrJobsB / PrMaxOnOne.

### Task 3 — PracticeBrain 1.1 · Wired (MDA-431)
With jobs on: targets filtered by canTarget (leash + MAX_ON_ONE via ctx taken counts), goal from jobGoal (hold keeps hold
below); BotJob / BotJobWhy. Also the known error at 1.0 line 267 (b.model nil after despawn inside startAttack's task) gets a
nil guard.

### Task 4 — QA + docs · Wired (MDA-432)
Practice 5v5 Normal, 2 matches: "new bots" 3 times -> no T-Rex; holders reach the point (time logged); PrMaxOnOne never above
2 (10 Hz sample for 60 s); duelists' targets differ; a team with no Pachy / Teno fills 2 holders; runner moves in the last 10
s; score and server ms per tick logged. Docs + Dev Hub.

## Red-team (2026-11-11)
1. **A team with no Pachy or Teno.** 7 dinos, 5 bots: about 1 in 7 teams rolls no holder. Covered by the fill rule (guards
   first). QA forces one such team.
2. **Duelists may wander off alone and feed.** Mitigation: the duel leash (250 from the point) and the flank walk keep them near
   the fight; retreat still works.
3. **Holders on the Summit.** Holders spend the most time climbing; the 1.0 hold-below stays, so a holder that can't climb
   waits below instead of running into the rock.
4. **The human is not a bot.** The team brain can't give you a job; you count as a holder only while you stand on the point.
5. **"Feels the same" risk.** Jobs only change who goes where and whom they pick; fight skill is the same. If bots still feel
   samey, the next lever is per-job difficulty (later, not in this plan).

## Status (2026-11-11)
Plan + tickets filed; waiting for "Build".
