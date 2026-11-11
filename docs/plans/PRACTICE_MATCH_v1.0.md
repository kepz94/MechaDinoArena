# Mecha Dino Arena — Practice Match v1.0 (Sandbox Hardpoint vs bots)

**Goal:** the Sandbox opens a Hardpoint practice match by default (for now). Bots fill both teams to 5v5 with random dinos
and random loadouts, play the point, fight each other and the players, and use their dino's real abilities. A kill feed
shows every kill, and players pick their team in a lobby.

**Kepu 2026-11-10 20:23:** "Have this be the default for sandbox for now. Look at how other games set up bots in games
like this so it can feel like a real practice match. Randomize bot dinosaurs selected as well as their loadouts. They
should be acting like bots and using their abilities and playing objective/interacting with each other. Make sure you have
the kill feed down as well as team selections." 20:32: "Look at how other mobile games handle kill feeds so you don't over
crowd the mobile side". 20:33: "Also how other mobile game menus function for game modes like this".

**Picks (mockup docs/mockups/practice_match_v0.1.html v0.2, artifact WdL5Q7awsddGETs6JHKYCa):**
- Direction **A · Practice lobby**: a team screen before the match (JOIN BLUE / JOIN RED / AUTO, EASY / NORMAL / HARD,
  NEW BOTS, START, starts by itself after 20 s), 5v5, kill feed on the left under the status line.
- Abilities **1 · real abilities**: bots fire the same server code as players, built one dino at a time.
- Menu **M1 · mode chip + PLAY**: one big PLAY in the bottom-right, a mode chip on it opens PRACTICE / HARDPOINT /
  FREE ROAM.
- Phone kill feed **yes**: 3 smaller lines, gone after 4 s, no BOT tags; one banner low in the middle for your own kill or
  death. PC: 5 lines, 5 s (yours 8 s).

**Tickets:** MDA-404 (T0) .. MDA-415 (T11); ADR-010 (real abilities through BotUse entrances).

**Architecture:** a new PracticeServer runs the lobby and the bots in the Sandbox; HardpointServer 1.1 also runs there
while the practice match is on and counts bot models as team members. Bots are server-owned dino models built from the
species ModelData (the SpeciesServer / BotServer pattern) and steered by a server brain whose decisions are pure functions
(PracticeRules). Each ability server gets one additive way in for bots (a BindableFunction "BotUse"), so a bot runs the
same checks and the same hit code as a player. Phase 1 (this plan) = the match, the lobby, the menu, the kill feed, the
scoreboard and bots using their **basic attacks**. Phase 2+ (later plans, one dino each, Raptor first) = each dino's parts.

## Global constraints
- Version branding: every changed script gets a header line and a version bump; VERSIONS.md and ATTRIBUTES.md rows.
- Every behaviour behind a switch; every number an attribute. Sandbox practice off (PracticeEnabled = false) = today's
  Sandbox exactly (BotServer roaming bots back on through PlaceGate 1.0 rules).
- PC and phone ship together. Fonts FredokaOne; HUD panel rgb(20,20,26); your team blue rgb(90,160,255), enemy red
  rgb(224,40,74), yellow rgb(255,200,50) (HardpointHUD 1.1 colours).
- The Arena stays players only (PlaceGate 1.0 arena rules unchanged).
- Studio tests: SpeciesRememberEnabled / SkillSaveEnabled false in Edit before Play, back to nil after; ZZ_ test models
  removed; never a second player; publish only on "Publish".

## Do-not-touch
- BotServer (the roaming bots; it just stays off while practice is on), PreyServer, CreepServer, SurvivalServer,
  GoalServer, RoarServer (already disabled in the place).
- HardpointRules 1.0 numbers; HardpointPointFX 1.0; StepAssistCore 1.2.
- Ability servers' player paths: every change is an added BotUse entrance; the RemoteEvent handlers stay byte-for-byte.
- SkillServer saving, SpeciesServer, ModeServer teleports, SquadServer invites.

## Research summary (sources in the mockup)
- Practice vs AI = 5v5 with bots in both teams (Call of Duty: Mobile, Overwatch). Overwatch's difficulties change damage,
  accuracy, ability use and movement; bots group toward the objective, retreat when outnumbered, focus the weakest.
