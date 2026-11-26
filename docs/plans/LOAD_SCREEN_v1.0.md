# Mecha Dino Arena v1.0 — Load Screen A + One Screen per Trip

**Goal:** the egg loading screens look clean and professional, and a trip shows one screen from start to finish (no second screen, no reset, no silent 95%).
**Chosen direction:** A · Centered hatchery, mockup `docs/mockups/load_screen_v0.1.html` (artifact "Load Screen Options"). Kepu 2026-11-26 03:37 "just do A. i dont want the hatch to be for the arena loading screen we already have that" → A only on the egg screens; the Arena / Bots briefing screen keeps its look (no egg, no hatch). Kepu 03:15 "nail down the double loading screen problem that we keep having".
**Architecture:** all in EggLoader (ReplicatedFirst LocalScript), version **1.9**. Look A is a second layout pass at the end of `layout(s)` for egg screens, plus a horizontal bar and a status label built in `build()`. The one-screen trip changes the arrival hand-off only. Every piece is behind its own switch.

## Grounding (EggLoader 1.8, repo = Studio hash 55505 1164935015)
- Modes: `splash` (join, plain LOADING), `join` (splash off), `play` (menu SANDBOX / ISLAND PLAY), `travel` (the screen on the server you leave, given to `SetTeleportGui`), `arrive` (after a trip). Targets Arena / Bots / Sandbox / Island.
- Egg screens today (1.2 / 1.5 look): grid backdrop, pod (lid, glass, base), egg + baby in the glass, left text (MECHA DINO / ARENA / caption / tip), vertical gauge + % on the right. Match screens (Arena, Bots) use `buildBriefing` / `layoutBrief` instead.
- Trip hand-off (1.2): travel writes `EggLoaderCarry` on its gui; on arrival `RemoveDefaultLoadingScreen()` (line 163), `GetArrivingTeleportGui()`, then `arriving:Destroy()` and `show("arrive", target)` builds a new screen at the carried % (lines 1115-1124). Three pictures, two swaps.
- Progress: `target = min(0.95, max(timeCurve, assetPart))`, timeCurve from the screen's own start, so an arrive screen sits at the carried % until its own curve passes it, then crawls to 95% and waits for `isLoaded`.

## Global Constraints
- Additive; switches default true, false = 1.8 exactly. Every number is a script attribute.
- Frames and text only (no images: the screen must show on the first frame).
- Phone first: checked on the emulated iPhone 17 Pro (750 × 381) and PC. Copy: no em dashes, short status words.
- Studio Play only with the save switches off; restored after. Teleports do not run in Studio (see R1).
- Publish only on "Publish".

## Do-not-touch
- The splash (join) screen, the Arena / Bots briefing look (`buildBriefing`, `layoutBrief`, map, cards, its tips), the hatch sequence itself, PortalHUD, MainMenu, ModeServer, HubServer, PracticeServer, PracticeLobby.

## Tasks

### Task 1 — Look A on egg screens · Wired (MDA ticket 1)
- Applies when `s.brief == nil and s.mode ~= "splash"` and script attribute `EggLoaderLookAEnabled ~= false`.
- `build()`: add `s.barA` (track, height max(1 ch, 6 px), rounded, white at 0.92 transparency), `s.barAFill` (cyan VOLT; orange for target Arena is not used since Arena has the briefing), `s.statusA` (Silkscreen via FontSwap, VOLT, left), `s.glowA` (an ellipse frame under the egg, VOLT at 0.75, gradient).
- `layout()` end, Look A pass (ch = H / 100):
  - hide: grid, pod lid / glass / base / lights, vertical tube, its %.
  - title: "MECHA DINO" (yellow, 2.6 ch) over "ARENA" (white, 7 ch, shadow) centred, top = max(TopbarInset + 2 ch, 9 ch).
  - egg: canvas centred horizontally, its bottom at 62% of H, box 30 ch tall; glow 32 ch × 5 ch under it.
  - bar: x 22% .. 78% of W (min 260 px wide), bottom 9 ch; status left and % right, 1.2 ch above the bar (2.4 ch, min 12 px).
  - tip: centred, 2.2 ch (min 12 px), 3 ch under the bar; one line, wraps to 2 on phones.
  - caption: hidden (the status label replaces it; HATCHED! / WELCOME TO THE ...! move into the status label).
- Running loop: the horizontal fill mirrors `s.p` (same value as the tube). Cracks, rocking, hatch, baby unchanged.
- Acceptance: join (splash off), play SANDBOX, play ISLAND, travel / arrive ISLAND all show A; Arena / Bots still show the briefing; nothing under the Roblox buttons; text never under 11 px; PC + iPhone screenshots.

### Task 2 — One screen per trip · Wired (MDA ticket 2, folds in MDA-598's double screen)
- Switch `EggLoaderSeamlessEnabled`.
- Arrival: keep the arriving teleport gui on screen (parent it to PlayerGui if Roblox has not, DisplayOrder 101) while the new screen builds under it; once the new screen has laid out and its labels' fonts are loaded (`ContentProvider:PreloadAsync` on the screen's labels, max `EggLoaderSwapWait` 2 s), destroy the copy in one frame. Diagnostic: player `EggLoaderArriveCopy` ("kept" / "none" / "timeout").
- The arrive screen copies the travel screen's state from the copy's attributes: % (`EggLoaderCarry`, as 1.2), tip index (new `EggLoaderTipIdx`), crack count (new `EggLoaderCracks` on the gui). No restart of the tip cycle or cracks.
- Progress keeps moving from the carried value: the arrive time curve starts at the carried % (curve offset) instead of 0, so the bar never stalls at the carried value.
- Acceptance: Studio cannot run a teleport (R1); checked with a Studio harness that builds a travel screen, clones it as the "arriving" gui and runs the arrival path; then live on Kepu's phone (portal to Arena and Arena back to island).

### Task 3 — Status words + "what is it waiting for" · Wired (MDA ticket 3)
- Switch `EggLoaderStatusEnabled`. The bar follows steps (the time curve still fills between them, capped at the next step):
  travel: SAVING (to 0.15) → TRAVELING (to 0.45); arrive: JOINING (0.5) → SPAWNING (0.7, until the character exists) → the arrive rule (0.95) → READY (1).
- Diagnostic: player `EggLoaderWaitingFor` = the first failing part of `isLoaded`: "game" / "character" / "inMenu" / "parked" / "noGround" / "menu" (so the next live 95% hang names its cause; MDA-598).
- Egg screens (A): the step word is the status label. Arena / Bots briefing: see R2.

## Red-team
1. **Studio can't run a teleport.** The arriving-gui behaviour (is the copy still on screen when ReplicatedFirst runs? does `RemoveDefaultLoadingScreen` remove it?) can only be confirmed live. Mitigation: the harness test, the `EggLoaderArriveCopy` diagnostic, the switch, and one live trip on your phone before calling it done.
2. **Arena screen change.** You want the Arena screen kept. The double-screen fix (Task 2) is invisible on it, but the status words (Task 3) would add one short word next to the tip line ("JOINING", "WAITING FOR PLAYERS"). Keep the Arena screen exactly as is, or allow that one word?
3. **The 95% hang is not fixed by this.** Task 3 only names its cause on the next hang. Accepted, or hold Task 3 until MDA-598 is solved?
4. **Status is tied to real steps.** If a step never happens (no character), the bar holds at that step's cap until the 45 s timeout, same as today, but now with the word showing why.
