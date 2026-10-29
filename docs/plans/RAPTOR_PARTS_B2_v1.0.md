# Mecha Dino Arena — Raptor parts batch 2 v1.0: Scent Sense + Raptor Screech

**Goal:** give the raptor two roamer-style button parts for PvP: a tracker (Scent Sense) and an aimed disruptor (Raptor Screech).
**Intent (Kepu 2026-10-29):** "these need to be Raptor specific. Remember the Raptor is a natural roamer"; Dart Launcher / Pack Beacon felt repetitive in PvP. "I like scent sense. Let's add that. Raptor screech is too powerful it needs to be aimed."
**Chosen direction:** mockup `docs/mockups/raptor_parts_b2_scent_screech.html` — Scent Sense **A · Glowing paw prints**, cloaked raptors leave **faint prints**; Raptor Screech **C · Hold to aim**; step numbers as in the mockup.
**Architecture:** both are server-gated timed button parts (the batch 1 pattern: SkillTree effects -> SkillEffects character attributes -> <Part>Server request / cooldown -> MechaButtons + AbilityBar TIMED_PARTS). Scent Sense trails are drawn on the owner's client only (from position history it records itself). Screech's bolt is simulated on the server.

## Global constraints
- Version tag on every file touched; VERSIONS.md row and ATTRIBUTES.md section per file.
- Install hash `h=7; h=(h*31+byte)%2147483647` + loadstring compile check; place 84022023159448 only.
- New parts ship maxed and unlocked through the test switch (SkillTestCloakEnabled).
- 35% rule for every step.
- Each part has an off switch (script attribute) and diagnostics for every state change.
- Never mention or test what a second player sees.

## Do-not-touch
Cloak (CloakServer / CloakFX logic except reading a new end stamp), PounceServer, BotServer AI, Thrusters boost physics (except a jam hook at star), batch 1 servers (Adrenaline / EnergyShield / Blade) except a jam hook at star.

## Replacements in the tree (additive)
- `PATHS.dart.dino = "none"`, `PATHS.beacon.dino = "none"` (kept, shown to nobody — the existing "none" rule).
- New paths appended: `screech` (attack, Raptor), `scent` (eng, Raptor). `LIVE_MECH` and `BUTTONS` += both.

## Steps and numbers

| Part | I | II | III | ★ |
|---|---|---|---|---|
| Scent Sense | Pulse: trails of every other dino that passed within 60 studs in the last 8 s glow for you for 6 s; recharge 16 s | 81 studs | memory 10.8 s; the freshest end pulses | bleeding dinos leave a blood trail you see all the time |
| Raptor Screech | Hold to aim (aim line grows to 50 studs over 1 s), release fires a sonic bolt (70 studs/s) at the first dino in its path: a raptor flinches 0.5 s and loses Cloak; a T-Rex is slowed for 0.5 s; recharge 14 s | max range x1.35 (67.5) | recharge 10.3 s (14 / 10.3 = 1.36; 10.4 failed the 35% rule) | jams parts: the target's running boost, Shield and Adrenaline end at once |

Effects fields: `scentRadius` (60 / 81), `scentMemory` (8 / 10.8), `scentTime` 6, `scentCooldown` 16, `scentFresh` (III), `scentBlood` (★); `screechRange` (50 / 67.5), `screechFlinch` 0.5, `screechCooldown` (14 / 10.3), `screechJam` (★).

