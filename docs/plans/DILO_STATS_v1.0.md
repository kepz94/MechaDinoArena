# Mecha Dino Arena — Dilo stat lines v1.0

**Goal:** the Dilophosaurus gets six stat lines of its own and stops seeing the shared ones, the way the Therizino did
(SkillTree 1.57).
**Picks (Kepu 2026-11-04 10:40):** from the 20-option list: 2 Venom Bite, 3 Quick Draw, 5 Long Spit, 9 Toxic Blood,
14 Venom Feast, 20 Cold Blood. Shared lines: "Only its own" (Regeneration, Lifesteal, Jaws, Thick Hide, Sprint Legs
hidden for the dilo). Each picked text is the line's star; steps I-III below lead up to it.
**Architecture:** the Therizino stat-row pattern. SkillTree adds dilo-only rows and their effects; SkillEffects reads a
dilo's whole build as the dilo's and writes the fields as character attributes; DiloAttackServer (owner of the bite, dart
and venom) acts on them; DiloAttackTest and the two HUDs get the "dart ready again" stamp for Cold Blood.

## Global constraints
- Additive only, every piece behind a switch; versions in headers, VERSION constants, docs/VERSIONS.md, docs/ATTRIBUTES.md.
- Saved progress untouched: SkillPath_* attributes are not edited. Hiding the shared lines from the dilo means a dilo's
  saved steps on them stop counting (sanitize drops them and their points come back), the Therizino precedent.
- Steps cost 1 / 2 / 3 / 4; build limits unchanged (40 points, 3 lines at III or higher, 4 slots).
- In-game numbers are at the dilo's scale 2 (data values x 2 for studs).
- HUD changes ship on PC (AbilityBar) and phone (ArenaTouch) together.
- Install by multi_edit, verify by hash; one-player Studio checks; publish only on Kepu's "Publish".

## Do-not-touch
The bite / dart input feel (press, hold, release), DiloPose, DiloFX, the dilo model data, other dinos' trees, the venom
of anything that is not a dilo's dart or bite, StatServer's Attack points.

## The six lines
| Line (area) | I (1) | II (2) | III (3) | ★ (4) |
|---|---|---|---|---|
| Venom Bite (attack) | bites poison 1/s for 2 s | 1/s for 3 s | 2/s for 2 s | bites poison 2/s for 3 s |
| Long Spit (attack) | dart range 70 studs (was 60) | range 80 | darts fly 40% faster (speed 45 -> 63) | range 90 |
| Toxic Blood (defense) | a dino that bites / slashes you is poisoned 1/s for 2 s | 1/s for 3 s | 2/s for 2 s | 2/s for 3 s |
| Venom Feast (health) | heal 20% of the venom damage you deal | 30% | 40% | 50% |
| Quick Draw (speed) | spit ready after a 0.35 s hold (was 0.4) | 0.3 s | dart recharges in 1.25 s (was 1.5) | 0.25 s hold and 1.0 s recharge |
| Cold Blood (sig) | below 30% health: darts +25% damage | darts and venom +50% | +75% | double, and the dart recharges instantly once per life when you first drop below 30% |

## Deterministic map
- Effects (SkillTree, off values when unbought / other dinos): venomBiteDps 0 / venomBiteTime 0; spitRangeMul 1 /
  spitSpeedMul 1; toxicDps 0 / toxicTime 0; feastFrac 0; drawHold 0 (= model value) / drawCooldown 0; coldMul 1 /
  coldBelow 0 / coldReset false.
- SkillEffects: a dilo's effects = ST.effects(steps, "Dilo") (the shared lines give nothing). Attributes written:
  DiloVenomBiteDps, DiloVenomBiteTime, DiloToxicDps, DiloToxicTime, DiloFeastFrac, DiloColdMul, DiloColdBelow,
  DiloColdReset. Spit numbers are written onto the attributes every reader already uses, from the model values captured
  once per character (SkillDiloBase_<key>): DiloHoldTime = drawHold or base; DiloDartCooldown = drawCooldown or base;
  DiloDartRange = base x spitRangeMul; DiloAssistMax = base x spitRangeMul (soft aim reaches as far as the dart);
  DiloDartSpeed = base x spitSpeedMul (range muls 7/6, 4/3, 4/3, 1.5 for I-★; speed mul 1.4 from III). Unbought = the base
  values written back.
