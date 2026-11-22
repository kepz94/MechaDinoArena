# Mecha Dino Arena v1.0 (First-Time Flow): build plan (DRAFT, red-team pending)

**Goal:** a new player gets a free random dino with all of its mecha parts maxed, learns the attack, the 4 slots and the
parts on a training bot, levels up once, spends the point, learns what points do, and walks onto the island.
**Chosen direction:** "A + B's cards" (Kepu 2026-11-22 10:28), mockup docs/mockups/first_time_flow_v0.2.html (artifact
"First-Time Flow", version 2). Trainer box + checklist (A) for the training steps; big cards (B) for the welcome, the roll,
the free parts and LEVEL 2. No skip. Old players keep every dino, never see it; a TUTORIAL button in the menu replays it.
**Architecture:** two new server scripts (DinoOwnership owns who owns which dino and the tutorial state, in its own
DataStore; TutorialServer owns the training lanes, the bot, the steps and the one XP grant), one new client script (the
cards, checklist, trainer, prompts), one pure rules module. Existing scripts only get small switched entrances: SkillServer
(free parts count as given), SpeciesServer / RespawnServer (refuse a locked dino), HubServer (no islet placement while in a
lane), MainMenu and the 3 dino pickers (lock badges, TUTORIAL button, hidden during the flow).

## Global constraints
- Every change additive, behind a switch; every number an attribute. Version-brand script headers, docs/VERSIONS.md,
  docs/ATTRIBUTES.md.
- Writing (Kepu 10:25 "sounded like AI too much"): objectives 1 to 5 words; trainer lines under 10 words; no em dashes, no
  "it's not X, it's Y", no rule of three, no sales tags; few exclamation marks. Exact strings are in the mockup v0.2 and in
  Task 5 below; the build uses them verbatim.
- Places: Sandbox 84022023159448 (the hub, where new players land). Arena 75433819286625 never runs the flow.
- Grounding facts used below (main, 2026-11-22): SkillServer 1.12 (save "MDA_Skills_v2", SkillSaveState "loaded" / "new" /
  "noApi" / "failed" / "off"; SkillGrantXp BindableFunction; SkillTestMaxAllEnabled default true), SpeciesServer 1.9
  (DinoSpeciesRequest; lastSpecies in "MDA_Settings_v1"), RespawnServer 1.0 (sets DinoSpecies for respawn picks),
  HubServer 1.6 (islet placement per spawn, re-place checks within 60 studs of the SpawnLocation), ModeServer 1.3 (InMenu on
  join), PracticeBots 1.1 (spawn(spec, team, groundCFrame, folder, opts)), MechaButtons 1.53 (character attribute
  MechaButtonsLastPress "slotN:<id>"), Lab 1.16 (SkillRequest "buy" / "slot"), MainMenu 1.26 (DINOS list: Raptor, TRex,
  Pachy, Herrera, Teno, Therizino, Dilo, Troodon), PregameScreen 1.5, IslandDino 1.0, RespawnScreen 1.0.
