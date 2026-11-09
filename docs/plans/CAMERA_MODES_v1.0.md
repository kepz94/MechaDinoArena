# Mecha Dino Arena v1.0 — Camera modes (Classic / Shift Lock / Shoulder)

**Goal:** players pick their camera: Classic (Roblox's regular camera), Shift Lock (centred behind, the dino faces where you look) or Shoulder (today's). New phone players start in Classic.
**Intent (Kepu, live mobile test 2026-11-08):** "The over the shoulder view on mobile sucks. My players want options to have the regular player camera & a shift lock option."
**Chosen (Kepu 2026-11-09):** mockup docs/mockups/camera_options_v0.1.html (artifact 3SFrsxwHavXxbTv5Q9SXDL), direction **C · Both** (a camera button under MENU that cycles the three + a CAMERA row in the in-game MENU card and a main-menu SETTINGS card, with an on/off for the button); phone start **Classic**; "regular camera" = **Classic** (follows, turns only when dragged; not Follow); Classic aim = **where the camera looks** (today's code).

## The three modes
- **Classic:** ShoulderCamEnabled = false -> Roblox Custom camera, touch movement mode Classic; TurnLimitMode "move" (the dino faces where it walks); drag orbits; no crosshair.
- **Shift Lock:** ShoulderCam with ShoulderCamSide = 0 and a raised height (dino under the crosshair); TurnLimitMode "aim"; every aim path as today.
- **Shoulder:** ShoulderCam 1.8 unchanged.

## Defaults I'm using unless Kepu says otherwise
- PC / mouse start: Shoulder (unchanged). Phones / tablets (touch, no mouse): Classic.
- Saved per player in the existing MDA_Settings_v1 DataStore (MusicServer 1.0 pattern), one value per device type (touch / mouse) because the defaults differ.
- Shift Lock exactly centred.
- PC: the same SETTINGS card; a keyboard key for the cycle is not added in v1.0.

## Aiming in Classic (Kepu: "Where the camera looks")
- Direction parts (Ink, Quills, Venom Gatling, Grappling / Reaper Hook, Feathers, Grapple, Spring Jets standing) keep sending the camera look — fire where the camera points.
- Crosshair-point parts (Toxin / Teno Mortar, Arc Lantern, Sap Wall, Portal): today they raycast from the screen centre; in Classic the screen centre is the dino, so the ray lands at its feet. Rule (still "where the camera looks"): in Classic the point = dino position + the camera's flat look x the part's default reach (or the first target / ground hit along that flat line). Behind a switch.
- Grapple lock-on / Slash dive target: cone around the camera look (as today).
- Body-aimed attacks (bite, dart, pod, pounce, headbutt, ram, Shock Cannon) unchanged.
- Bug fixed with it: Tether Spike tactical aim leaves the camera Scriptable when the shoulder cam is off (MechaButtons 1.39 :765 / :792, ShoulderCam 1.8 release() :272-281) -> the tether end sets CameraType = Custom itself when ShoulderCam is off.

## Red-team (short)
1. **Classic + camera-look aim:** a player who orbits the camera to look behind while running fires parts backwards. That is the pick; the button/label shows the mode so it's learnable. Accepted.
2. **The crosshair-point parts** would land at the dino's feet in Classic without the flat-look rule above (that rule is my reading of "where the camera looks" — flag to Kepu in the report).
3. **ShoulderCam hooks silently skipped in Classic:** the ram camera turn (RamTest :318) and the eating side view (SurvivalBars :275). Accepted for v1.0; listed.
4. **One more HUD button on phones** next to MENU / SQUAD (Kepu once said no shoulder-swap button on mobile): the card's on/off hides it.
5. **Studio phone emulator keeps MouseEnabled = true**, so the device-type default needs a test hook (like ShoulderCamTouchPitchLockTest).

## Tickets
1. CameraSettings server (save / load per player, device type) + remote. Logic + Wired.
2. ShoulderCam 1.9: CameraMode attribute (classic / shift / shoulder), Shift Lock framing, mode switch at runtime, Tether fix. Wired.
3. Classic aim rules in MechaButtons (crosshair-point flat-look rule) behind a switch. Wired.
4. HUD camera button (ArenaTouch / ArenaStatus) + MENU card CAMERA row + main-menu SETTINGS card (MainMenu), mockup layout; PC + phone together. Wired.
5. Docs + Studio check (every dino's parts in all three modes, PC + forced touch).

## Built (2026-11-09)
- CameraSettings 1.0 (server), CameraModes 1.0 (client: mode state + all UI), ShoulderCam 1.9, MechaButtons 1.40.
- Delta from the plan: Roblox's camera movement mode Classic is set on the server (a client may not set DevTouchCameraMode); ShoulderCam claims the camera (subject + Custom) every Classic frame because the menu swaps the dino model without moving the camera subject.
- The MENU card section and the SETTINGS pill are added by CameraModes into ArenaStatus's LeaveConfirm card and MainMenu's GUI (no edits to those scripts).
