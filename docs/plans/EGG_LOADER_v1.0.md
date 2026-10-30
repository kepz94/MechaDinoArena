# Mecha Dino Arena — Egg Loader v1.0 (hatching load screen)

**Goal:** replace Roblox's loading screen with an egg in a mecha incubator that keeps cracking while the game loads; when it is loaded, a baby T-Rex hatches, and 2 s later the screen fades into the main menu. Shown on join and on every Sandbox ↔ Arena trip.
**Intent (Kepu 2026-10-29):** "a load screen in between with a Dino egg hatching and a baby Dino sitting inside looking all cute. The egg should keep cracking until the Dino baby comes out then 2 seconds after that the game should be fully loaded in the background." Answers: join + every place hop; cracks until loaded; always a baby T-Rex.
**Chosen direction:** mockup `docs/mockups/egg_loading_options.html` — **C · Mecha incubator** (Kepu: "I like the incubator"): metal pod (lid with two orange lights, glass with a volt glow, base), the blocky egg inside, title + caption + tip on the left, a volt gauge with % on the right; the lid lifts when the egg hatches.
**Architecture:** one LocalScript in ReplicatedFirst draws the screen from plain UI frames (no images, so it shows on the first frame), removes the default loading screen, and runs the crack → hatch → fade sequence. MainMenu hands the same screen to Roblox's teleport so it covers the trip, and the loader picks it up again on arrival.

## Current state (grounded)
- ReplicatedFirst is empty in the place; the repo has no ReplicatedFirst mapping (default.project.json maps src/server, src/shared, src/character, src/client only).
- Join today: Roblox's default loading screen, then the MainMenu 1.0 opens (InMenu = true from ModeServer 1.0; MainMenuOpen = true on the client).
- Trips: ModeServer 1.0 `TeleportAsync` from the server after "teleporting"; nothing is shown during the trip except Roblox's default teleport screen.
- Fonts: FredokaOne / Gotham are bundled with the Roblox client (no download).

## Global constraints
- Version tags: EggLoader 1.0, MainMenu 1.1, ArenaScope 1.11. Header vX.Y + changelog, VERSION attribute, docs/VERSIONS.md row, docs/ATTRIBUTES.md entries.
- Every new behaviour behind a switch (false = today exactly).
- Look = mockup C; colours from the game (panel 20,20,26; yellow 255,200,50; orange 255,155,46; volt 127,233,255); Scale layout with px minimums (text ≥ 11 px), clear of the Roblox top-left buttons (GuiService.TopbarInset); checked at PC and 844 × 390.
- Tests on your own client only.

## Do-not-touch
ModeServer, SpeciesServer, SkillServer, every combat / bot script, MainMenu layout (only the travel hand-off is added).

## Deterministic map
**Loaded** = all of: `game:IsLoaded()`; `LocalPlayer.Character` exists; and, when ModeServer is on (player attribute `InMenu` is not nil within 10 s of join), `MainMenuOpen == true`. Safety: 45 s after the screen appeared it counts as loaded anyway (EggLoaderLoadReason "timeout").
**Progress p (0..1)**, every frame: before Loaded, `p = min(0.95, max(timeCurve, assetPart))` with `timeCurve = 0.95 × (1 − e^(−t / 6))` and `assetPart = 0.95 × (1 − queue / maxQueueSeen)` (ContentProvider.RequestQueueSize; 0 when no queue was seen); p never goes down. After Loaded: p rises to 1 over 0.4 s.
**Cracks:** 5 crack lines appear at p ≥ 0.12 / 0.3 / 0.5 / 0.7 / 0.9; wobble level 1 (p > 0.1), 2 (p > 0.45), 3 (p > 0.8).
**Minimum show time:** the hatch never starts before MIN_CRACK = 3 s after the screen appeared, so a fast load still shows the egg cracking (Kepu: at least 3 seconds).
**Sequence after p = 1:** shell top halves fly off + lid lifts (0.9 s) → baby T-Rex rises and sits (0.7 s) → caption "HATCHED!" (join) / "WELCOME TO THE ARENA!" / "WELCOME TO THE SANDBOX!" (trip) → 2 s → fade 0.6 s → screen removed (EggLoaderState "done").
**Trip:** on SANDBOX / ARENA when the result is "saving" / "teleporting", MainMenu 1.1 asks the loader to show (caption "TRAVELING TO ARENA" / "TRAVELING TO SANDBOX", gauge creeping, egg cracking) and passes a copy of the screen to `TeleportService:SetTeleportGui`. "teleportFailed" → the loader hides and the menu toast shows as today. On arrival the loader takes `TeleportService:GetArrivingTeleportGui()` (if any) and continues with the trip caption.

## Tasks (build order)
### Task 1 — EggLoader 1.0 · Wired (new, ReplicatedFirst)
**Files:** Create `src/first/EggLoader.client.luau`; modify `default.project.json` (add `"ReplicatedFirst": {"$className": "ReplicatedFirst", "$path": "src/first"}`).
**Produces:** ScreenGui "EggLoader" (DisplayOrder 100, IgnoreGuiInset, ResetOnSpawn false); BindableFunction `ReplicatedFirst.EggLoader.Show(target: "Arena" | "Sandbox") -> ScreenGui` (shows the trip version, returns the gui for SetTeleportGui) and `Hide()`; LocalPlayer attributes EggLoaderVersion, EggLoaderState ("loading" / "hatching" / "hatched" / "fading" / "done" / "travel"), EggLoaderProgress (0..1, 0.01), EggLoaderLoadReason ("loaded" / "timeout"), EggLoaderShownFor (s). Switch: script attribute EggLoaderEnabled (false = default Roblox screen).
**Layout (mockup C):** grid backdrop; left column title "MECHA DINO / ARENA", caption, tip; centre pod 46ch × 70ch (lid, glass, base), egg 26ch × 34ch of 8-unit cells (egg shape, shading, spots), 5 crack lines (thin dark frames along the mockup's paths), baby T-Rex frames hidden behind the lower shell; right gauge tube 4ch × 44ch with volt fill and %.
**Acceptance:** shows on the first frame of a join (no default screen); cracks and gauge move while loading; hatch only after Loaded and MIN_CRACK; baby pops; 2 s; fade; menu underneath ready; PC + phone screenshots match the mockup; timeout path.

### Task 2 — MainMenu 1.1 · Wired (travel hand-off)
**Files:** Modify `src/client/MainMenu.client.luau`.
- On ModeLastResult "saving" / "teleporting" after a SANDBOX / ARENA press for the other place: `EggLoader.Show(target)` and `TeleportService:SetTeleportGui(gui)`; "teleportFailed" → `EggLoader.Hide()`. Switch MainMenuTravelLoaderEnabled.
**Acceptance:** Studio: pressing the other mode shows nothing new ("studio" toast stays); live: the incubator covers the trip and keeps going on arrival until that place has loaded.

### Task 3 — ArenaScope 1.11
EggLoader (ReplicatedFirst) expected on.

### Task 4 — Publish both places (on Kepu's yes) + live trip check.

## Red-team outcome (Kepu 2026-10-29)
| Challenge | Kepu's answer | Result |
|---|---|---|
| Fast loads (Studio, good connections) would hatch before any cracking is seen | At least 3 seconds | MIN_CRACK = 3 s |
| A stuck load would trap the player behind the screen | Hatch anyway after 45 s | Safety timeout 45 s, EggLoaderLoadReason "timeout" |
| The trip hand-off (SetTeleportGui / GetArrivingTeleportGui) cannot run in Studio | Build it, check it live | Join screen verified in Studio; trip checked after publish (Task 4) |
