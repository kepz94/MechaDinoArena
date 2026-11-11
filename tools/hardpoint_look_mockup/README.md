# Hardpoint point-look mockup v0.1

What the Hardpoint point looks like from the player's camera (Kepu 2026-11-10: "show me what the actual hard point looks like
from a player perspective ... Use cod for inspo"). Three looks (A neon border, B border + beacon, C mecha pylons), five states
(open, yours, enemy's, contested, next/locked), four views, PC / phone.

Build: `python3 tools/model_json` exports first, then
`python3 tools/hardpoint_look_mockup/build.py three.min.js(r128) tools/hardpoint_mockup/grid.txt raptor.json trex.json docs/mockups/hardpoint_point_look_v0.1.html`
(raptor.json / trex.json = `python3 tools/mockup/model_json.py src/shared/Models/<Raptor|TRex>ModelData.luau OUT.json`).

- Terrain: the Studio grid around Centre Meadow (point 1 of layout B), 30-stud cells; the point's floor is levelled within 75 studs.
- Dinos: RaptorModelData x 2 (RaptorScale), TRexModelData x 1.63 (TRexScale). Camera: ShoulderCam framing, distance 16 x 2.
