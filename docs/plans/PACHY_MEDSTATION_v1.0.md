# Mecha Dino Arena v1.0 — Pachy Med-Station

**Goal:** give the pachy a way to heal mid-fight that costs it mobility: it drops a machine and has to stay in its circle to heal.
**Chosen direction:** look "C · Pulse pad" (mockup docs/mockups/pachy_medstation_options.html): a flat pad with a green neon rim that sends a green wave out to the edge once a second (one heal tick per wave); the edge is a dashed ring on the ground.
**Architecture:** the existing shared path `medstation` (Health area, mech, today OWNER "none" + soon) becomes the pachy's live slot part (OWNER Pachy, LIVE_MECH, BUTTONS, soon false). SkillEffects writes Med* attributes while it is bought AND slotted on a pachy. A new MedStationServer takes the button press, drops the pad at the pachy's feet and heals the owner while its root is inside the circle. MechaButtons / AbilityBar treat it as a timed part (prefix "Med").

## Kepu's answers (2026-10-30)
- "drop a Machine that provides heals in an area for 5 seconds and heals your health up to 50 percent in those 5 seconds. It can't be dropped while pinned down by another dinosaur or stunned. This gives the pachy heals but limits its mobility so it's not broken"
- Heal: 50% of max health over 5 s (pachy +45, 10%/s), capped at full.
- Cooldown 30 s from the drop.
- Heals only inside the circle; leaving pauses the heal; hits don't stop it; the pad still ends on time.
- Steps: keep II bigger area / III lasts longer; ★ "Why would I allow two drops of it ... Just extend the duration to be able to full heal in 10 seconds".
- Look: "Let's do the pulse pad."

## Steps (SkillTree)
| Step | Effect fields | What it does |
|---|---|---|
| I | medRadius 12, medTime 5, medRate 0.10, medCooldown 30 | Button: drop a Med-Station at your feet; inside its circle heal 10% of max health per second for 5 s (50%). Not while pinned or stunned |
| II | medRadius 18 | Bigger heal area |
| III | medTime 7 | Lasts 7 s (up to 70%) |
| ★ | medTime 10 | Lasts 10 s: a full heal (100%) |

## Global constraints
- Additive only, each change behind a switch, version header + docs/VERSIONS.md + docs/ATTRIBUTES.md rows.
- Shipped maxed through the test layer (SkillTestCloakEnabled gives LIVE_MECH parts at ★ and slots them).
- Install by multi_edit, verify by hash; Studio tests with own pachy and bots only.

## Do-not-touch
- SkillEffects' 8 s heal, Lifesteal, Regeneration; KillRegenServer; HeadbuttServer / Blood Rush; ArenaPvP bridge (read only: a Humanoid heal copies into DummyHealth already).
- The raptor / T-Rex trees (they never saw Med-Station; OWNER stays theirs = nothing).

## Tasks
1. **SkillTree 1.29** (Logic): medstation for the pachy: PATHS.medstation.dino = "Pachy", soon = false, LIVE_MECH, BUTTONS, step texts above; effects() fields medRadius / medTime / medRate / medCooldown (0 below I). Switch SkillTree.PACHY_MEDSTATION. Spec checks: seesPath Pachy true / Raptor false / TRex false; effects 0..4.
2. **SkillEffects 1.22** (Wired): while bought AND slotted on a pachy: MedEnabled, MedRadius, MedTime, MedRate, MedCooldown (off values otherwise). The 8 s heal is skipped while the owner is inside a running pad (red-team 1). Switch SkillEffectsMedEnabled.
3. **MedStationServer 1.0** (new, Wired): ReplicatedStorage.DinoMedRequest:FireServer(stamp). Checks, first failing wins: badArg, dead, disabled, menu, stunned (StunnedUntil > now), pinned (PinHeld), cooldown (now < MedReadyAt), ok. ok: MedReadyAt = now + MedCooldown, MedActiveUntil = now + MedTime, MedDroppedAt = now (last). Pad: Model "MedPad" in Workspace.MedStations at the ground under the pachy's root (raycast down, CanCollide parts), anchored, no collide / query / touch. Heal: every 0.25 s while now < MedActiveUntil and the owner is alive: inside = flat distance from root to pad centre <= MedRadius (scaled studs) -> Humanoid.Health += MedRate x MaxHealth x 0.25, capped at MaxHealth. MedInside true / false, MedHealed total. Ends on time, owner death, leave, MedEnabled false ("time" / "dead" / "removed"). Only the owner is healed. Switch MedStationServerEnabled.
4. **Pulse pad look** (in MedStationServer, Wired): dark pad disc (3 studs x dino scale) with a green neon rim and a green PointLight; a dashed ring of neon segments at MedRadius on the ground; once a second a green neon ring "MedWave" grows from the pad to MedRadius and fades (one per heal second); "+N" pop over the pachy every second it heals; the ring dims while the owner is outside.
5. **HUD** (Wired): MechaButtons 1.18 (TIMED_PARTS.medstation = {"Med", "DinoMedRequest", "MED-STATION"}), AbilityBar 1.11 (TIMED_PARTS.medstation = "Med"; no MedUntil so ready / cooling only). Slot key = the slot it sits in.
6. **ArenaScope + docs + Studio test**: drop at 45 / 90 -> +9/s inside, paused outside, ends at 5 s; refused when stunned / pinned / cooling; ★ 10 s full heal; pad look capture.

## Branches
| Condition | Result |
|---|---|
| press, not bought / not slotted / not a pachy | "disabled" |
| press while StunnedUntil > now | "stunned", nothing dropped |
| press while PinHeld | "pinned", nothing dropped |
| press before MedReadyAt | "cooldown" |
| press ok | pad drops at feet; cooldown starts now |
| owner root inside radius, pad running, health < max | heals MedRate x max per second |
| owner outside radius | no heal, MedInside false, ring dims |
| health at max | no heal (pad keeps running) |
| pad time up / owner dies / leaves / part unslotted | pad removed |
| press again while a pad runs (only after the cooldown, 30 s > 10 s) | not possible at these numbers |

## Red-team answers (Kepu 2026-10-30)
1. Pad heal vs the 8 s heal (SkillEffects 1.21, 5%/s) -> "Bigger one only": while the owner is inside a running pad, SkillEffects 1.22 skips its 8 s heal (character MedInside == true and MedActiveUntil > now). No 15%/s.
2. Who heals -> "Only the pachy who dropped it". Enemies in the circle get nothing.
3. Pad + Blood Rush (a full heal resets the Blood Rush count) -> "That's fine": accepted, no change to HeadbuttServer.
Accepted risk: no way for enemies to break the pad; it only ends on time / death / leave / unslot.
