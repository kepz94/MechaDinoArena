# Mecha Dino Arena — origin (v0.1)

- Branched from Dino Arcade (kepz94/DinoBlox) at commit 3427ce8 (BotServer 1.9) on 2026-10-27.
- Dev Hub project: `mecha-dino-arena` (ticket prefix MDA). The SRD v0.1 holds the user's idea verbatim, the decisions and the decomposition.
- All script versions continue from the Dino Arcade numbers (BotServer 1.9, GrowthServer 1.2, ...). Mecha changes add new version rows to docs/VERSIONS.md as before.
- The upstream remote `upstream-dinoblox` points to the Dino Arcade repo for reference only. Nothing is pushed there from this repo.

## Plan (each part: feature-planning → options + mockup → red-team → tickets)
1. Project setup (this commit).
2. Adult spawns + class stat profiles (T-Rex Bulky, Raptor Roamer).
3. Kill → skill points, saved builds (DataStore), stat trees.
4. Mecha skills (2 per tree) + visible mech parts.
5. Squads, friendly fire off.
6. King of the hill: mountain-top 1v1 challenge in the shared lobby, spectating.
