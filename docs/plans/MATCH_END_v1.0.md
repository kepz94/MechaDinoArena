# Mecha Dino Arena v1.0 — Match End (results, MVP, XP)

**Goal:** when a Hardpoint match ends (Arena and the bots match), show who won, the match's best players and what each player
earned, give skill XP for player kills, time on the point, winning and MVP, and let the squad leader take the squad back to the
island or stay for the next match.
**Chosen direction:** Kepu 2026-11-11 19:43 "Build with all the recs" on docs/mockups/match_end_v0.1.html (artifact "Match End
Options"): results **B · Three beats**, MVP **One per team**, XP **kill 50 · 1 / s on the point · win 100 (draw 50) · MVP 50 ·
SVP 25 · bots match 10%**, after **Leader decides**. Research on other squad games is on the mockup (CoD Winner's Circle, CoD
Mobile practice 90% reduced XP, Valorant Match / Team MVP, THE FINALS MVP screen, Fortnite Stay with Squad, MW2 Play Again).
**Architecture:** a pure MatchAwards module decides MVP / SVP and each player's XP lines from the scoreboard HardpointServer
already keeps; HardpointServer grants the XP once, at the moment the match is won, through a new SkillServer grant function,
and publishes the awards as one JSON attribute; HardpointHUD plays the three beats from that attribute. KillFeedServer adds a
"player kill" stat so only kills of players earn kill XP.

## Global Constraints
- Additive only; every change behind a switch; every number an attribute. Version tags in headers, docs/VERSIONS.md,
  docs/ATTRIBUTES.md. PC and phone ship together.
- Results stay 15 s (HardpointRules.RESULTS). Beats: banner 0–2 s, spotlight 2–6 s, board 6–15 s; a tap skips to the next beat.
- MVP score = kills × 100 + seconds on the point × 10 (HpMvpKillPts 100, HpMvpSecPts 10); deaths don't count. Ties: more seconds
  on the point, then fewer deaths, then the smaller id. Bots are never MVP / SVP.
- Win: MVP = best human on the winning team, SVP = best human on the losing team. Draw: MVP = best human overall, SVP = best human
  on the other team.
- XP (skill XP, the dino being played): kill a player HpXpKill 50; each second on the point HpXpPerSec 1; winning side HpXpWin
  100; draw HpXpDraw 50; MVP HpXpMvp 50; SVP HpXpSvp 25. Bots match (practice): point, win / draw, MVP, SVP × HpXpPracticeMul
  0.1; kill XP there stays as today (bot kills, SkillServer 1.9, live). Each line rounded to a whole number.
- Granted once per match, when the winner is decided, to every human with a scoreboard row who is still in the server. No row
  (joined and did nothing) = nothing. Left before the end = nothing (accepted, see red-team).
- Island kills (hub kind) give no XP: no Hardpoint match runs there, so no stats are counted.
- Board buttons: PLAY AGAIN (1.2 behaviour) + BACK TO ISLAND (DinoModeRequest "island", ModeServer 1.3: a leader takes the
  squad). A squad member who is not the leader sees both greyed and "★ LEADER CHOOSES". No press = stay (next match / team
  screen, as today). HubOn ~= true -> 1.2's PLAY AGAIN + MAIN MENU.
- Never test with a second player.

## Do-not-touch
SkillServer's bot-kill credit and save flow; the 10% bot SkillXpMul; HardpointRules scoring / RESULTS; PracticeServer lobby and
team screen; ModeServer "island" trips; KillFeed lines and the kill feed UI; HardpointHUD score card, compass, marker, tags.

## Files
- Create `src/shared/MatchAwards.luau` (ServerStorage.DinoArcade.MatchAwards) — pure maths.
- Create `tools/tests/MatchAwards.spec.luau`.
- Modify `src/server/SkillServer.server.luau` -> 1.10 (grant function).
- Modify `src/server/KillFeedServer.server.luau` -> 1.1 ("pk" stat).
- Modify `src/server/HardpointServer.server.luau` -> 1.5 (pk field, awards, HpAwards).
- Modify `src/client/HardpointHUD.client.luau` -> 1.8 (three beats, board v2).

## Task 1 — MatchAwards 1.0 · Mode: Logic
**Interfaces — Produces:**
- `MatchAwards.CFG` = {mvpKill 100, mvpSec 10, kill 50, sec 1, win 100, draw 50, mvp 50, svp 25, practiceMul 0.1}
- `MatchAwards.score(row, cfg) -> number` (row = {k, pt}): k × mvpKill + floor(pt + 0.5) × mvpSec.
- `MatchAwards.pick(rows, winner, cfg) -> mvpId | nil, svpId | nil` (rows = {{id, team, bot, k, d, pt}}; winner "A" / "B" /
  "draw").
- `MatchAwards.lines(row, ctx, cfg) -> {kill, point, win, mvp, svp, total}`; ctx = {winner, practice, mvpId, svpId}; row.pk =
  player kills.
- `MatchAwards.compute(rows, winner, practice, cfg) -> {mvp = id | "", svp = id | "", rows = {[id] = lines}}` (humans only).
**Acceptance:** spec PASS covering win / draw picks, tie rules, bots skipped, empty teams (nil), practice multiplier and rounding,
cfg overrides, bad input -> empty result.

## Task 2 — SkillServer 1.10 · Mode: Wired
BindableFunction `SkillGrantXp` (child): Invoke(player, amount, reason) -> "ok", before = {level, into, next}, after = {level,
into, next} | "disabled" | "notLoaded" | "badArg". Adds to the active dino's XP (d.xp), dirty, publish(levelUp = true),
SkillLastXp = reason .. " +" .. amount. Switch SkillGrantEnabled (true). Diagnostic SkillGrants (count).
**Acceptance:** Play: grant 500 -> SkillXP +500, levels and SkillLevelUpAt move; amount 0 / negative / non-number -> "badArg";
SkillEnabled false -> "disabled".

## Task 3 — KillFeedServer 1.1 · Mode: Wired
After the "k" stat: when killer and victim are both players (not bots) -> also stat field "pk" for the killer. Switch
KillFeedPlayerKillStatEnabled (true).
**Acceptance:** HardpointServer row gets pk (checked through the stat hook with a player id); bot kills never add pk.

## Task 4 — HardpointServer 1.5 · Mode: Wired
- boardRow rows get pk = 0; the stat hook accepts "pk"; HpBoard rows carry pk.
- When the winner is set (once per match, match.awarded): rows -> MatchAwards.compute(rows, winner, PRACTICE, cfg from the
  script attributes) -> for each id "u<UserId>" whose Player is here and total > 0: SkillGrantXp(player, total, "match");
  stores before / after levels; set HpAwards = JSON {mvp, svp, practice, rows = {[id] = {kill, point, win, mvp, svp, total,
  lvB, inB, lvA, inA, nxA}}}; newMatch / stop set HpAwards "".
- Switch HardpointAwardsEnabled (true; false = no awards, HpAwards ""). Settings HpXpKill 50, HpXpPerSec 1, HpXpWin 100,
  HpXpDraw 50, HpXpMvp 50, HpXpSvp 25, HpXpPracticeMul 0.1, HpMvpKillPts 100, HpMvpSecPts 10. Diagnostics HpAwardsLast.
**Acceptance:** Studio practice match ended with the test hook: HpAwards has my row with point / win lines × 0.1, SkillXP grew
by total; arena kind: win 100 + point × 1; a second winner tick doesn't grant again; switch off -> nothing.

## Task 5 — HardpointHUD 1.8 · Mode: Wired
**Layout** (switch HardpointHUDMatchEndEnabled, default true; false = 1.7 / 1.2 board):
- t = now − (HpResultsEndAt − 15) + skip.
- Banner 0–2 s: centre VICTORY / DEFEAT / DRAW (FredokaOne 84, yellow / pink / white), "BLUE 250 – 187 RED" under it, then
  "HARDPOINT" / "PRACTICE · <DIFFICULTY> BOTS".
- Spotlight 2–6 s: one or two cards (MVP gold rgb(255,210,90) larger, SVP silver rgb(201,211,224)) side by side: label pill,
  ViewportFrame with a copy of that player's character (scripts removed, anchored, camera fits the box), name, dino, "K" and
  "ON PT". No character -> the card without the model. No MVP and no SVP -> straight to the board.
- Board 6–15 s: the 1.2 board grown to 760 × 410 (UIScale rule as 1.2): XP column ("+N", green, "—" for bots), MVP / SVP chips
  after the name; an XP strip under the tables: "+N XP" (counts up over 2.5 s), the lines (Kills / Point / Win / MVP / SVP),
  "<DINO> LV n" bar from before to after, "▲ +n LEVEL(S) · +n SKILL PT"; footer: countdown (left), PLAY AGAIN + BACK TO
  ISLAND (right), "★ LEADER CHOOSES" for a non-leader squad member (buttons greyed). BACK TO ISLAND text follows
  ModeLastResult: SAVING… / TELEPORTING… / LIVE GAME ONLY (studio) / TRY AGAIN.
- Skip: a full-screen transparent button only during banner / spotlight.
- Phone: same, scaled by the UIScale; spotlight cards and banner scale with the screen width.
**Acceptance:** Play (PC + phone emulation): beats in order with timings, tap skips, board shows my XP lines matching HpAwards,
leader / solo / member button states, HubOn off -> MAIN MENU, switch off -> 1.7 look.

## Deterministic map
| State | Condition | End state |
|---|---|---|
| win | HpWinner == my team | VICTORY; MVP from my team |
| lose | HpWinner == other team | DEFEAT; SVP may be me |
| draw | HpWinner == "draw" | DRAW; draw bonus |
| no humans on a team | pick returns nil | that card not shown |
| no awards | HpAwards "" (switch off / not yet) | board without XP column / strip |
| me not in awards | joined late / no row | strip says "NO XP THIS MATCH" |
| practice | ReplicatedStorage.Practice / awards.practice | ×0.1 lines, "TEAM SCREEN IN" |
| hub off | HubOn ~= true | PLAY AGAIN + MAIN MENU |
| squad member | SquadId ~= "" and not SquadLeader | greyed + "★ LEADER CHOOSES" |
| leader / solo | otherwise | both buttons live |
| board dismissed | PLAY AGAIN | hidden until the next results (1.2) |

## Red-team (pre-mortem, folded in)
1. **A leaver loses everything** (grant at the end). Accepted: CoD does the same; nothing to farm by leaving. Recorded.
2. **Late joiners take the win bonus.** Mitigated: only players with a scoreboard row (stood on the point, killed or died).
   Someone touching the point for 1 s in the last seconds still gets it — accepted.
3. **Spotlight model breaks** (dead / ragdolled / mecha parts with scripts / huge T-Rex). Mitigated: scripts stripped, parts
   anchored, camera fitted to the bounding box, no character -> card without the model; switch HardpointHUDSpotModelEnabled.
4. **Kill trading in the Arena** (friends on opposite teams). Accepted at 50 XP per kill; all numbers are attributes.
5. **Double grant** if the winner branch ran twice. Mitigated: match.awarded flag; HpAwardsLast diagnostic.
6. **Save before an island trip.** Covered by HubTravel.saveWait (waits for a skill save after the grant).
