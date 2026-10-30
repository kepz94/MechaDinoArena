# Mecha Dino Arena — Main Menu v1.0 (Sandbox / Arena + Dino Select)

**Goal:** a main menu shown on join (and from a MENU button) where the player picks SANDBOX or ARENA and, on the same screen, picks a dino, sees it (plain or with its mech parts) and edits its loadout. Arena = PvP on the same island with no bots.
**Intent (Kepu 2026-10-29):** "a main menu that says sandbox and then arena which would include PvP. Also a Dino select screen. It would show the current selected Dino and if someone clicks on it it'll be the Dino with the attachments ... keep the same kinda block design and just real simple but also gamey and correctly spaced out layout that takes into account how it looks both on pc and phone" / "you can customize the Dino with the mecha parts or select other Dino's" / "The arena will be the same island with no bots".
**Chosen direction:** mockup `docs/mockups/main_menu_options.html` — **A · One-screen lobby** (dino stage + name + ◀ ▶ + loadout slots on the left; title + SANDBOX / ARENA on the right; tap the dino = plain ↔ mech view). **MENU button replaces the "RAPTOR ▾" pill.**
**Architecture:** two places in the same experience, one place file published to both. Sandbox place (84022023159448) = today's island with bots, no player-vs-player damage. Arena place (75433819286625, "Mecha Dino Arena - Arena") = the same file; a gate keeps BotServer off and a PvP bridge lets bite / pounce / blade hurt players. Both places open the same menu on join; the other mode's button teleports.

## Red-team outcome (Kepu 2026-10-29)
| Challenge | Kepu's answer | Result |
|---|---|---|
| Sandbox + Arena players sharing one server | Separate Arena place, same island, no bots | Two places; no per-player bot rules; **BotServer code untouched** |
| BotServer target filter | No, leave BotServer | Dropped. Bots are kept off in Arena by not starting BotServer (Enabled property), not by code |
| How the Arena place is built | One file, published to both | PlaceGate script picks the mode from `game.PlaceId`; every release is published twice |
| Arena would have almost no combat (bite / pounce / blade only hurt bots today) | Add player damage in this plan | ArenaPvP bridge (Task 5), Arena place only |
| Dino switch in the menu | Respawn behind the menu | ◀ ▶ = existing DinoSpeciesRequest (2 s cooldown); menu re-parks the new body |
| Arena join | Same menu | Menu on join in both places |
| Where the dino waits in the menu | No preference | Recommended default: lobby pad out of play |

**Accepted risks / notes**
- Teleports do not run in Studio. Studio tests use the test switch `ModeTestArena`; the real hop is checked in the live game after publish.
- Every release = install once, File > Publish (Sandbox), then File > Publish As > Mecha Dino Arena > "Mecha Dino Arena - Arena" > Overwrite. Checked 2026-10-29: Studio stays bound to the Sandbox place after Publish As ("you are still editing Mecha Dino Arena"), so no publish back is needed.
- GrowthServer XP / level is session-only (DINO-10 still open), so it resets on a place hop. Skill XP, steps and loadouts are in DataStore `MDA_Skills_v2` (experience-wide) and carry over.
- Save race on hop: SkillServer saves changed data at most every 10 s and on leave. ModeServer waits for the save before teleporting (Task 3); SkillServer is not changed.

## Global constraints
- Version tags: ModeRules 1.0, PlaceGate 1.0, ModeServer 1.0, MineServer 1.4, ScreechServer 1.4, ArenaPvP 1.0, MainMenu 1.0, ArenaStatus 1.2, ArenaScope 1.10. Each: header vX.Y + changelog, VERSION attribute, docs/VERSIONS.md row, docs/ATTRIBUTES.md entries.
- Every new behaviour behind a switch attribute; switch off = today's behaviour exactly.
- UI style: panels (20,20,26), yellow (255,200,50), orange (255,155,46), FredokaOne titles / Gotham body; Scale layout with px minimums (text ≥ 12 px, tap targets ≥ 40 px), clear of the Roblox top-left buttons; checked at PC (1456×819) and phone (844×390 landscape) sizes from the default camera.
- Tests use your own character, bots and bot-owned / server test hooks only.
- Read booleans with explicit if/else.

## Do-not-touch
BotServer code (only its `Enabled` property changes, via BotServer.meta.json + the place), SkillTree / SkillServer, SpeciesServer, BiteServer, PounceServer, BiteTargetHealth, DinoHealthServer, move scripts, mech part servers except the ModeRules check in MineServer / ScreechServer.

## Deterministic map
**Mode** (`ModeRules.placeMode(placeId, isStudio, testArena)`):
- isStudio and testArena == true → "arena"
- placeId == ARENA_PLACE_ID (ARENA_PLACE_ID ~= 0) → "arena"
- otherwise → "sandbox"

