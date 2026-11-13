# Mecha Dino Arena v1.0: Pre-Game Lineup, W-L Record, 4v4 (red-teamed 2026-11-12)

**Goal:** before every Arena match and every bots match, a 30 s lineup shows each team on pedestals with W-L records. Each player picks a dino and 4 parts on a select screen with 3D previews. Player intros and VS follow. The Arena keeps a win-loss record per player.
**Chosen direction:** layout B (Kepu 2026-11-12), mockup docs/mockups/pregame_v0.4.html (artifact A2NNX4m7qWKYMCXWkPsRqR, v2).
**Architecture:** an Arena match becomes a private server built by a queue on the hub island, the way the bots match already is. PracticeServer already runs that kind of match: roster, bot fill, refill on leave, lobby, start, end. It gains an "arenaMatch" kind with humans on both sides and full XP. Its lobby phase becomes the lineup. A new client screen replaces PracticeLobby during the lineup and intro. A new ArenaRecordServer keeps W-L in a DataStore.

## Kepu's decisions (2026-11-12)
| # | Decision |
|---|---|
| D1 | W-L counts Arena matches only. |
| D2 | The same dino twice on a team is allowed. |
| D3 | Bots matches are 4v4. Bots are 2 Elite + 2 Hard on BOTH teams (your team: you plus 3 bots, mix dealt over the bots). |
| D4 | Arena: the lineup runs at every match start. Nobody can join a running match. |
| D5 | Someone leaves an Arena match: their team gets no loss and the other team still gets the win. The leaver gets a loss. |
| D6 | Arena fill: queue up to ~30 s, start 4v4 with whoever is found, and bots fill the empty slots. |
| D7 | After an Arena match (results screen) everyone goes back to the hub island. |
| D8 | Arena teams are 4. The Arena place's max players must be 8 (Game Settings, Kepu). |
| D9 | An Arena match counts toward W-L only when each team has at least 1 real player (eligible = both teams have a human in the roster when the lineup starts). Otherwise it plays the same and no record changes. |
| D10 | Ship in two parts. Part 1: pregame screens on the bots match, 4v4, 2 Elite + 2 Hard, W-L loaded and shown (no writes). Part 2: Arena queue, private 4v4 Arena, W-L written. |
| D11 | A draw: no change to anyone's W-L. |
| D12 | Leaving during the lineup is a loss, the same as leaving mid-match. |
| D13 | A queued player who finishes loading after the match started still gets their slot (from a bot). Anyone not in the trip is sent back to the island. |

## Global Constraints
- Additive only. Each change sits behind its own switch (script attribute) and every number is an attribute.
- Version-brand every script header, docs/VERSIONS.md and docs/ATTRIBUTES.md.
- PC and phone ship together. Player-facing text says only the objective, how you score and the win condition. No explainer copy.
- Studio test rules: no second player; SkillSaveEnabled=false, SpeciesRememberEnabled=false, the new ArenaRecordSaveEnabled=false while testing.
- Teleports and reserved servers don't run in Studio. Every server step therefore gets a Studio test attribute (as ModeTestPractice / PrPrivateTest do).

## Do-not-touch
- Public Arena place servers (kind "arena"): HardpointServer's auto teams and matches, ArenaSpawnServer and ArenaPvP all stay exactly as today. Only the portal stops sending players there.
- The hub island (HubServer free roam, safe area, BOTS portal trip).
- SkillServer's save, XP and loadout code. Pregame uses the existing remotes: DinoSpeciesRequest and SkillRequest("slot").
- The bot brain (PracticeBrain2 2.6, PracticeKit 1.3).
- MatchAwards values. HardpointRules scoring.

