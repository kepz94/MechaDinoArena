# Mecha Dino Arena v1.0 — Skills per dino (part 1: separate progress)

**Goal:** each dino has its own skill progress: XP, level, points, bought steps and mecha loadout.
**Chosen direction (Kepu 2026-10-29 02:30):**
- Everything is per dino.
- Old saves are reset.
- Stat paths are shared, and every mecha part belongs to one dino. That is part 2: a separate plan, including the T-Rex's own speed part.
- Order: the split ships first.

**Architecture:** SkillServer keeps one save per player that holds a record per dino. The player's existing Skill* attributes always show the record of the dino the player is playing now. SkillEffects, StatServer, SkillScreen, MechaButtons and AbilityBar already read those attributes, so they follow the switch with no change.

## Global Constraints
- Cloud place 84022023159448 only. Check `game.PlaceId` before every install; verify by hash + loadstring compile.
- Version: SkillServer 1.2. Header and changelog, the SkillServerVersion attribute, a docs/VERSIONS.md row and a docs/ATTRIBUTES.md section.
- Version: SkillScreen 1.2 (Task 2).
- One UI change (Kepu 2026-10-29 02:35, after the dino label mockup docs/mockups/skills_dino_label_options.html): "i dont think you need the "skills" label to be there. just dino name and level and xp progress".

## Do-not-touch
SkillTree (maths and data), SkillEffects, StatServer, SkillScreen apart from its title, MechaButtons, MechaServer, AbilityBar, SpeciesServer.

## Grounded facts (repo f764cd1)
- SkillServer 1.1 keeps `data[player] = {xp, steps, loadout, ...}` and saves `{v = 1, xp, steps, loadout}` in DataStore "MDA_Skills_v1", key "u" .. UserId.
- `publish(player, d, levelUp)` writes every player attribute. SkillLevelUpAt is set only when levelUp is true.
- SkillEffects re-applies when a SkillPath_* or SkillSlot* player attribute changes, and on CharacterAdded.
- Which dino the player is: the character attribute Species ("TRex" / "Raptor"). SpeciesServer also keeps the player attribute DinoSpecies.

## Task 1 — SkillServer 1.2 · Mode: Wired
**Files:** Modify `src/server/SkillServer.server.luau`.

**Design (deterministic):**
- **Store:** a new DataStore "MDA_Skills_v2" (Kepu: reset all). "MDA_Skills_v1" is never read or written again; it is kept as is, so the reset can be undone.
  - Value: `{v = 2, dinos = {[dinoKey] = {xp, steps, loadout}}}`.
- **dinoKey(player):**
  - The current character's Species attribute if it is a string.
  - Else the player's DinoSpecies.
  - Else "TRex".
  - With the script attribute SkillPerDinoEnabled == false, always "All" (one shared record, as before).
- **Active record:** `d.dinos[key]`. A missing record is created fresh: `{xp = 0, steps = {}, loadout = {false, false}}`, sanitized like loaded ones.
  - The active record holds the xp / steps / loadout that buy / respec / slot and `publish` use today.
- **Switch:** on CharacterAdded, and on the character's Species attribute changing:
  1. Compute the key.
  2. If it differs from `d.active`, set `d.active` and `publish(player, record, false)`. No level-up stamp.
  3. Set the player attribute SkillDino = key.
- **XP from a kill** goes to the killer's active record at the moment KilledAt is credited.
  - Level-up detection compares that record's level before and after.
- **Save and load** cover the whole `dinos` table. A v2 load sanitizes each record.
  - A value without `v = 2` (none expected in the new store) counts as "new".
- **Requests** (buy / respec / slot) act on the active record only.

**Interfaces:**
- Consumes: SkillTree (unchanged); character Species; player DinoSpecies.
- Produces:
  - Unchanged: every existing player Skill* attribute, now for the active dino.
  - New: player SkillDino (diagnostic) and script SkillPerDinoEnabled (default true).

**Steps:**
1. Store name and v2 value shape.
2. The record table and dinoKey.
3. Switch hooks.
4. Credit to the active record.
5. Header.
6. Install and verify.
7. Commit.

**Acceptance:**
- T-Rex kill XP raises only the T-Rex. After switching to Raptor: level 1, all points free, empty loadout.
- Buy Thrusters as the raptor, switch to the T-Rex: no Thrusters. Switch back: Thrusters and its slot are back.
- Switching dinos never sets SkillLevelUpAt and never shows a level-up.
- SkillEffects follows: StatAdded_* and DashEnabled match the dino being played after a switch.
- Death keeps both records. Leave and rejoin keeps both, in the live game (SkillSaveState "saved").
- First join after the release: a fresh start on every dino (store v2). MDA_Skills_v1 is untouched.
- SkillPerDinoEnabled false: one shared record "All".
- Hash matches; docs.

**Out of scope:** per-dino tree content (part 2); the SKILLS screen (Task 2).

## Task 2 — SkillScreen 1.2 · Mode: Wired
**Files:** Modify `src/character/SkillScreen.client.luau`.

**Layout:** the top bar title label keeps its place and size (90 × 34, FredokaOne 22). Its text becomes the dino name:
- DINO_TITLES[Species]: TRex → "T-REX", Raptor → "RAPTOR".
- Any other Species → that Species in capitals.
- No Species → "SKILLS".

Level box, XP bar, PTS, RESPEC and X are unchanged. The HUD's SKILLS button is unchanged.

**Interfaces:**
- Consumes: the character attribute Species.
- Produces: script attribute SkillScreenDinoTitleEnabled (default true; false = "SKILLS"); character diagnostic SkillScreenTitle.

**Acceptance:**
- T-Rex: the title reads "T-REX". Raptor: "RAPTOR". Each shows that dino's LV and XP.
- The title updates on a species switch.
- The toggle false shows "SKILLS".
- Hash matches; docs.
- Kepu checks it on phone and PC.

## Red-team (pre-filing)
1. **Switch timing.** The new character spawns, then SkillServer swaps the attributes. For a tick, SkillEffects may apply the previous dino's build to the new body: wrong speed points, or DashEnabled from the old loadout.
   - Mitigation: both scripts handle the same CharacterAdded, and SkillEffects re-applies on every SkillPath_ / SkillSlot change in that same dispatch. So the end state is right within the frame.
   - Swapping on DinoSpecies was dropped: it is set before the new body exists, so it would swap the old body's build early.
   - Acceptance item: after a switch, StatAdded_* / DashEnabled match the new dino.
2. **The reset is irreversible for players if it is done by wiping.** Mitigation: use a new store name instead of deleting. Undo = point back to v1 (one constant).
3. **Kill credit after a switch.** A bleed tick that kills a bot after the player switched dinos credits the new dino. Accepted as a rare edge: the credit rule is "the dino you are playing when the kill lands".
4. **No visible cue on the SKILLS screen** that progress is per dino. Resolved: Kepu asked for a dino label, the mockup was made, and he chose "just dino name and level and xp progress" (Task 2).