**canAffect(srcIsPlayer, tgtIsPlayer, tgtInMenu, mode)** — may a source hurt / stun / throw a target:
| tgtIsPlayer | tgtInMenu | srcIsPlayer | mode | result |
|---|---|---|---|---|
| false | – | any | any | true (bots, prey, dummies unchanged) |
| true | true | any | any | false |
| true | false | false (bot / test hook) | any | true |
| true | false | true | "arena" | true |
| true | false | true | "sandbox" | false |

**Player menu state** (player attribute `InMenu`):
- join, ModeServerEnabled true → InMenu = true, character parked on the lobby pad (HumanoidRootPart anchored)
- CharacterAdded while InMenu (species switch, death respawn) → parked again
- DinoModeRequest("play") in the place's own mode → InMenu = false, character moved to the SpawnLocation, unanchored
- DinoModeRequest(other mode) → save wait → TeleportAsync → result "teleporting" / "teleportFailed" (stays in menu) / "studio" (Studio: no teleport) / "noArenaPlace" (ARENA_PLACE_ID == 0)
- DinoModeRequest("menu") while playing → InMenu = true, parked
- ModeServerEnabled false → no menu, today's spawn, InMenu never set

## Tasks (build order)

### Task 0 — Arena place (done 2026-10-29)
Created in Studio Asset Manager → Places In Experience → Add New Place, renamed "Mecha Dino Arena - Arena": **place id 75433819286625** (verified with AssetService:GetGamePlacesAsync). Still the empty default place until the first "Publish to Roblox As" (Task 9).

### Task 1 — ModeRules 1.0 + spec · Mode: Logic
**Files:** Create `src/shared/ModeRules.luau` (ServerStorage.DinoArcade.ModeRules), `tools/tests/ModeRules.spec.luau`.
**Produces:** `ModeRules.SANDBOX_PLACE_ID = 84022023159448`, `ModeRules.ARENA_PLACE_ID = 75433819286625`, `placeMode(placeId: number, isStudio: boolean, testArena: boolean?) -> "sandbox" | "arena"`, `canAffect(srcIsPlayer: boolean, tgtIsPlayer: boolean, tgtInMenu: boolean, mode: string) -> boolean`, `currentMode() -> string` (reads game.PlaceId, RunService:IsStudio(), workspace attribute ModeTestArena).
- [ ] Spec covering every row of the two tables above (failing first), then the module, spec PASS, commit.
**Acceptance:** all rows; unknown mode string → canAffect false for player→player.

### Task 2 — PlaceGate 1.0 · Mode: Wired
**Files:** Create `src/server/PlaceGate.server.luau`; modify `src/server/BotServer.meta.json` (add `"properties": {"Enabled": false}`, attributes kept); Studio: BotServer.Enabled = false.
**Consumes:** `ModeRules.currentMode()`.
- sandbox → `BotServer.Enabled = true` (bots start as today). arena → BotServer stays off; Workspace models with `Bitable` / `BiteDummy` that are not player characters are removed at start and when added (count in `PlaceGateRemoved`).
- Diagnostics (script attributes): PlaceMode, PlaceGateState ("sandboxBotsOn" / "arenaNoBots"), PlaceGateRemoved. Switch PlaceGateEnabled (false = BotServer turned on in both, today).
**Acceptance:** Sandbox Play: bots spawn as before (BotServerState unchanged). ModeTestArena = true Play: no bots, no display dinos, BotServer never ran.

