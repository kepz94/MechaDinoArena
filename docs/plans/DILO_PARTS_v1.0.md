# Mecha Dino Arena v1.0 — Dilophosaurus mecha button parts (7 parts)

**Goal:** the dilo gets its own MECHA ABILITIES: 7 button parts it can slot (4 slots: R / T / C / V), each with a visible
part, a Lab card and four steps. Today it has none (only the six stat rows, SkillTree 1.60).

**Intent (Kepu 2026-11-06):** 00:35 "Let's work on the dilo mecha" -> 20 options (maxed texts only) -> 00:41 picks
"1. 3. 9. 13. 15. 16. 20." -> looks mockup docs/mockups/dilo_parts_options.html v0.1 (artifact 7LTsbM7v3asbFFSZLCBfeE)
-> 01:20 "All recommended except Venom Gatling - C, Toxin Mortar - C".
**Looks:** Gatling C Twin Hood Repeaters, Mortar C Chest Launcher, Hiss A Hood Speakers, Spine C Frill Barbs, Pump A Back
Pump, Jets C Tail Booster, Overdrive A Venom Reactor. Clash check of this exact set (mockup "All 7" with these letters,
2026-11-06): no overlaps; the neck base (launcher tube, repeaters, barb magazines) and the chest (launcher tank, reactor
core) are the busy spots, fine with 4 slotted at most.
**Animation spec:** tools/mockup/dilo_parts_looks.js v0.1 (part meshes, key poses, timings); every move wind-up -> action
-> result -> recovery; no landing FX.

**Architecture:** the therizino parts pattern (docs/plans/THERIZINO_PARTS_v1.0.md):
- SkillTree adds dilo-only button parts (`dino = "Dilo"`, LIVE_MECH, BUTTONS), ids prefixed `d` (no clash).
- SkillEffects writes `DiloPart*` character attributes while a part is bought AND slotted AND the species is Dilo.
- New DiloPartsServer builds the looks (`DPart_<id>`) and the Lab cards (`BuildPreview_<id>`); Lab / MainMenu learn `DPart_`.
- New DiloMovesServer owns the remotes and the effects; new DiloMovesFX draws them and moves the part pieces; MechaButtons
  gets 7 `TIMED_PARTS` entries (PC, gamepad and phone together); DiloPose gets the move poses.

## Global constraints
- Additive only; every script change behind its own switch; every number an attribute with a default.
- Versions (re-read the live version at build time and bump from it): SkillTree 1.69 + SkillTreeDiloParts.spec 1.0,
  SkillEffects 1.45, MechaButtons 1.35, DiloAttackServer 1.5, DiloPose 1.2, IdleAnimation 1.47, Lab 1.13, MainMenu 1.19,
  SprintTest (next); new DiloPartsServer 1.0, DiloMovesServer 1.0, DiloMovesFX 1.0, DiloJetsLaunch 1.0. VERSIONS.md /
  ATTRIBUTES.md rows for each.
- Install by multi_edit / execute_luau and verify by hash. Publish only on Kepu's "Publish" (both places). One-player tests.
  Saved progress untouched (test slots saved in ZZ_TenoTestBefore and restored).
- Every ability: parts shown only while slotted; a Lab card; squadmates never hit (SquadRules sameChar); players only where
  ModeRules.canAffect allows (the Arena); bots always.
- Upgrade rule (Herrera trim): steps extend time / reach / count / recharge.
- SkillTree lesson (the 1.61 hookRange bug): the dilo parts write only new `d*` effect fields and never assign a field
  another dino uses; a SkillTree.spec case checks a Pachy / Therizino / Teno effects table is unchanged with DILO_PARTS on.
- Every HUD change ships on PC and phone together (MechaButtons is the one button path for both).

## Do-not-touch
The dilo's bite / dart / Cobra Leap (DiloAttackServer, DiloAttackTest) except the two guarded hooks named below; the dilo
stat rows (SkillTree 1.60); every other dino's parts, servers and the SkillTree 1.61 therizino wrapper; DiloFX 1.2
(the parts FX are a new script); HookServer / the pachy hook bug (separate).

