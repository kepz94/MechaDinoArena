# Mecha Dino Arena v1.0 — Tenontosaurus mecha abilities (7 button parts)

**Goal:** the teno gets its own MECHA ABILITIES: 7 button parts it can slot (4 slots: R / T / C / V), each with a visible part, a Lab card and four steps.

**Intent (Kepu 2026-11-01):**
- "Let's just list 16 or so possible abilities. Try to keep them versatile while also keeping in mind what's already on the roster, what the teno is naturally good at and ways to make the teno versatile with options."
- Picks: "3. 4. 5. (9. But make it 50% less damage and 50 percent faster.). 11. 40% less damage. 12. And 14. 7. But make it so if anyone attacks in that period they're slowed down for 4 seconds."
- "Remove the nest beacon."
- Looks: "3,4,7 - A", "5,9,14 - b", 11 "needs a redesign" -> "Let's go D".
- Kepu 22:22: "All you do is tag the other Dino's with a debuff instead of keeping track like that" -> no attacker tracking: Challenge and Mud put debuff tags on the enemies (Weak, Slow).
- Red-team answers: Mud "gives a real shield"; Mortar "Auto-target"; build size not decided yet ("My pc isn't on so we can't do it yet"; default two builds, asked again at build time).

**Chosen direction:** mockup `docs/mockups/teno_abilities_options.html` v0.3 (+ PICK.challenge = D). Sources `tools/mockup/teno_abilities_app.js` / `teno_abilities_head.html`, built by `tools/mockup/build_teno_abilities.py <three.min.js r128>`.

**Architecture:** the Herrera pass 2 / 3 pattern:
- SkillTree adds teno-only button parts (`dino = "Teno"`, LIVE_MECH, BUTTONS).
- SkillEffects writes `<Prefix>*` character attributes while a part is bought AND slotted (off values otherwise).
- A new TenoPartsServer builds the looks (`TPart_<id>`) and the Lab cards (`BuildPreview_<id>`).
- A new TenoMovesServer owns the remotes and the effects.
- A new TenoMovesFX draws them.
- MechaButtons gets the 7 entries in its `TIMED_PARTS` table.
- TenoPose gets the move poses.

## Global Constraints
- Additive only. Every script change sits behind its own switch, and every number is an attribute with a default.
- Versions:
  - SkillTree 1.48, SkillTreeTenoParts.spec 1.0, SkillEffects 1.32.
  - New: TenoPartsServer 1.0, TenoMovesServer 1.0, TenoMovesFX 1.0.
  - StatServer 1.2 (Weak debuff), BotServer 1.23 (Weak + Slow + mark target), MechaButtons 1.26, TenoPose 1.2, IdleAnimation 1.39, SprintTest 1.18.
- Install by multi_edit / execute_luau and verify by hash. Rows go in docs/VERSIONS.md and docs/ATTRIBUTES.md.
- Publish only when Kepu says "publish". Test PC + gamepad + phone before publishing. Never test with a second player.
- Rules that apply to every ability:
  - Parts are shown only while slotted.
  - Every part has a Lab card.
  - Squadmates are never hit, slowed, marked or grabbed (SquadRules sameChar).
  - Players are affected only where ModeRules.canAffect allows (the Arena); bots are always affected.
- Upgrade rule (after the Herrera trim): steps extend time / reach / recharge and never re-stack the main %.

## Do-not-touch
- The teno's tap / hold attack, TenoAttackServer, TenoStatsServer (Charge Up / Brace / Buck Off).
- The Herrera / raptor / pachy parts and their servers.
- SlashServer, BiteServer, PounceServer, HeadbuttServer and every other damage server: not edited. The Weak debuff reaches them through the attack attributes StatServer writes.
- The jump: no new jump effects (Kepu: keep the jump plain).

