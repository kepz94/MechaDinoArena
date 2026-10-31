# Mecha Dino Arena v1.0 — Arena squads

**Goal:** in the Arena, players squad up (up to 4). Squadmates can't harm each other in any way. They see each other's health, respawn near each other, and Med Stations heal them too.

**Intent (Kepu 2026-10-31):**
- "for arena allow for a teams mode where you can squad up with other players turning friendly fire off. Just have a button under skills that allows me to send an invite to someone to squad up. Also lets me unsquad with that person and shows me their health when we're squadded up"
- "Also allow heals to work for both of us like the patchy heal mine"

**Picks:**
- Up to 4 per squad.
- Friendly fire: "Everything harmful".
- Respawn near a squadmate.
- Health HUD: "A · Under my health".
- Unsquad: "Leave the squad".

**Chosen direction:** A · Under my health. Prototype: docs/mockups/arena_squads_options.html.

**Architecture:**
- A pure shared module, `SquadRules`, answers "are these two on the same squad".
- A new `SquadServer` owns the squads: invites, joins, leaves.
- Each existing harm path gets one squad check at the point where it picks a target. Each check sits behind a switch, with result `"squad"` or a skip.
- A new client `SquadHUD` draws the SQUAD button, the panel, the invite card, the health rows and the over-head tags.

## Global constraints
- Additive only. Each changed script gets:
  - a new version, header line and VERSION constant;
  - its own switch attribute, default true; false gives the old behaviour;
  - rows in docs/VERSIONS.md and docs/ATTRIBUTES.md.
- Arena only. With ModeRules.currentMode() ~= "arena":
  - SquadServer refuses everything ("notArena");
  - SquadHUD shows nothing;
  - SquadRules.same is false, so nothing changes in the Sandbox.
- Testing:
  - Never test with a second player. Squad tests use SquadServer's server-only test hook with ArenaPvP's test target.
  - Test PC, gamepad and phone (forced touch) before publish.
- Install by multi_edit, verify by hash, commit and push each change. Publish only on Kepu's "publish".

## Do-not-touch
- **ModeRules.canAffect:** its signature and rows stay as they are. The squad check is added beside it in the callers, not inside it.
- **ArenaPvP's bridge maths:**
  - `Bitable` stays a per-character switch;
  - ArenaPvP is not changed in v1.0 (see red-team note R2).
- **RoarServer's existing gaps** stay as they are: it has no Bitable / ModeRules / InMenu gate. v1.0 only adds the squad skip.
- **BoneCrest:** not changed. Its reflect / visor effects never run because the squad check comes first in the callers.
- **Combat numbers, cooldowns, aim maths.** Only the target filters change.

## Data
| Where | Attribute | Type | Writer | Meaning |
|---|---|---|---|---|
| Player | SquadId | string ("" = none) | SquadServer | squad key = the founder's UserId .. "_" .. a counter |
| Player | SquadInviteFrom / SquadInviteFromName / SquadInviteUntil | number / string / server time | SquadServer | pending invite shown to this player (one at a time; a newer invite replaces it) |
| Player | SquadInvitedAt_<userId> | server time | SquadServer | the last invite this player sent to <userId> (5 s re-invite guard) |
| Player | SquadResult / SquadResultAt | string / time | SquadServer | last request result (diagnostic, last) |
| Model | SquadTestId | string | SquadServer test hook | ArenaPvP's test target counts as a member of that squad |
| ReplicatedStorage | SquadsLive | bool | SquadServer | true in the Arena with SquadServerEnabled |
| ReplicatedStorage | SquadShared (ModuleScript) | | SquadServer | a clone of SquadRules for clients (the SkillShared pattern) |

## Task S1 — SquadRules 1.0 + SquadServer 1.0 · Mode: Logic (SquadRules) + Wired (SquadServer)
**Files**
- Create `src/shared/SquadRules.luau`. It lives in ServerStorage.DinoArcade.SquadRules and is cloned to ReplicatedStorage.SquadShared.
- Create `src/server/SquadServer.server.luau`.
- Create `tools/squad_rules_test.luau`: a Studio loadstring test for the pure functions.