- Feel human: only what a player could do — reaction delay, aim error, no wall knowledge; random personalities.
- Kill feed: killer · how · victim, own lines highlighted and longer; a few lines in a corner on phones, fading.
- Mobile menus: one PLAY in the thumb corner with a mode chip that opens the mode list (Call of Duty: Mobile, Brawl Stars,
  Rivals).

## Deterministic map (Phase 1)
Practice state (ReplicatedStorage.Practice attributes): PrPhase = "off" | "lobby" | "match" (HardpointServer phases run
inside "match") .
- PracticeEnabled false -> "off": no lobby, no bots, HardpointServer 1.0 behaviour (sandbox: off), PlaceGate 1.0.
- Sandbox, PracticeEnabled -> "lobby" at start.
  - lobby: every human out of the menu (InMenu false via PLAY on PRACTICE) is in the lobby (player PrInLobby true, parked
    like the menu). Roster = 10 slots (5 BLUE, 5 RED). Humans first by their pick (JOIN BLUE / JOIN RED / AUTO = the
    smaller team, ties BLUE), a full side refuses the join ("full"); bots fill every other slot from the rolled roster.
  - START by any lobby human, or PrStartAt reached (the first human entering the lobby sets now + PrAutoStart 20 s) ->
    "match": bots spawn, HardpointServer newMatch.
  - NEW BOTS: re-roll every bot slot (species + loadout + name); refused within 1 s of the last.
  - Difficulty: last chosen value wins (PrDifficulty).
- match:
  - a human pressing PLAY (PRACTICE) mid-match takes a bot slot on the smaller team (ties: the team behind on score); that
    bot is removed; joins straight into the match (HardpointServer team = that side).
  - a human leaving or going to the menu -> a new bot takes the slot within PrRefill (5) s.
  - a bot dies -> respawns after PrBotRespawn (5) s at HardpointPickSpawn's model spot (the CoD spawn rule).
  - HardpointServer results (15 s) -> "lobby" with the same roster (scoreboard stays on the lobby screen until START).
  - no humans left (all left / in the menu) -> bots removed, "lobby".
- Teams on models: bot model attribute HardpointBotTeam "A" (BLUE) / "B" (RED); SquadRules 1.2 teamOf reads it.

## Tasks (build order)

### Task 0 — PracticeRules 1.0 + spec · Mode: Logic
**Files:** create src/shared/PracticeRules.luau (ServerStorage.DinoArcade.PracticeRules, cloned to
ReplicatedStorage.PracticeShared for clients), tools/tests/PracticeRules.spec.luau.
**Interfaces (Produces):**
- `NAMES` (40 bot names), `SPECIES` {"Raptor","TRex","Pachy","Herrera","Teno","Therizino","Dilo","Troodon"},
  `DIFF = {Easy = {react 0.8, sight 70, abil 0.25, retreat false, aimErr 14}, Normal = {0.5, 90, 0.5, true, 8},
  Hard = {0.3, 110, 0.85, true, 3}}`, `SIZE` 5, `AUTO_START` 20, `CONE` 120.
- `rollBot(rng, usedNames, SkillTree, level) -> {name, species, steps, loadout}`: species uniform; steps = random buys with
  SkillTree.canBuy until the points of `level` (default 30) are spent or nothing is buyable; loadout = up to SkillTree.SLOTS
  random owned button parts (SkillTree.setSlot).
- `fillRoster(humans: {{id, want}}, bots, size) -> {A = {...}, B = {...}}`.
- `pickSide(nA, nB, scoreA, scoreB) -> "A" | "B"`.
- `assignRoles(n, rng) -> {roles}`: 5 -> cap, cap, def, hunt, esc (shuffled); fewer -> cap first.
- `scoreTarget(dist, onPoint, hpFrac) -> number` (lower is better): dist - (onPoint and 60 or 0) + hpFrac x 30.
- `shouldRetreat(hpFrac, mates, foes, diff) -> bool`: diff.retreat and hpFrac < 0.3 and foes > mates + 1.
- `goalFor(role, team, centre, nextCentre, into, pointTime) -> Vector3` (the mockup sim's offsets: cap +/-8, def +/-55 /
  +20, hunt +/-140 / -90, esc +/-30 / +40; esc rotates to the next point when into > pointTime - 10).
