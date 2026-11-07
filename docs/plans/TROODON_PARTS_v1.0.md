# Mecha Dino Arena v1.0 — Troodon mecha parts (9 slotted parts) + bigger splashes

**Goal:** the Troodon gets its own MECHA ABILITIES: 9 parts it can slot (4 slots R / T / C / V), 5 buttons and 4 always-on parts that still take a slot, each with a visible part, a Lab card and four steps; and every splash area is twice as big as proposed, including the main glow zone.
**Intent (Kepu 2026-11-06):** 19:34 "create a list of 20 different abilities for each stat category ... pull inspiration from different games to create something unique for this Dino" -> brainstorm docs/plans/TROODON_PARTS_brainstorm_v1.0.md -> 19:44 picks H1 Mender Drone, H7 Last Feather, H12 Overheal Plume, A6 Arc Lantern, A10 Ricochet Pod, D1 Sap Wall, D5 Fortify Field, D18 Feather Shed, S6 Portal Feathers -> passives "Slotted parts", buttons "any 4 of 5" -> 20:11 "these need to have some actual design aspect like the inspo they come from. With real vfx ... consistent w the rest of the rosters" -> looks mockup docs/mockups/troodon_parts_options.html (artifact NAxM7vJr7FRixCiv4Uz7Ui) -> 21:24 "I like all the recommended I think the areas should be doubled for splashes even the wall should be doubled" -> main zone "Yes, main zone 20->40 too", throw pose "Yes, 12 deg wider".
**Looks (all recommended, mockup v0.2):** Mender Drone A Shoulder Dock, Arc Lantern A Hip Lantern, Sap Wall B Shoulder Pod, Feather Shed A Flank Plates, Portal Feathers A Tail Rings, Last Feather A Tail-Base Cell, Overheal Plume A Tail Plume, Fortify Field B Neck Pylon, Ricochet Pod A Spring Cups. Clash check: all 9 together 0% part-vs-part, worst piece inside the body 3.2% (Ricochet A in the throw).
**Animation / VFX spec:** tools/mockup/troodon_parts_looks.js (part meshes, key poses, timings, the layered VFX and the Roblox pieces each maps to, the existing effects each follows).

**Architecture:** the Dilo parts pattern (docs/plans/DILO_PARTS_v1.0.md + DILO_PARTS_FIT_v1.0.md):
- SkillTree adds troodon-only parts (`dino = "Troodon"`, LIVE_MECH, all 9 in BUTTONS so each takes a slot, like Mecha Legs), ids prefixed `o` (no clash): omender, olantern, osapwall, oshed, oportal, olastfeather, oplume, ofortify, oricochet.
- SkillEffects writes `TrooPart*` character attributes while a part is bought AND slotted AND the species is Troodon.
- New TrooPartsServer builds the looks (`OPart_<id>`) and the Lab cards (`BuildPreview_<id>`) with the FIT layer from the start; Lab / MainMenu learn `OPart_`.
- New TrooMovesServer owns the 5 button remotes and the 4 passives' rules; new TrooPartsFX draws the effects and moves the part pieces; MechaButtons gets the 5 buttons in TIMED_PARTS (PC, gamepad and phone together); TrooPose gets the part move poses.

## Global constraints
- Additive only; one switch per script change; every number an attribute with a default; version branding (headers, VERSIONS.md, ATTRIBUTES.md).
- Every ability: part shown only while slotted; a Lab card; squadmates never hurt (SquadRules.sameChar); players only where ModeRules.canAffect allows; bots always; heals only to squadmates (or yourself).
- Upgrade rule: steps extend time / reach / count / recharge (the 35% rule).
- SkillTree lesson (the 1.61 hookRange bug): troodon parts write only new `o*` effect fields; a spec checks the other dinos' effects tables are unchanged.
- Parts: fewer, bigger shapes on the body surface with mounts, ≤ 5% of any piece inside the body (measured in Studio, idle + own move + kit poses), checked from the game camera and up close; VFX built from ParticleEmitters / Beams / Trails / Neon / PointLights, following the roster's effects (Med-Station heals, TrooFX glow, the raptor's shock look). Every move: wind-up -> action -> result -> recovery; no landing FX.
- Install by multi_edit + hash; one-player Play tests; publish only on "Publish"; saved progress untouched.

