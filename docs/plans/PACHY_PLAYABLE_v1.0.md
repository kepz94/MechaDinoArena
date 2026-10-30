# Mecha Dino Arena v1.0 — Playable Pachy + Headbutt Charge

**Goal:** the pachy is the third playable dino: picked in the menu, 2x like the raptor, with a headbutt charge as its ATTACK, charges, a self-slow downside, a leap, an attack line, and a charge pose.
**Intent (Kepu 2026-10-30, verbatim):** "i think its speed should be a bit slower than the raptor but faster than the t-rex. it should have a headbutt charge that speeds it up a bit and knocks opponents back with a debuff to their speed. it should come with two charges and max out at 3 charges fully statted up. the downside is if you use all your headbutt charges it debuffs your speed for a couple of seconds so you have to be wise with the charges once you get up to 3 it'll be a lot better. i think it should be able to leap as well as charge and leap for when it gets introduced to pvp when players try to jump out of the charge. when its in charge mode it should be pretty manueverable as well as have animations that indicate a speed up and the charge. the pachy should dip its head forward with intent like the inspo pick that i sent where its charging"
**Answers:** headbutt = ATTACK (left click / big yellow button) · health 90 · run 45 in the arena · 3rd charge from its own attack line · charge display A (pips) · damage "at least 20" -> 20 · other numbers "yes".
**Mockup:** `docs/mockups/pachy_charge_options.html` (option A pips). Model: `docs/plans/PACHY_MODEL_v1.0.md` (PachyModelData 1.0, approved "i like it").

## Numbers (all settings, tunable)
| Setting | Value |
|---|---|
| Arena run speed | 45 (base MoveRunSpeed 69.2 x ArenaSpeedScale 0.65); walk base 36.9 (raptor walk / run ratio) |
| Health | 90 |
| Charges | 2; 3 at the Battering Dome star |
| Charge | speed x1.4 of run, up to 1.8 s, ends early on a hit; turning about 2x the normal turn rate |
| Hit | 20 damage, knockback 30 studs, target speed -35% for 3 s |
| Refill | 5 s per charge, one at a time |
| Last charge used | self speed -35% for 2.5 s after that charge ends |
| Leap | the raptor's leap values; usable during a charge, keeps charge speed in the air |
| Battering Dome | I +25% damage · II +30% knockback · III refill 30% faster · star 3rd charge + spikes shown |