- Venom (DiloAttackServer): a new venom on a target keeps the higher of (its running dps, the new dps) and the later end;
  never stacked. Bite hit with DiloVenomBiteDps > 0 (not shielded) -> venom dps / time from it. Dart venom = DiloVenomDps
  x Cold Blood multiplier when the dilo is under its line.
- Venom Feast: each venom tick heals the dilo named in VenomBy by tick damage x its DiloFeastFrac (only while alive; never
  above MaxHealth).
- Toxic Blood: when a dilo's LastHitAt changes and LastHitBy names a model whose root is within 12 x the dilo's scale
  (24 studs) of the dilo's root (melee: bites, pounces, slashes, scratches, headbutts; Shock Cannon, mines, mortars,
  darts are farther and do not count), that model gets venom DiloToxicDps / DiloToxicTime (squadmates and players outside
  the Arena skipped, ModeRules / SquadRules as everywhere).
- Cold Blood: dilo health under DiloColdBelow (0.3) x MaxHealth -> dart damage x DiloColdMul and dart venom dps x
  DiloColdMul (I: dart only). Star: the first time in a life the dilo drops under the line, the server's dart cooldown is
  cleared and the dilo gets DiloDartResetAt = now; DiloAttackTest 1.1 then clears its own cooldown and writes
  DiloDartReadyAt; ArenaTouch 1.16 / AbilityBar 1.27 show the dart pip full from that stamp.
- Diagnostics: DiloStatsRows ("venombite=n,..."), DiloVenomFeastHealed (total), DiloToxicHits, DiloColdActive,
  DiloDartResetCount.

## Files
- src/shared/SkillTree.luau 1.60 (rows, effects, notFor.Dilo on the five shared lines) + tools/tests/SkillTreeDilo.spec.luau 1.0 (Logic).
- SkillEffects 1.41 (dilo effects, attributes, base capture).
- DiloAttackServer 1.1 (venom rule, Venom Bite, Toxic Blood, Venom Feast, Cold Blood).
- src/character DiloAttackTest 1.1 (DiloDartResetAt), ArenaTouch 1.16 + AbilityBar 1.27 (pip reads DiloDartReadyAt).
- Docs.

## Tasks (Dev Hub MDA-235 .. MDA-239)
1. SkillTree 1.60 + spec · Logic (red, then green; other skill specs still pass).
2. SkillEffects 1.41 · Wired.
3. DiloAttackServer 1.1 · Wired.
4. DiloAttackTest 1.1 + ArenaTouch 1.16 + AbilityBar 1.27 · Wired (PC and phone together).
5. Studio check + docs · Wired: every line at each step on the test player only (SkillPath restored after), other dinos
   untouched.

## Red-team rulings (Kepu 2026-11-04)
- R1: "Close hits only" (24-stud rule as written).
- R2: "Stronger one wins" (higher dps and later end; never stacked).
- R3: "Yes, change both" (input + PC and phone buttons for the Cold Blood recharge).
- R4: settled earlier by "Only its own". R5: accepted; tune after a phone test.

## Red-team
- R1 Toxic Blood needs "who bit me". LastHitBy / LastHitAt are stamped by bots (BotServer), Arena players (ArenaPvP), the
  Shock Cannon and mines; the 24-stud rule keeps the ranged ones out. A melee hit from a player in the Sandbox never
  happens (no player damage there). Accepted unless Kepu objects.
- R2 Two venoms on one target: today a new dart simply overwrites. With bite venom (weaker) the overwrite could lower a
  stronger dart venom, so the rule becomes "higher dps and later end win, never stacked". This changes nothing for a
  dart-only dilo.
- R3 Cold Blood's instant recharge has to reach the phone and PC buttons, or the pip would look empty while the spit is
  ready: three client files change (input + both HUDs). Kept.
- R4 Hiding the shared lines: a dilo player who already bought Jaws / Thick Hide etc. loses those effects on the dilo and
  gets the points back (Therizino precedent, Kepu's "Only its own").
- R5 Balance at max: Venom Feast 50% heals about 3 per dart; Cold Blood doubles a dart to 12 + venom 4/s under 30% health.
  Numbers are attributes; tune after a phone test.
