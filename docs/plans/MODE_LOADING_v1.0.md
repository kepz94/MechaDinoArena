# Mecha Dino Arena — Mode Loading Screens v1.0 (B · Mode Briefing)

**Goal:** each trip shows a loading screen for where you are going (ARENA, HARDPOINT VS BOTS, ISLAND) that teaches the
mode while it loads, and the bar never jumps back.
**Kepu 2026-11-12 16:20:** "we need separate loading screens for the game modes"; **16:28** pick **B** (mockup
docs/mockups/mode_loading_v0.1.html, artifact 8PiCJQXfMy6SHRTnjHEGwM, "B · Mode briefing").
**Architecture:** the loader stays ReplicatedFirst.EggLoader (it is up on the first frame of an arrival and is the
teleport gui). A new look `briefing` replaces the egg pod in the "travel" / "arrive" / "play" modes; the join splash is
unchanged. The caller passes the right target; squad names ride over the teleport on the gui, like the bar (1.2).

## Global constraints
- Frames / TextLabels only (first frame); no images, no module requires from ReplicatedStorage (not there on arrival).
- Colours: ARENA orange rgb(255,155,46), VS BOTS yellow rgb(255,214,64), ISLAND cyan rgb(95,224,200); font Silkscreen
  (the FontSwap face, set directly).
- Bar carries over the trip and only goes up (EggLoader 1.2 rule kept).
- Additive: switch EggLoaderBriefingEnabled (false = the 1.2 egg pod). Version branding everywhere.

## Do-not-touch
- The join splash, the hatch timing rules (MIN_CRACK, TIMEOUT, island rule), HubServer / HubTravel / ModeServer trips.

## Tasks

### T1 — EggLoader 1.3: the briefing look · Wired
- Targets: "Arena", "Bots", "Island" (old "Sandbox" = "Bots"; the hub kind is shown as "Island" when the trip says so).
- Layout (16:9 frame scaled to the screen, cw = width / 100):
  - top-left title (5 cw, mode colour) + sub line (1.4 cw, white); top-right "where" line (grey).
  - left: map 44 cw × 25 cw: sea, island ellipse, the summit rock, the 5 points numbered (copied from
    HardpointRules.LAYOUT_B; spec checks they match), SUMMIT label, blue / red spawn sides; ISLAND: points dim, PORTALS
    marked.
  - right: "HOW TO WIN" card (3 lines per mode, as the mockup) and "YOUR SQUAD" / "BLUE TEAM" card (names carried, else
    "YOU").
  - bottom: tip line (per mode, changes every 4 s), % right, a full-width bar in the mode colour; a small egg rocking
    left of the %.
  - Narrow screens (width < 700 px or width / height < 1.5): no map, the two cards full width.
- Carry: the travel screen writes EggLoaderTarget, EggLoaderCarry (1.2) and EggLoaderSquad ("NAME · DINO|…", the squad
  members on this server) on its gui; arrival reads them.
- Hatch → for the briefing look: bar to 100%, "READY" in the title colour, 0.6 s, fade (no egg hatch).
- **Acceptance:** each target shows its screen (Studio: Show("Arena"/"Bots"/"Island")); narrow layout at 390 × 844;
  switch off = 1.2; spec: map points = LAYOUT_B.

### T2 — Callers pass the right target · Wired
- Player attribute `TripTarget` ("Arena" / "Bots" / "Island") set by whoever starts a trip on this client, read first by
  MainMenu's travel loader (1.24) before its lastPressedMode guess.
- PortalHUD 1.2: arena → "Arena", bots → "Bots". HardpointHUD 1.11: BACK TO ISLAND and the auto island → "Island".
  MainMenu 1.24: island → "Island".
- Found while planning: a BACK TO ISLAND trip today shows "TRAVELING TO ARENA" (lastPressedMode defaults to "arena").
- **Acceptance:** each trip start shows the matching screen in Studio (Show is called; the teleport itself is live only).

### T3 — QA + docs + live check · Wired
- Screenshots of the 3 screens PC + phone; VERSIONS / ATTRIBUTES; Dev Hub live check (portal trips both ways, back to
  island, bar never jumps back).

## Red-team (folded in)
1. *Map data copied into the loader can drift from HardpointRules.* Spec compares the copy with LAYOUT_B.
2. *Squad names may not survive the teleport copy.* Fallback "YOU" + the count; not a blocker.
3. *Too much text on small phones.* Narrow layout drops the map; checked at 390 × 844.
4. *Back-to-island showed the wrong caption.* Fixed in T2 by TripTarget.
5. *The egg's hatch was the payoff.* Kept as the small rocking egg; the end beat is "READY" (Kepu can ask for the hatch back).

## Build notes (2026-11-12)
- T2 came out smaller than planned: EggLoader 1.3 maps the old "Sandbox" target to the VS BOTS screen, so PortalHUD needs no
  change; MainMenu 1.23 already marks every trip from a mode (board button, automatic trip, menu) as "island", so only
  MainMenu 1.25 changes (island -> "Island"). HardpointHUD unchanged. No TripTarget attribute.
