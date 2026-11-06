# Mecha Dino Arena — Dilo animation pass: seven moves (plan v1.0)

**Goal:** each Dilo move reads as wind-up → action → result → recovery, and the three venom passives become visible.
**Chosen directions (Kepu 2026-11-05 22:32, "A for all of them"):** Bite **A · Cobra Strike**, Spit Dart **A · Hood Flare**,
Cobra Leap **A · Spring Coil**, Venom **A · Toxic Bubbles**, Toxic Blood **A · Spine Burst**, Venom Feast **A · Life Motes**,
Cold Blood **A · Frost Breath**. Mockup `docs/mockups/dilo_moves_anim.html` v0.1 (artifact "Dilo Move Animations"; key poses
and times in `tools/mockup/dilo_moves_anim.js`).

## Grounding (current code, commit after fb14b9b)
- DiloPose 1.0 (IdleAnimation 1.43+): tracks bite {0 $from, 0.1 C_BWIND, 0.17 C_BITE, 0.32 C_BITE2, 0.7 READY}, coil {0.3
  C_COIL, 0.85 C_COIL2}, release, spit {0.05 C_DART, 0.25 C_DART2, 0.8 READY}; owner reads DiloLocal* (DiloAttackTest), others
  DiloBiteAt / DiloDartAt and **never see a coil**. Frill open while coil / spit < 0.75 s / leap 0.16 s → landing + 0.32;
  frill grow = 0.2 + 0.8 back(t / 0.13) (+ rattle). Sac x DiloSacSwell (1.55) in the coil and early spit. Leap layer: crouch
  J_CROUCH (JumpWindup), push J_PUSH 0.1 s, air J_AIR, J_DOWN before touchdown, land J_LAND 0.12 s → READY 0.7 s.
- DiloAttackServer 1.3: remote DinoDiloAttack(kind "bite" | "dart", stamp) — any other kind = "badArg". Bite hit at the
  stamp + DiloBiteDelay 0.18. Venom ticks every 0.5 s. Toxic Blood on LastHitAt (close attacker) — counts DiloToxicHits, no
  target stamp. Venom Feast heals in `feast(byName, dealt)` — adds DiloVenomFeastHealed, no per-heal stamp. Cold Blood:
  character **DiloColdActive** already replicated (HealthChanged).
- DiloAttackTest 1.1: press → "bite"; hold → state "coil" after 0.15 s, "armed" at DiloHoldTime 0.4 when the dart is ready;
  release armed → "dart"; else "idle".
- DiloFX 1.1: dart glob + Trail, bite flash / sparks / pop, dart splash, venom (Highlight "DiloVenomGlow" + drips + tick pop),
  lock ring (owner, armed). No landing FX (house rule).

## Global constraints
- Additive, every change behind a switch (default on; off = the previous version exactly). Version branding in headers,
  docs/VERSIONS.md, docs/ATTRIBUTES.md. Diagnostics in attributes. Commit + push each change.
- Studio HTTP off: multi_edit / execute_luau, verified by hash. Never test with a second player.
- Damage, range, hold time, recharge, leap distance / timing unchanged. The bite still hits 0.18 s after the press.
- No HUD change. Saved progress untouched. Publish only on Kepu's word. No landing FX.

## Do-not-touch
Hit / target / venom / squad / mode rules, DeflectRules, the dart flight and body-hit rule, DiloModelData numbers,
JumpServer / the leap physics, ArenaTouch / AbilityBar, SkillTree / SkillEffects.

## Tasks

### Task 1 — DiloAttackServer 1.4: stamps for the animations · Wired
Switch: script `DiloAttackAnimStampsEnabled` (default true; false = 1.3).
- Kinds "coil" / "uncoil" (stamp only): alive, DiloAttackEnabled, not in the menu → "coil": DiloCoilAt = now; "uncoil":
  DiloCoilEndAt = now. No damage, no cooldown; other kinds unchanged. A "dart" also ends the coil (DiloCoilEndAt = now,
  before DiloDartAt).
