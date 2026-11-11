# Arena Hardpoint mockup v0.1

`python3 build.py` builds `arena_hardpoint_v0.1.html` from `template.html`; copy it to `docs/mockups/`.

- `grid.txt`: the island sampled in Studio (Edit) on 2026-11-10. 72 x 72 cells over x/z -1080..1080, 30 studs a cell; raycasts down onto
  Workspace.DinoIsland Ground / Rocks / MountainSteps. Each cell = a type letter (g Grass, m Meadow, r RockGround, s Sand,
  w Seabed, v Shallows, t Trail, k MountainStep, o Rocks) + a height char (index in 0-9a-zA-Z x 5 - 50 studs). Every row was
  checked against a Studio hash (h = (h*31 + byte) % 1000000007).
- `pc.jpg` / `phone.jpg`: docs/reference/arena/arena_respawn_point8.jpg and studio_squad_phone_v1.0.jpg at 1200 x 482.
- Hill spots, the spawn ring per point (12 directions, 220-380 studs, flat dry ground) and run times come from that grid; in-game run = model run x 0.65.
- Spawns (Kepu 2026-11-10: "in relation to the hard point like how call of duty does it"): pick on respawn, never within 150 studs of an enemy, score = min(enemy dist, 350) + 0.4 x max(0, 300 - nearest teammate dist). Checked: the 3 situations give the intended sides on all 14 points.