## The 7 abilities (Lab step texts; ★ = Kepu's picked maxed text; recharges are proposals)
| # | id | Name · area · look | I | II | III | ★ | Recharge |
|---|---|---|---|---|---|---|---|
| 1 | `dgatling` | Venom Gatling · ATTACK · C Twin Hood Repeaters | 4 auto-aimed darts in 1 s, 3 each + dart venom | 6 darts | Recharge 10 s | 8 darts | 12 s |
| 3 | `dmortar` | Toxin Mortar · ATTACK · C Chest Launcher | Lob a canister up to 40 studs: a 16-stud poison cloud for 3 s | 50 studs, cloud 20 | Cloud lasts 4 s | 60 studs, cloud 24, lasts 5 s | 16 s |
| 9 | `dhiss` | Sonic Hiss · ATTACK · A Hood Speakers | A 20-stud cone knocks dinos back and silences their mecha parts 1.5 s | Cone 25 studs | Silence 2 s; recharge 12 s | Cone 30 studs, silence 3 s | 15 s |
| 13 | `dspine` | Spine Burst · DEFENSE · C Frill Barbs | The frill fires 6 spines all around, 4 each | 8 spines | Spines add dart venom | 12 spines | 12 s |
| 15 | `dpump` | Antivenom Pump · DEFENSE · A Back Pump | Clear your debuffs and heal 15 | Heal 20 | Heal 30 | Immune to slows, stuns and blinds for 4 s | 20 s |
| 16 | `djets` | Spring Jets · SPEED · C Tail Booster | A 25-stud dash the way you move | 30 studs, 2 charges | 40 studs; leaves a poison trail | 3 charges | 6 s per charge |
| 20 | `dover` | Venom Overdrive · SIGNATURE · A Venom Reactor | 4 s: your darts recharge at once | 6 s | Your venom does double damage | Lasts 8 s | 30 s |

"Dart venom" = the dilo's own dart venom (DiloVenomDps 2 for DiloVenomTime 3 s, plus Venom Bite / Cold Blood as they
stand), applied through DiloAttackServer so Venom Feast and Cold Blood count it.

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Not bought / not slotted / not a dilo | — | off values; no `DPart_<id>`; no button |
| Any request | first failing check: badArg, dead, disabled, menu, stunned, pinned, dazed, silenced, cooldown | `DiloPart<Id>Result` = reason; nothing happens |
| ok | — | `DiloPart<Id>ReadyAt` = now + recharge (Jets: per charge) |
| Gatling | N darts over 1 s from the hood barrels (alternating), each at the nearest allowed dino in a 25° cone of the camera heading within the dart range; none -> straight ahead | each hit: 3 + dart venom; misses fly to range |
| Mortar | target = the camera-aimed ground point clamped to the reach; 1.2 s arc | cloud of diameter D for T s; every 0.5 s each allowed dino inside gets dart venom (refreshed, not stacked) |
| Hiss | cone of half-angle 35° along the facing, reach R | each allowed dino inside: knock-back 18 studs (players: the HeadbuttShove client path; bots: server move), `SilencedUntil` = max(old, now + S) |
| Silenced | `SilencedUntil` > now | MechaButtons greys every part button with a SILENCED tag; every DiloMovesServer request refuses "silenced" (other part servers: red-team 1) |
| Spine | N spines evenly round the dilo, 22 studs each | each hitbox crossed: 4 (+ dart venom from III) |
| Pump | — | clears VenomUntil, StunnedUntil, DazedUntil, InkedUntil and the slow tags (list in DiloMovesServer) to now; heals H; ★ `DiloImmuneUntil` = now + 4 |
| Immune | `DiloImmuneUntil` > now | DiloMovesServer resets any new StunnedUntil / DazedUntil / InkedUntil / slow tag on the dilo to now (one watcher, red-team 2); SprintTest skips slow multipliers |
| Jets | move direction (camera forward if standing) | the owner's client dashes the root L studs (DiloJetsLaunch, the ServoDashLaunch / TenoLeapLaunch client-launch pattern); III+: a 6 s trail, every 0.5 s dinos on it get dart venom |
| Overdrive | `DiloOverdriveUntil` = now + T | DiloAttackServer: the dart cooldown is 0 while on; III+: venom dps x2 (one guarded read each) |

## Tasks (two builds) — Dev Hub MDA-314 .. MDA-321 (T1..T8)
**Build 1 (projectiles + venom, proven patterns):** Venom Gatling, Toxin Mortar, Spine Burst, Venom Overdrive.
**Build 2 (cross-cutting):** Sonic Hiss (silence), Antivenom Pump (immunity), Spring Jets (client launch + trail).

1. **SkillTreeDiloParts.spec 1.0 + SkillTree 1.69** (Logic): the 7 paths, `dino = "Dilo"`, effects (numbers above), build-2
   parts `soon` until build 2; the no-overwrite spec case. Switch `SkillTree.DILO_PARTS`.
2. **SkillEffects 1.45** (Wired): `DPARTS` list writing DiloPart* attributes. Switch `SkillEffectsDiloPartsEnabled`.
3. **DiloPartsServer 1.0** (Wired): the 7 picked looks as `DPart_<id>` (welded, massless, no collision; meshes from the
   mockup), shown while enabled; `BuildPreview_<id>`; Lab / MainMenu learn `DPart_`. Switch `DiloPartsServerEnabled`.
