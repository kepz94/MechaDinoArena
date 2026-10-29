# Mecha Dino Arena v1.0 — Raptor parts, batch 1: Blade Claws, Adrenaline Injector, Energy Shield

**Goal:** three more raptor parts become buyable and working, so the raptor tree loses three "soon" lines.
**Kepu's calls (2026-10-29):** finish the raptor tree in 3 batches (this is batch 1 of 3; batch 2 = Dart Launcher + Pack Beacon, batch 3 = Grapple Hook + Decoy Hologram). Pack Beacon marks show to you only until squads exist. Looks (mockup docs/mockups/raptor_parts_b1_options.html, artifact https://claude.ai/artifact/GXFp1PQ5Lw8sfQRpJtEpGQ): Blade Claws **A · Sickle claws**, Adrenaline **A · Neck injector**, Energy Shield **B · Hard-light shell** (full block).
**Architecture:** SkillTree gets the three effects and marks them live. SkillEffects writes them as character attributes. Each part gets its own server script (BladeServer, AdrenalineServer, EnergyShieldServer) that owns its state and its visible part, following the CloakServer pattern. Existing scripts get small additive hooks: PounceServer (Blade numbers), StaminaServer (a refund stamp), SprintTest (Adrenaline speed), CloakServer (the new parts break the cloak), MechaButtons / AbilityBar (two new button parts), ArenaScope (expects the new scripts).

## Global Constraints
- Cloud place 84022023159448 only. Check `game.PlaceId` before every install; verify by hash + loadstring compile.
- Versions: SkillTree 1.6 (+ spec), SkillEffects 1.6, PounceServer 1.6, StaminaServer 1.5, SprintTest 1.6, CloakServer 1.3, MechaButtons 1.5, AbilityBar 1.3, ArenaScope 1.7, BladeServer 1.0 (new), AdrenalineServer 1.0 (new), EnergyShieldServer 1.0 (new).
- 35% rule: every step's number is at least 1.35× the step before. Energy Shield step II is therefore 2.05 s (1.5 × 1.35 = 2.025), not the mockup's 2 s.
- Enemy effects hit bots (`IsBot`), the only enemies today (no PvP).
- Every new behaviour has an on/off script attribute; every state change is an attribute.
- Boolean settings are read with an explicit if, never `cond and a or v` (lesson 2026-10-29, BoostPose 1.1).

## Do-not-touch
MechaServer / Thrusters, CloakFX, IdleAnimation and its pose modules, BotServer, BiteServer, RamServer, ShakeOffServer, StatServer, SkillServer, SkillScreen (already draws any live path), the T-Rex parts, the batch 2 / 3 parts (stay "soon").

## Steps and numbers

| Part | I | II | III | ★ |
|---|---|---|---|---|
| Blade Claws (passive) | pounce landing hit +0.35 (added to the other landing bonuses) | latch / pin bite interval × 0.74 | pounce hits bleed 3 / s for 4 s | a pin kill gives back 50% of PounceStaminaCost |
| Adrenaline Injector (button) | heal 20% of max health over 3 s, run × 1.3 for 3 s, cooldown 20 s | heal 27% | cooldown 14.8 s | usable while stunned and ends the stun |
| Energy Shield (button) | block all damage for 1.5 s, cooldown 16 s | 2.05 s | cooldown 11.9 s | burst at the end: bots within 12 studs × the raptor's scale are pushed away |

