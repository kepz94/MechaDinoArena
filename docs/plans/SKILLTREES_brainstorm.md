# Mecha Dino Arena — skill trees (brainstorm, 2026-10-28)

Kepu: "We need to do the leveling up system thingy. Each area should get different branches so for example health could be self healing or drop a healing machine that heals a vicinity which would benefit teams. For attack you could do an upgrade on your bite or attach a light turret on your back."

## Decisions so far
- **Areas (5):** Health, Attack, Defense, Speed, Engineering (dropped machines). There is no Support tree; the Support row in StatSheet 1.0 was Claude's addition and does nothing.
- **Paths:** each area has 3 paths, each about 3 upgrades long plus a final upgrade.
- **Mixing:** players can put points into any paths; skill points are the only limit.
- **Points:** come from kills (players and bots), using growth XP as skill points (earlier decision).
- **Abilities (buttons):** about 2 per area, maybe 3. Players use **loadout slots**: unlock as many as their points allow, pick which go on the buttons, and swap in a menu. **2 ability buttons** on screen, on top of BITE, RUN and the dino's own move.
- **Mecha parts:**
  - one design per part, the same for every dino, scaled to its proportions;
  - parts attach to mount points on named body parts (Back, Shoulders, Flanks, Hips, Head / Jaw, Tail base);
  - a new species only needs mount points and a scale;
  - blocky style like the dinos, built in code by Claude;
  - the look changes with each upgrade;
  - parts can share a mount point (they stack with offsets).

## The paths (⚙ = visible mech part)
| Area | Path | What it does |
|---|---|---|
| Health | Regeneration | Heal after a few seconds without damage; faster and sooner with upgrades; final: a heal burst on each kill |
| Health | ⚙ Med-Station | Button: drop a machine that heals everyone nearby (good for squads); bigger area, lasts longer; final: two stations |
| Health | Lifesteal | Part of your bite damage heals you; a bigger share with upgrades; final: overheal becomes a temporary shield |
| Attack | Jaws | Stronger bite, faster bites, a bleed; final: a crushing bite that stuns briefly |
| Attack | ⚙ Back Turret | A light turret on the back auto-fires at the nearest enemy; fire rate, range; final: twin barrels |
| Attack | ⚙ Shoulder Rocket | Button: aimed rocket with splash damage; reload, blast size; final: a 3-rocket burst |
| Defense | Thick Hide | Flat damage reduction, less knockback, shorter stuns; final: no stuns above 50% health |
| Defense | ⚙ Armor Plating (Kepu: "like black panthers") | Button: press to start absorbing incoming damage as charge; press again to release it as a blast around you (a bigger charge makes a bigger blast); at max charge it releases by itself |
| Defense | ⚙ Energy Shield | Button: a bubble that blocks damage for a few seconds; stronger, shorter cooldown; final: it bursts and knocks enemies back |
| Speed | Sprint Legs | Faster run and acceleration; final: shorter pounce / ram / leap cooldowns |
| Speed | ⚙ Thrusters | Button: dash forward; 2 charges; final: rocket hop (lets the T-Rex get up high) |
| Speed | ⚙ Grapple Hook | Button: pull yourself to a tree; longer range; final: hook an enemy and pull them in |
| Engineering | ⚙ Sentry | Button: drop an auto-turret; more health and damage; final: two sentries |
| Engineering | ⚙ Traps | Button: drop mines; a slowing net trap; final: an EMP mine that shuts off enemy mech skills |
| Engineering | ⚙ Barricade | Button: drop a wall; bigger, tougher; final: a dome the squad can stand inside |

**First piece to build (Kepu):** points + the tree screen (kills → skill points, saved builds, the screen to spend them), starting with the passive paths.

Numbers (damage, cooldowns, points per upgrade) are not set yet. They come in the build plan.
