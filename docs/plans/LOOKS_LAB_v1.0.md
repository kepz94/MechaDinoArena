# Mecha Dino Arena — Looks Lab v1.0 (Lab 2.1)

**Ask (Kepu 2026-11-26 01:06):** "Instead of having a second row of tabs for owned/earned/robux and all, just have the owned skins show up first, the rest locked and showing why it's locked, if it's for Robux have it say buy, if it's for a challenge have it show the challenge when you click on it and the progression." Also: "the emote wheel setup on mobile... It makes more sense to just click on the wheel and replace from my list. Also make the wheel more properly spaced out and even sections."

**Mockup:** docs/mockups/looks_lab_v0.1 (artifact https://claude.ai/artifact/HZAr7cY5Kjhc8AfqVrrYpr).

**Picks:**
- "A: Big wheel on the left".
- Applies to SKINS, EMOTES and TRAILS.
- Robux tile: "Select it, BUY in the detail".
- Selected section: "No upload: lit label + lines".

**Build:** Lab 2.1 (tools/lab21_patch.luau, lab21_patch2.luau), script-global table L3; switches LabLooksSortEnabled and LabWheelLeftEnabled. Details are in docs/VERSIONS.md.

**How it can fail (one-ticket change, no red-team pass):**
1. A locked state the code doesn't know (a new unlock kind). It falls into the Robux group and shows its price.
2. The live game still has SkinCatalog.ALL_UNLOCKED on, so players see everything owned and no locked tiles until that is turned off.
3. Put-on-wheel uses the same remote as 2.0's slot tap, so the server rules are unchanged.

**Test side effect:** the Studio test moved Cooked onto Kepu's wheel slot 3, then put Skill Issue back (wheel dead, mic, skill, tea, easy, party, stomp, moon as before).