4. **DiloAttackServer 1.5** (Wired): server BindableFunction `DiloVenomApply(target, char, mul)` calling its applyVenom;
   Overdrive reads (dart cooldown 0, venom x2). Switches `DiloAttackVenomApiEnabled`, `DiloAttackOverdriveEnabled`.
5. **DiloMovesServer 1.0 build 1** (Wired): remotes + the Gatling / Mortar / Spine / Overdrive rows. Switches
   `DiloMoves_<id>Enabled`.
6. **Client build 1** (Wired): MechaButtons 4 entries (PC + phone), DiloMovesFX (barrels spin, darts, canister arc + cloud,
   barbs, reactor glow), DiloPose move poses from the mockup keys. Studio check, then publish on Kepu's word.
7. **Build 2 server**: Hiss (cone, knock-back, SilencedUntil), Pump (clear, heal, immunity watcher), Jets (stamps, trail).
8. **Client build 2**: DiloJetsLaunch, MechaButtons 3 entries + SILENCED grey-out, SprintTest immunity skip, FX + poses.
   Studio check 2, then publish.

## Red-team rulings (Kepu 2026-11-06)
- 1 Silence: "Buttons + dilo server" (MechaButtons grey-out + DiloMovesServer refuses; other part servers untouched).
- 2 Immunity: "One watcher" (DiloMovesServer resets new debuffs while DiloImmuneUntil; SprintTest skips slows).
- 3 Venom: "Same venom system" (DiloAttackServer 1.5 DiloVenomApply API).
- 4 Numbers: "Use the proposals" (the table above; all tunable attributes).
- 5 Scope: not asked; the plan's two builds stand.

## Red-team
1. **Silence reach.** Silence only means something if every part server refuses a silenced player. Options: (a) MechaButtons
   greys the buttons + DiloMovesServer refuses (one client file; other dinos' servers untouched, so a modified client could
   still fire); (b) (a) + a shared `PartGate` check added as one guarded line to every part server (~20 servers).
   Recommended: (a) now — bots have no parts, players use MechaButtons; (b) can follow.
2. **Pump immunity.** Stuns / dazes / blinds / slows are set by ~15 servers. A single watcher in DiloMovesServer that resets
   them while `DiloImmuneUntil` runs keeps every other server untouched (a debuff can show for one frame). Recommended: the
   watcher + SprintTest skip.
3. **Part venom route.** Gatling / Mortar / Spine / Jets venom through DiloAttackServer (one new guarded API) so Venom
   Feast, Cold Blood and the venom ticks stay one system, vs a second venom loop in DiloMovesServer. Recommended: the API.
4. **Numbers.** Only the ★ texts were picked; the I–III ladders, the gatling dart damage 3 and the recharges are proposals.
5. **Scope.** 7 parts ≈ the therizino's two builds. Recommended: two builds as above.

## Build 1 notes (2026-11-06)
- Installed (Studio hash = repo): SkillTree 1.69 149007/519608414, SkillTreeDiloParts.spec 1.0 7939/362767414 (PASS 252),
  SkillEffects 1.45 92674/568023128, DiloPartsServer 1.0 18022/526335896, Lab 1.13 78212/479075335, MainMenu 1.19
  72519/39287555, DiloAttackServer 1.5 33836/947748107, DiloMovesServer 1.0 22951/546305223, MechaButtons 1.35
  96998/194805260, DiloPose 1.2 37001/835330355, DiloMovesFX 1.0 18526/117986659.
- Deviations: IdleAnimation not bumped (DiloPose.top already runs inside it). Hood pieces (speakers, barbs) weld to the
  frill part and copy its LocalTransparencyModifier so they follow DiloPose's frill pop. Overdrive's instant dart reuses
  DiloDartResetAt (DiloAttackTest unchanged). DiloMovesServer does not stamp LastHitBy / LastHitAt (TheriMovesServer doesn't).
- Verified in Play: see docs/VERSIONS.md (Dilo parts build 1 row): all 4 moves ok with damage, venom through the API,
  Venom Feast, Overdrive x2 + dart recharge, switches, keys R / T, FX cleanup, 0 errors.
- Not verified: touch buttons, AbilityBar seconds text during cooldown (blank), poses by eye, other players' view.
- Test note: setting SkillSlot attributes directly is overwritten by SkillServer's publish (death / respawn); the test kept
  them with a 0.2 s loop and SkillServer SkillSaveEnabled false for the Play session only.
- Pre-existing: SkillTree_spec fails 34 checks (it expects SkillTree v1.0); not changed.
