# Mecha Dino Arena — Cloak Field look 1.1 (camo plates + hex dissolve)

**Goal:** the Cloak part stops reading as a second Thrusters and gets a turn-on / turn-off animation.
**Chosen direction:** option C "Camo plates" (Kepu 2026-10-29 12:44: "I like option C"), mockup docs/mockups/cloak_look_options.html.
Kepu's feedback that started it: "the cloak design looks too similar to the thrusters. it also doesnt have an animation to show when it turns on."

## Global Constraints
- Cloud place 84022023159448 only; `game.PlaceId` check before every install; hash + loadstring verify.
- Versions: CloakServer 1.1, CloakFX 1.1. Header, changelog line, version attribute, docs/VERSIONS.md row, docs/ATTRIBUTES.md section.
- Colours: stealth black rgb(29, 37, 51) plates, neon cyan rgb(95, 243, 255) rims, open face teal rgb(18, 58, 68). Thrusters keep grey + orange.
- Cloak rules unchanged (CloakServer 1.0 state map, 4.1 s / 12 s / star 2x); the animation is cosmetic and on every client.

## Do-not-touch
MechaServer (Thrusters), PounceServer, BotServer, SkillServer / SkillEffects, MechaButtons, AbilityBar, SkillScreen, the cloak state map.

## 2D mockup → 3D
- Plates: 4 upright hexagonal plates in the body's mid-plane on top of the Torso segment, at 14 / 33 / 52 / 70 % of its length from the front (mockup x positions), radius 5.2 % of the dino's height, centre half a radius above the top. Each plate = 3 black blocks (√3R × R, rotated 0 / 60 / 120° about the sideways axis) + a cyan neon rim hex (radius 1.12 R, slightly thinner) behind them. The front black block of each plate is held by a Weld (BaseC0 attribute) so clients can turn it.
- "Flip open" = each plate turns 180° about the spine axis through its centre (side view: it narrows to an edge and comes back, as in the mockup), front to back 0.06 s apart, 0.12 s each; past half-way its black blocks show teal (the open face). Closing is the reverse, back to front.
- "Hex cells blink out" = the dino's own blocks: each visible part flashes neon cyan for 0.08 s, then takes the cloak transparency, in an order set by its distance to the nearest plate (75 %) plus a fixed per-part jitter (25 %): first at 0.12 s, last by 0.56 s. Turning off reverses it (far parts first) over 0.35 s. Hitbox boxes and invisible parts never flash.

## Task 1 — CloakServer 1.1 · Mode: Wired
- Script attribute CloakLookStyle (default "plates"; "fins" = the 1.0 fins). buildPack builds Model "Mecha_Cloak" with Plate_1..4 (Plate_n_Body_0..2 black, Plate_n_Rim_0..2 cyan neon; Plate_n_Body_0 welded with Weld "PlateHinge" + attribute BaseC0, the rest WeldConstraint to it). CloakLook "plates" / "fins" / "none" / "noTorso".
- Acceptance: 4 plates on the raptor's back (side view reads as hexes), Thrusters still visible next to them, removed when unslotted, rebuilt on respawn / re-slot.

## Task 2 — CloakFX 1.1 · Mode: Wired
- Phases from replicated stamps: turningOn = cloaked and now − CloakStartedAt < 0.56; on; turningOff = not cloaked and 0 ≤ now − CloakedUntil < 0.35 (an end of this cloak); off. Script attribute CloakFXAnimEnabled (default true; false = 1.0 instant look). Diagnostic CloakFXPhase on each dino (this client).
- Acceptance: turn-on and turn-off play for yourself and are timed from server stamps; full restore after (colours, materials, transparency, plate angle); no flashing hitboxes; death mid-animation leaves nothing behind.

## Red-team (one paragraph, 2 tickets, no data / sync / security)
How this fails: local colour / material changes on parts could stick if a part is changed by another script mid-flash (restored from the saved original, risk accepted); a Weld C0 change on another player's dino is local only, which is what we want, but a server rebuild (re-slot) mid-animation resets the plates (the next frame re-reads the new parts); the 0.56 s dissolve happens after bots have already lost you (server state turns on at once), which matches the 1.0 rules. The "others see" view still needs a second player to check.
