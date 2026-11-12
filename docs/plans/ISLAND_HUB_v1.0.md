# Mecha Dino Arena — Island Hub v1.0 (portal islet, squad travel)

**Goal:** after the menu you land on the island. A safe islet with portals sits off the south-east coast: walk into a portal
to go to that mode; a squad leader takes the whole squad. Off the islet it is the normal island with player damage on.

**Kepu 2026-11-11 17:43:** "when you spawn on the main island there will be portals that lead you to arena, hard point v bots,
etc. have this work like Fortnite creative mode ... if you're squaded up and enter into a game mode your squad queues with
you, even bot island. We'll still have the main menu but it'll just be lab and then the spawn onto island. Have the portal
options its own safe section on the map where no fighting happens ... once you leave that selection area it's just the
regular island with players on it."

**Picks (17:5x):** off the safe area **PvP on**; **the leader walks in, the whole squad goes**; portals **ARENA (PvP)** and
**HARDPOINT VS BOTS**; menu **dino pick + Lab + PLAY**. Mockup docs/mockups/island_portals_v0.1.html (artifact
9nwdochrmdNnVazZwU85mA): layout **C · Portal Islet**; **3 s edge guard** after leaving; **no bots** on the hub island.

**Architecture:** no new place. The Sandbox place (where everyone joins) becomes the hub on its public servers. A private
(reserved) copy of the Sandbox place runs today's practice match for one party (your squad vs bots). The Arena place is
unchanged (Hardpoint PvP). One rule decides what a server is (ModeRules.serverKind); every script that today switches on
"Sandbox + practice set up" also checks it. Trips use TeleportService with teleport data that rebuilds the squad on arrival.
The islet is a parts model kept in ServerStorage and placed only on hub servers, so the Arena and bots servers keep today's
island.

## Global constraints
- Additive: every change behind a switch; every number an attribute or a named constant. Version rows in VERSIONS.md /
  ATTRIBUTES.md. PC and phone ship together.
