# Mecha Dino Arena Filler Bots v1.0 (red-teamed 2026-11-25)

## Red-team results (Kepu 2026-11-25 21:33)
| # | Challenge | Ruling | Plan change |
|---|---|---|---|
| R1 | Roblox's player list, the game page server list, squad invites and chat show real players only, so the disguise leaks. | Leave the player list as it is. | Accepted risk, no task. |
| R2 | Results show "—" XP for bots and MVP / SVP is never a bot, which gives bots away. If bots could be MVP, real players would lose the bonus. | Fake XP for persona bots; MVP / SVP among real players only. | New T6b (MatchAwards display lines) and the HardpointHUD part of T7. |
| R3 | Island filler bot kills count for skin unlocks and XP, so a solo player can farm them, and new players can get jumped. | Count them as today's island bots; no new-player protection. | No change. Tier mix Normal 60% / Hard 40%. |
| R4 | A generated name could be a real Roblox username. | Check each name and reroll. | New T1b (FillerNameCheck), used by T4 and T6. |
| R5 | Server cost of 7 brain bots per hub server, and client FX cost on phones. | Measure in T8; FillerFillTo can be lowered. | T8 acceptance: FillerServer think time and phone frame time recorded. |
| R6 | PracticeBrain2.step was built around a capture point; using a moving roam spot as the "point" is unproven. | Spike first in T4. If it fails, stop and ask Kepu before any edit to the brain. | T4 step 1 = the spike. |

### T1b · FillerNameCheck · Mode: Wired
**Files:** create src/server/FillerNameCheck.luau (ServerStorage.DinoArcade.FillerNameCheck, server only).
**Interfaces:** `pick(rng: Random, used: {[string]: true}) -> string`. It loops up to 5 times: name = FillerRules.name(rng,
used), then `pcall(Players.GetUserIdFromNameAsync, Players, name)`. Success with an id means a real account, so it rolls
again. An error means "not found", so the name is accepted. After 5 real-account hits it takes the last name + 2 random
digits without checking. The accepted name goes into `used`. Results are cached per server; the call yields, so callers
run it inside task.spawn.
**Acceptance:** Studio: a known real username fed in is rejected (test hook `FillerNameCheck.test(name) -> bool`), and
FillerRules names come back accepted.