## Tasks (build order)
1. **SkillTree 1.9** (Logic) — paths, texts, effects, dart / beacon to "none", spec cases incl. 35% rule.
2. **SkillEffects 1.8** (Wired) — Scent* / Screech* character attributes while slotted.
3. **ScentServer 1.0** (Wired, new) — DinoScentRequest gate (badArg / dead / disabled / stunned / active / cooldown / ok); ScentStartedAt / Until / ReadyAt; ScentServerEnabled.
4. **ScentFX 1.0** (Wired, new client) — position history (4 Hz ring buffer, max memory) of every other player character and DinoIsland.Bots model, with cloak / bleed flags per sample; on ScentStartedAt: paw prints (pooled neon parts on the ground, oldest faint, colour by species, cloaked samples at 30%) within the radius for ScentTime; III fresh-end ring; ★ blood trail live for bleeding dinos (SkillBleedUntil / bleed attributes). Cap 300 prints. ScentFXEnabled.
5. **ScreechServer 1.0** (Wired, new) — DinoScreechRequest(stamp, range): gate + clamp range to ScreechRange; bolt moved on the server along the shooter's facing, first hit within 4 studs of the path (players + bots); raptor: StunnedUntil = now + 0.5 (the existing stun), cloak ended with "screech"; T-Rex: ScreechSlowUntil (SprintTest multiplies 0.5); ★: PartsJammedAt on the target. ScreechHits / ScreechMisses.
6. **Jam hooks at ★ (Wired)** — AdrenalineServer 1.3 / EnergyShieldServer 1.3 finish on PartsJammedAt ("jammed"); MechaButtons boost stops on PartsJammedAt; CloakServer PART_STAMPS unchanged (Screech breaking cloak goes through ScreechServer).
7. **MechaButtons 1.8 + AbilityBar 1.4** (Wired) — TIMED_PARTS += scent ("SCENT") and screech ("SCREECH"); Screech is hold-to-aim on PC keys and touch (tap slot: hold = aim; pull slot: aim starts when the pull registers), aim line drawn on the client from the character's facing, release fires with the held range.
8. **SkillServer** — no change: the test layer already gives every live part at ★; slots are left as they are (Kepu swaps).
9. **ArenaScope 1.8** — expects ScentServer, ScentFX, ScreechServer.

## Red-team (pass 1, before filing) and Kepu's answers
1. **Slots: 6 button parts, 4 slots; the test layer's slots are full.** Kepu: "Leave slots; I'll swap myself". The parts are unlocked at ★ by the test layer; no auto-placement change. Acceptance: both appear unlocked at ★ and can be slotted from the SKILLS screen.
2. **Hold-to-aim on touch.** Aim = the raptor's facing (the move thumb steers); on a pull slot the aim starts when the pull registers. Acceptance: tap slot and pull slot both aim + fire on touch emulation.
3. **Flinch uses the existing stun, so Thick Hide applies.** Kepu: "Hide counts". Accepted: Hide III shortens it, Hide ★ blocks it above 50% health. Acceptance: a Hide ★ target above half health does not flinch.
4. **★ jam touches 4 scripts.** Kepu: "All three". One attribute (PartsJammedAt) read by AdrenalineServer, EnergyShieldServer and MechaButtons; acceptance per script.
5. **Scent trail performance.** Accepted: client-only pooled prints, cap 300, history 4 Hz.

## Follow-up after v76 (Kepu 2026-10-29)
Kepu: "the screech shouldn't be called that because it's not even a screech also the dart doesn't even shoot far at all. I like the way the scent works tho. Also the equip skills menu is stupid. I should be able to tap a slot then tap the skill to fill that slot not tap through to cycle through skills for each slot." Picks: **Shock Dart**, **100 / 135 studs**, **Glowing dart** look, loadout **A · Picker row** (mockup `docs/mockups/loadout_picker_options.html`).

| Task | Mode | Change |
|---|---|---|
| 10 — SkillTree 1.10 + spec | Logic | `screech` shown as "Shock Dart" (id kept: saves and attributes unchanged); screechRange 100 / 135; texts I / II |
| 11 — ScreechServer 1.1 + MechaButtons 1.9 | Wired | bolt 110 studs/s; dart look (steel body, red neon tip, red-white streak); button "SHOCK DART" |
| 12 — SkillScreen 1.4 | Wired | tap a slot to select it, a picker row of owned button parts (+ Empty) appears above the strip, the tree dims; tap a part to fill; SkillScreenSlotPickerEnabled (false = 1.3 cycle) |

Red-team (one paragraph): the id stays "screech" so nothing saved breaks, at the cost of an internal name that no longer matches (accepted, documented). A longer dart at 110 studs/s is harder to dodge at range; the hold-to-aim and the 14 s recharge stay the counterweights (accepted; Kepu tunes after playing). The picker row overlaps the bottom 44 px of the tree while open; the dimmer makes that clear and a tap on it cancels, so no accidental buys.