- `wantsAttack(seenFor, dist, reach, cdLeft, diff) -> bool`: seenFor >= diff.react and dist <= reach and cdLeft <= 0.
**Steps:** write the spec first (each function's branches, roster fill 0-10 humans, full side, names unique, rollBot only
buys own-dino paths, loadout only owned buttons), run it red, write the module, run it green (PASS n), commit.
**Acceptance:** spec PASS in Studio; T-Rex rolls give an empty loadout (no parts live); hash recorded.

### Task 1 — practice rules in ModeRules 1.1, SquadRules 1.2, ArenaPvP 1.3, PlaceGate 1.1 · Mode: Logic + Wired
**Files:** modify src/shared/ModeRules.luau, src/shared/SquadRules.luau, src/server/ArenaPvP.server.luau,
src/server/PlaceGate.server.luau.
- ModeRules 1.1 `canAffect`: one row before "otherwise false": mode == "sandbox" and ReplicatedStorage PracticeLive ==
  true -> true (players hurt players on the other team; the team check stays in SquadRules). `practiceLive()` helper.
- SquadRules 1.2 `teamOf(model)`: also reads model attribute HardpointBotTeam (after HardpointTestTeam).
- ArenaPvP 1.3: bridges player characters in the Sandbox too while PracticeEnabled (script attribute
  ArenaPvPPracticeEnabled, default true; read at start with ServerScriptService.PracticeServer:GetAttribute
  ("PracticeEnabled")).
- PlaceGate 1.1: Sandbox + PracticeEnabled -> BotServer stays off, PlaceGateState "sandboxPractice".
- SkillServer 1.9 (red-team 3): a killed bot's model attribute SkillXpMul (default 1) multiplies its kill XP (practice bots
  0.1, Kepu "10% (like CoD Mobile)"); switch SkillBotXpMulEnabled.
**Acceptance:** squad_rules_test PASS (new rows), ModeRules rows tested; Sandbox Play with practice off = today's bots.

### Task 2 — PracticeBots: build a bot of any dino · Mode: Wired
**Files:** create src/server/PracticeBots.luau (ModuleScript under PracticeServer).
**Interfaces:** `PracticeBots.spawn(spec{name, species, steps, loadout}, team, cframe) -> model`, `despawn(model)`.
Model: DinoModelBuilder build of Models.<Species>ModelData (T-Rex: StarterCharacter clone, as SpeciesServer); clones of
StarterCharacterScripts children that run on clients (IdleAnimation, StatusBadges, the species' FX scripts — the BotServer
list); attributes IsBot, PracticeBot, Bitable, BotSpecies, Species, DisplayName = name, DummyMaxHealth = DummyHealth = the
species' Humanoid MaxHealth, HardpointBotTeam, PracticeLoadout (JSON), SkillPath_<id> copies on the model; parent
Workspace.DinoIsland.Bots (StepAssistServer lifts bots there); network owner = server.
**Acceptance:** each of the 8 dinos spawns, stands, walks (Humanoid:MoveTo), shows its health bar and BOT name, and takes
damage from a player's attack in the Sandbox practice.

### Task 3 — HardpointServer 1.1: practice in the Sandbox · Mode: Wired
**Files:** modify src/server/HardpointServer.server.luau.
- Runs in the Sandbox when script attribute HardpointPracticeEnabled (default true) and PracticeEnabled; the match starts
  only when PracticeServer invokes HardpointTest-like BindableFunction `HardpointPractice`("start", teams) and ends to
  "lobby" after results (no auto new match in practice).
- counted() also counts models registered with ("bot", model, team).
- HardpointPickSpawn accepts a model (bot) as well as a player.
- Per-participant stats: kills, deaths, point seconds -> ReplicatedStorage.Hardpoint HpBoard (JSON, at most 2 Hz).
**Acceptance:** Arena behaviour identical (hook pass from the Hardpoint build re-run); Sandbox practice: bots count on the
point, contested works with a bot on each side, a bot spawn follows the point.

