# Mecha Dino Arena v1.0 — Welcome Screen, Dino Passives, JUMP Parts in "Use Each Part"

**Goal:** a new player learns what the game is before the roster, sees each dino's built-in non-button moves (Herrera climbing) next to its main attack, and learns the mecha parts that fire through JUMP by actually doing them.
**Chosen direction:** mockup `docs/mockups/welcome_moves_v0.2.html` (artifact "Welcome and Passives"). Kepu 2026-11-26: welcome "A"; 02:10 "It shouldn't be a special move. It should be introduced if the glider is equipped in the tutorial. Just have the climbing ability in the description of the Dino attack ability as a passive"; "Only unusual ones"; "passive abilities under Dino's like Herrera climbing, for mecha parts that's just a different mechanic to use it"; v0.2 "Yes, write the plan"; Spin Dive / Flap & Glide rows "Yes, list them"; glide line "+30%" "Cut it".
**Architecture:** client-only, inside the existing Tutorial LocalScript, fed by pure data in TutorialRules. TutorialServer is not changed (it already takes `"used", n` from the client). Every new piece is behind its own script attribute.
**Supersedes:** the first draft of this file (commit 54f9bd1, option B reveal list), kept in git history.

**Root cause found (why the glide was never learned):** in step 6 the coach points at the part's slot button and `MechaButtonsLastPress` "slot<n>:glider" counts as used (Tutorial 1.6 `onChar`), but MechaButtons 1.x gives Glider Wings no action ("has no key (it acts through JUMP)"), Mecha Legs ("Pressing it does nothing (the jump fires it)") and Hydraulic Leap (1.28 "pressing the tleap slot does nothing") likewise. GliderTest needs Glider Wings bought AND slotted, so the glide can only be taught after the equip step.

**Tree damage:** unchanged (Do-Not-Touch default). A drop from a tree does normal slash damage (SlashServer 1.8: only a glide drop applies GliderDropMul). Copy says only what the game does.