- Toxic Blood: with each venom it applies, stamp on the dilo DiloToxicTarget (model name) then DiloToxicAt (last).
- Venom Feast: each heal stamps on the dilo DiloFeastFrom (the ticking model's name), DiloFeastAmount (healed, 0.1), then
  DiloFeastAt (last).
- Acceptance: stamps seen in Studio for a held spit, a cancelled hold, a Toxic Blood hit, a Feast heal; switch off = 1.3.

### Task 2 — DiloAttackTest 1.2: send the coil · Wired
Switch: character `DiloCoilStampEnabled` (default true). When the local state becomes "coil": FireServer("coil", t). When a
hold that had reached "coil" ends without a spit (release not armed, stun / menu cancel): FireServer("uncoil", t).
- Acceptance: one "coil" per hold, one "uncoil" per cancelled hold, none on a plain bite tap.

### Task 3 — DiloPose 1.1: Cobra Strike, Hood Flare, Spring Coil · Wired
Model switches `DiloCobraStrikeEnabled`, `DiloHoodFlareEnabled`, `DiloSpringCoilEnabled` (default true each).
- Bite (Cobra Strike): track {0 $from, 0.1 DRAW (io), 0.17 C_BITE + root 0.6 (in2), 0.24 CLAMP (out), 0.42 CLAMP (io), 0.6
  C_BITE2 (io), 1.0 READY (io)}; between 0.2 and 0.42 s Neck yaw + 12 sin(55 (t − 0.2)) x (1 − (t − 0.2) / 0.22), Head 0.6 of
  it; the frill opens 0.01 → 0.5 s. DRAW = RootJoint 6, Neck 26, Head −18, Jaw −6, Arms −12, root −1.2; CLAMP = C_BITE +
  Jaw 2, root +0.6. Hit time unchanged (server 0.18 s).
- Spit (Hood Flare): coil key FLARE_COIL (= C_COIL + Neck 6, Head −4, Jaw −10) at 0.27 s, + Neck 3 at 0.75 s; frill scale
  x1.25 while the coil / spit plays; sac pumps (1.55) at coil 0.03–0.15, 0.27–0.39, 0.51–0.63 s and the last 0.1 s before
  the spit; spit keys {0.05 THRUST (= C_DART + Neck −8, root +0.8, in2), 0.18 RECOIL (= C_DART + RootJoint 10, Neck 10,
  root −1.6, out), 0.9 READY (io)}. **Others** play the coil from DiloCoilAt (until DiloCoilEndAt / DiloDartAt), the same
  keys and sac pumps.
- Leap (Spring Coil): crouch J_DEEP (= J_CROUCH + Neck 10, Head −6, Knees −10, Tail1 6, Tail2 6, Tail3 4); push J_STRETCH
  over 0.08 s (out5: RootJoint −14, Neck −18, Head 6, Jaw −14, Arms 30, Legs −40, Knees −2, Ankles −30, Tail1 −6); air
  J_AIR from push + 0.24 s; land J_SOFTLAND (= J_LAND + Knees −12, Neck 6) over 0.14 s, READY by 0.8 s; frill from 0.1 s.
  Same leap timing and distance.
- Diagnostics: DiloPoseSet "1.1", DiloPoseState adds "coil:server".
- Acceptance: side-camera frames at bite 0.3 s, coil armed, spit +0.1 s, leap push, landing match the mockup; feet planted
  (ground lock); switches off = 1.0.

### Task 4 — DiloFX 1.2: the effects · Wired
Script switches (default true): `DiloFXStrikeEnabled`, `DiloFXFlareEnabled`, `DiloFXBubblesEnabled`, `DiloFXSpinesEnabled`,
`DiloFXMotesEnabled`, `DiloFXFrostEnabled`.
- Strike: a bite with targets adds a small spark burst at the point 0.12 s later (the clamp).
- Flare: a green mouth glow (pulsing) while armed (own: DiloLocalState "armed"; others: DiloCoilAt + 0.25 s until the coil
  ends); at each DiloDartAt 9 green droplets spray out of the mouth.
- Bubbles (venom): bubbles rise off the poisoned body (16/s) and pop; each tick a burst of 6 + the "-N" pop (see red-team Q1
  for the glow / drips).
- Spines (DiloToxicAt): 9 green spines fly from the dilo's neck toward DiloToxicTarget (0.32 s), a green flash, a
  "TOXIC BLOOD" tag (red-team Q3).
- Motes (DiloFeastAt): a green mote flies from DiloFeastFrom's chest to the dilo's mouth (0.42 s, curved), then a small green
  flash and "+N" (DiloFeastAmount).
- Frost (DiloColdActive): turning true → an icy flash + a blue ground ring (your own: a blue vignette); while true → an icy
  tint (red-team Q2) and a breath puff from the mouth every 0.45 s; darts fired while true are icy (glob and trail light blue)
  and their hit shows "×<DiloColdMul>".
- All parts in Workspace "DiloFX", non-colliding, cleaned up; MAX_PARTS still applies.
- Acceptance: each effect seen in Studio Play; part count back to baseline 2 s after; no errors; switches off = 1.1.

## Deterministic map
- Coil seen by others: DiloCoilAt newer than DiloCoilEndAt and DiloDartAt → coil (armed glow from +0.25 s); a dart → spit;
  "uncoil" → release. A lost "uncoil" ends the coil after 3 s (DiloPose timeout).
- Toxic Blood with no target model found on a client → flash only. Feast from a model that left → the mote starts at the dilo.
- DiloColdActive false → no frost; DiloColdMul missing → "×1.25" not shown (only "×" when > 1).
- Every switch off → the 1.x path.

## Red-team (resolved, Kepu 2026-11-05)
1. Venom: **bubbles + keep the faint green glow** (the drips go).
2. Cold Blood: **light tint** (a faint blue Highlight wash, FillTransparency ~0.85, no outline) + breath puffs.
3. Toxic Blood: **spines every time, the "TOXIC BLOOD" tag at most once per 3 s** per dilo.
4. Venom Feast motes: **everyone** sees them.
Accepted risks: the coil now costs one extra remote message per hold ("coil", plus "uncoil" when cancelled); a lost
"uncoil" leaves the coil on others' screens for up to 3 s (timeout).

Tickets: MDA-299 (Task 1), MDA-300 (Task 2), MDA-301 (Task 3), MDA-302 (Task 4) — see Dev Hub.