## Numbers (areas doubled, Kepu 21:24)
| Part | I | II | III | star |
|---|---|---|---|---|
| Mender Drone (button) | heals the most hurt squadmate within 40 studs (you, with no squad) 4/s for 4 s; recharge 20 s | heals for 5.4 s | recharge 14.8 s | moves on to the next most hurt squadmate |
| Arc Lantern (button) | throw up to 40 studs; zaps the nearest enemy, chains to 1 more within **24** studs, 8 each; recharge 14 s | chain reach **32.4** | recharge 10.3 s | chains to 3 |
| Sap Wall (button) | throw up to 40 studs: a **50**-stud wall that blocks dinos and shots for 2.1 s; recharge 18 s | **67.5** wide | lasts 2.9 s | lasts 4 s |
| Feather Shed (button) | break a stun / pin / grab, immune 1 s; recharge 24 s | immune 1.4 s | recharge 17.7 s | burst knocks dinos within **20** studs back, slows 25% for 2 s |
| Portal Feathers (button) | two linked rings, the far one up to 40 studs, last 6 s, you only; recharge 20 s | far ring 54 studs | last 8.1 s | squadmates can use them |
| Last Feather (always on) | once per life a killing hit leaves you at 1 HP, untouchable 0.7 s | bursts up into a glide | untouchable 1 s | drops a glow zone (**40** studs) |
| Overheal Plume (always on) | heals above max become a plume soaking up to 10; fades after 5 s | up to 14 | fades after 7 s | squadmates you heal get plumes |
| Fortify Field (always on) | squadmates inside your zones (**40** studs) take 25% less damage | lingers 1 s after leaving | lingers 1.4 s | you're fortified too |
| Ricochet Pod (always on) | the pod bounces once: a second zone **20** studs wide on the next enemy within **30** studs, 2.2 s | bounce reach **40** | lasts the full 3 s | full size (**40** studs) |
Kit change with it: the main glow zone 20 -> **40** studs wide (TrooZoneRadius 5 -> 10; TroodonModelData 1.5); per-second numbers unchanged.

## Tickets (one per task, build order)
1. **Troodon kit: bigger zone + throw pose** · Wired — TroodonModelData 1.5 (TrooZoneRadius 10), TrooFX zone visuals follow the radius (check), TrooPose 1.3 throw wind-up arms 12 deg wider (Kepu's OK; hands no longer pass through the knees). Acceptance: zone 40 studs measured; enemies / squadmates at 18 studs from the centre inside; hand parity with mockup v0.2's widened keys.
2. **SkillTree + SkillEffects** · Logic — 9 `o` parts (steps above, mech, BUTTONS, LIVE_MECH, OWNER Troodon), spec red then green (others unchanged); SkillEffects `TrooPart*` while bought + slotted + Troodon.
3. **TrooPartsServer 1.0 looks + Lab** · Wired — the 9 recommended looks with brackets, FIT measured in Studio ≤ 5%, all-9 clash 0%, Lab cards; captures from the game camera and close.
4. **TrooMovesServer 1.0: the 5 buttons** · Wired — remotes, checks (dead / menu / stunned / dazed / pinned / silenced / cooldown), the effects in the table; the Sap Wall a real collidable wall (blocks characters; blocks the raycast projectiles; red-team 3).
5. **The 4 always-on parts** · Wired — Last Feather, Overheal Plume, Fortify Field, Ricochet Pod through shared hooks (red-team 1).
6. **MechaButtons / AbilityBar** · Wired — 5 buttons with timers on PC + phone; passives show as slotted (no timer; Last Feather lit / spent).
7. **TrooPartsFX 1.0 + TrooPose part poses** · Wired — the mockup's layered VFX, roster-consistent; captures.
8. **Docs + full Studio check** · Wired.

## Kepu's answers (2026-11-06 21:3x)
- Ricochet bounce reach doubled: "Yes, 30 / 40".
- "Two builds": Build 1 = tickets 1-4 + the 5 buttons' parts of 6-7; Build 2 = ticket 5 (the 4 always-on parts) + their parts of 6-8. Each gets its own Studio check and publish.
- Sap Wall: "Do 50 studs" -> 50 studs wide at I, 67.5 at II (the 35% rule). Blocking stays as proposed (dinos + flying shots; instant-hit bites / soft-aim darts not stopped) since the answer didn't ask for more.

## Red-team (Phase 4.5)
1. **Always-on parts need hooks in every damage / heal path.** Many servers write DummyHealth directly; "survive a killing hit" (Last Feather), "25% less damage" (Fortify) and "heal above max becomes a plume" (Overheal) only work if every path honours them. Proposed: Fortify through the shared damage-taken multiplier the attack servers already read (takenMul), Overheal on the troodon's own heals only (zone, drone, self-heal), and Last Feather at the one place health reaches 0 (DinoHealthServer / the ArenaPvP bridge). If there is no single place, the build stops that ticket and reports the options.
2. **The doubled main zone makes the Ricochet bounce overlap the first zone.** With a 40-stud zone, a second zone "within 15 studs" lands mostly inside the first. Proposed: double the bounce reach too (30 / 40.5). Needs Kepu's OK.
3. **A 50-67.5-stud wall that blocks dinos and shots.** It can trap players / bots against terrain and only blocks shots whose server checks for walls (raycast projectiles); soft-aim darts that resolve by distance would pass through. Proposed: blocks characters + raycast projectiles; the build lists which attacks it stops; walls can't be placed overlapping a dino.
4. **Portal Feathers teleport characters.** Proposed: server-side move with a per-dino 1 s re-use lock, no portals into terrain, bots can't use them.
5. **Scope.** 9 parts is the biggest set yet (the dilo had 7). Proposed: two builds like the teno (decision #9): Build 1 = tickets 1-4 + 6-7 for the 5 buttons; Build 2 = ticket 5 (the 4 always-on parts) + the rest of 6-8. Each build gets its own Studio check and publish.