- Tests: tools/tests/*.spec.luau run in Studio Edit via execute_luau (no runner in the repo), returning "PASS n".

## Do-not-touch
- SkillServer saving, records, XP maths, buy / slot / respec rules, the test layer itself (only a new given-parts input).
- SpeciesServer templates, spawn functions, cooldown, lastSpecies saving.
- ModeServer, HubTravel, portals, PracticeServer match flow, PracticeBrain, HardpointServer.
- Every ability server and MechaButtons (read-only use of their attributes).
- Lab layout, MainMenu layout (one button and badges added, nothing moved), EggLoader.
- GameSounds and all sound beats.

## Decisions Kepu still owes (from his "Decide later" and the red-team)
1. Dino unlock price (DinoUnlockCost). Until set, the unlock button shows SOON and the gate switch stays off.
2. See the red-team list in the chat reply (test layer, T-Rex, gate timing). Answers are folded in before filing.

## Deterministic map
Player tutorial state = DinoOwnership attribute `TutState`:
- `"wait"`: join, both stores not read yet. Menu waits (no flash of the menu for a new player).
- `"grand"`: ownership store has no value AND SkillSaveState == "loaded" (has a v2 skills record) -> owns all 8, tut done,
  written once. Never sees the flow.
- `"done"`: ownership value with tut.done == true -> normal game.
- `"new"`: ownership store has no value AND SkillSaveState == "new" -> the flow starts at step 1.
- `"resume"`: ownership value with tut.done ~= true -> the flow restarts at step 3 with the dino already rolled (the roll
  and the free parts are kept; welcome / roll / parts cards are not shown again).
- `"off"`: OwnershipEnabled false, or SkillSaveState / store read "noApi" / "failed" / "off" -> owns all, no flow, nothing
  written (a DataStore outage never locks anyone out or forces the flow).
- Studio test: Workspace attribute TutorialTestForce = true -> "new" for every joiner, nothing written.
- Replay (TUTORIAL button, state "done" or "grand"): steps 3 to 10 with the current dino; no roll, no free parts, no XP
  grant; step 8 shows only when SkillLeft > 0, else it is ticked as done with the line "No points to spend." and NEXT.

Steps (TutorialServer is the judge of 2, 7; the client of 4, 5, 6, 8; cards advance on their button):
| # | Objective (checklist) | Done when | Server action |
|---|---|---|---|
| 1 | Welcome | ROLL pressed | none |
| 2 | Roll | server answers the roll | pick 1 of the roll pool at random, OwnedDinos = {it}, FreeDino = it, write |
| 3 | Parts | TO TRAINING pressed | lane reserved, player spawned as the free dino in the lane, target bot spawned |
| 4 | Hit the bot | bot DummyHealth drops (client sees the replicated attribute) | none |
| 5 | Equip 4 parts | SkillSlot1..4 all non-empty | slots via SkillRequest "slot" (existing judge) |
| 6 | Use each part | MechaButtonsLastPress showed each slot 1..4 once | none |
| 7 | Defeat the bot | bot KilledAt set | bot health set low at step 7 start; on KilledAt: SkillGrantXp(player, xpToNext(level), "training") |
| 8 | Spend your point | SkillSpent increased | buy via SkillRequest "buy" (existing judge) |
| 9 | Skill points | GOT IT pressed | none |
| 10 | Island | GO TO THE ISLAND pressed | tut.done = true, write, lane freed, bot removed, LoadCharacter (islet spawn) |
Before step 7 the bot cannot die: its DummyMaxHealth / DummyHealth = TutBotSafeHealth (100000), refilled to max whenever it
drops under half. At step 7 start: DummyHealth = TutBotFinishHealth (40). Its SkillXpMul = 0 (the grant is the only XP).
Leaving mid-flow: lane and bot freed; state stays "resume". Death in the lane: respawn placed back in the lane, same step.

## File structure
| File | New / extend | Responsibility |
|---|---|---|
| src/shared/TutorialRules.luau | New | Pure: classify(), rollPick(), STEPS, OBJECTIVES, nextStep(), laneCFrame() |
| tools/tests/TutorialRules.spec.luau | New | Spec for the above |
| src/server/DinoOwnership.server.luau | New | Store "MDA_Owned_v1": owned set, free dino, tut state; attributes; remote DinoOwnRequest |
| src/server/TutorialServer.server.luau | New | Lanes, bot, steps, the XP grant, TutorialRequest remote |
| tools/training_ground_install.luau | New | Builds ServerStorage.TrainingGround (one lane model) in Studio |
| src/client/Tutorial.client.luau | New | Cards, checklist, trainer, prompts, ring + arrow, equip panel, stat panel |
| src/server/SkillServer.server.luau | Extend 1.13 | Player attribute FreeDino -> that dino's live parts count as given (like the test parts) |
| src/server/SpeciesServer.server.luau | Extend 1.10 | Refuse a dino not in OwnedDinos ("locked") when the gate is on; join default = an owned dino |
| src/server/RespawnServer.server.luau | Extend 1.1 | Same refusal for respawn picks |
| src/server/HubServer/init.server.luau | Extend 1.7 | Skip islet placement while the player has TutLane > 0 |
| src/client/MainMenu.client.luau | Extend 1.27 | Hidden while TutActive; TUTORIAL button; lock badge on locked dinos |
| src/client/PregameScreen.client.luau, IslandDino.client.luau, RespawnScreen.client.luau | Extend 1.6 / 1.1 / 1.1 | Lock badge; SELECT on a locked dino shows "LOCKED" |

## Tasks (build order)

### Task 0 — TutorialRules 1.0 + spec · Mode: Logic
**Files:** create src/shared/TutorialRules.luau (Rojo -> ServerStorage.DinoArcade.TutorialRules, cloned to
ReplicatedStorage.TutorialShared by TutorialServer), create tools/tests/TutorialRules.spec.luau.
**Interfaces (produces):**
- `classify(ownValue: table?, readOk: boolean, skillState: string, enabled: boolean, force: boolean) -> "grand"|"done"|"new"|"resume"|"off"`
  (the map above, first matching row: not enabled -> "off"; force -> "new"; not readOk -> "off"; skillState not in
  {"loaded","new"} -> "off"; ownValue table with tut.done -> "done"; ownValue table -> "resume"; skillState "loaded" ->
  "grand"; else "new").
- `rollPick(pool: {string}, r: number) -> string` (r in [0,1); pool[floor(r * #pool) + 1]; empty pool -> nil).
- `ALL_DINOS = {"Raptor","TRex","Pachy","Herrera","Teno","Therizino","Dilo","Troodon"}`; `ROLL_POOL` = Kepu's answer to
  red-team point 2.
- `STEPS = {"Welcome","Roll","Parts","Hit the bot","Equip 4 parts","Use each part","Defeat the bot","Spend your point","Skill points","Island"}`
- `startStep(state: string, replay: boolean) -> number` ("new" -> 1, "resume" -> 3, replay -> 3).
- `laneCFrame(origin: CFrame, lane: number, spacing: number) -> CFrame` (origin * CFrame.new((lane - 1) * spacing, 0, 0)).
- [ ] Write the spec: every classify row, rollPick at r = 0 / 0.999 / empty pool, startStep 3 cases, laneCFrame lane 1 and 3.
- [ ] Run it in Studio Edit -> FAIL (module missing).
- [ ] Write the module -> spec PASS.
- [ ] Commit.
**Acceptance:** spec returns "PASS n" with every map row covered.

### Task 1 — DinoOwnership 1.0 · Mode: Wired
**Files:** create src/server/DinoOwnership.server.luau.
**Interfaces:**
- Consumes: TutorialRules.classify / rollPick / ALL_DINOS / ROLL_POOL; player SkillSaveState (SkillServer).
- Produces: player attributes `OwnedDinos` ("Herrera" or comma list), `FreeDino` ("" or key), `TutState`, `TutActive`
  (bool); BindableFunction `OwnRoll(player) -> key?`, `OwnFinishTut(player) -> boolean` (children of the script, for
  TutorialServer); script attributes `OwnershipEnabled` (default true), `OwnGateEnabled` (default false), `DinoUnlockCost`
  (nil = SOON), diagnostics `OwnSaveState`, `OwnGrandfathered` (count).
- Store "MDA_Owned_v1", key "u"..UserId, value `{v = 1, owned = {[key] = true}, free = key, tut = {done = bool, at = unix}}`.
- [ ] Join: read the store (pcall), wait for SkillSaveState ~= "loading" (max 15 s, then treat as "failed"), classify.
- [ ] "grand": owned = all 8, tut.done = true, write once, OwnGrandfathered += 1.
- [ ] "new" / "resume": TutActive = true; OwnRoll picks once (a second call returns the stored free dino), writes, sets
      DinoSpecies = the free dino.
- [ ] OwnFinishTut: tut.done = true, write, TutActive = false.
- [ ] Writes use UpdateAsync, retried every 30 s on failure; on leave a final write.
- [ ] Commit.
**Acceptance:** in Studio with API access: a fresh key -> "new"; a key with an MDA_Skills_v2 record -> "grand" and all 8
owned; a second join after finishing -> "done"; Studio without API access -> "off", owns all, no flow. Two rolls -> same
dino.
**Out of scope:** the unlock purchase (decision 1).

### Task 2 — SkillServer 1.13 free parts · Mode: Wired
**Files:** modify src/server/SkillServer.server.luau (testParts / buyBase / stepsFor gain one input; header, VERSION).
**Interfaces:** consumes player attribute FreeDino; switch script attribute `SkillFreePartsEnabled` (default true, read per
publish); republish the player when FreeDino changes.
- [ ] `freeParts(player, d)`: when the switch is on and d.active == FreeDino -> the same LIVE_MECH list testParts builds
      for that dino; merged into stepsFor (at 4) and buyBase (given, left out of points and mastery, buy refused "maxed").
- [ ] Placed once into empty slots exactly like the test parts (d.testPlaced).
- [ ] Never stored: d.steps and the save stay the real record (same rule as 1.4 to 1.11).
- [ ] Commit.
**Acceptance:** with SkillTestMaxAllEnabled false: FreeDino = "Herrera" shows every Herrera part at star, stats at their
real steps, SkillLeft unchanged; another dino shows its real build; FreeDino = "" -> 1.12 exactly.
**Out of scope:** the test layer's own rules.

### Task 3 — Training ground + TutorialServer 1.0 · Mode: Wired
**Files:** create tools/training_ground_install.luau, src/server/TutorialServer.server.luau.
**Interfaces:**
- Consumes: OwnRoll / OwnFinishTut (Task 1), SkillGrantXp (SkillServer 1.10), PracticeBots (ServerScriptService.
  PracticeServer.PracticeBots), TutorialRules.
- Produces: RemoteEvent `TutorialRequest` (client -> server: "roll", "toTraining", "step", n, "island", "replay");
  player attributes `TutStep` (1..10), `TutLane` (0 = none), `TutBot` (bot model name), `TutLastResult`; script
  attributes `TutorialEnabled` (true), `TrainingOrigin` (CFrame as Vector3 position, default (0, 600, 4000)),
  `TrainingLanes` (8), `TrainingSpacing` (300), `TutBotSafeHealth` (100000), `TutBotFinishHealth` (40), `TutBotSpecies`
  ("Pachy"), `TutBotDistance` (28).
- Layout of a lane (install script): a 120 x 120 grass pad, fence ring, a "TRAINING" sign, player spawn mark at the south
  edge facing north, bot mark 28 studs north. Lanes are copies at TrainingOrigin + (lane - 1) x 300 on X.
- [ ] Install script builds ServerStorage.TrainingGround once (Edit mode), run and saved in the place.
- [ ] "roll" -> OwnRoll; "toTraining" -> free lane (none free -> TutLastResult "full", the client retries every 3 s),
      LoadCharacter as the free dino, place at the lane spawn after the body loads, spawn the bot (passive: no brain,
      SkillXpMul 0, safe health), TutStep = 4.
- [ ] Health guard per Heartbeat while TutStep < 7 (refill under half). "step", 7 -> finish health.
- [ ] Bot KilledAt -> SkillGrantXp(player, SkillTree.xpToNext(SkillLevel), "training") (not on replay), TutStep = 8.
- [ ] "island" -> OwnFinishTut (not on replay), free lane, remove bot, LoadCharacter.
- [ ] PlayerRemoving / leave mid-flow -> free lane and bot.
- [ ] Commit.
**Acceptance:** new player reaches step 10 with level 2 and 1 point on the free dino; bot cannot die before step 7 (a
mortar / sentry / any part); 2 players get 2 lanes; leaving frees the lane; death respawns in the lane; replay grants no XP.
**Out of scope:** PracticeServer, PracticeBrain.

### Task 4 — HubServer 1.7, SpeciesServer 1.10, RespawnServer 1.1 · Mode: Wired
**Files:** modify the three server scripts (headers, VERSION).
- [ ] HubServer: per spawn, TutLane > 0 -> skip islet placement and the re-place checks (switch HubTutorialSkipEnabled,
      default true).
- [ ] SpeciesServer: OwnGateEnabled true and species not in OwnedDinos -> SpeciesLastResult "locked", no switch; join
      default (lastSpecies / SpeciesDefault) not owned -> the free dino (switch SpeciesGateEnabled, default true; the gate
      itself only acts while OwnGateEnabled).
- [ ] RespawnServer: the same refusal for a respawn pick (RespawnLastResult "locked").
- [ ] Commit.
**Acceptance:** gate off -> 1.6 / 1.9 / 1.0 exactly; gate on -> a locked pick from every picker is refused, the owned one
works; a death still respawns through the T-Rex step (internal LoadCharacter is not a pick).

### Task 5 — Tutorial client 1.0 · Mode: Wired
**Files:** create src/client/Tutorial.client.luau.
**Interfaces:** consumes TutActive, TutStep, FreeDino, SkillSlot1..4, SkillSpent, SkillLeft, MechaButtonsLastPress,
the bot's DummyHealth, TutorialRequest.
**Layout (from the mockup v0.2, ScreenGui DisplayOrder 30, above MainMenu):**
- Cards (steps 1, 2, 3, 7's level-up, 9, 10): centered panel 56% wide (80% on phones), yellow title, one line under it, one
  yellow button. Step 9's card sits right of the checklist (left 59%, width 72% of the safe area on PC).
- Checklist: top left panel, title "TRAINING", rows ✓ green / ▸ white / · grey.
- Trainer box: bottom center, portrait + "TRAINER" + the line.
- Prompt: top center, key chip + action ("CLICK Slash", "R Tail Grab & Fling"; phone "Tap ATTACK").
- Ring under the bot and an arrow over it on steps 4, 6, 7.
- Equip panel (step 5) and stat panel (step 8): the mockup's small Lab; buttons send SkillRequest "slot" / "buy".
**Strings (verbatim):** "WELCOME!" / "Your first dino is free." / ROLL; "YOUR FREE DINO" reel; "<DINO>!" / "It's yours.
More dinos unlock with skill points."; "6 MECHA PARTS" (the count) / "All maxed out." / TO TRAINING; "See that bot? Hit it
with your <attack>."; "Pick 4. <n> left." / "Good. Now try them."; "Now try your parts."; "Finish it!"; "LEVEL 2" / "+1
skill point" / SPEND IT; "Spend your point." / "Tap + on a stat." / "<Stat> went up."; "SKILL POINTS" / "1 every level." /
UPGRADE STATS "Health, attack, armor, speed." / UPGRADE PARTS "Parts go from I to ★." / UNLOCK DINOS "Points from any dino
count." / GOT IT; "TRAINING DONE" / "Level <n> <Dino>" / GO TO THE ISLAND.
- [ ] Build the screens per step; advance on the map's conditions; send "step", n for 4, 5, 6, 8.
- [ ] Commit.
**Acceptance:** the full flow on PC and on phone emulation matches the mockup v0.2 screens; the attack prompt names each
dino's own input (Raptor F, the others left click, phone ATTACK); nothing else on screen takes clicks during cards.

### Task 6 — MainMenu 1.27 + pickers · Mode: Wired
**Files:** modify MainMenu, PregameScreen, IslandDino, RespawnScreen (headers, VERSION).
- [ ] MainMenu hidden while TutActive or TutState == "wait"; a TUTORIAL button under MUSIC (same size and style) sends
      TutorialRequest "replay" (shown when TutState is "done" or "grand"; switch MainMenuTutorialEnabled).
- [ ] Lock badge (🔒 + the dino name dimmed) on dinos not in OwnedDinos, only while OwnGateEnabled; ◀ ▶ still browse;
      PLAY on a locked dino shows "LOCKED" and does nothing. Same badge in the 3 pickers.
- [ ] Commit.
**Acceptance:** gate off -> every screen as before (screenshot compare); gate on -> locks shown, only owned dinos selectable.

### Task 7 — Live check · Mode: Wired
- [ ] Studio: TutorialTestForce run through all 10 steps for 3 different rolled dinos (one melee, one ranged, Raptor for F).
- [ ] Restore the test setup (species Therizino, slots, bots, attributes, health).
- [ ] Docs: VERSIONS.md rows, ATTRIBUTES.md entries. Commit. Publish only on Kepu's "Publish".