**Interfaces**
- `SquadRules.MAX = 4`
- `SquadRules.same(plA: Player?, plB: Player?) -> boolean`: true when both are players, plA ~= plB, both SquadId are non-empty and equal, and ReplicatedStorage.SquadsLive == true.
- `SquadRules.idOf(model: Model?) -> string`: the player's SquadId, or the model's SquadTestId, or "".
- `SquadRules.sameChar(a: Model?, b: Model?) -> boolean`: a ~= b and idOf(a) ~= "" and idOf(a) == idOf(b) and SquadsLive.
- `SquadRules.members(squadId) -> {Player}`: players whose SquadId == squadId.
- Remote `ReplicatedStorage.DinoSquadRequest:FireServer(action: string, targetUserId: number?)`, where action is "invite" | "accept" | "decline" | "leave".

**Server rules (first failing check wins; result goes to the player's SquadResult)**
- **invite:**
  - Refused with: "notArena", "badArg", "menu" (sender InMenu), "self", "noTarget" (not in the server), "targetMenu", "same" (already your squadmate), "full" (sender's squad has 4), "inSquad" (target is in another squad), "cooldown" (5 s guard).
  - ok: target gets SquadInviteFrom / FromName / Until = now + 15.
- **accept:**
  - Refused with: "noInvite" (none, or expired), "gone" (inviter left or is in the menu), "full".
  - ok: the accepter leaves any old squad (the "leave" rules). If the inviter has no SquadId, a new one is made and set on the inviter. The accepter gets the inviter's SquadId. The invite attributes are cleared.
- **decline:** clears the invite attributes; "ok".
- **leave:** SquadId = "". A squad left with 1 member is dissolved: that member's SquadId becomes "".
- **Automatic leave:** InMenu turns true, or PlayerRemoving. A death keeps the squad.
- **Test hook:** BindableFunction "SquadTest" under the script (server only).
  - `Invoke("join", player, model)` sets player.SquadId (made if empty) and model.SquadTestId to the same id, so ArenaPvP's test target is a "squadmate".
  - `Invoke("clear", player, model)` clears both.

**Switch:** SquadServerEnabled (default true, read at start).

**Diagnostics:** script SquadServerVersion, SquadRequests, SquadSquads (live count).

**Acceptance**
- The pure tests pass:
  - same / sameChar for: nil, the same player, two players with no squad, the same squad, different squads, SquadsLive false, and the test target.
- Invite → accept → both SquadId equal.
- A 5th accept → "full".
- Leave dissolves a 2-squad.
- Going to the menu leaves the squad.
- Sandbox: every request → "notArena".

## Task S2 — Friendly fire, server gates · Mode: Wired
Each script gets `local SquadRules = require(DinoArcade.SquadRules)`, a switch `<Script>SquadEnabled` (default true, read at each check) and one check at the point below. Lines are as of HEAD f6feda1 and must be re-grounded.

| Script → version | Where | Check |
|---|---|---|
| BiteServer 1.10 | claim handler 340-371 (after the target check 350-354); request aim target 406-409; sweep in checkHit 283-290 | refuse "squad" / skip a squadmate |
| PounceServer 1.13 | claim chain 360-365, a new row after "busy" and before the visor block (377/388) | "squad" |
| SlashServer 1.6 | hit claim 390-413 ("squad" after "self"); dive target 293-315 (treated as no target); burst loop 464-479 (skip) | |
| HeadbuttServer 1.13 | hit chain 443-460, before the visor check 461 | "squad" |
| HookServer 1.8 | candidates 165-179 and the smash re-check 374 | skip a squadmate (the shot goes past them) |
| RoarServer 1.2 | sweep loop 133-150 | skip a squadmate |
| InkServer 1.6, TetherServer 1.3, MineServer 1.8, ScreechServer 1.11, HerreraMovesServer 1.1/1.2 | their `mayAffect(source, target)` | `and not SquadRules.sameChar(source, target)` (Mine: the owner character; Screech: b.shooter) |
| HerreraMovesServer | quill arrival re-check (246) | adds the mayAffect re-check (squad and mode) |
| SkillEffects 1.29/1.30 | findBridgedPlayer 554-563 | skip a squadmate (backstop for bleed) |

**Acceptance (in Studio, ArenaPvP test target joined via SquadTest)**
- A bite, pounce, slash, headbutt, hook, roar, ink, tether, mine, Shock Cannon, quills, strobe, smoke ★, breaker push, caltrops and goo on the test target: no damage and no effect attribute set.
  - Server results read "squad" where the table says so.
  - The same moves on it after `clear` work as before.
- Bots are unchanged.
- The Sandbox is unchanged.

## Task S3 — Friendly fire, clients · Mode: Wired
Squadmates are skipped by the client target finders, so no local latch, no stopped charge and no aim-assist onto a friend:
- BiteTest 1.7: aimCandidates / chooseAim / claimHit.
- PounceTest 1.7: findTargets.
- SlashTest 1.5: findTargets / diveTarget / contact loop.
- HeadbuttTest 1.2: findTargets / contact.

Each uses `ReplicatedStorage.SquadShared` and the switch `<Script>SquadEnabled`.

Visibility (v1.0):
- TreeTopHide 1.2: never hides a squadmate's GUIs from you (tree tops and smoke).

Deferred to Squads v1.1 (red-team R4, Kepu "Defer to v1.1"):
- CloakFX 1.5: a cloaked squadmate shows to you as your own cloak does.
- ScentFX 1.1: no paw prints for squadmates.
- MineColors 1.1: a squadmate's mines are BLUE, like your own.

**Acceptance**
- With the test target as a squadmate:
  - pouncing it doesn't latch locally;
  - a headbutt passes through without stopping;
  - bite aim-assist ignores it.
- Its smoke and tree-top hiding don't hide its bars from you.

## Task S4 — Squad heals + squad spawn · Mode: Wired
**MedStationServer 1.2**
- Every TICK, for each other character whose player SquadRules.same(owner, them) holds (or the SquadTestId model), alive, with its root within the pad's radius (flat):
  - heal at the same rate × its own MaxHealth, capped;
  - the "+N" pop over it;
  - character MedSquadHealed (total), MedSquadInside.
- The owner rules are unchanged.
- Switch: MedStationSquadHealEnabled.

**ArenaSpawnServer 1.2**
- Before the 1.1 rules: when the player has a live squadmate (alive, not InMenu, root known):
  - try NEAR_TRIES spots 30–60 studs from a random live squadmate, with the 1.1 ground / clear checks;
  - non-squad live players must be ≥ 60 studs away;
  - face toward the squadmate.
- If that fails, use the 1.1 rules.
- Player ArenaSpawnKind "squad", ArenaSpawnNearTo = the squadmate's name.
- Switch: ArenaSpawnSquadEnabled.

**Acceptance**
- The test target as a squadmate, standing in a Med Station circle, gains health; outside it, it gains none.
- Respawn with a live squadmate lands 30–60 studs from it (ArenaSpawnKind "squad").

## Task S5 — SquadHUD 1.0 · Mode: Wired
**Files:** create `src/client/SquadHUD.client.luau` (StarterPlayerScripts; ResetOnSpawn false). It shows only while ReplicatedStorage.SquadsLive and player InMenu ~= true.

**Layout (mockup A, measured on the phone capture)**
- **SQUAD pill:** ScreenGui "SquadButton" (DisplayOrder 6, DeviceSafeInsets).
  - Same look as the SKILLS pill: PANEL (20, 20, 26) at 0.18, white stroke 0.5 / 1.5 px, FredokaOne 18, height 36, padding 12.
  - Right-aligned with the SKILLS pill: it follows LabButton.Skills' AbsolutePosition / AbsoluteSize each 0.5 s. y = the SKILLS bottom + 8.
  - Text "SQUAD", then 4 dots (8 px) once in a squad: green (120, 200, 80) for each member, grey (58, 69, 86) for each free place.
  - Tap or PC key G toggles the panel. ShoulderCam keeps the mouse locked, so it is clickable with Left Alt held, like SKILLS. While the panel is open the mouse is free (the LeaveConfirm RenderStep pattern).
- **Panel:** under the pill, right-aligned, width min(40% of the screen, 330 px). From the top:
  - header "SQUAD" + "n / 4" (yellow);
  - "IN YOUR SQUAD": one row per member, ◆ name + "DINO · h / max HP", and a green "SQUADMATE" tag;
  - a red (224, 40, 74) "LEAVE SQUAD" button, only while in a squad;
  - "ON THE ISLAND": every other player not in the menu, name + species, with a button that reads one of:
    - yellow INVITE;
    - dark "INVITED…" (5 s);
    - grey "IN A SQUAD" (another squad);
    - grey "SQUAD FULL".
  - Scrolls past 6 rows.
- **Invite card:** full-screen dim (the LeaveConfirm style, DisplayOrder 30).
  - Card width 80% (max 340 px) with a yellow stroke, "SQUAD INVITE", "<name> wants to squad up." / "No friendly fire, respawn together.", and a 15 s yellow time bar.
  - Buttons: NO (dark) and JOIN (yellow). It times out to NO.
- **Health rows:** inside PlayerGui.ArenaStatus.BarsBL, rows with LayoutOrder −4..−1, so they sit above HEALTH; one per squadmate in join order. Each row:
  - label 12 px, green (156, 240, 138): "◆ name"; right side "h / max", or "DOWN · respawning" while dead;
  - an 8 px bar in the HEALTH bar's colours (green, red below 30%).
  - Rows are re-added when ArenaStatus is rebuilt (on respawn).
- **Over-head tag:** BillboardGui "SquadTag" (this client only), AlwaysOnTop, on each squadmate's Head (or HumanoidRootPart), StudsOffset (0, 4 × scale, 0): a green ◆ + name, 14 px.
- **Toasts:** "Invite sent to X", "X joined your squad", "You left the squad", "X is in another squad". Shown at the top centre for 2.2 s.

**Switch:** SquadHUDEnabled.

**Diagnostics:** player SquadHUDVersion, SquadHUDPanel ("open" / "closed"), SquadHUDRows.

**Acceptance**
- PC, gamepad and phone (forced touch, the ArenaTouch styled table) show the pill under SKILLS.
- The panel opens; INVITE sends; the invite card shows on the invitee (simulated by setting SquadInviteFrom* on yourself in Studio); JOIN sends accept.
- The rows show the test target's health and update on damage and heals.
- LEAVE clears everything.
- Nothing shows in the Sandbox or in the menu.

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Not Arena | mode ~= arena | no HUD; requests "notArena"; same() false |
| Solo | SquadId "" | pill "SQUAD", no dots, no rows, no tags |
| Invite | all checks pass | target sees the card 15 s |
| Invite refused | menu / self / noTarget / targetMenu / same / full / inSquad / cooldown | toast with the reason, no card |
| Accept | valid, inviter present, room left | joined; the old squad is left first |
| Accept late | expired / gone / full | toast, no join |
| Decline / timeout | | card closes, nothing changes |
| In a squad | SquadId set, ≥ 2 members | dots, rows, tags; harm checks skip squadmates; Med Station heals them; respawn near them |
| Squadmate dead | Humanoid health 0 | row "DOWN · respawning", tag hidden; still in the squad |
| Leave / menu / quit | | SquadId ""; a 1-member squad is dissolved |
| Hidden caltrops (Herrera ★) | Hidden true | drawn for the owner + squadmates (SquadRules.same) |

## Tickets
S1 MDA-158, S2 MDA-159, S3 MDA-160, S4 MDA-161, S5 MDA-162, v1.1 polish MDA-163. ADR-006.

## Red-team synthesis (Kepu 2026-10-31)
| # | Challenge | Outcome |
|---|---|---|
| R1 | 13 server + 4 client scripts each need the squad check; one missed path = friendly fire | Kept. Mitigation: S2 / S3 acceptance runs every move against the SquadTest squadmate before publish. Rule for every future part: pick targets through `candidates` / `mayAffect` with the squad check. |
| R2 | The DummyHealth bridge can't tell who is attacking, so there's no single backstop | Accepted risk. The per-path checks are the only guard. ArenaPvP stays unchanged. |
| R3 | No real second player in testing (Kepu's rule): the invite card on another client and their health on yours are only simulated | Kepu: "No, ship and see in the group test". Accepted risk; watch these in the group test. |
| R4 | Scope | CloakFX / ScentFX / MineColors squad polish deferred to v1.1 (backlog ticket). |
| R5 | Order vs Herrera pass 3 | Squads first. |