## The 7 abilities (step texts as shown in the Lab)
| # | id | Name · area · look | I | II | III | ★ | Recharge |
|---|---|---|---|---|---|---|---|
| 3 | `tgrab` | Tail Grab & Fling · ATTACK · A Clamp Tail | Grab the nearest raptor-size dino within 12 studs with your tail and fling it 30 studs ahead: 8 damage, stunned 1 s on landing | Fling 45 studs | Grabs bigger dinos too (up to pachy size) | The flung dino crashes into others where it lands: 8 damage each | 16 s |
| 4 | `tmortar` | Boulder Mortar · ATTACK · A Tail Catapult | Lob a boulder at the nearest enemy in front (up to 60 studs, auto-target; none -> 45 studs ahead): 12 damage in a 10-stud splash, slowed 30% for 2 s | Splash 14 studs | 2 boulders side by side | Rubble patch for 4 s slows 30% | 14 s |
| 5 | `tstomp` | Stomp Shockwave · DEFENSE · B Iron Hoof Plates | Rear up and stomp: a 14-stud shockwave, 6 damage, stun 0.5 s, knocks latched raptors off | Stun 1 s | Shockwave 20 studs | Stomped dinos can't jump or pounce for 3 s | 15 s |
| 9 | `tbellow` | Herd Bellow · HEALTH · B Crest Speakers | You + squadmates within 25 studs take 50% less damage and run 50% faster for 4 s | Lasts 6 s | Reaches 40 studs | Also clears stuns | 30 s |
| 11 | `tchallenge` | Challenge Call · DEFENSE · D Target Painter | Enemies within 30 studs are marked for 5 s: they deal 40% less damage, and bots go for you | Mark 7 s | Reaches 45 studs | Marked enemies are also slowed 20% | 20 s |
| 14 | `tleap` | Hydraulic Leap · SPEED · B Spring Coils | Leap 40 studs forward; the landing slams the tail: 10 damage in 12 studs (no slam charge used) | Leap 55 studs | Landing stuns 0.5 s | 2 leaps (2 charges) | 14 s |
| 7 | `tmud` | Mud Armor · DEFENSE · A Mud Tank | A mud coat for 8 s blocks your next 3 hits completely (even a killing blow); each blocked hit slows every enemy within 15 studs of you 40% for 4 s; latched raptors slide off | Soaks 4 hits | Coat lasts 12 s | When the coat ends, a 12-stud mud splash slows enemies 40% for 4 s | 20 s |

The ids are prefixed `t` so they can't clash with existing paths (`stomp`, `leap`, `mud` are free today, but the raptor / pachy trees grew with similar names).

The areas follow the mockup. The teno also sees its Signature area for Buck Off, which is a stat row, not one of these 7.

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Not bought / not slotted / not a teno | — | off values; no `TPart_<id>`; button absent |
| Any request | first failing check wins: "badArg", "dead", "disabled", "menu", "stunned", "pinned", "dazed", "cooldown" | `<Prefix>ServerResult` = reason; nothing happens |
| ok | — | `<Prefix>ReadyAt` = now + Cooldown (Leap ★: per charge) |
| Grab, no target | no allowed dino of an allowed size within 12 studs (behind or beside) | "noTarget", no cooldown |
| Grab size | I–II: Raptor, Herrera; III+: + Pachy, Teno; T-Rex never | — |
| Grab target is a latched raptor | latched on the teno | released (ShakeOffReason "grabbed"), then flung |
| Fling landing | — | 8 dmg, StunnedUntil = max(old, now + 1); ★: every other allowed dino within 8 studs of the landing: 8 dmg + stun 1 s |
| Mortar target | nearest allowed enemy root in a 30° cone of the camera heading within 60 studs | none -> lands 45 studs straight ahead |
| Mortar landing | each allowed dino within the splash | 12 dmg; slowed 30% for 2 s (players: TenoSlowUntil / TenoSlowMul; bots: WalkSpeed scale) |
| Mortar ★ | rubble patch for 4 s | enemies inside are slowed 30% |
| Stomp | allowed dinos within R of the front feet | 6 dmg + stun; latched raptors released ("stomped"); ★ NoJumpUntil = now + 3 (PounceServer / jump read it) |
| Bellow | the teno + squadmates within R | BellowUntil = now + T: 50% of every health drop refunded; SprintTest × 1.5; ★ StunnedUntil = now |
| Challenge | allowed enemies within R | debuff tags on each: TenoMarkedBy = teno name, TenoWeakUntil = now + T, TenoWeakMul 0.6; ★ also TenoSlowUntil = now + T, TenoSlowMul 0.8 |
| Weak (a tag, no tracking) | TenoWeakUntil > now | a player dino: StatServer 1.2 writes its attack attributes (StatSheet ATTACK_KEYS) × TenoWeakMul, back when it ends; a bot: its damage × TenoWeakMul and its target = TenoMarkedBy (BotServer 1.23) |
| Slow (a tag) | TenoSlowUntil > now | a player: SprintTest 1.18 run / walk × TenoSlowMul; a bot: WalkSpeed scaled (BotServer 1.23) |
| Leap | — | root impulse forward, landing (FloorMaterial back + 0.2 s) = slam 10 dmg in 12 studs; III stun 0.5 s |
| Mud | coat on (TenoMudUntil > now, TenoMudHits > 0) | a hidden ForceField "TenoMudShield" on the character (the Energy Shield mechanism: every Humanoid:TakeDamage is blocked: the ArenaPvP bridge, bot bites, Shock Cannon). Each blocked hit attempt (a new LastHitAt, or a bridged DummyHealth drop = ArenaPvPLastDelta write) = TenoMudHits −1, and every allowed enemy within 15 studs gets the Slow tag (TenoSlowUntil = now + 4, TenoSlowMul 0.6); nobody is tracked. At the start, latched raptors released ("mud") |
| Mud ends | TenoMudHits = 0 or TenoMudUntil passed | the ForceField is removed; ★: splash 12 studs, enemies slowed 40% for 4 s |
| A killing blow | health reaches 0 | Mud: blocked (ForceField). Bellow: not refunded (the same rule as Brace) |

