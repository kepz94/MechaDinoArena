# Mecha Dino Arena v1.0 — Quest Stand (roadmap piece 4)

**Goal:** a quest stall on the island plaza with 3 daily quests (paying skill points) and special quests (paying skins), claimed only at the stall.

**Kepu 2026-11-26:**
- 03:55: "lets have a quest stand where 3 daily quests are placed as well as special quests. this is the only place where you can claim them ... 25 kills streak unlocks the thunder storm skin. 10 kill streak unlocks the zebra. these will also be in the daily quest thingy for this week"
- 03:56: "the daily quest rewards will be skill points for the basic daily quest"

**Picks (06:2x):**
- Streak skins: "Claim at the stand".
- Daily pool: "Island fighting, Arena, Mecha parts, Dinos".
- Pay: "1 / 2 / 3 by difficulty".
- Specials: "A fixed rotating list".
- Layout: "A · Board" (mockup `docs/mockups/quest_stand_v0.1.html`, artifact "Quest Stand").
- Spot: "Mirror of the shop".
- Zebra / Storm Front after this week: "Always claimable".
- Unclaimed daily at the reset: "Lost at reset".

**Architecture:** new scripts that copy the shop stand pattern (ShopStandServer 1.1 / ShopStandClient 1.1 / ShopScreen 1.3), plus a quest server with its own DataStore.
- Rewards go through existing grants: SkillServer 1.15 `SkillGrantPoints` for dailies and specials that pay points, and a new SkinServer `SkinGrant` for skins.
- Zebra / Storm Front stop unlocking on their own; they become permanent stand specials.

## Grounding (repo = Studio, v1022)
- **Stall.** ShopStandServer 1.1 builds `Workspace.ShopStand` on hub servers, at plaza centre + angle 160° / radius 85, facing the centre. Model attributes ShopStandFront / ShopStandRange.
- **Prompt and screen.** ShopStandClient 1.1 makes the OPEN SHOP prompt (E / X / TAP), sets player ShopStandNear, and anchors the dino while the shop is open. ShopScreen opens with `Open:Invoke("stand")`.
- **Kills.** KillCredit BindableEvents on KillFeedServer (players, practice / persona bots) and KillRegenServer (IsBot) fire (killer UserId, victim, KilledAt). SkinStats 1.1 shows the dedupe pattern.
- **Server kinds.** ReplicatedStorage ServerKind is "hub" (island), "arena" or "practice" (ModeRules.serverKind).
- **Arena results.** ArenaRecordServer writes ArenaW / ArenaL (ArenaRecordReady once loaded) on match servers.
- **Island streak.** SkinStats 1.1 publishes player IslandStreak.
- **Dino and ownership.** Character `Species` gives the dino. DinoOwnership publishes player `OwnedDinos`.
- **Mecha part uses.** Each part server stamps a cooldown on the character when the part is used (`<Part>ReadyAt` for 19 parts: Cloak, Screech, Mine, Ink, EnergyShield, Adrenaline, Scent, Med, Tether, Hook, Visor, ServoDash, Cruise, ...). The Thrusters dash counts `DashCount`. Passive parts have no use.
- **Points.** SkillServer 1.15 `SkillGrantPoints(player, n 1..100, reason)` gives bonus points that count on every dino, with no cap.
- **Skins.** UniversalSkins 1.4: Zebra = earn istreak 10, Storm Front = earn istreak 25. SkinServer 1.6 `checkEarn` grants met earn skins on its own.

## Global Constraints
- Additive; every piece behind a switch; every number an attribute.
- Versions:
  - New: QuestRules 1.0, QuestServer 1.0, QuestStandServer 1.0, QuestStandClient 1.0, QuestScreen 1.0.
  - Updated: UniversalSkins 1.5, SkinServer 1.7.
- Phone first (taps ≥ 44 px), Silkscreen headings, no em dashes in game copy.
- Studio tests: save switches off, quest store `QuestStoreName` set to a test store. Never a second player.
- Publish only on "Publish".

## Do-not-touch
ShopStandServer / ShopStandClient / ShopScreen (the quest stall copies them, it does not edit them), SkinStats, KillFeedServer, KillRegenServer, ArenaRecordServer, SkillServer, every part server.

## Quest data (QuestRules 1.0, for Kepu's OK)
**Dailies.** One easy (+1 pt), one medium (+2), one hard (+3) per player per UTC day. They are picked by hash(day, UserId) from the kinds below and stored at the first load of that day, so they don't change mid-day.