### T6b · MatchAwards display lines · Mode: Logic
**Files:** extend src/shared/MatchAwards.luau (+0.1), extend its spec in tools/tests.
**Interfaces:** rows with `bot == true and p == true` get `res.rows[id] = M.lines(r, ctx, cfg)` with `shown = true,
granted = false`. MVP / SVP still pick from rows with `bot ~= true` only (today's rule). HardpointServer never grants a
`b<...>` id (today's rule). HardpointHUD shows `+total` for a `p` row.
**Acceptance:** spec: a persona row gets lines and is never MVP / SVP. A plain bot row (no p) gets nothing, as today.


**Goal:** a new player never lands in an empty game. The hub island always feels like 8 dinos, and Arena matches fill to
4v4. The filler bots pass as players (option A, Kepu 2026-11-25 21:23).
**Chosen direction:** A · Full disguise. Mockup: docs/mockups/filler_bots_v0.1/index.html (artifact "Filler Bots v0.1").
**Architecture:** bodies, loadouts and abilities reuse the practice bots (PracticeBots 1.1, PracticeKit 1.1,
PracticeBrain2 2.x, BotProxy). A new pure module, FillerRules, decides names, records, looks, emotes and how many bots there
should be. A new hub-only script, FillerServer, keeps the island filled. Arena fill bots (PracticeServer 1.10) get the same
persona. Every client that tags bots today learns one flag, the model attribute `FillerPersona`, and draws those bots like
players.

## Picks
| # | Pick |
|---|---|
| P1 | Hub island fills to 8 dinos. One bot leaves for each real player who joins; at 8 or more real players there are no bots. |
| P2 | Hub filler bots fight real players outside the safe area, as players do. |
| P3 | Arena matches fill to 4v4 (today's rule, PREGAME_LINEUP D6). |
| P4 | A bot's W-L is made up from its name and stays the same. It is never saved and never on the worldwide leaderboard. |
| P5 | Option A: no BOT tag on the hub or in Arena matches. The VS BOTS portal match is unchanged and keeps its BOT tags. |

## Global constraints
- Version tag: **Filler Bots v1.0**. Every script touched gets a header line `-- vX.Y (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md Tn)`
  and a VERSION bump, plus rows in docs/VERSIONS.md and docs/ATTRIBUTES.md.
- Additive only. Every new behaviour is behind a script attribute switch that defaults on, and turning it off restores
  today's behaviour exactly.
- Every number is a script attribute or a FillerRules constant.
- Game copy: no em dashes, short HUD tags. Mobile-first.
- Bots never get a UserId, never write any DataStore, never appear in LeaderboardServer's OrderedDataStore.
- Real players' W-L rules are unchanged: ArenaRecordServer counts a match only with a real player on each team (D9).

## Do-not-touch
- PracticeServer's VS BOTS match (private bots trip, public practice): its rosters, names, tiers and BOT tags.
- PracticeBrain2 / PracticeBrain / PracticeKit logic: called as they are, never edited.
- HubServer trips, the Arena queue, the safe area rules, SquadServer, ArenaRecordServer writes, LeaderboardServer.
- BotServer 1.28 (old test bots, Enabled false): stays off.
- SkinServer, TrailServer and EmoteServer save, buy and receipt paths.

## File map
| File | New / extend | Responsibility |
|---|---|---|
| src/shared/FillerRules.luau (ServerStorage.DinoArcade.FillerRules) | new | names, records, how many bots, looks, emote timing, leave timing |
| tools/tests/FillerRules.spec.luau | new | Logic test |
| src/server/FillerNameCheck.luau (ServerStorage.DinoArcade.FillerNameCheck) | new | rerolls names that are real Roblox accounts (R4) |
| src/shared/MatchAwards.luau + spec | extend | display-only XP lines for persona bots (R2) |
| src/server/SkinServer.server.luau | extend 1.2 → 1.3 | BindableFunction `SkinPaintBot` (tag roles + paint a bot model) |
| src/server/PracticeServer/PracticeBots.luau | extend 1.1 → 1.2 | `opts.persona` → persona attributes, skin, trail on spawn |
| src/client/BotChars.luau (StarterPlayerScripts ModuleScript) | new | client list of bot models + a stand-in "player" table per bot |
| src/client/EmoteFX, TrailFX + the 15 mecha FX scripts | extend | also draw for bot models through BotChars |
| src/server/FillerServer.server.luau | new | hub only: fill to 8, spawn, brain loop, roam, emotes, leave via portal, respawn |
| src/client/IslandTags.client.luau | extend 1.2 → 1.3 | name + W-L tag over persona bots |
| src/server/PracticeServer/init.server.luau | extend 1.10 → 1.11 | Arena match bots get a persona (name, W-L, look) |
| src/server/HardpointServer.server.luau | extend 1.x → +1 | scoreboard row `p = true` for persona bots |
| src/server/KillFeedServer.server.luau | extend 1.2 → 1.3 | entry `kP` / `vP` for persona bots |
| src/client/PregameScreen, HardpointHUD, KillFeed | extend | persona bots drawn as players (W-L, no BOT tag) |

## Tasks (build order)
T1 → T1b → T2 → T3 → T4 → T5 → T6 → T6b → T7 → T8. The red-team sections T1b and T6b are written at the top of this file.

### T1 · FillerRules · Mode: Logic
**Files:** create src/shared/FillerRules.luau, tools/tests/FillerRules.spec.luau.
**Interfaces (produces):**
- `name(rng: Random, used: {[string]: true}) -> string`: a Roblox-style name from curated word lists (dino words, mecha
  words, gamer words), with patterns like `Word_Word`, `WordWord12`, `xWordx`, `word_main`, `Word2fast`. 3 to 20
  characters, letters, digits and at most one underscore. Never in `used`, never a PracticeRules.NAMES entry. The lists are
  written by hand: no slurs, no real people, no brand names.
- `record(name: string) -> (w: number, l: number)`: FNV-1a hash of the name. Games 6..220, skewed low (most 20..90). Win
  rate 0.36..0.64. The same name always gives the same record.
- `wanted(realPlayers: number, fillTo: number) -> number`: `math.clamp(fillTo - realPlayers, 0, fillTo - 1)` with a whole
  number count, and 0 when realPlayers is 0.
- `look(rng, skinIds: {string}, trailIds: {string}) -> (skinId, trailId)` (the caller passes that species' skin ids): classic skin with weight 0.4, else a
  random skin of that species. Trail "" with weight 0.3, else a random trail.
- `emote(rng, state) -> string?`: state = {afterKill: bool, idleFor: number, inSafe: bool, emoteIds: {string}}. After a
  kill, an emote half the time. Idle in the safe area, one emote every 20..45 s. Otherwise nil.
- `joinDelay(rng) -> number` (8..20 s), `respawnDelay() -> number` (5 s), `leaveWalkMax() -> number` (25 s).
**Steps:** write the spec first, run it in Studio Edit and watch it fail, then write the module, run it and watch it pass,
then commit.
**Acceptance:** spec PASS. 1000 rolled names are unique and valid. `record` is stable across runs. `wanted` covers 0, 1, 7,
8 and 12 players.

### T2 · Bot looks · Mode: Wired
**Files:** SkinServer 1.3, PracticeBots 1.2.
**Interfaces:**
- SkinServer: server-only BindableFunction `ServerStorage.SkinPaintBot`. `Invoke(model, species, skinId) -> "ok" | reason`
  runs the same role tagging and painting as a player's body (SkinCatalog.roleOf, UniversalSkins.paintModel), sets
  `SkinApplied`, and never touches a DataStore.
- PracticeBots.spawn(spec, team, cf, folder, opts): when `opts.persona = {name, w, l, skin, trail}` is given, the model gets
  `DisplayName = name`, `FillerPersona = true`, `FillerW`, `FillerL`, `TrailId = trail`, and SkinPaintBot runs after the
  build. The name stays `PBot_<name>`. Without `opts.persona`, behaviour is exactly 1.1.
**Acceptance:** a spawned persona bot shows its skin and trail on a second client view (Studio Play with server + client).
A practice bot without persona looks as it does today.

### T3 · Bots are drawn like players · Mode: Wired
**Files:** new src/client/BotChars.luau; extend EmoteFX, TrailFX, TenoMovesFX, TenoFX, TheriMovesFX2, TheriMovesFX, TheriFX,
HerreraMovesFX, HerreraPartsFX, DiloMovesFX, DiloPartsVFX, DiloFX, TrooPartsFX, TrooFX, CloakFX, HookFX, MechaLegsFX.
**Interfaces:**
- `BotChars.each(fn)`: calls fn(standIn) for every model in Workspace.DinoIsland.Bots now and for each new one.
  `standIn = {Character = model, Name = model.Name, DisplayName = model:GetAttribute("DisplayName"), UserId = 0,
  CharacterAdded = <signal that never fires>}`. Models leaving the folder are dropped.
- In each FX script: one added block after its existing Players loop: `if script:GetAttribute("BotFXEnabled") ~= false then
  BotChars.each(<that script's own per-player function>) end`. The build session opens each script to find that function.
  It was proven in the trailer shoot (FX watcher copies, 2026-11-25).
**Acceptance:** practice bots and filler bots show mecha part FX, trails and emote props on a client. BotFXEnabled false on
a script restores its old behaviour. Client frame time on a phone-size Studio emulator with 7 bots stays within 2 ms of
today's.

### T4 · FillerServer (hub) · Mode: Wired
**Files:** create src/server/FillerServer.server.luau (ServerScriptService).
**Runs when:** ReplicatedStorage ServerKind == "hub" and script attribute FillerEnabled ~= false. Otherwise FillerState
"notHub" / "off" and nothing else.
**Interfaces (consumes):** FillerRules (T1); FillerNameCheck.pick (T1b) for every new name; PracticeBots.spawn with persona (T2); PracticeRules.rollBot (loadout only; the
name comes from FillerRules.name); PracticeBrain2.step; PracticeKit; PracticeRules TIERS; BotRoam.pickSpot; HubServer's
HubSpawn markers and Workspace.PortalIslet.Portal_arena.
**Step 1 (spike, R6):** in Studio, drive 2 spawned persona bots with PracticeBrain2.step and the per-bot ctx below for
5 minutes. Pass = they roam between spots, fight each other and a player outside the safe area, and none freezes for more
than 20 s. Fail = stop and report to Kepu; no brain edits without his OK.
**Behaviour:**
- **Count:** real = #Players:GetPlayers(). wanted = FillerRules.wanted(real, FillerFillTo (8)). Checked every 1 s.
- **First fill:** at the first player's arrival, wanted bots spawn spread over the island at BotRoam.pickSpot spots, so the
  island is already busy on the first frame.
- **Join** (wanted > current): one bot after FillerRules.joinDelay, on a free HubSpawn marker, facing the portals. Its
  persona is new and its name is unused this server session.
- **Leave** (wanted < current): the bot with the fewest seconds on the island and not in a fight walks to Portal_arena's
  Trigger (PathfindingService, at most leaveWalkMax s). On arrival, Portal_arena gets PortalFlareAt = server time and the
  bot is removed. If the walk times out, the bot is removed where it stands when no player is within 120 studs, otherwise
  on its next death.
- **Brain:** 10 Hz. Each bot record = {model, hrp, hum, species, team = "F<n>", tier ("Normal" 60%, "Hard" 40%), job = nil}.
  Per bot, ctx = {R = PracticeRules, H = HardpointRules, kit = PracticeKit, rng, pathBudget, tiered = true, bots =
  allFillerRecords + standIns, centre = that bot's roam spot, home = roam spot, index = 1}. standIns = one record
  {team = "P<UserId>", model = character} per player whose character is alive, InMenu ~= true and HubSafe ~= true. Players
  in the safe area are never targets. Roam spot: BotRoam.pickSpot every 25..45 s, and a new one when reached.
- **Death:** DummyHealth <= 0 → removed after 2 s, back after FillerRules.respawnDelay on a HubSpawn marker with the same
  persona.
- **Emotes:** FillerRules.emote → model EmoteId, EmoteStartedAt, EmoteDuration (EmoteCatalog dur) while it stands still.
- **XP:** SkillXpMul = PrBotXpMul (0.1), as practice bots.
- **Switches / numbers:** FillerEnabled, FillerFillTo (8), FillerTick (0.1), FillerLeaveViaPortal (true).
- **Diagnostics:** FillerServerVersion, FillerState, FillerBots, FillerWanted, FillerLast.
**Deterministic map:**
| Condition | Result |
|---|---|
| ServerKind ~= "hub" | nothing runs |
| real 0 | every bot removed, nothing spawned |
| 1..7 real | 8 - real bots |
| 8+ real | 0 bots (leaving ones walk out) |
| join during a bot's leave walk | that walk continues; the count settles on the next check |
| bot dies while leaving | removed, not respawned |
| player in the safe area | never a target |
| player in a trip / queued | counted as real while on this server |
**Acceptance:** Studio hub test (Play, ServerKind hub): 1 player → 7 bots fighting each other and the player outside the
safe area, using parts and emoting. Add test players by setting `FillerTestReal` (script attribute, Studio only, default
nil) → bots walk into the ARENA portal one by one. FillerEnabled false → no bots.

### T5 · Island tags for bots · Mode: Wired
**Files:** IslandTags 1.3. Models in DinoIsland.Bots with FillerPersona == true join the tag list (same distance and count
rules): name = DisplayName upper case, bar and numbers from FillerW / FillerL, no rank badge. Switch IslandTagsBotsEnabled.
**Acceptance:** tags on bots look the same as player tags in the mockup's hub view.

### T6 · Arena match personas · Mode: Wired
**Files:** PracticeServer 1.11, HardpointServer (+1), KillFeedServer 1.3.
- PracticeServer: on Arena match servers (PrArena true) with FillerArenaPersona ~= false, each bot slot's name =
  FillerNameCheck.pick, plus slot fields `p = true, w, l`, and spawns with opts.persona. VS BOTS matches are unchanged.
- HardpointServer: a bot registered with ("bot", model, team) whose model has FillerPersona gets row field `p = true` in HpBoard.
- KillFeedServer: entry fields `kP` / `vP` = the killer's / victim's model FillerPersona.
**Acceptance:** in an Arena test match (PrArenaMatchTest), PrRoster bot slots carry p/w/l and HpBoard rows carry p. In a
VS BOTS match nothing changes.

### T7 · Clients draw persona bots as players · Mode: Wired
**Files:** PregameScreen 1.6 (a `p` slot shows W-L, not "<TIER> BOT"), HardpointHUD (+1: no BOT tag for `p` rows; XP cell
`+total` from the T6b display lines), KillFeed 1.3 (no BOT tag when kP / vP).
**Layout:** exactly the mockup's sections 2 to 4 (option A). Switch FillerPersonaUI on each script.
**Acceptance:** an Arena test match shows no BOT tag anywhere; a VS BOTS match shows them as today.

### T8 · QA pass · Mode: Wired
Phone emulator and PC: hub with 1 player for 10 minutes (no stuck bots for more than 20 s, no bot inside the safe area
attacking, no errors in Output), joins and leaves (FillerTestReal 1 → 8 → 1), an Arena test match, a VS BOTS match
(unchanged). Record FillerServer think time per tick and phone frame time with 7 bots (R5). Restore every test switch
afterwards.

## Build + QA log (2026-11-25, not published)
Built T1-T7 (commits d0932ad .. 703ef67); every script's length + hash in Studio equals the repo (tools/srchash.py; VERSIONS.md rows).
Deviations from the plan: PlaceGate 1.4 (the hub removed persona bots at once); PersonaPlates 1.0 (the green bot health plate
gave bots away); FillerServer 1.1 (EmoteId cleared after a bot's emote, else its island tag stayed hidden); leaving bots are
removed at 50 s at the latest; look() takes no species argument.
QA (T8):
- Hub soak, 10 min, 1 player on the islet: no bot still for more than 20 s outside a death / emote, the player took 0 hits in the
  safe area, no FillerServer brain error, no script error in Output; FillerServer tick 0.7 ms typical, 15.9 ms peak. Bots died
  and came back often (178 spawns in about 15 min, 2 to 7 alive at a time).
- Join / leave: FillerTestReal 5 / 1 / 8 (T4 note).
- Arena test match: personas on the lineup, board, kill feed and results (T6 / T7 notes).
- VS BOTS private match: practice names, BOT tags, no personas (unchanged).
- Frame time: Studio's client ran at its 15 fps cap with and without filler bots (66.66 ms both) and with the bot effects on or
  off (within 0.35 ms), so the phone cost is checked on a live phone after a publish.
- Test switches back to nil (ModeTestPractice, PrPrivateTest, PrArenaMatchTest, FillerEnabled); SkillTestMaxAllEnabled false.
