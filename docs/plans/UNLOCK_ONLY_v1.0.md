# Mecha Dino Arena v1.0 — Unlock-only progression

**Goal:** players earn points and unlock dinos and mecha parts; no stat rows, no part upgrade levels.
**Chosen direction:** C (unlock on the card + KIT n/m chip + FULL KIT · R$149 button) — in-game Studio mockup
`docs/mockups/unlock_only_v0.1/` (sheet `unlock_only_v0.1_sheet.jpg`).
**Architecture:** one server switch (SkillServer `SkillUnlockOnlyEnabled`) turns the mode on. The saved part steps are kept as
they are; the server publishes *effective* steps (every live mecha part the player has at 1, stat rows at 0), so SkillEffects,
the Lab and every client keep reading `SkillPath_<id>` as today and get level-1 numbers. Part unlocks spend from one account
wallet (new saved number `pspend`, like the dino unlock's `unlock`). Turning the switch off brings the old system back untouched.

## Kepu's picks (2026-11-27)
- 19:31 "take out the upgrade and stat system entirely so that people are just unlocking Dino's and mecha parts. Not upgrading
  the mecha parts".
- Dino numbers: **base** (no stat bonuses). Part power: **level 1**. Part price: **10 points each** (flat). R$149 buy:
  **dino + all its parts**. Lab layout: **C**. Wallet: **one shared wallet**. Parts bought before: **stay unlocked, free**.

## Global constraints
- Additive, every change behind a switch; version branding in each script header, docs/VERSIONS.md, docs/ATTRIBUTES.md.
- Mobile first: tap targets >= 44 px; no em dashes in game copy.
- Studio tests with the save switches off (test set in the session notes), restored after.
- Publish only on Kepu's "Publish".

## Do-not-touch
- XP, levels, level points (`SkillTree.pointsOf`), quest / achievement point grants (`SkillGrantPoints`), the 40-point dino
  unlock price, skins / emotes / trails, the loadout + saved loadout system, ArenaRecord / quests / First Steps logic.
- The SkillTree path data (texts, numbers, overlays) and SkillEffects' formulas: level 1 comes from the existing step-1 data.
- Saved part steps (`value.dinos[key].steps`): read, never rewritten by this mode.

## Current state (read 2026-11-27, live v1108)
- SkillServer 1.18: `SkillAllStatsMaxEnabled` gives every stat row at step 4 (never stored); free dino (`FreeDino`) and
  `MaxedDinos` get every live part at step 4 (testParts / stepsFor); points = level points + bonus - dino unlocks (`earnedOf`);
  each dino spends that full pool on its own build (`ST.spent` per record); `buy` = +1 step at cost 1/2/3/4; free `respec`.
- Lab 2.4: part cards with 4 pips, STEP I-★ tag, BUY / UPGRADE · n PT(S) / MAXED, MASTERY n/3 chip. Live bug seen in Studio:
  every card reads "NEED 1 PT" with 25 points and the chip says "MASTERY 4/3" (the maxed stat rows count toward mastery).
- PregameScreen: "MAXED · R$149" (DinoUnlockRequest "robux"; an owned, not maxed dino may be bought).
- Tutorial 1.9 showcase: ability stat chips are fixed numbers read at step 4.
- FirstSteps / FirstStepsServer: step 2 "SPEND A POINT IN THE LAB" ticks on SkillRequest "buy" + SkillLastResult "ok".
- PracticeKit: bots buy random part steps with `ST.buy`.

## Deterministic map (SkillUnlockOnlyEnabled ~= false)
| State | Condition | Result |
|---|---|---|
| Stat row | any `ST.PATHS[id]` that is not a live mecha part | effective step 0 (base numbers); a buy -> "notPart" |
| Part owned | saved step >= 1, or the active dino is FreeDino / in MaxedDinos | effective step 1, shown UNLOCKED |
| Part locked | saved step 0, not given | effective step 0, card UNLOCK · 10 PTS (left >= 10) / NEED 10 PTS |
| Buy a locked part | left >= SkillPartPrice (10) | saved step 1, pspend += 10, autoSlot as today, result "ok" |
| Buy an owned part | step >= 1 or given | result "owned" |
| Buy, not enough | left < 10 | result "noPoints" |
| Respec | any | result "disabled" (no refunds in this mode) |
| Dino unlock (40) | left >= 40 | ok; no build is reset (1.17's over-pool reset is skipped in this mode) |
| Load | a record over the old per-dino pool | kept (no reset) |
| Wallet | always | SkillLeft = level pts + bonus - dino unlocks - pspend (never below 0 shown) |
| Switch off | `SkillUnlockOnlyEnabled` false | 1.18 exactly; pspend kept in the save, ignored |

## File map
- Modify `src/shared/SkillTree.luau` (1.94): pure helpers `isPart(id, dino)`, `unlockSteps(steps, dino, given)`.
- Modify `src/server/SkillServer.server.luau` (1.19): the mode (effective steps, buy = unlock, wallet, respec off, no resets,
  save `pspend`, player attributes).
- Modify `src/server/PracticeServer/PracticeKit.luau`: bot parts at level 1 (switch).
- Modify `src/client/Lab.client.luau` (2.5): layout C.
- Modify `src/client/PregameScreen.client.luau`, `src/client/Tutorial.client.luau`, `src/client/FirstSteps.client.luau`: copy + numbers.
- New `tools/tests/SkillTreeUnlock.spec.luau`.

### Task 1 — SkillTree 1.94 unlock helpers · Mode: Logic
**Files:** Modify `src/shared/SkillTree.luau` (append at the end, before `return SkillTree`); Test
`tools/tests/SkillTreeUnlock.spec.luau` (run in Studio Edit like the other specs).
**Interfaces:** Produces `SkillTree.isPart(id: string, dino: string?) -> boolean` (live mecha path, not soon, seen by dino);
`SkillTree.unlockSteps(steps: {[string]: number}, dino: string?, given: {[string]: boolean}?) -> {[string]: number}` (every
path: isPart and (steps >= 1 or given) -> 1, else 0); `SkillTree.PART_PRICE = 10`.
- [ ] Write the spec: Raptor screech step 3 -> 1; stat row `regen` step 4 -> 0; given `traps` step 0 -> 1; soon part -> 0;
  another dino's part -> 0; nil steps -> all 0.
- [ ] Run it in Studio Edit, watch it fail (helpers missing); add the helpers; run, watch it pass; commit.
**Acceptance:** spec PASS; `ST.effects(ST.unlockSteps(...))` for each of the 7 dinos runs without error.
**Out of scope:** path data, effects(), buy/canBuy (left as they are for the switch-off path).

### Task 2 — SkillServer 1.19 unlock-only mode · Mode: Wired
**Files:** Modify `src/server/SkillServer.server.luau`.
**Interfaces:** Consumes Task 1. Produces player attributes `SkillUnlockOnly` (bool), `SkillPartPrice` (10), `SkillLeft`
(wallet), `SkillPartSpent` (pspend), `SkillKitOwned` / `SkillKitTotal` (active dino); script attributes
`SkillUnlockOnlyEnabled` (true), `SkillPartPrice` (10); save field `value.pspend` (whole number >= 0).
- [ ] `stepsFor(d)`: in the mode return `ST.unlockSteps(d.steps, d.active, given)` where given = testParts(d) (free dino,
  MaxedDinos, test layer); `testStats` returns {} in the mode (no stat rows given).
- [ ] `publish`: SkillLeft = max(0, earnedOf(d) - (d.pspend or 0)); SkillSpent = SkillPartSpent = d.pspend; kit counts.
- [ ] `buy` branch in the mode: isPart / owned / noPoints checks -> d.steps[id] = 1, d.pspend += price, autoSlot, publish.
- [ ] `respec` -> "disabled" in the mode; SkillSpendUnlock: wallet check against SkillLeft, skip the over-pool reset;
  load `cleanRecord`: skip the over-pool reset in the mode.
- [ ] Save / load `pspend`.
- [ ] Studio Play (test stores): new player -> 0 parts, buy 1 part -> left -10, second buy of it -> "owned", 0 points ->
  "noPoints", respec -> "disabled", dino unlock with parts owned -> parts kept, FreeDino all parts = 1, stats base
  (`StatDamageTakenMul` 1, MaxHealth = model base), switch off -> 1.18 numbers back.
**Acceptance:** every row of the deterministic map; SkillEffects writes level-1 numbers (e.g. Raptor Shock Cannon damage 0,
Herrera Quill 5 x 4); no script errors.
**Out of scope:** XP / levels / grants, loadout rules.

### Task 3 — PracticeKit bots at level 1 · Mode: Wired
**Files:** Modify `src/server/PracticeServer/PracticeKit.luau` (prepareSpec).
- [ ] While SkillServer `SkillUnlockOnlyEnabled` ~= false and PracticeKit switch `PrKitUnlockOnlyEnabled` ~= false: after the
  steps are rolled, `steps = ST.unlockSteps(steps, species)`.
- [ ] Studio: a practice match's bots carry SkillPath_* values of 0 / 1 only.
**Acceptance:** bots fight with the same level-1 parts as players. **Out of scope:** bot brains.

### Task 4 — Lab 2.5 layout C · Mode: Wired
**Files:** Modify `src/client/Lab.client.luau`.
**Layout:** as mockup C: part card pips hidden; locked card: art dimmed + lock badge, state "LOCKED" (muted), card button
yellow "UNLOCK · 10 PTS" (dark text) when SkillLeft >= price else dark "NEED 10 PTS" (muted); owned card: state "UNLOCKED"
(green) / "ON <key>", button EQUIP / TAKE OFF <key> as today; INFO detail: the level-1 text only (no STEP list), button
UNLOCK · 10 PTS / EQUIP; top bar: MASTERY chip -> "KIT n/m"; points chip shows SkillLeft; "ALL UPGRADES" -> "YOUR KIT";
new top-bar button left of CHANGE DINO: "FULL KIT · R$149" (phone "R$149 KIT"), 44 tall, green outline, hidden when the
dino is the free dino or in MaxedDinos -> DinoUnlockRequest("robux", dino).
- [ ] Draw by `SkillUnlockOnly`; switch `LabUnlockLayoutEnabled`.
- [ ] Studio PC + iPhone emulation captures; tap UNLOCK -> card turns UNLOCKED, KIT count +1, points -10.
**Acceptance:** matches mockup C on both screens; tap targets >= 44. **Out of scope:** SKINS / EMOTES / TRAILS tabs.

### Task 5 — Copy + numbers · Mode: Wired
- [ ] PregameScreen: "MAXED · R$149" -> "FULL KIT · R$149" while SkillUnlockOnly (switch).
- [ ] FirstSteps: step 2 label "UNLOCK A PART IN THE LAB" while SkillUnlockOnly (detection unchanged).
- [ ] Tutorial showcase: ability stat chips from level-1 values (read with ST.effects at step 1 in Studio Edit) while the
  mode is on (switch).
**Acceptance:** Studio captures of the three screens.

### Task 6 — Balance re-measure (after 1-5) · Mode: Wired
- [ ] Re-run the docs/BALANCE_2026-11-27.md rig with base stats + level-1 parts; table to Kepu before any number changes.

## Red-team (Phase 4.5)
1. **Economy speed.** 10 per part from one wallet: a level-10 player has 9 level points (+ quests), so a non-free dino's kit
   (7-10 parts) is 70-100 points plus the 40 to unlock. *Mitigation:* the free dino has its full kit; price is a script
   attribute (`SkillPartPrice`), tunable without code.
2. **Balance swing.** Base stats + level-1 parts drop most damage a lot; the Dilo x1.15 / Troodon x2.5 were set on maxed
   numbers, and some parts only did damage at higher levels (Shock Cannon's 30 is level 4). *Mitigation:* Task 6 before publish.
3. **No refunds.** With respec off, a wrong unlock is permanent. *Accepted* (10 points; matches "unlock" in other games).
4. **Grandfathered parts.** Players who bought parts under the per-dino full pool keep them all free. *Accepted* (launch reset
   was 2026-11-26; few players).
5. **Rollback.** Saved steps are never rewritten, `pspend` is ignored with the switch off: off = 1.18 exactly.