## Tasks
Dev Hub tickets: MDA-173 (T1) … MDA-180 (T8). Open decision: build size.

1. **SkillTreeTenoParts.spec 1.0 + SkillTree 1.48** (Logic)
   - Write the spec red first, then add the 7 paths through `part(id, name, area, steps)` with `dino = "Teno"` and an effects wrapper (numbers above).
   - Switch: `SkillTree.TENO_PARTS`.
   - Check that the other dinos see none of them and the teno sees all 7 as BUTTONS.
2. **Debuff tags: StatServer 1.2 + BotServer 1.23** (Wired)
   - StatServer: while a character's TenoWeakUntil > now, its ATTACK_KEYS values are written × TenoWeakMul; re-apply when the tag starts and ends. Switch `StatWeakEnabled`.
   - BotServer: a bot's damage × TenoWeakMul and its target = TenoMarkedBy while the tag lasts; WalkSpeed × TenoSlowMul while TenoSlowUntil > now. Switch `BotTenoTagsEnabled`.
   - No attacker tracking anywhere (Kepu).
3. **SkillEffects 1.32** (Wired)
   - A `TPARTS` list like `HPARTS` that writes TenoGrab*, TenoMortar*, TenoStomp*, TenoBellow*, TenoChallenge*, TenoLeap*, TenoMud* on teno characters.
   - Switch: `SkillEffectsTenoPartsEnabled`.
4. **TenoPartsServer 1.0** (Wired)
   - The 7 looks as `TPart_<id>` (welded, massless, no collision, non-skin colours), shown while `<Prefix>Enabled`, plus `BuildPreview_<id>` for the Lab cards.
   - Switch: `TenoPartsServerEnabled`.
   - The Lab's `isMechaPart` doesn't know `TPart_*` yet, so this task also adds "TPart_" to the Lab 1.10 / MainMenu 1.11 checks: Lab 1.11, MainMenu 1.13.
5. **TenoMovesServer 1.0 — attacks** (Wired)
   - Remotes DinoTenoGrabRequest, DinoTenoMortarRequest(aimDir), DinoTenoStompRequest, DinoTenoLeapRequest.
   - Grab / fling, mortar, stomp, leap as in the map.
   - Switches: `TenoMoves_<id>Enabled`.
6. **TenoMovesServer 1.0 — support** (Wired)
   - Remotes DinoTenoBellowRequest, DinoTenoChallengeRequest, DinoTenoMudRequest.
   - Bellow: a refund hook on the buffed dinos' Humanoid.HealthChanged (no attacker needed).
   - Challenge: writes the Weak / Slow tags (Task 2 acts on them).
   - Mud: the hidden ForceField shield (EnergyShieldServer pattern; re-ground how it counts blocks before building). No damage server is edited.
7. **Client** (Wired)
   - MechaButtons 1.26: 7 `TIMED_PARTS` entries.
   - TenoMovesFX 1.0: beams, boulder arc, rings, mud coat, slow / mark tags, as in the mockup.
   - TenoPose 1.2 + IdleAnimation 1.39: grab curl / fling, catapult whip, rear + stomp, bellow, painter turn, spring-coil leap, wallow.
   - SprintTest 1.18: TenoBellowRunMul and TenoSlowMul.
8. **Studio check** (Wired)
   - Each ability at I and ★ against bots and a test target.
   - Squadmate never affected.
   - Lab cards and slots on PC / gamepad / phone.
   - Captures.

## Red-team (to answer before filing)
1. **Attribution (resolved by Kepu: "tag the other Dino's with a debuff").** No tracking of who hit whom. Challenge tags enemies Weak (their attack attributes × 0.6, so it covers every move that reads them) and Mud tags enemies near you Slow. Trade-offs: the 40% now applies to everything a marked dino hits (Kepu's original pick was simply "40% less damage"), and a far-away shooter is not slowed by Mud. Check at build: any damage move that does not read its attack attribute (re-ground the list) is listed in VERSIONS as "not weakened".
2. **Refund-based reduction can't save a killing blow** (same as Brace). Kepu picked "Mud gives a real shield". Grounding: every way a player loses health in a fight goes through Humanoid:TakeDamage (the ArenaPvP bridge, BotServer, ScreechServer), and a ForceField blocks that. This is how the raptor's Energy Shield already works. So Mud uses a hidden ForceField while the coat has hits left. Bellow keeps the refund (a killing blow still kills).
3. **Herd Bellow 50/50** is the strongest thing on the roster for 4 s. With 2 tenos in a squad it could chain. Mitigation: a second Bellow refreshes the time and doesn't stack, and there's a 30 s recharge. Watch it in play.
4. **Mortar aim:** Kepu picked "Auto-target" (no new aiming UI).
5. **Scope.** 7 parts is about the size of Herrera passes 2 + 3 together. Open (Dev Hub decision): two builds (attacks first: Tasks 1–5 + 7 for those 4; then support) or all 7 at once. Kepu answers when the PC is back.