| Kind | Easy | Medium | Hard |
|---|---|---|---|
| Island kills | Get 5 kills on the island | Get 12 kills on the island | Get 25 kills on the island |
| Island streak | — | Reach a 5 kill streak on the island | Reach a 10 kill streak on the island |
| Arena play | Play 1 Arena match | Win 1 Arena match | Win 3 Arena matches |
| Arena kills | — | Get 8 Arena kills | Get 20 Arena kills |
| Mecha parts | Use mecha parts 10 times | Use mecha parts 30 times | Use mecha parts 60 times |
| Dino of the day | Get 2 kills as a <dino> | Get 5 kills as a <dino> | Get 12 kills as a <dino> |

The 3 dailies are never the same kind. The dino of the day is one of the player's OwnedDinos.

**Specials.**
- **Permanent** ("Always claimable"):
  - "Get a 10 kill streak on the island" → Zebra.
  - "Get a 25 kill streak on the island" → Storm Front.
  - Progress is the best island streak (StatIslandBest).
- **Rotating** ("A fixed rotating list", one per week, Monday 00:00 UTC; reward +5 skill points each, for Kepu's OK):
  - Win 5 Arena matches
  - Get 60 kills on the island
  - Use mecha parts 120 times
  - Reach a 15 kill streak on the island

## Tasks

### Task 1 — QuestRules 1.0 · Logic
**Files:** `src/shared/QuestRules.luau`, `tools/tests/QuestRules.spec.luau`.
**Produces:**
- `day(t)`, `week(t)` (Monday 00:00 UTC), `secsToDay(t)`, `secsToWeek(t)`.
- `pickDailies(day, userId, ownedList)` → 3 `{id, kind, diff, need, pts, dino?}`.
- `specials(week)` → the permanent ones plus the week's rotating one.
- `text(q)` (game copy).
- `counts(q, ev)`: which event kinds feed a quest.
- `claimable(q, prog, claimed)`.

**Spec:**
- Same input gives the same picks; one of each difficulty; no repeated kind.
- The dino comes from the owned list.
- Week boundaries on a Monday.
- The 4-week rotation.
- Claimable only when progress ≥ need and not claimed.

### Task 2 — QuestServer 1.0 · Wired (all server kinds)
**Store:** DataStore `QuestStoreName` ("MDA_Quests_v1"), key "u<UserId>".
- Value: `{v = 1, day, d = {picks}, dp = {[id] = n}, dc = {[id] = true}, week, wp = {[id] = n}, wc = {[id] = true}, pc = {zebra = true, storm = true}}`.
- Loaded at join.
- Progress is written as **deltas** with UpdateAsync (`n = stored + ours`; a day / week change in the store resets that part) 10 s after a change, on leave and on close. So island and Arena servers add up and never overwrite each other.

**Events** (counted only for the current day / week picks):
- **Kill:** KillCredit from both sources, deduplicated like SkinStats.
  - Kind hub: island kills.
  - Other kinds: Arena kills.
  - Either kind: dino-of-the-day kills when the killer's Species is that dino.
- **Arena play / win:** an ArenaW or ArenaL increase while ArenaRecordReady was already true (the load does not count).
- **Island streak:** IslandStreak reaching N completes "reach N".
- **Part use:** on the player's character, a number attribute ending in `ReadyAt` going up to a time in the future, or DashCount going up. Counts 1.

**Requests:** RemoteFunction `QuestRequest`.
- `("state")` → a fresh read of the store (GetAsync) merged with unsaved deltas.
- `("claim", id)`, allowed only when ServerKind == "hub" and the player is within QuestStandRange of the stall front (server check). Then:
  1. UpdateAsync that sets the claimed flag only if the progress is still complete and the quest is not claimed yet (claims once).
  2. Then the reward:
     - `SkillGrantPoints(player, pts, "quest")` for points;
     - `SkinGrant(player, skin, "quest")` for a skin.
  3. Results: "ok" / "notNear" / "notReady" / "claimed" / "busy" / "failed".
- A reward that fails after the flag is set is retried on the next state request (`pending` list in the value).

**Player attributes:**
- `QuestReady` (count claimable now; feeds the stall tag)
- `QuestDay`
- `QuestState` ("loading" / "loaded" / "new" / "off" / "failed")

**Switches:** `QuestEnabled`, `QuestSaveEnabled` (false = memory only, the Studio guard), `QuestStoreName`, `QuestRange` (24).

### Task 3 — UniversalSkins 1.5 + SkinServer 1.7 · Wired
- **UniversalSkins 1.5:**
  - Zebra and Storm Front unlocks get `claim = "stand"` (flag `US.STAND_CLAIMS`, true).
  - Their text becomes "10 kill streak on the island, claim at the Quest Stand" / "25 kill streak ...".
- **SkinServer 1.7:**
  - `checkEarn` skips skins with `unlock.claim == "stand"` (switch `SkinStandClaimsEnabled`).
  - New BindableFunction `SkinGrant(player, id, reason)` → "ok" / "owned" / "unknown" / "notLoaded" (same UpdateAsync as checkEarn; SkinUnlocked + SkinServerResult "earned").
  - Players who own the skins already keep them.

### Task 4 — QuestStandServer 1.0 · Wired
- Waits for Workspace.ShopStand, clones it as Workspace.QuestStand and places it "Mirror of the shop": the same radius, at the angle mirrored over the line from the plaza centre through the ARENA portal, turned to face the centre.
- Look:
  - Roof / valance stripes orange / yellow → blue rgb(47,143,216) / cyan rgb(127,233,255).
  - Sign text "QUESTS".
  - A notice board (dark wood, 3 pinned papers) on the back posts.
- Model attributes QuestStandFront / QuestStandRange.
- Switch `QuestStandEnabled`, numbers `QuestStandAngle` (unset = mirrored), `QuestStandRadius` (unset = the shop's).

### Task 5 — QuestStandClient 1.0 · Wired
- A copy of ShopStandClient 1.1 "prompt" mode.
- Text "OPEN QUESTS" and a red "<n> READY" tag when QuestReady > 0.
- Opens QuestScreen (`Open:Invoke("stand")`) and anchors the dino while it is open.
- Player QuestStandNear.

### Task 6 — QuestScreen 1.0 · Wired (layout A)
**Layout:** mockup A, phone and PC.
- **Header:** QUESTS, the cyan "NEW DAILIES IN <h>H <m>M" chip, "<n> READY · +<pts> PTS TODAY", X.
- **DAILY:** 3 cards in a row. Each card has difficulty pips + EASY / MEDIUM / HARD, the text, a progress bar, "n / need", and the reward "+1 PT" or a yellow CLAIM button (or CLAIMED ✓).
- **SPECIAL:** the cards in rows of 2: skin swatch or points, text, bar, "BEST n / need", reward / CLAIM.
  - The rotating special shows "ENDS IN <d>D <h>H".
  - Up to 3 specials in 2 columns; the panel scrolls on short phones.

**Toasts:** "+2 SKILL POINTS", "ZEBRA UNLOCKED".

**Behaviour:** state from QuestRequest("state") on open and every 5 s while open.

### Task 7 — Check, docs · Wired
**Studio (hub Play, test store, save switches off):**
- Join → 3 dailies.
- Bot kills → island kill progress.
- Part use (Cloak via the test layer) → mecha progress.
- Walk to the stand → prompt with READY.
- Claim a daily → SkillBonusPoints + pts.
- Claim Zebra after a 10 streak → owned.
- Claim from far away → "notNear".
- Second claim → "claimed".
- Day change (test clock offset `QuestTestDayOffset`) → new picks, old unclaimed lost.

Then phone + PC screenshots. Docs, commit, ticket.

## Red-team (to answer before build)
1. **Same dailies for everyone, or per player?** The plan picks per player (hash of day and UserId), so a "dino of the day" is always one you own. The other way is the same 3 for everyone (simpler, people can talk about them), but then a dino quest may ask for a dino you don't have.
2. **Mecha part counting is broad.** Any part with a cooldown counts; passive parts (Blade Claws, Bark Hide ...) can never count. Bots never count (players only). OK?
3. **Arena progress shows up late.** Kills and wins on an Arena server are saved when you leave it. The stand reads the store when you open it, so they show after the trip back, not live.
4. **Zebra / Storm Front stop unlocking on their own** (live since v1022). Anyone who earned them in the last hour keeps them. Players who reach the streak from now on claim them at the stand.
5. **Rotating specials:** +5 points each from the 4-quest list above. OK, or other rewards?
6. **Scope.** This is 7 tasks: 5 new scripts and 2 changes. A smaller first release could ship the dailies + the two streak skins, and add the rotating specials next.

## Synthesis (Kepu 2026-11-26)
- R1 "Per player": picks by hash(day, UserId), dino quests from OwnedDinos, stored for the day.
- R2 "Use as written": the daily pool and the weekly list as above (numbers in QuestRules, tunable).
- R3 "OK": part uses = cooldown stamps (`*ReadyAt` up) + DashCount; Arena progress shows after the trip back.
- R4 "Dailies + streak skins first": release 1 = Tasks 1-7 without the rotating weekly special (QuestRules.specials returns the two permanent ones; the weekly list ships in the next release on the same stand).
