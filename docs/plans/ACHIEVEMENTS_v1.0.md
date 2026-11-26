# Mecha Dino Arena v1.0 — Achievements (roadmap piece 5)

**Goal:** 17 achievements across island fighting, the Arena and both. Each pays skill points by medal and is claimed at the Quest Stand.

**Kepu 2026-11-26:**
- 03:55: "i want you to just create random achievements they can collect on through either the island fighting or the arena or both".
- 06:4x picks:
  - Reward: "Skill points by tier" (bronze +2, silver +5, gold +10).
  - Claim: "Claim at the Quest Stand".
  - Badges: "In-game only".
  - Mockup `docs/mockups/achievements_v0.1.html` (artifact "Achievements Board"): "B · Three columns".
  - List: "Use as written".
  - Old progress: "Start fresh"; counted things count from launch, and "Live state" for own / reach.
  - Pop-up: "Yes, top centre 1 s".

**Architecture:** additive on the live Quest Stand:
- **AchievementRules 1.0** (new, data + maths).
- **QuestServer 1.1** keeps the achievement counters in the same store value (`ach`), claims through the same `claim` (ids `a_<id>`), and pays through SkillGrantPoints.
- **QuestScreen 1.1** gets a QUESTS / ACHIEVEMENTS tab pair and the three-column list (scrolls).
- **SkinUnlockPopup 1.1** also shows "ACHIEVEMENT DONE".

## Grounding (live v1027)
- **QuestServer 1.0 already counts** kills (KillCredit, hub → island, else Arena), Arena play / win (ArenaW / ArenaL rises after ArenaRecordReady), the island streak (IslandStreak) and part uses. It saves deltas with UpdateAsync into MDA_Quests_v1, and claims only near the stand with a pend / retry for rewards.
- **Live state** comes from player attributes:
  - OwnedDinos (DinoOwnership, comma list);
  - SkinOwnedU (SkinServer, comma list);
  - SkillLevel (SkillServer 1.15, account level).
- **The Arena win streak** is player ArenaStreak (ArenaRecordServer).

## The list (AchievementRules.LIST)

| id | Name | How | Where | Medal (pts) | stat, need |
|---|---|---|---|---|---|
| first | FIRST BLOOD | Get your first kill on the island | ISLAND | bronze (2) | ikill 1 |
| hunter | ISLAND HUNTER | Get 50 kills on the island | ISLAND | silver (5) | ikill 50 |
| apex | APEX OF THE ISLAND | Get 250 kills on the island | ISLAND | gold (10) | ikill 250 |
| fire | ON FIRE | Reach a 5 kill streak on the island | ISLAND | bronze | istreak (max) 5 |
| unstop | UNSTOPPABLE | Reach a 15 kill streak on the island | ISLAND | silver | istreak 15 |
| storm | STORM BRINGER | Reach a 25 kill streak on the island | ISLAND | gold | istreak 25 |
| win1 | FIRST WIN | Win an Arena match | ARENA | bronze | awin 1 |
| regular | ARENA REGULAR | Play 25 Arena matches | ARENA | silver | aplay 25 |
| champ | CHAMPION | Win 25 Arena matches | ARENA | gold | awin 25 |
| hot | HOT STREAK | Win 3 Arena matches in a row | ARENA | silver | awstreak (max) 3 |
| brawler | ARENA BRAWLER | Get 100 Arena kills | ARENA | silver | akill 100 |
| collect | DINO COLLECTOR | Own 4 dinos | BOTH | silver | dinos (live) 4 |
| roster | FULL ROSTER | Own all 8 dinos | BOTH | gold | dinos (live) 8 |
| lvl10 | LEVELING UP | Reach level 10 | BOTH | bronze | level (live) 10 |
| lvlmax | MAX LEVEL | Reach level 41 | BOTH | gold | level (live) 41 |
| quests | QUEST FAN | Claim 25 daily quests | BOTH | silver | qclaim 25 |
| fashion | FASHION DINO | Own 5 skins | BOTH | bronze | skins (live) 5 |

The total is 95 skill points.

## Tasks
1. **AchievementRules 1.0 · Logic** (`src/shared/AchievementRules.luau`, spec):
   - `LIST`, `PTS = {b = 2, s = 5, g = 10}`.
   - `liveStats(ownedDinos, skinOwned, level)` → `{dinos, skins, level}` (counts of the comma lists, the level).
   - `have(a, counters, live)`.
   - `claimable(a, have, claimed)`.
2. **QuestServer 1.1 · Wired.**
   - **Store:** value field `ach = {p = {[stat] = n}, c = {[id] = true}, n = {[id] = true}}`. p holds the counters (add or max); c is claimed; n is "pop-up already shown".
   - **Saves:** the same delta UpdateAsync as quests, so achievements start at 0 for everyone ("Start fresh"). The day roll never touches `ach`.
   - **Events:** ikill / akill / aplay / awin / istreak as now, plus `awstreak` (ArenaStreak rises, max) and `qclaim` (+1 on a successful daily claim).
   - **Claims:** `claim("a_<id>")` uses the same near-the-stand rule. It sets `ach.c[id]` and `pend` with one UpdateAsync if have ≥ need (counter stats: the stored counter; live stats: the attributes), then `SkillGrantPoints(player, PTS[medal], "achievement")`.
   - **View and ready count:** the view gets `achievements = {{id, name, text, where, medal, have, need, pts, claimed}}` and `achReady`. QuestReady = quests + achievements ready, so the stall's red tag counts both.
   - **Pop-up signal:** when an achievement first becomes claimable and is not in `n`, set player AchDone (name) / AchDoneMedal / AchDoneAt (server time), and add it to `n` (saved).
   - **Switch:** `QuestAchievementsEnabled`.
3. **QuestScreen 1.1 · Wired (layout B).**
   - The header title becomes two tabs: QUESTS and ACHIEVEMENTS. ACHIEVEMENTS has a red count when any are ready.
   - **ACHIEVEMENTS tab:**
     - A ScrollingFrame with three columns: ISLAND / ARENA / BOTH, each headed by "got / total".
     - Rows of 58 px: a medal disc (B / S / G in bronze / silver / gold; grey "?" while not done), the name, a bar, "have / need", and on the right "+n PTS", a yellow CLAIM +n (44 px tall at the phone scale) or "✓ +n".
     - The header right reads "<got> / 17 · +<pts> PTS".
   - The quests tab is unchanged.
   - Switch `QuestAchTabEnabled`.
4. **SkinUnlockPopup 1.1 · Wired.**
   - On AchDoneAt: the same top-centre plate for 1 s, with a medal disc instead of the swatch, "ACHIEVEMENT DONE" (yellow), the name (white), and "CLAIM AT THE QUEST STAND" (cyan, small).
   - Several at once queue, 1 s each, at most 3 (then "+n MORE" on the third).
   - Switch `AchPopupEnabled`.
5. **Check, docs.** Studio hub Play with the test quest store:
   - Kills → First Blood ready, the pop-up, and the stall READY count.
   - Claim → +2.
   - Level / dinos live → Leveling Up ready.
   - Claim away → notNear.
   - The day roll keeps achievements.
   - Phone + PC screenshots.

## Red-team
1. **A burst of pop-ups at launch.** "Live state" achievements (level 10, 4 dinos, 5 skins) are done for many players the first time they join. They queue, 1 s each, up to 3, then "+n MORE". They show once per player ever (`n` is saved).
2. **The total is 95 skill points.** That is on top of levels and dailies, and bonus points have no cap (piece 2). Accepted by the list?
3. **Arena achievements show at the stand after the trip back**, same as the Arena dailies.