### Task 4 — PracticeServer 1.0: lobby, roster, bot life · Mode: Wired
**Files:** create src/server/PracticeServer.server.luau; ReplicatedStorage.Practice (state), RemoteEvent
ReplicatedStorage.PracticeRequest (client -> server: "lobby" | "join", side | "difficulty", name | "newbots" | "start" |
"leave").
State attributes: PrPhase, PrStartAt, PrDifficulty, PrRoster (JSON: A / B slots {kind "human"/"bot", name, species,
loadout names, userId}), PrResult; player PrInLobby, PrSide, PrLastResult. Script attributes PracticeEnabled (true),
PracticeTeamSize (5), PrAutoStart (20), PrBotRespawn (5), PrRefill (5), PrBotLevel (30).
Implements the deterministic map above.
**Acceptance:** every map branch walked in Play with the hooks (one human only; extra "humans" faked with hook slots).

### Task 5 — PracticeBrain: bots that play · Mode: Wired (decisions from PracticeRules, tested in Task 0)
**Files:** create src/server/PracticeBrain.luau (ModuleScript under PracticeServer).
10 Hz per bot: sense (enemies in CONE within DIFF.sight, line of sight by a ray against DinoIsland; cloaked / hidden only
within 15 studs), target (scoreTarget), roles (assignRoles at each point change), goal (goalFor), movement
(PathfindingService path for trips over 80 studs, recomputed every 2 s or on block; Humanoid:MoveTo per waypoint; unstuck:
under 2 studs of progress in 2 s -> sidestep 8 studs and retry, then jump), retreat (shouldRetreat -> toward the nearest
mate), attack (wantsAttack -> the basic attack's BotUse entrance with aim at the target + aimErr degrees).
Attributes per bot: BotRole, BotGoal, BotTarget, BotState (move / fight / retreat / dead), BotStuckCount.
**Acceptance:** 5v5 bots alone for 3 minutes: both teams score, every point gets visited, bots fight each other, a bot
that gets stuck frees itself (BotStuckCount rises then falls back to moving), no errors in the output.

### Task 6 — bot entrances for the 8 basic attacks · Mode: Wired
**Files:** create src/server/BotProxy.luau (ServerStorage.DinoArcade.BotProxy): a stand-in for `player` with Character =
the model, Name / DisplayName, UserId 0, GetAttribute / SetAttribute / GetAttributeChangedSignal on the model,
IsA("Player") false. Modify, additive only (a BindableFunction "BotUse" child + the same handler body called with the
proxy): TrooAttackServer, DiloAttackServer, TenoAttackServer, TheriAttackServer (server-resolved: request only);
PounceServer, HeadbuttServer, SlashServer, BiteServer (client-motion attacks: request + claim entrances; the lunge / dash
motion for bots in src/server/PracticeMotion.luau, server physics like BotServer's pounce lunge, copied not shared).
Per server: list every `player.` use in its handler first (ticket note); anything the proxy cannot answer is a refusal
"botUnsupported", never an error.
**Acceptance:** each dino's bot hurts a team-B dummy and not a team-A dummy; KilledBy = the bot's name on a kill;
BiteServer etc. still pass their player tests.

### Task 7 — kill feed · Mode: Wired
**Files:** create src/server/KillFeedServer.server.luau, src/client/KillFeed.client.luau.
Server: watches KilledAt on bridged player characters and practice bots; entry {k, kTeam, how (KilledWith -> display name;
none -> LastHitBy within 5 s, how = ""), v, vTeam, kBot, vBot, kId, vId, at} -> RemoteEvent ReplicatedStorage.KillFeed
FireAllClients; counts K / D for HpBoard.
Client (ScreenGui KillFeed, DisplayOrder 6): left column under HardpointHUD's status / next pills; PC 5 lines, 5 s (lines
with you 8 s), BOT tags; phone (TouchEnabled or ArenaTouchForceTouch) 3 lines, 82% size, 4 s, no BOT tags; own kill /
death banner low in the middle on phones (ELIMINATED <NAME> / KILLED BY <NAME> · how, 2.5 s). Team colours from the
viewer (your team blue). Switch KillFeedEnabled; KillFeedPhoneBanner.
**Acceptance:** PC and forced-touch screenshots; no overlap with the HUD, the touch buttons or the ability bar.

### Task 8 — PracticeLobby screen (direction A) · Mode: Wired
**Files:** create src/client/PracticeLobby.client.luau.
Shown while PrInLobby: title PRACTICE MATCH · HARDPOINT · SUMMIT · STARTS IN m:ss; BLUE / RED columns of 5 slots (dino
tag, name, BOT tag, loadout names; your slot yellow); JOIN BLUE / JOIN RED / AUTO / EASY / NORMAL / HARD / NEW BOTS /
START / MAIN MENU; after a match, the last scoreboard above the columns until START. Phone: columns side by side down to
360 px tall, slot text 12 px minimum, buttons 44 px minimum.
**Acceptance:** PC and forced-touch screenshots; every button's request result shown (PrLastResult toast).

### Task 9 — MainMenu 1.22: mode chip + PLAY (M1) · Mode: Wired
**Files:** modify src/client/MainMenu.client.luau (switch MainMenuModeChipEnabled, default true; false = 1.21).
Right column replaced by: PLAY (yellow block) bottom-right with a mode chip above it; the chip opens a list: PRACTICE
(Sandbox: opens the lobby here; Arena: travels to the Sandbox), HARDPOINT (Arena: plays here; Sandbox: travels), FREE ROAM
(greyed "SOON" while PracticeEnabled). The dino stage moves to the centre, the slots to the bottom-left (mockup M1).
**Acceptance:** PC and forced-touch screenshots; ◀ ▶, slot picker and travel still work.

### Task 10 — HardpointHUD 1.2: match-end scoreboard · Mode: Wired
**Files:** modify src/client/HardpointHUD.client.luau. Results panel -> VICTORY / DEFEAT / DRAW + two tables (name, dino,
K, D, on point) from HpBoard; PLAY AGAIN (practice: back to the lobby) and MAIN MENU. Switch HardpointHUDBoardEnabled.

### Task 11 — QA and performance · Mode: Wired
5v5 with 9 bots for 5 minutes in Studio: server Heartbeat time (attribute PrServerMs), client FPS, memory; phone emulation
screenshot pass; docs rows; Dev Hub notes.

## Phase 2+ (separate plans after Phase 1 ships)
Per dino (Raptor first: Shock Cannon, Cloak Field, Energy Shield, Adrenaline Injector, Shock Mine, Thrusters, Scent Sense):
SkillEffects for bot models, mecha part visuals on bots, a BotUse entrance per part server, and the ability tags
(ranged / gap / burst / save / hold / sneak) in PracticeRules.

## Red-team (2026-11-10, Kepu's answers 20:4x)
1. **Bots stuck on the mountain** (the Summit is P3; climb test: Pachy / Herrera 1 of 5 sides). Kepu: "Paths + hold
   below". -> Task 5: PathfindingService routes for every trip over 80 studs; a bot whose goal is a point it hasn't
   reached within PrClimbGiveUp (25) s takes the nearest reachable spot within DY 40 / 45 studs flat of the centre, else the
   nearest reachable spot on its path, and holds there (BotState "holdBelow"). Acceptance: every dino's bot reaches or
   holds below each of the 5 points; a 3-minute bots-only run shows no bot stuck in one place for 25 s without "holdBelow".
2. **Phones slowing down** (10 full dinos). Kepu: "Yes, 4v4 if needed". -> Task 11 measures server Heartbeat and phone
   FPS; PracticeTeamSize (5) drops to 4 when the phone check is under 30 FPS; the lobby and the roster read it.
3. **XP farming** (every bot kill gives DummyMaxHealth x 0.5 XP). Kepu: "10% (like CoD Mobile)". -> Task 1 adds SkillServer
   1.9: a bot model attribute SkillXpMul (default 1) multiplies its kill XP; practice bots get 0.1. Diagnostic SkillLastXp
   shows the reduced value.
4. **Loadouts that don't work yet.** Kepu: "Show only working parts". -> PracticeRules `BOT_LIVE` (set of part ids whose
   BotUse entrance exists; empty in Phase 1). Bots still roll a full random loadout (kept in PracticeLoadout), but the
   lobby lists only BOT_LIVE parts; a bot with none shows its dino and "basic attack".
5. (internal, no question) **The bot stand-in for `player`** can break ability code that expects a real Player. -> Task 6
   lists every `player.` use per server before touching it; anything the proxy can't answer returns "botUnsupported"
   inside a pcall, never an error; each server keeps its player tests passing.
6. (internal) **Kill feed gaps** (a death without KilledBy). -> Task 7 falls back to LastHitBy within 5 s; otherwise no line.

Scope check: Phase 1 is 12 tasks; the smaller version (no lobby, no menu change) was direction B, which Kepu passed over.
Nothing cut.