## Attribute contract (written by SkillEffects 1.6 on the character; 0 / false while off or not owned / not slotted)
- Blade (bought, passive; no slot): `BladeLandBonus` (0 / 0.35), `BladeTickMul` (1 / 0.74), `BladeBleedDps` (0 / 3), `BladeBleedTime` (0 / 4), `BladePinRefund` (0 / 0.5), `BladeLook` (true when steps ≥ 1).
- Adrenaline (bought and in any slot): `AdrenalineEnabled`, `AdrenalineHeal` (0.20 / 0.27), `AdrenalineTime` (3), `AdrenalineSpeedMul` (1.3), `AdrenalineCooldown` (20 / 14.8), `AdrenalineStunClear` (false / true).
- Energy Shield (bought and in any slot): `EnergyShieldEnabled`, `EnergyShieldTime` (1.5 / 2.05), `EnergyShieldCooldown` (16 / 11.9), `EnergyShieldBurst` (false / true).
- Server state (each part's own script): `AdrenalineStartedAt`, `AdrenalineUntil`, `AdrenalineReadyAt`, `AdrenalineServerResult`; `EnergyShieldStartedAt`, `EnergyShieldUntil`, `EnergyShieldReadyAt`, `EnergyShieldServerResult`, `EnergyShieldBlocks`, `EnergyShieldBlockAt`, `EnergyShieldBurstAt`, `EnergyShieldBurstCount`.

## Deterministic map
| State | Condition | Result |
|---|---|---|
| Request "badArg" | stamp not a number | denied |
| "dead" | no character / health ≤ 0 | denied |
| "disabled" | script switch off or `<Part>Enabled` ~= true | denied |
| "stunned" | StunnedUntil > now (Adrenaline: only without `AdrenalineStunClear`) | denied |
| "latched" | PounceLatched == true | denied |
| "active" | `<Part>Until` > now | denied |
| "cooldown" | now < `<Part>ReadyAt` | denied |
| "ok" | otherwise | StartedAt = stamp clamped to [now − 0.3, now]; Until = now + time; ReadyAt = Until + cooldown (cooldown counts from the end, like Cloak) |
| Adrenaline heal | each 0.1 s while Until > now and health > 0 | health += heal × MaxHealth × dt / time, capped at MaxHealth |
| Adrenaline ★ | ok while StunnedUntil > now | StunnedUntil = now |
| Adrenaline speed | AdrenalineUntil > now (SprintTest 1.6) | the chosen speed × AdrenalineSpeedMul (× the roar debuff as before) |
| Shield block | Until > now | a ForceField (Visible false) on the character: every Humanoid:TakeDamage does nothing; a new LastHitAt counts a block |
| Shield end | Until reached, death, or `EnergyShieldEnabled` false | ForceField and the shell removed; burst only on the timed end with ★ |
| Death mid-part | health ≤ 0 | Until = now, effects removed; the cooldown still applies |
| Cloak on | AdrenalineStartedAt / EnergyShieldStartedAt changes | cloak ends "part" (CloakServer 1.3) |
| Blade pin kill | a PounceServer pin hit takes the target's DummyHealth to 0 and BladePinRefund > 0 | StaminaRefundAmount = refund × PounceStaminaCost, then StaminaRefundAt = now (StaminaServer adds it, clamped to max) |

## Tasks (build order)

### Task 1 — SkillTree 1.6 · Mode: Logic
**Files:** Modify `src/shared/SkillTree.luau`; Test `tools/tests/SkillTree.spec.luau`.
**Produces:** `effects(...)` fields `bladeLandBonus, bladeTickMul, bladeBleedDps, bladeBleedTime, bladePinRefund, adrenHeal, adrenTime, adrenSpeedMul, adrenCooldown, adrenStunClear, eshieldTime, eshieldCooldown, eshieldBurst`; `LIVE_MECH.blade / .adrenaline / .shield = true` (blade stays out of BUTTONS: passive).
- [ ] Spec first: the step table above for each part, 35%-rule checks (I→II heal 0.27/0.20 = 1.35; shield 2.05/1.5 ≥ 1.35; cooldowns 20/14.8 and 16/11.9 ≥ 1.35), T-Rex gets all zeros, blade not slottable, adrenaline / shield slottable. Run in Studio Edit → FAIL.
- [ ] Code, run → PASS. Version header + changelog.
**Acceptance:** spec PASS; raptor tree shows the three lines as buyable (no "soon").

### Task 2 — SkillEffects 1.6 · Mode: Wired
**Files:** Modify `src/server/SkillEffects.server.luau`.
**Consumes:** Task 1 fields. **Produces:** the attribute contract above; pounce-hit bleed uses max(Jaws bleed, Blade bleed).
**Acceptance:** buying each step changes the attributes; adrenaline / shield enabled only while slotted; T-Rex all off.

### Task 3 — PounceServer 1.6 + StaminaServer 1.5 · Mode: Wired
**Files:** Modify `src/server/PounceServer.server.luau`, `src/server/StaminaServer.server.luau`.
- Landing: `extra += BladeLandBonus` (script switch `PounceBladeEnabled`, default true); diagnostic `PounceBladeBonus`.
- Tick: interval × `BladeTickMul` (clamped 0.2..1).
- Pin kill: in `hit`, when the latch mode is "pin" and the hit kills → refund stamp (see map).
- StaminaServer: a new `StaminaRefundAt` adds `StaminaRefundAmount`, clamped; diagnostic `StaminaLastEvent "refund"`, `StaminaRefundCount`.
**Acceptance:** landing 8 → 11 with Blade I alone (8 × 1.35); with Cloak III as well 8 × 1.70 = 14; tick 0.5 → 0.37 s; pin kill refunds 7.5.

### Task 4 — BladeServer 1.0 (new) · Mode: Wired
**Files:** Create `src/server/BladeServer.server.luau` (ServerScriptService).
- While `BladeLook` is true: Model "Mecha_Blade" with a silver sickle (2 wedge parts: steel blade + red edge) on each foot segment (FootL / FootR Root), joined by Weld "SickleHinge" (BaseC0). Massless, no collide / query / touch, no shadow.
- PounceStartedAt → hinges flick up 50° over 0.12 s; back down 0.6 s after PounceLatched turns false (or 1.2 s after the start without a latch).
- PounceBiteAt with a landing (PounceLatchedAt within 0.05 s): 3 red neon slash strips at the latch part for 0.3 s.
- Switch `BladeServerEnabled`; diagnostics `BladeLookState` ("none" / "on" / "noFeet"), `BladeFlick` ("down" / "up").

### Task 5 — AdrenalineServer 1.0 (new) · Mode: Wired
**Files:** Create `src/server/AdrenalineServer.server.luau`; RemoteEvent `DinoAdrenalineRequest`.
- Request checks per the map; heal loop; ★ stun clear.
- Look: Model "Mecha_Adrenaline" while `AdrenalineEnabled`: dark canister + green glass + grey plunger on the side of the neck (Neck segment Root), Weld "PlungerHinge". On use: plunger pushed in (0.25 s), a green Highlight pulse (FillTransparency 0.4 → 1 over 0.5 s), green Trails on both feet enabled for the boost.
- Switch `AdrenalineServerEnabled`; diagnostics `AdrenalineRequests`, `AdrenalineHealed` (last total).

### Task 6 — EnergyShieldServer 1.0 (new) · Mode: Wired
**Files:** Create `src/server/EnergyShieldServer.server.luau`; RemoteEvent `DinoEnergyShieldRequest`.
- Request checks per the map; ForceField "EnergyShieldField" (Visible false); Highlight "EnergyShieldShell" (OutlineColor 90,160,255, FillTransparency 0.85, OutlineTransparency 0) while on; a block (new LastHitAt) → `EnergyShieldBlocks` + 1, `EnergyShieldBlockAt`, outline white for 0.12 s.
- Small chest emitter disc (Torso Root, front) while `EnergyShieldEnabled`.
- ★ burst on the timed end: each bot HumanoidRootPart within 12 × raptor scale gets AssemblyLinearVelocity = away × 60 + up × 25 (`EnergyShieldBurstPush` 60); a blue ring Highlight flash.
- Switch `EnergyShieldServerEnabled`.

### Task 7 — SprintTest 1.6 + CloakServer 1.3 · Mode: Wired
- SprintTest: speed × AdrenalineSpeedMul while AdrenalineUntil > now; re-applied at start and at the end (scheduled like the debuff). Diagnostic `MoveSpeedMul` includes it.
- CloakServer: PART_STAMPS += "AdrenalineStartedAt", "EnergyShieldStartedAt".

### Task 8 — MechaButtons 1.5 + AbilityBar 1.3 + ArenaScope 1.7 · Mode: Wired
- MechaButtons: press on "adrenaline" / "shield" fires the part's remote; `partState` for both from `<P>Enabled / <P>Until / <P>ReadyAt / <P>Cooldown`; names "ADRENALINE" / "SHIELD".
- AbilityBar: the same states as the cloak tile (off / active with seconds left / cooling with fill / ready).
- ArenaScope: expects the three new server scripts.

## Verification (Play, raptor with fake kills for points)
Each task's acceptance plus: buy all three (Mastery allows), slot Adrenaline in C and Shield in V, use both on PC; a bot bites during the shield → health unchanged, blocks counted; adrenaline from 45% → +20% in 3 s and run speed × 1.3; cloak breaks on either press; 2-player check that the other player sees the sickles, the canister pulse and the shell.

## Red-team
1. **ForceField blocks more than bot bites.** Any `TakeDamage` source (future PvP, survival damage uses Health directly so it is not blocked) is blocked too. Accepted: "blocks damage" is the step text; noted for PvP.
2. **ForceField shows a sparkle by default.** Mitigated: `Visible = false`; the shell is the Highlight.
3. **Highlight limit (31 per client).** Many raptors shielding at once could hit it. Accepted for now (solo / small servers); the shell would just not draw past the limit, the block still works.
4. **Bot push fights BotServer's movement.** BotServer may move the bot right after; the push may look short. Mitigated by a strong, short impulse; tune `EnergyShieldBurstPush`. If it doesn't read, follow-up: use BotServer's toss path (out of scope here, BotServer is do-not-touch).
5. **Mastery 3 caps builds.** Players can't max all parts; that is intended (ADR-003).