## Global Constraints
- Version tags: TutorialRules **1.3**, Tutorial (client) **1.7**. Header + docs/VERSIONS.md + docs/ATTRIBUTES.md.
- Additive; switches default true; false = the 1.6 / 1.2 screens unchanged.
- Tap targets ≥ 44 px on the emulated iPhone 17 Pro (750 × 381). Copy: no em dashes; short tags.
- Install: pairs patch → `tools/lab_pairs.py` → same pairs in Studio → compile check → srchash match.
- Studio Play only with the save scripts switched off (Kepu's wiped account; "No preference" → the safe default), reported.
- Publish only on "Publish".

## Do-not-touch
- TutorialServer (steps, TutNeed, TutUsed, lanes, bot), TutorialRules LESSONS / lessonsFor / ROLL_POOL / ROLE, the egg / incubator, the Lab coach (steps 5 / 8), drawShowcase (1.4), the 1.1 fallbacks.
- MechaButtons, ArenaTouch, GliderTest, JumpTest / JumpServer, HerreraMovesServer, SlashServer, ClimbLogic / ClimbTest, SkillTree, SkillEffects, PregameScreen.
- Step 6 for every part not in `JUMP_PARTS` (tap / pull down on its slot button, as today).

## File structure
| File | Change | Responsibility |
|---|---|---|
| `src/shared/TutorialRules.luau` | extend 1.3 | `PASSIVES`, `passivesFor`, `JUMP_PARTS`, `jumpPart`, `jumpPartEvent` |
| `tools/tests/TutorialRules.spec.luau` | extend | specs for the above |
| `src/client/Tutorial.client.luau` | extend 1.7 | `drawWelcome`; PASSIVE rows in `drawShowcase2` and `drawReveal`; roster title; step 6 JUMP-part coach + stamp watch |
| `tools/welcome_patch1..4.luau` | new | install pairs |

Tutorial.client has 121 top-level locals (limit 200); new state goes in one table `WM`.

---

### Task 1 — TutorialRules 1.3: passives + JUMP parts data · Mode: Logic

**Files:** Modify `src/shared/TutorialRules.luau` (after `M.lessonsFor`); Test `tools/tests/TutorialRules.spec.luau`.

**Interfaces (Produces):**
- `M.PASSIVES[dino] = {{n, tag, line}}`; `M.passivesFor(dino) -> {..}` (a copy; `{}` for nil / unknown).
- `M.JUMP_PARTS[id] = {stamp = string, needAttr = string?, big = string, small = string, tip = string, pcBig = string}`; `M.jumpPart(id) -> entry | nil`.
- `M.jumpPartEvent(entry, attrName, needValue) -> bool`: true when `attrName == entry.stamp` and (`entry.needAttr == nil` or `needValue == true`).

**Data:**
| Dino | n | tag | line |
|---|---|---|---|
| Herrera | Tree Climber | PASSIVE | Walk into a tree to climb it. SLASH from a tree drops onto the dino below. |
| Therizino | Spin Dive | ON JUMP | JUMP spins you forward. 3 charges. |
| Troodon | Flap & Glide | ON JUMP | JUMP, then JUMP twice more in the air. Then it glides. |

| id | stamp (character attribute) | needAttr | big (touch) | pcBig | small | tip |
|---|---|---|---|---|---|---|
| glider | GlideStartedAt (HerreraMovesServer) | | JUMP, THEN HOLD JUMP | SPACE, THEN HOLD SPACE | Glider Wings | Glider Wings works on JUMP. Jump, then hold JUMP in the air. |
| mechalegs | JumpDoubleAt (JumpServer 1.2) | | JUMP, THEN JUMP AGAIN | SPACE, THEN SPACE AGAIN | Mecha Legs | Mecha Legs works on JUMP. Leap, then JUMP again in the air. |
| tleap | JumpStartedAt (JumpServer) | TenoLeapOnJump | TAP JUMP | PRESS SPACE | Hydraulic Leap | Hydraulic Leap works on JUMP. Every jump is the leap. |

- [ ] Step 1: specs: the 3 dinos have exactly 1 passive; others / nil / "TRex" → `{}`; result is a copy; no "—" in any line; tag ∈ {PASSIVE, ON JUMP}; `jumpPart("glider").stamp == "GlideStartedAt"`; `jumpPart("quills") == nil`; `jumpPartEvent(tleap, "JumpStartedAt", false) == false`, `(…, true) == true`; `jumpPartEvent(glider, "JumpStartedAt", nil) == false`; every JUMP_PARTS id is in SkillTree PATHS (Studio run).
- [ ] Step 2: run in Studio Edit → new cases fail.
- [ ] Step 3: implement; header v1.3.
- [ ] Step 4: run → PASS (35 + new); push to ReplicatedStorage.TutorialShared.TutorialRules; hash match.
- [ ] Step 5: commit + push.

**Acceptance:** spec PASS; LESSONS / lessonsFor / ROLL_POOL / ROLE byte-identical.

### Task 2 — Tutorial 1.7: Welcome screen · Mode: Wired

**Files:** `src/client/Tutorial.client.luau`: new `drawWelcome()` before `drawShowcase2`; `incubatorKey` (scene "welcome"); the step-1 draw branch.

**Interfaces:** Consumes `backdrop`, `text`, `cta`, `px`, `C`, `pod`, `render`. Produces `WM.welcomed` (client, once per join).

**Layout (v0.2 section 1):** opaque backdrop; below `topH`, centred: "WELCOME TO" (GothamBlack, cyan, spaced, ≈1.6 cqw, min 10 px), "MECHA DINO ARENA" (title font, white, ≈6.4 cqw, min 32 px, "DINO" yellow via RichText); 3 tiles in a row, ≈19 cqw each, gap ≈1.6 cqw, `C.card` + `C.line` stroke: icon ⚔ / ⚙ / ★ (yellow), FIGHT / UPGRADE / COLLECT, lines "Squad battles on the island" / "Mecha parts and skill points" / "7 dinos, skins, emotes, trails"; tiles fade + rise in, 0.12 s apart; bottom centre CTA "LET'S GO" → `WM.welcomed = true`, `pod.sceneKey = nil`, `render()`.

**Map:**
| Condition | Scene |
|---|---|
| step 1, TutRolled "", phase ≠ "open", `showcaseOn()`, `TutorialWelcomeEnabled` ≠ false, not `WM.welcomed` | welcome |
| same but `WM.welcomed` | roster (showcase) until NEXT |
| `TutorialWelcomeEnabled` false | roster first (1.6) |
| `showcaseOn()` false | charge (no welcome) |
| step ≥ 2 / rejoin at step ≥ 2 | unchanged |
| rejoin at step 1 | welcome again (once per join, like the roster) |

- [ ] Steps: patch 1 → repo + Studio → compile → hash → Studio check PC + iPhone (⚔ / ⚙ render, else drop the icon line on all 3; nothing under the Roblox buttons; LET'S GO ≥ 44 px) → commit + push.

**Acceptance:** every map row; no clipped text at 750 × 381; the roster's auto-cycle starts only once the roster shows.

### Task 3 — Tutorial 1.7: Roster title + PASSIVE section · Mode: Wired

**Files:** `drawShowcase2()` title block and `show(i)` (between the MAIN ATTACK cards and the ABILITIES section).

**Layout:**
- Title (switch `TutorialRosterTitleEnabled`): "MEET THE ROSTER" / "1 OF THESE 7 IS YOURS FREE" (`#R.ROLL_POOL`); if the sub wraps at 750 × 381 → "7 DINOS · 1 IS FREE".
- PASSIVE (switch `TutorialRosterPassiveEnabled`), only when `R.passivesFor(key)` is not empty: `section(body, "PASSIVE", y)`, then one full-width card like the MAIN ATTACK card but with a green left bar: name (title font, white), the tag chip (green, ink text, "PASSIVE" / "ON JUMP") top right, the line (GothamBold, `lineS`, wraps to 2 lines max, truncates after). No stat grid. ABILITIES list keeps min height `px(6, 40)` and gets the rest.

**Map:** no passive → 1.6 panel; passive → one card; switch off → 1.6; auto-cycle / tap-hold unchanged.

- [ ] Steps: patch 2 → apply → compile → hash → Studio check all 7 dinos PC + iPhone (Herrera / Therizino / Troodon show the card, the others don't; ABILITIES still scrolls; Teno's 2 attack cards unchanged) → commit + push.

### Task 4 — Tutorial 1.7: PASSIVE on "FREE DINO UNLOCKED" · Mode: Wired

**Files:** `drawReveal()` after the lessons loop (LayoutOrder 12–14).

**Layout:** header "PASSIVE" (title font, green, same size as "MAIN ATTACK"); one row per passive: a rounded green pill with the tag (ink text) instead of the round lesson badge, name (black font, white), line (body, muted, wraps). Switch `TutorialRevealPassiveEnabled`.
**Map:** no passive → no header (1.6); NEXT stays LayoutOrder 21; if the panel's content height > panel height on the phone, the line's text size steps down to its minimum, then the row's line is truncated (NEXT is never pushed off).

- [ ] Steps: patch 3 → apply → compile → hash → Studio check (Play, saves off) for Herrera, Therizino, Troodon + one without (rolled via repeat or a test attribute if TutorialServer has one) → commit + push.

### Task 5 — Tutorial 1.7: JUMP parts in "use each part" (step 6) · Mode: Wired

**Files:** the step-6 draw branch (`elseif s == 6`) and the step-6 watcher (`onChar`).

**Interfaces:** Consumes `R.jumpPart`, `R.jumpPartEvent`, `slotOf(n)`, `need()`, `send`, `localUsed`, `pointAt`, `pcCallout`, `objective`. Switch `TutorialJumpPartsEnabled`.

**Behaviour:**
- Watcher: when step 6 and slot n (n ≤ `need()`) holds a part with `R.jumpPart(id)`: a `MechaButtonsLastPress` "slot<n>:<id>" does **not** count; instead a change of the character attribute `entry.stamp` (with `needAttr` read from the character at that moment) → `localUsed[n] = true`, `send("used", n)`. All other parts: unchanged.
- Coach for the next unused slot n holding a JUMP part: touch → `pointAt(<ArenaTouch "Leap" button>, true, "tap", entry.big, entry.small, "up")`; PC → `pcCallout(entry.pcBig, entry.small)`; the objective tip = `entry.tip`. If the ArenaTouch Leap button is missing or hidden: callout only, no ring (no crash).
- A press on that part's slot button while it is next: tip "That button does nothing for <small>. It works on JUMP." for 2 s.
- SKIP (red-team R2, Kepu "Show SKIP after 20 s"): when the next unused slot holds a JUMP part and it has been next for `TutJumpPartSkipAfter` s (script attribute, default 20) without a tick, a CTA "SKIP" (≥ 44 px) appears bottom-right (where step 5's TRY THEM sits) and the tip ends with " Or tap SKIP."; SKIP → `localUsed[n] = true`, `send("used", n)` (the same message a real use sends); the timer restarts for the next JUMP part. Normal parts get no SKIP (today's behaviour).

**Map:** JUMP part next < 20 s → coach only; ≥ 20 s → coach + SKIP; JUMP part in slots 1..need → as above; JUMP part in a slot above need → ignored (as today); switch off → 1.6 (slot press counts); stamp changes outside step 6 → ignored; a respawn → watcher re-hooked by `onChar` (CharacterAdded), already-used slots stay in `localUsed` and the server's TutUsed.

- [ ] Step 1: patch 4.
- [ ] Step 2: apply → compile → hash.
- [ ] Step 3: Studio check (Play, saves off): Herrera step 6 on PC and iPhone: the glider slot tap does not tick; jump + hold JUMP glides and ticks "✓ Glider Wings"; Pachy Mecha Legs ticks on the air leap only. Confirm the ArenaTouch JUMP button, held, keeps the glide on touch (GliderTest reads the jump hold) — if not, stop and report before building more.
- [ ] Step 4: commit + push; VERSIONS / ATTRIBUTES; Dev Hub session log.

**Acceptance:** the map; step 6 still auto-advances after the last part (TutorialServer TutAutoNext unchanged).

---

## Self-review
- Coverage: welcome (T2), roster (T3), climbing / Spin Dive / Flap & Glide as passives (T1, T3, T4), glide taught only when equipped and through JUMP (T5), Mecha Legs / Hydraulic Leap (T5), tree damage recorded, glide "+30%" copy cut (glider tip has none).
- Names consistent: `passivesFor`, `jumpPart`, `jumpPartEvent`, `WM.welcomed`, switches `TutorialWelcomeEnabled`, `TutorialRosterTitleEnabled`, `TutorialRosterPassiveEnabled`, `TutorialRevealPassiveEnabled`, `TutorialJumpPartsEnabled`.
- Fence: no task touches TutorialServer or any gameplay script.

## Red-team (answered 2026-11-26)
1. **Hold-to-glide on the touch JUMP button may not work.** ArenaTouch's JUMP sets `Humanoid.Jump` for LEAP_HOLD s; if GliderTest needs a held jump input, a phone player can't glide and step 6 would never tick. Mitigation: Task 5 Step 3 checks this first and stops if it fails (a separate fix in ArenaTouch / GliderTest would need Kepu's OK, it's do-not-touch here).
2. **Step 6 can now block.** Today any tap passes; with real checks a player who can't do the move is stuck. Mitigation: the existing "next" still works at step 6 (TutorialServer: "next" still works); add acceptance: the coach's tip after 20 s without a tick adds "Or tap NEXT to skip." — needs Kepu's OK (new copy / behaviour).
3. **Equip order decides who sees it.** Only the parts the Lab coach equips are tried; Teno never gets Hydraulic Leap with today's order (Tail Grab & Fling, Boulder Mortar, Stomp Shockwave, Herd Bellow). Accepted: Hydraulic Leap still says "Fires through JUMP" on its card.
4. **Roster panel height on the phone.** One PASSIVE card (≈ 2 lines) shrinks the ABILITIES list on the 3 dinos that have one. Mitigation: card has no stat grid; checked in Task 3.
5. **Play tests on the wiped account.** Mitigation: save scripts off, reported.

## Synthesis (Kepu 2026-11-26)
- R2 survived: SKIP after `TutJumpPartSkipAfter` (20) s, added to Task 5 (behaviour, map, acceptance: SKIP shows at 20 s, never for normal parts, sends "used", n).
- R1 conceded: Kepu "Why would the jump not do that? It works right now." The glide already works on the phone JUMP button live; Task 5 Step 3 still checks it as part of the normal Studio check, no stop rule.
- R3 (Teno never gets Hydraulic Leap with today's equip order): accepted risk.
- R4 (roster panel height): checked in Task 3.
- R5 (Play tests): save scripts off, reported.