## Impact map
| Script (current) | Change | New/extend |
|---|---|---|
| src/shared/ArenaRecordRules.luau | pure W-L outcome rules + spec | NEW 1.0 |
| src/server/ArenaRecordServer.server.luau | DataStore load and write, player attributes | NEW 1.0 |
| src/shared/HubRules.luau 1.1 | queue rules (group packing, start condition), kind "arenaMatch" | 1.2 |
| src/shared/ModeRules.luau 1.3 | serverKind "arenaMatch" (Arena place reserved server / tripData mode "arena") | 1.4 |
| src/server/HubServer (1.3) + HubTravel 1.0 | ARENA portal: queue instead of public teleport. ReserveServer(Arena place) + teleport with teams | 1.4 / 1.1 |
| src/client/PortalHUD.client.luau 1.2 | "FINDING MATCH m:ss · n / 8" + LEAVE QUEUE | 1.3 (needs a mockup frame) |
| src/server/PracticeServer/init 1.8 | kind arenaMatch: both sides human from tripData, 4v4, lineup/intro phases, after-match travel, leaver tracking | 1.9 |
| src/shared/PracticeRules.luau 1.2 | TEAM_MIX switch 2 Elite + 2 Hard; pregame timings | 1.3 |
| src/server/PlaceGate 1.2, ArenaPvP 1.4, HardpointServer 1.7 | treat arenaMatch like practice (bots allowed, bridge on, practice-owned teams), awards practice = false | 1.3 / 1.5 / 1.8 |
| src/server/PregameModels.server.luau | builds each dino body + each part on that body into ReplicatedStorage.PregameModels | NEW 1.0 |
| src/client/PregameScreen.client.luau | LINEUP, SELECT (dino → parts), INTRO, VS | NEW 1.0 |
| src/client/PracticeLobby.client.luau 1.6 | hidden while PrPhase is "lineup" / "intro" | 1.7 |

## Deterministic map
**Record outcome** (ArenaRecordRules.outcome(eligible, winner, myTeam, left, teamHadLeaver)):

| Condition | Outcome |
|---|---|
| eligible ~= true | nil (D9) |
| left == true (lineup, intro or match) | "l" (written at the moment of leaving; D12) |
| winner == myTeam | "w" |
| winner is the other team and teamHadLeaver | nil (no loss) |
| winner is the other team | "l" |
| winner == "draw" | nil (D11) |
| match stopped with no winner (everyone left, server shutdown) | nil |

**Match phases** (PracticeServer, kind arenaMatch or a private bots match): "lineup" (PG_LINEUP 30 s; drops to PG_READY 5 s once all humans are ready) → "intro" (PG_INTRO ~10 s) → "match" (HardpointPractice "start") → "results" (HpResultsEndAt) → arenaMatch: HubTravel "island" for every human / bots: "lobby" as today.

**Arrivals into arenaMatch:**

| When | Result |
|---|---|
| expected member (tripData.members), lineup | takes their slot (replaces the bot) |
| expected member, intro or later | takes their slot from a bot (D13) |
| anyone not in members | sent back to the island at once |

**Queue (hub server):** a group is a squad (leader walks in) or a single player. Start when queued humans ≥ 8, or the oldest group has waited QUEUE_WAIT (30) s. Groups are packed into two teams of ≤ 4 (assignGroups, squads kept together). Leaving the portal ring or pressing LEAVE QUEUE drops the group.