### Task 3 — ModeServer 1.0 · Mode: Wired
**Files:** Create `src/server/ModeServer.server.luau`.
**Produces:** RemoteEvent `ReplicatedStorage.DinoModeRequest:FireServer(action)`, action ∈ "play" / "sandbox" / "arena" / "menu"; player attributes `InMenu` (bool), `DinoMode` ("sandbox" / "arena" = the place's mode), `ModeLastResult` ("ok" / "badArg" / "busy" / "saving" / "teleporting" / "teleportFailed" / "studio" / "noArenaPlace").
- Lobby pad: anchored platform "MenuLobbyPad" 600 studs above the SpawnLocation, invisible to the default camera, CanCollide; one parking spot per player.
- "play"/own mode → leave menu; other mode → hop. Hop save wait: ModeServer listens to the existing SkillRequest RemoteEvent (extra connection, read-only) and records the player's last change time; if within 12 s, ModeLastResult = "saving" until SkillSaveState becomes "saved" after that time or 12 s pass; then `TeleportService:TeleportAsync(targetPlaceId, {player})`. 1 request in flight per player ("busy").
- Switch ModeServerEnabled (false = today: no pad, no InMenu).
**Acceptance:** join → parked, untouchable (no bot reaches it); ◀ ▶ respawn → re-parked; play → at spawn; MENU → parked; Studio hop → "studio"; ARENA_PLACE_ID 0 → "noArenaPlace"; recent loadout change → "saving" then teleport.

### Task 4 — Combat hooks · Mode: Wired
**Files:** Modify `src/server/MineServer.server.luau` (1.4), `src/server/ScreechServer.server.luau` (1.4).
**Consumes:** `ModeRules.canAffect`, `ModeRules.currentMode()`, player attribute `InMenu`.
- Before damage / stun / throw / jam on a target: `if canAffect(...) then (existing code) else` skip, set target attribute `ModeBlockedAt` and source attribute `ModeBlockedTarget`. Switches MineModeRulesEnabled / ScreechModeRulesEnabled (false = 1.3).
**Acceptance:** Sandbox: player-owned mine / cannon still hit bots, never players; MineTestDrop (bot owner) still hits your character. Arena (ModeTestArena): unchanged from 1.3.

### Task 5 — ArenaPvP 1.0 · Mode: Wired
**Files:** Create `src/server/ArenaPvP.server.luau`.
**Consumes:** `ModeRules.currentMode()`; existing BiteServer / PounceServer DummyHealth writes; Humanoid health (DinoHealthServer).
- Arena only. Each player character (CharacterAdded, after parenting, so BiteTargetHealth does not adopt it): `Bitable = true`, `DummyMaxHealth = MaxHealth`, `DummyHealth = Health`. When DummyHealth drops by d: `Humanoid:TakeDamage(d)` (ForceField / Energy Shield blocks it), `LastHitBy` / `LastHitAt` from the attacker; then DummyHealth := Humanoid.Health. Kill credit = existing KilledBy… writes. Menu players: not Bitable.
- Test hook: BindableFunction `ArenaPvPTest:Invoke("hit", dmg)` lowers your DummyHealth as a bite would; `ArenaPvPTest:Invoke("target")` spawns a test T-Rex model with a Humanoid bridged the same way, to bite / pounce / blade.
- Diagnostics: ArenaPvPState, character ArenaPvPLastDelta. Switch ArenaPvPEnabled.
**Acceptance:** bite, pounce (latch + ticks), blade bonus damage the test target's Humanoid; kill sets KilledBy; hook hit lowers your health; with Energy Shield on → no damage; no health bar over player characters; Sandbox: player characters never Bitable.
**Stop rule:** if a pounce latch on a Humanoid model fights physics, or BiteTargetHealth adopts player characters, stop and report (both scripts are do-not-touch).

### Task 6 — MainMenu 1.0 · Mode: Wired
**Files:** Create `src/client/MainMenu.client.luau` (StarterPlayerScripts, survives respawn).
**Consumes:** InMenu, DinoMode, ModeLastResult, DinoSpeciesRequest, SkillRequest("slot", n, id), DinoModeRequest.
**Layout (A, from the mockup):** full-screen dimmer; left panel = ViewportFrame stage (clone of your live character, slow turntable; tap = plain ↔ mech: mech shows `Mecha_*` parts, plain hides them; caption "TAP TO SEE MECH" / "TAP FOR PLAIN"), name plate, ◀ ▶ (greyed during the 2 s cooldown), loadout slot row (tap slot → part picker row, as SkillScreen 1.4); right = title "MECHA DINO ARENA", SANDBOX (yellow) and ARENA (orange) block buttons (as the mockup) with one-line subtitles ("Bots · no PvP" / "PvP · no bots"), status line (SAVING… / TRAVELING… / ARENA OPENS IN THE LIVE GAME / COMING SOON). Phone: same two columns, scaled, slots wrap to 2 rows.
- Switch MainMenuEnabled.
**Acceptance:** PC and phone screenshots match the mockup spacing; flip works; ◀ ▶ switch dino and refresh the preview; slot change shows on the preview's mech view; buttons give each ModeLastResult state.

### Task 7 — ArenaStatus 1.2 · Mode: Wired
**Files:** Modify `src/character/ArenaStatus.client.luau`.
- MENU block button in the species pill's place, fires DinoModeRequest("menu"). Switch ArenaMenuButtonEnabled (false = 1.1 pill).
**Acceptance:** visible from the default camera at PC and phone sizes; opens the menu.

### Task 8 — ArenaScope 1.10
Expects ModeRules, PlaceGate, ModeServer, ArenaPvP, MainMenu.

### Task 9 — Publish both places (on Kepu's yes)
Publish → Sandbox; Publish As → Arena place (Studio stays on the Sandbox place). Live check: SANDBOX ↔ ARENA hop, loadout carries over, no bots in Arena.
