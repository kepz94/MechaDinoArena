# Mecha Dino Arena — Herrera Cruise Missile (mecha part) v1.0

**Ask (Kepu 2026-11-13 17:23):** "a cruise missile that works just like the call of duty one ... mounted on its back and look really funny but it will go into the same animation basically that the call of duty one goes into where you're directing the missile as it's flying down on the map. Zero damage to teammates but does 40 damage to enemies with a big splash radius maybe just around the size of the point or a little bigger". 17:26 "Shorten the reload time to 25 seconds".
**Mockup:** docs/mockups/herrera_cruise_missile_v0.1.html. **Picks:** look "B · Backpack silo", view "A · Thermal (CoD)", damage "Flat 40 everywhere", numbers as the Lab card with recharge 25 s, III "Recharges in 20 s".
**Research (mockup section 0):** CoD MW2 Predator Missile — fired from high above, the view jumps into the missile looking down, slow steering, one boost, grey thermal picture, red boxes on enemies, your body stands defenceless; BO Hellstorm cluster split left out.

## Part `cmissile` "Cruise Missile" (Herrera, attack, button)
1. Button: launch a missile from your back and fly it down onto the map yourself. 40 damage to every enemy in a 45-stud blast (the size of the point), 0 to your team. You stand still while you fly it. Recharges in 25 s
2. Bigger blast (45 → 55 studs)
3. Recharges in 20 s
4. Leaves a burning crater for 4 s (8 damage a second to enemies in it)

## Rules
- Press (key / touch slot, the usual timed-part press): DinoCruiseMissileRequest(stamp) = launch. Usual part checks + recharge. The missile starts CruiseHeight (250) studs above the ground under the Herrera, CruiseAhead (40) studs in front, falling at CruiseFall (30 studs/s), steering at up to CruiseSteer (30 studs/s) flat; BOOST once = fall x CruiseBoostMul (3), steering x 0.5. Lasts at most CruiseMaxFlight (10) s, then it drops where it is.
- Client-flown, server-checked: the owner's client moves the missile and sends ("steer", pos) 10 times a second and ("impact", pos) when it hits the world / a dino / the ground; the server clamps every update to what the speeds allow since the last one (+2 studs), never lets it rise, and explodes at its own clamped point. Other players see the missile at the server's CruisePos.
- While flying: the Herrera's movement and jump are off on the owner's client (it stands still; it can be hit). Dying / leaving / a stun = the missile falls straight down where it is (server).
- Blast: every enemy dino (squad + mode rules) whose hitboxes come within CruiseRadius (45 / 55) of the blast point takes CruiseDamage (40) flat (shield / debuffs / armor as every part hit); teammates 0. ★: a crater CruiseCrater (4) s: CruiseCraterDps (8) a second to enemies within the radius (every 0.5 s).
- Recharge starts at the launch.

## Tasks (MDA-519..524)
1. SkillTree 1.93 + SkillEffects 1.63 — the part + Cruise* attributes (cmDamage 40, cmRadius 45 / 55, cmCooldown 25 / 20, cmCrater 0 / 4, cmCraterDps 8).
2. HerreraPartsServer 1.5 — "HPart_cmissile" Backpack Silo on Torso_hump (box, yellow lid, red light, the missile's nose peeking out, role "nose" / "lid") + Lab card.
3. HerreraMissileServer 1.0 (new) — the remote, launch / steer / impact / boost, clamp, auto-drop, blast, crater, stamps.
4. HerreraMissileCam 1.0 (new, owner's client) — thermal missile view (camera at the missile looking down, grey + contrast, white-hot dinos, red boxes on enemies, blue diamonds on teammates, scanlines, crosshair box, altitude bar, blast ring on the ground, BOOST button on touch / Space or click on PC), steering (mouse, WASD / stick, thumb drag), local flight + impact raycast, movement off while flying, camera back after.
5. HerreraMissileFX 1.0 (new, every client) — silo lid flips + the missile pops up at launch, the missile + smoke trail for others, the explosion (fireball, shock ring at the radius, smoke), -40 tags, the crater glow.
6. MechaButtons 1.49 + AbilityBar 1.43 — TIMED_PARTS.cmissile ("Cruise", DinoCruiseMissileRequest, "CRUISE MISSILE").

## Do-not-touch
Other Herrera parts, bots (PracticeKit does not use it), the hardpoint rules, other dinos.

## Red-team (folded in)
- **Client-flown missile could be cheated (teleport the blast):** the server clamps every update by the allowed speeds and explodes at its own point.
- **Defenceless body:** intended (CoD rule, mockup "The cost"); the recharge is short (25 s) so a lost Herrera mid-flight is the trade.
- **Camera / control fights (ShoulderCam, TurnLimit, the touch move stick):** ShoulderCamExternal as the Dilo scope; controls disabled through the PlayerModule only while flying, restored on landing / death.
- **Too strong at 25 s with flat 40 over 45 studs:** accepted (Kepu's numbers); every number is an attribute.
- **Bots don't use it:** accepted for v1.0.
