# Mecha Dino Arena v1.0 — Troodon slot effects: Lattice Bastion (Shield Dome) + Blossom Nova (Bloom Burst)

**Goal:** replace the lazy Shield Dome and Bloom Burst effects with the picked looks.
**Intent (Kepu 2026-11-10):** 10:38 "better vfx it looks so lazy. The bloom burst needs better vfx as well"; 11:36 "I like both of your picks" = Dome A Lattice Bastion + Burst A Blossom Nova.
**Chosen direction:** mockup docs/mockups/troodon_slotvfx_v0.1.html (artifact A7XSDhaap5SMWDWw5DoWkr), options A + A.
**Architecture:** client only. TrooSlotFX 1.1 draws both effects from the stamps the server already writes (TrooDome parts in Workspace.TrooDomes with TrooDomeRadius / TrooDomeUntil / WallBlockedPos / WallBlockedAt; the character's TrooBurstTo / TrooBurstLandAt / TrooPartBurstRadius; TrooBoostUntil / TrooHealCutUntil on the targets). No server, blocking or number change.

## Global constraints
- Every change behind a switch, every number an attribute (TrooSlotFX_* on the script); version tags in the header, VERSIONS.md, ATTRIBUTES.md.
- Wind-up -> action -> result -> recovery; no landing FX. Same on PC and phone (one client script).
- Colours from the roster: shield blue 5AB4FF / BFE6FF / EAF7FF, heal green 46E08A / C8FFD8, no-heal violet B36BFF.
- No new images (petals are Neon parts with a Sphere SpecialMesh, rings are Neon segments).
- Not published until Kepu says "Publish".

## Do-not-touch
TrooSlotServer 1.1 (the ball, its grow / shrink, the heals, the 20-damage sentry), SapWallBlock 1.3 (blocking), TrooSlotLooks / TrooPartsServer (the canister and bud on the body), MechaButtons, AbilityBar, the other dinos.

## The two looks (game studs)
| | Shield Dome · Lattice Bastion | Bloom Burst · Blossom Nova |
|---|---|---|
| Trigger | a TrooDome part appears (server opens the dome) | TrooBurstLandAt (server heals at the same moment) |
| Action | geodesic frame (icosahedron detail 2, upper half: ~270 Neon beams ~0.5 studs thick) turns on row by row from the ground up in 0.55 s; 10 base pillars flare; base ring (48 Neon segments) | flash; 6 petals (Neon green-white, Sphere SpecialMesh 0.46 x 0.05 x 1) unfold flat to 0.55 x radius in 0.28 s (Back ease); light column (Neon cylinder) 40 studs up in 0.28 s |
| Result | edge glow = a Highlight on the server ball (fill 5AB4FF 0.85, outline BFE6FF, DepthMode Occluded); a scan band (48 segments) climbs the dome every 1.4 s; a blocked shot lights the struck triangle (2 WedgeParts, white, 0.45 s) + flat ring + sparks | white + green shockwave rings to the radius (the existing ring()); 26 petal parts drift out over the area and settle in 1.6 s; each boosted squadmate: 6 petals swirl round it for 1.1 s; each cut enemy: a violet ring (24 segments) shrinks at its feet + a dark puff |
| Recovery | the frame drops away top-down in the last 0.45 s (TrooDomeUntil - 0.45 .. TrooDomeUntil); the server ball shrinks as today | petals fade; the bud regrows in the sling as today (0.8 s) |
| Numbers (attributes) | TrooSlotFX_latticeDetail 2, _latticeThick 0.5, _latticeBuild 0.55, _latticeFall 0.45, _latticeScan 1.4, _latticePillars 10, _latticeRingSegs 48 | TrooSlotFX_novaPetals 6, _novaOpen 0.28, _novaSize 0.55, _novaColumn 40, _novaDrift 26, _novaSwirl 6 |
| Switch | TrooSlotFX_domeLatticeEnabled (false = 1.0: the ripple only) | TrooSlotFX_burstNovaEnabled (false = 1.0: flash + 2 rings + sparks) |

## Tasks
### Task 1 — Lattice Bastion · Mode: Wired
Files: Modify `src/client/TrooSlotFX.client.luau` (1.0 -> 1.1): new block after watchDome (geodesic built once and cached per detail; one Model per dome in a client folder Workspace.TrooSlotFXLocal; parts Anchored, CanCollide / CanQuery / CanTouch false, CastShadow false).
Consumes: TrooDome part (Position = ground centre, TrooDomeRadius, TrooDomeUntil, WallBlockedPos / At). Produces: diagnostics TrooSlotFXLast "odome:lattice" / "odome:panel".
Acceptance: frame builds bottom-up and covers the full 90 / 121.5-stud dome; scan band; struck panel lights on a blocked shot; frame drops at the end and all its parts are gone 0.1 s after TrooDomeUntil; switch off = 1.0; no script errors; seen the same on the PC and phone emulator.

### Task 2 — Blossom Nova · Mode: Wired
Files: Modify `src/client/TrooSlotFX.client.luau` (TrooBurstLandAt handler: the 1.0 look stays as the off branch).
Consumes: TrooBurstTo, TrooPartBurstRadius, TrooBurstLandAt; targets' TrooBoostUntil / TrooHealCutUntil. Produces: TrooSlotFXLast "oburst:nova".
Acceptance: petals, column, rings, drifting petals, squad swirls, enemy violet rings at the landing; all parts gone within 2 s; switch off = 1.0; no script errors; PC + phone emulator.

### Task 3 — Studio check + docs · Mode: Wired
Install by hash; Play: dome (C) and burst (R / phone tap) with held bots, screenshots from the game camera and close; part count per dome; VERSIONS / ATTRIBUTES; ticket notes. Not published.

## Deterministic map
- Dome appears while the switch is off -> 1.0 ripple only. On -> lattice. Dome ends early (TrooDomeUntil set to 0 by the server) -> the frame drops at once (0.2 s) and is destroyed. Dome part removed without an end -> frame destroyed with it (Destroying / AncestryChanged). Two domes at once (two troodons) -> one frame each. Joined mid-dome -> the frame shows fully built (no build-up) with the time left.
- Burst with no squadmate / no enemy inside -> petals + column + rings only. Switch off -> 1.0.

## Red-team
1. **Phone frame rate.** ~270 beams + 48-segment ring + 48-segment scan band per dome, on the client. Mitigation: built once and only Transparency / CFrame tweened in batches (rows, not per part per frame); scan band moved 30 times a second; `TrooSlotFX_latticeDetail` 1 (~70 beams) as the fallback number. Accepted risk: Studio's phone emulator can't show real phone FPS, so Kepu checks it on his phone after a publish.
2. **Uneven ground.** The server's ball sits on the landing point; on a slope or next to rocks part of the frame goes into the ground or floats on the low side, and the 121.5-stud frame can stick through nearby walls. Visual only (CanQuery off). Accepted, flagged.
3. **Highlight cap.** Roblox draws at most 31 Highlights per client; TrooSlotFX already uses them for boost / NO HEAL / sleep marks. The dome edge glow is one more; if the cap is hit the oldest one stops drawing. DepthMode Occluded so the dome doesn't show through walls.
4. **Timing differs from the mockup by 0.3 s.** In the mockup the bud swells 0.3 s before it blooms; in the game the server heals the moment the bud lands, so the bloom plays at the landing (otherwise the +20 numbers pop before the flower). Accepted: the bud's flight is the wind-up.
5. **Petals as parts.** No image upload, so the drifting petals are small Neon ellipsoids (Sphere SpecialMesh), a little blockier than the mockup's sprites; ~26 + 6 per squadmate parts for 1.6 s. Alternative if Kepu wants it softer: upload one petal image and switch to a ParticleEmitter.