- Studio: teleports do not run. Every trip in Studio ends with the result "studio" after the countdown.
- Test kinds in Studio: Workspace attributes ModeTestArena (existing), ModeTestPractice (new); neither = hub.
- Never test with a second player (squad cases use SquadServer's server-only test hook).

## Do-not-touch
- Workspace.DinoIsland (ground, trees, rocks, water, EdgeWalls at ±1085), the SpawnLocation, MenuLobbyPad.
- Every ability server, BotServer, HardpointRules (points, scores, spawns), PracticeRules / PracticeBrain, skills, saves,
  skins, the Lab, FontSwap.
- The Arena place's game: Hardpoint PvP, ArenaSpawnServer.

## What's live (read 2026-11-11)
- ModeRules 1.1: placeMode -> "sandbox" / "arena"; canAffect(srcIsPlayer, tgtIsPlayer, tgtInMenu, mode) — 16 servers call it
  with a MODE read at start; practiceLive() row.
- SquadRules 1.2: sameChar(a, b) is called before damage by every damage path (29 scripts: all canAffect callers plus Bite,
  Pounce, Headbutt, Hook, Slash). SquadsLive only in the Arena (SquadServer 1.0). InMenu turning true leaves the squad.
- PlaceGate 1.1 / ArenaPvP 1.3 / HardpointServer 1.3 / PracticeServer 1.3 each decide "practice set up" from
  ServerScriptService.PracticeServer (exists, Enabled, PracticeEnabled not false).
- ModeServer 1.2: menu, lobby pad, "play" / "menu" / "sandbox" / "arena", hop with save wait, teleport data mdaPlay.
- MainMenu 1.22: mode chip (PRACTICE / HARDPOINT / FREE ROAM) + PLAY. PracticeLobby 1.2: team screen. SquadHUD 1.0.
- Map: the island fills the walls except the sea corners. South-east corner: sea from about x 780..1080, z 780..1080; sea
  floor y -8, water top y -0.8; beach sand y -1.

## Deterministic map
**Server kind (ModeRules.serverKind, at start)** first row wins:
1. placeMode == "arena" -> "arena".
2. hub off (ServerScriptService.HubServer missing, not Enabled, or HubEnabled == false) -> "practice" (today's Sandbox).
3. Studio: Workspace ModeTestPractice == true -> "practice"; else -> "hub".
4. game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 (a reserved server) -> "practice".
5. otherwise (public server, or a VIP server) -> "hub".

**Per kind**
| | hub | practice | arena |
|---|---|---|---|
| Bots (PlaceGate) | none (removed like the Arena) | practice bots | none |
| Player damage | on, except a protected player (below) | practice match rules (today) | on (today) |
| Hardpoint | off | practice match (today) | PvP match (today) |
| Squads | on | on (Hardpoint teams win, today's rule) | on (today) |
| Islet | placed | not placed | not placed |
| Menu PLAY | onto the islet | the practice lobby (today) | into the match (today) |
| Menu BACK TO ISLAND | hidden | shown | shown |

**Protected (hub only):** character attribute HubSafe = HubInZone or now < HubGuardUntil.
- HubInZone: HumanoidRootPart inside any SafeZone part of the islet (islet disc + bridge), checked every 0.2 s.
- Leaving the zone: HubGuardUntil = now + GUARD (3 s). Re-entering clears nothing (the zone protects anyway).
- Dead / no root: HubInZone false, HubSafe false.
- A protected character can't be hurt and can't hurt any player (both ways, every damage path): SquadRules.sameChar answers
  "same side" on the server when HubLive and either character is HubSafe. Bites: ArenaPvP also sets Bitable false while
  HubSafe.

**Trip (HubServer)** — a player whose root is inside a portal's trigger box (checked every 0.2 s):
| Case | Result |
|---|---|
| not in a squad | countdown 5 s for that player |
| squad leader | countdown 5 s for every member on this server, wherever they are (menu, dead, across the island) |
| squad member (not leader) | nothing; toast "ONLY <LEADER> ★ CAN START A MODE" (HubLastResult "notLeader", once per entry) |
| a countdown already running for this player | nothing new |
- Cancel (HubTripState "cancelled", all in the trip): the starter's root leaves the trigger box; the starter leaves the squad
  or quits.
- A member who leaves the squad or quits during the countdown is dropped from the trip; the rest still go.
- A player who joins the squad during the countdown is not added.
- At 0: save wait (each traveller: last skill change < 12 s ago -> wait for SkillSaveState "saved" after it, at most 12 s;
  HubTripState "saving"), then "teleporting". Studio -> "studio". Teleport error / TeleportInitFailed -> "failed" for that
  player; others that already left are gone.
- Destinations: "arena" -> TeleportAsync(ARENA place, party); "bots" -> TeleportService:ReserveServer(SANDBOX place) then
  TeleportAsync with ReservedServerAccessCode; "island" -> TeleportAsync(SANDBOX place, party). Teleport data:
  {mdaPlay = true, mdaFrom = kind, mdaTrip = {mode, key, leader (UserId), members (UserIds)}}.

**Arrival (any kind)** with mdaTrip: ModeServer 1.1 already skips the menu (mdaPlay). SquadServer 1.1 puts everyone with
the same key in one squad (first arrival makes it; later ones join; leader = mdaTrip.leader when present, else the first);
the key is kept 60 s. Practice kind: PracticeServer 1.4 opens the lobby and puts the player on side A. Hub kind: HubServer
places the body on an islet spawn spot.

**Back to the island (ModeServer "island")** in practice / arena: a leader takes every squad member on this server; a
member goes alone (the squad here loses them as a quit). Hub kind -> "badArg".

## Tasks (build order)

### Task 1 — HubRules 1.0 · Mode: Logic
**Files:** Create src/shared/HubRules.luau (ServerStorage.DinoArcade.HubRules; HubServer clones it to
ReplicatedStorage.HubShared). Test: tools/tests/HubRules.spec.luau.
**Interfaces (pure):**
- `M.TRIP_TIME = 5`, `M.GUARD = 3`, `M.SAVE_WAIT = 12`, `M.POLL = 0.2`, `M.KEY_KEEP = 60`
- `M.kind(info) -> "hub" | "practice" | "arena"`; info = {placeMode, hubOn, isStudio, testPractice, privateId, ownerId}
  (the server-kind table above).
- `M.inShape(pos, cf, size, shape) -> bool`; shape "box" (inside the oriented box) or "cyl" (Roblox cylinder: axis = the
  part's X; inside radius min(size.Y, size.Z)/2 and |x| <= size.X/2).
- `M.inZone(pos, shapes) -> bool` (any of {cf, size, shape}).
- `M.protected(inZone, guardUntil, now) -> bool`.
- `M.tripParty(starter, info) -> {UserId} | nil, reason`; info = {squadId, leaderId, members = {UserId}}: no squad ->
  {starter}; starter == leader -> members; else nil, "notLeader".
- `M.nextLeader(members) -> UserId | nil`; members = {{id, joinedAt}}: earliest joinedAt, ties -> smallest id.
- `M.tripData(mode, key, leader, members, from) -> table` (the teleport data shape above).
**Acceptance:** every row of the server-kind table; box / cylinder in and out, edges inclusive; protected with and without
guard; tripParty for solo, leader, member, empty squad list; nextLeader ties; spec PASS.

### Task 2 — ModeRules 1.2 + SquadRules 1.3 · Mode: Logic
**Files:** Modify src/shared/ModeRules.luau, src/shared/SquadRules.luau. Test: tools/tests/HubModeRules.spec.luau.
**Interfaces:**
- ModeRules `serverKind() -> string` (HubRules.kind with live values; ServerScriptService.HubServer gating;
  Workspace ModeTestPractice); `hubLive() -> bool` (ReplicatedStorage HubLive == true). canAffect gets one row before the
  last: `mode == "sandbox" and M.hubLive() -> true`. Hub off -> exactly 1.1.
- SquadRules `leaderOf(id) -> Player | nil` (the member with player attribute SquadLeader == true); `isLeader(player)`.
  sameChar row first (server only, RunService:IsServer()): `hubLive and a ~= b and (a.HubSafe or b.HubSafe) -> true`.
  Clients: unchanged answers (team tags and FX don't treat strangers on the islet as friends).
**Acceptance:** canAffect rows with HubLive on / off; sameChar safe row on the server, off on clients and with HubLive off;
leaderOf with 0 / 1 leader; spec PASS; ModeRules.spec and the squad test still pass.

### Task 3 — Kind gates · Mode: Wired
**Files:** Modify PlaceGate (1.2), ArenaPvP (1.4), HardpointServer (1.4), PracticeServer (1.4 part 1).
- PlaceGate 1.2: kind "hub" -> BotServer off and bot models removed (the Arena branch). PlaceGateState "hubNoBots". Switch
  PlaceGateHubEnabled.
- ArenaPvP 1.4: kind "hub" -> bridge on (as the Arena); while a character's HubSafe is true, Bitable = false. ArenaPvPState
  "hub". Switch ArenaPvPHubEnabled.
- HardpointServer 1.4: kind "hub" -> not started; HardpointState "hub". Switch HardpointHubEnabled.
- PracticeServer 1.4: runs only in kind "practice"; else PracticeState "hub". Switch PrHubGateEnabled.
**Acceptance:** Studio Play in each kind (none / ModeTestPractice / ModeTestArena): states as the table; hub: no bots, no
Hardpoint HUD, no practice lobby; practice: today's match; arena: today's match; each switch false = today.

### Task 4 — SquadServer 1.1 · Mode: Wired
**Files:** Modify src/server/SquadServer.server.luau.
- Live in every kind (switch SquadAllKindsEnabled; false = Arena only).
- Leader: the inviter who makes a squad gets SquadLeader = true; each member gets SquadJoinedAt; when the leader leaves,
  HubRules.nextLeader picks the next.
- InMenu no longer leaves the squad (switch SquadMenuKeepEnabled; false = 1.0).
- Arrival: TeleportData mdaTrip -> squad by key (map kept KEY_KEEP s); leader from mdaTrip.leader.
- Test hook SquadTest gains "arrive", player, tripTable (runs the arrival path) and "leader", player.
**Acceptance:** invite / accept / leave in the hub kind; leader moves on leave; menu keeps the squad; "arrive" twice with
one key -> one squad, right leader; switches false = 1.0.

### Task 5 — Portal Islet build · Mode: Wired
**Files:** Create tools/build/PortalIslet.build.luau (run in Studio Edit; builds ServerStorage.PortalIslet).
**Layout:** south-east sea corner. Islet: sand disc (cylinder) about 200 across, top y 1, its whole edge inside x / z <
1060; stone plaza disc on top; the two portal arches side by side facing the island (left ARENA orange rgb(255,155,46),
right HARDPOINT VS BOTS yellow rgb(255,200,50)), each a neon arch + swirl disc + a sign (SurfaceGui: name, one line, PVP /
BOTS) + an invisible trigger box (attribute HubPortal = "arena" / "bots"). A wooden bridge (planks + rails, 16 wide) from
the islet's north-west edge to the nearest flat dry sand. SafeZone parts (attribute HubSafeZone = true; invisible; no
collide / query / touch): the islet disc and the bridge (its island end = the edge). A cyan ground line on the zone edge.
Spawn spots IsletSpawn1..8 on the plaza. Exact spot chosen in Studio so the bridge lands on Sand / Grass at y >= -1.
**Acceptance:** Studio screenshots (top-down and standing on the islet) sent to Kepu before Task 6 is wired in; nothing in
DinoIsland changed (part count same); islet fully inside the walls.

### Task 6 — HubServer 1.0 + HubTravel 1.0 · Mode: Wired
**Files:** Create src/server/HubServer.server.luau, src/server/HubServer/HubTravel.luau (child module).
- At start (every kind): ReplicatedStorage ServerKind = ModeRules.serverKind(), HubOn. Kind "hub": clone
  ServerStorage.PortalIslet to Workspace, HubLive = true.
- Zone loop (POLL): HubInZone / HubGuardUntil / HubSafe on characters (map above).
- Placement: InMenu -> false, a respawned own-dino body (Species == DinoSpecies, as ArenaSpawnServer), or a first body
  arriving outside the menu -> after 0.15 s on a free IsletSpawn spot (farthest from other players), facing the portals,
  camera via ShoulderCamLookAt (cleared 1 s later).
- Portal loop and trips (map above). Player attributes: HubTripMode, HubTripEndsAt, HubTripLeader (name), HubTripState
  ("count" / "saving" / "teleporting" / "failed" / "cancelled" / "studio" / ""), HubTripMembers (names, comma list),
  HubLastResult, HubLastAt.
- HubTravel.go(players, mode, data) -> ok, err (the destination rules); HubTravel.saveWait(players).
- Switch HubEnabled (read at start). Diagnostics: HubServerVersion, HubState, HubTrips, HubTripsFailed.
- Test hook (server-only BindableFunction HubTest): "trip", player, mode (as if the player walked in), "state".
**Acceptance:** Studio hub: spawn on the islet after PLAY and after a death; zone in / out with the 3 s guard; damage blocked
both ways while HubSafe (a test target via ArenaPvP's hook placed on the islet); solo countdown -> "studio"; step out ->
"cancelled"; squad trip via SquadTest join + HubTest -> members listed; "notLeader" toast case.

### Task 7 — ModeServer 1.3 + PracticeServer 1.4 part 2 · Mode: Wired
- ModeServer 1.3: action "island" (practice / arena kinds) -> HubTravel with the party rule above. Switch
  ModeIslandEnabled.
- PracticeServer 1.4: in a reserved server, an arrival with mdaTrip.mode "bots" -> "lobby" + side A; humans always side A
  there ("join B" -> "squadSide"); ReplicatedStorage.Practice PrPrivate = true. Switch PrPrivateSideEnabled.
**Acceptance:** Studio practice kind: "island" -> "studio"; the side-A rule with PrPrivate forced through a test attribute;
switches false = today.

### Task 8 — Client: PortalHUD 1.0, MainMenu 1.23, PracticeLobby 1.3, SquadHUD 1.1 · Mode: Wired
- PortalHUD (new LocalScript): top-centre banner "SAFE AREA · NO FIGHTING HERE" in the zone; on leaving "FIGHTING ON" with
  "PROTECTED 3..1" during the guard; the countdown panel (mode name, one line, big number, squad chips with ★, "STEP OUT TO
  CANCEL" for the starter, "<LEADER> PICKED THIS" + LEAVE SQUAD button for members -> DinoSquadRequest "leave"); "SAVING..."
  / "TRAVELING TO <MODE>" screen; toasts for notLeader / failed / studio ("TRAVEL WORKS IN THE LIVE GAME") / cancelled.
  Look as the mockup; fonts GothamBlack (FontSwap turns them Silkscreen). Switch PortalHUDEnabled.
- MainMenu 1.23 (HubOn): mode chip hidden; hub PLAY sub "ONTO THE ISLAND" -> "play"; practice / arena PLAY as today; BACK TO
  ISLAND (cyan outline, above PLAY) in practice / arena -> DinoModeRequest "island". Switch MainMenuHubEnabled.
- PracticeLobby 1.3: BACK TO ISLAND button in the bar (HubOn); JOIN RED / AUTO hidden while PrPrivate. Switch
  PracticeLobbyHubEnabled.
- SquadHUD 1.1: ★ after the leader's name (panel + health rows); shows in every kind where SquadsLive.
**Acceptance:** screenshots PC + Studio phone view of: the hub menu, islet spawn view, the banner in / out, a solo countdown,
the member countdown (test hook), the arena / practice menu with BACK TO ISLAND, the practice lobby; switches false = today.

### Task 9 — QA, docs, live checks
- Full Studio pass per kind; frame time with the zone loop; zz = 0; test attributes back to nil.
- VERSIONS / ATTRIBUTES rows; plan build notes.
- Live (after Publish, Kepu): solo to ARENA, solo to BOTS, back to island from each; a squad of 2+ to ARENA and BOTS (same
  server, same squad, same team); islet safe area with another player.

## Red-team (2026-11-11, Kepu's answers 18:0x)
| # | Risk | Result |
|---|---|---|
| R1 | Teleports don't run in Studio: squad travel is first seen live | Accepted. HubTravel is isolated, HubTest hook covers everything up to the teleport; HubEnabled false = today's game. Live check list in Task 9. |
| R2 | A party can split (one member's teleport fails) | Mitigated: squad rebuilt on arrival by key for 60 s; a failed member gets "failed" and stays on the islet. |
| R3 | "Ends early if you attack" needs every ability server | Kepu: "Yes, both ways". The guard protects both ways for 3 s (no ability server edits). |
| R4 | Public 5v5 practice with strangers goes away | Kepu: "Yes, private". Bots match = one reserved server per party. |
| R5 | The islet is tight (sea corner ~300 x 300 inside the walls) | Mitigated: Task 5 builds it first; screenshots to Kepu before Task 6 wires it. Moving the walls stays do-not-touch. |
| R6 | The safe rule lives in SquadRules.sameChar (server): ally-only effects (heals, buffs) may reach strangers on the islet | Accepted: only while one of the two is HubSafe and only in the hub; clients unchanged. |
| R7 | Studio default becomes the hub | Accepted: QA sets ModeTestPractice / ModeTestArena per kind and back to nil. |
Scope: Kepu "Keep everything".