## Tasks
| T | Name | Mode | Depends |
|---|---|---|---|
| T1 | ArenaRecordRules 1.0 + spec (outcome table above, dedupe by matchId) | Logic | — |
| T2 | ArenaRecordServer 1.0: DataStore MDA_ArenaRecord_v1 {w, l, lastMatch}; load on join → player ArenaW / ArenaL / ArenaRecordReady; UpdateAsync on result and on leave; BindToClose; switches ArenaRecordEnabled, ArenaRecordSaveEnabled | Wired | T1 |
| T3 | PracticeRules 1.3: TEAM_MIX_ELITE (2 Elite + 2 Hard at size 4) behind PrEliteMixEnabled; PG_* timings | Logic | — |
| T4 | HubRules 1.2 + ModeRules 1.4: queue pack/start rules + spec; kind "arenaMatch" | Logic | — |
| T5 | HubServer 1.4 + HubTravel 1.1: ARENA portal queue, ReserveServer(Arena place), tripData {mode "arena", teams, members}; test hook "queue" | Wired | T4 |
| T6 | PortalHUD 1.3: FINDING MATCH bar + LEAVE QUEUE (mockup frame first) | Wired | T5 |
| T7 | PlaceGate 1.3, ArenaPvP 1.5, HardpointServer 1.8: arenaMatch behaves like practice; awards practice = false; HardpointPracticeEnded carries leaver info | Wired | T4 |
| T8 | PracticeServer 1.9: kind arenaMatch (teams from tripData, bots fill, PvP), PracticeTeamSize 4, lineup/intro phases (PrPhase, PrPhaseEndsAt, player PgReady), CONFIRM request "ready", leaver tracking → ArenaRecordServer, after-match island trip; Studio attribute PrArenaMatchTest | Wired | T1–T4, T7 |
| T9 | PregameModels 1.0: ReplicatedStorage.PregameModels.<Dino>.Body + Parts.<id> (body-relative, same build as the Lab) | Wired | — |
| T10 | PregameScreen 1.0 LINEUP: one ViewportFrame stage with 4 pedestals, plaques (name, W-L, win %, LV, dino, role, READY, 4 pips), SELECT DINO, timer bar | Wired | T8, T9 |
| T11 | PregameScreen 1.0 SELECT: roster by role (TEAM NEEDS, teammate tags), showcase viewport (drag to spin), stats/kit; SELECT <DINO> → DinoSpeciesRequest, then the PARTS step (4 slots, the dino's parts, owned / BUY IN THE LAB, point = preview on the model) → SkillRequest("slot"); CONFIRM → "ready" | Wired | T10 |
| T12 | PregameScreen 1.0 INTRO: per-player spotlight with W-L, red team reveal, VS, CAPTURE AND HOLD THE HARDPOINT. PracticeLobby 1.7 hidden in those phases | Wired | T10 |
| T13 | Kepu: Arena place Game Settings max players 8; publish both places | Manual | — |

## Releases (D10)
- **Part 1 (v1.0a):** T1, T2 (load + show only: ArenaRecordWriteEnabled default false), T3, T8 bots parts only (4v4, lineup/intro phases, ready), T9, T10, T11, T12. Fully testable in Studio on the bots match.
- **Part 2 (v1.0b):** T2 writes on, T4, T5, T6, T7, T8 arenaMatch parts, T13. Proven live (Studio can't run reserved servers or teleports).

## Red-team (2026-11-12), outcome
| Challenge | Outcome |
|---|---|
| Queue alone = 1 human + 7 bots, so W-L can be farmed | Survived → D9 (each team needs a real player) |
| The Arena half can't be tested in Studio | Survived → D10 two parts; Part 2 gets test hooks + a live check with Kepu's group |
| DataStore double counts (retries, shutdown, leave races) | Survived → T1 dedupes by matchId (lastMatch); UpdateAsync only; BindToClose writes nothing for an unfinished match (leavers are already written) |
| Phone speed of 3D viewports | Survived → T10/T11 acceptance: thumbnails render once (static camera), one live showcase; switch PregameFlatIcons falls back to icons |
| ~1.5 min from portal to play | Accepted risk: lineup 30 s is Kepu's number. The intro is kept at ~8 s |
| Draw / lineup leave / late loaders unmapped | Survived → D11, D12, D13 |

## Part 2 as built (2026-11-13)
- Kepu pick (queue bar): A · Top pill (mockup docs/mockups/arena_queue_v0.1.html). You can walk around while queued; LEAVE drops you and your squad.
- Deviation from the impact map: the Arena 4v4 runs on a reserved copy of the **Sandbox** place (HubTravel "arenaMatch"), not the Arena place. Both are the same file (ADR-005), and this way PlaceGate / ArenaPvP / HardpointServer need no change: the server is kind "practice" (ModeRules 1.4) and PracticeServer 1.10 runs it. T7's PlaceGate / ArenaPvP / HardpointServer edits were not needed; HardpointServer's HpXpPracticeMul is set to 1 on those servers by PracticeServer.
- So MDA-492 becomes: the **Sandbox** place's max players must be at least 8 (the public Arena place is no longer used by the portal).
