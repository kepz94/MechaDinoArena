# Mecha Dino Arena — Hardpoint point marker v3: CoD style, rides the screen edge (HardpointHUD 1.7)

**Goal:** the icon over the point sits exactly on the point while it's on screen, never sticks, jumps or pops, slides to the
screen edge on the point's side when the point is off screen (as CoD does), doesn't block your aim, and hides while you're on
the point. PC and phone, Arena and practice.
**Kepu 2026-11-11 13:46:** "fix the actual hard point icon how it interacts with the screen when it tries to show you where it
is. It looks weird and buggy. I'm not talking about the compass ... Look at how cod does it"; 13:5x pick "A · Rides the edge".
Mockup: docs/mockups/point_marker_v0.2.html (artifact "Point Marker Fix").
Research note: no write-up of CoD's marker rules was found online; the CoD behaviour used here (icon on the objective, fixed
size, slides to the screen edge when off screen, faded near the crosshair, gone while you're in the zone) is how the games play.

## What's live (HardpointHUD 1.6) and why it looks buggy (from the code)
- Anchor = point centre + 34 studs, marker frame anchored at its bottom (0.5, 1), so the whole marker is drawn above a spot 34
  studs up: up close it floats high in the sky.
- `y = math.max(y, 150 + GuiInset 58)` -> never above 208 px from the top. A landscape phone is ~390 px tall, so the marker
  can't reach the top half and slides along that line under the point.
- When `x - 60 < the score card's right edge` it is pushed under the pills / kill feed (+74) -> a ~100 px jump while turning.
- `onScreen` false for the +34 spot -> the marker is hidden at once (1.4 rule), so it pops at the screen edges.
- Full size over the crosshair and while standing on the point.

## Global constraints
- Additive; every number an attribute; every change behind a switch; version header + VERSIONS / ATTRIBUTES.
- Do-not-touch: the compass (1.4–1.6), score card / pills / slim scale, name tags, results board, KillFeed, TeamTags, the
  marker's look (label, diamond with number, distance; colours per state).

## Rules (HardpointHUD 1.7, switch HardpointHUDMarkerV3Enabled, default true, read per frame; false = 1.6 marker)
- Anchor: point centre + HardpointHUDMarkerLift 6 studs; the diamond's centre sits on it (marker AnchorPoint (0.5, 0.5) at the
  diamond, label above, distance below).
- Safe frame (screen px): left / right HardpointHUDMarkerEdge 28 from the safe edges; top = Roblox top bar bottom
  (GuiService.TopbarInset.Max.Y) + 8; bottom = screen bottom − HardpointHUDMarkerBottomPhone 110 (phone) / HardpointHUDMarkerBottomPC
  60 (PC).
- In view: the anchor is in front of the camera and inside the safe frame -> placed exactly there (no easing while it stays in
  view), full marker (label + diamond + distance).
- Off view: the direction from the screen centre to the anchor in camera space (behind the camera: left or right by the side it
  is on, with the compass's hysteresis — beyond ±170° it keeps its last side) is pushed onto the safe frame's edge; the marker
  shows the diamond + distance only, at 84% size, no label. Moving between in view and off view (and along the edge) glides at
  rate 14 / s, so it never jumps.
- Near the crosshair: within HardpointHUDMarkerFade 70 px of the screen centre, opacity goes down to 35%.
- On the point (you count as on it, not in the warm-up): the marker fades out (rate 10 / s); the Status pill already says
  SECURED / CONTESTED.
- Drawn under the HUD panels (ZIndex 0), so the score card, pills and kill feed stay on top when they overlap.
- No height limit and no left-column push in 1.7.
- Diagnostic HardpointHUDMarker: "view" / "edge L|R|T|B" / "on point" / "off".

## Deterministic map
| State | Trigger | End state |
|---|---|---|
| off | switch false | 1.6 marker as it is |
| view | anchor z > 0 and inside the safe frame | glued on the anchor, full marker, opacity by crosshair distance |
| edge | anchor outside the safe frame or behind | on the safe-frame edge toward the point, small, no label, glides |
| behind, near 180° | rel bearing beyond ±170° | keeps the last side (no flip) |
| on point | you're inside the point (not warm-up) | fades to hidden |
| warm-up | HpPhase warmup | point 1, label LOCKED m:ss (as 1.6), same placement rules |
| no point | no points list | hidden ("off") |

## Tasks
### Task 1 — HardpointHUD 1.7 marker v3 · Wired (MDA-433)
Files: src/client/HardpointHUD.client.luau. Placement, glide, fade, on-point hide, ZIndex, diagnostic, attributes above.

### Task 2 — QA + docs · Wired (MDA-434)
Practice match, scripted camera sweeps (yaw 0..360 at 90° / s, pitch −30..+20) on PC size and forced touch: marker never above
the top line or inside the bottom band; frame-to-frame jump while turning ≤ the glide step (no > 40 px jumps); edge side matches
the compass side; on point -> hidden; Summit point (high) sits on the point. Docs + Dev Hub. Kepu: a look on the phone.

## Red-team (2026-11-11)
1. **Two pointers when the point is behind you** (edge icon + compass). CoD has both; accepted with Kepu's pick A.
2. **The edge icon can slide under the score card / kill feed on the left.** Drawn under the HUD (ZIndex 0) so the panels win;
   the distance still shows next to them. Accepted.
3. **Fast turns.** Glued while in view (no lag); glide only across the in / off-view change, so a fast flick doesn't trail.
4. **Phone buttons.** The bottom 110 px is kept clear so the icon never sits on the joystick or attack buttons.

## Status (2026-11-11)
Plan + tickets filed; Kepu "Build" 13:57.

## Build (2026-11-11)
Commit 64bcee7, then the two QA fixes below; installed in Studio, hash 974173247.
- QA fix 1: behind the camera, a left / right side switch glided straight across the middle of the screen. Now the behind
  direction is (sideways offset, distance behind), so the icon rides the bottom edge round (no side hysteresis needed).
- QA fix 2: an easing glide lagged 60–100 px behind the point while turning. Now a change between in view and off view blends
  over HardpointHUDMarkerBlend 0.15 s and then the icon is exactly on the point.
- Scripted sweeps (practice match, Studio window 325 x 487): settled error on the point 0.8–1.4 px (max); settled per-frame
  move ≤ 43 px at 90° / s (smooth along the edges); 0 frames over the middle while behind at 90° / s; a 360° / s flick
  crosses near the middle only during the 0.15 s blend. Phone mode: behind -> bottom edge at 110 px from the bottom, 0.84
  size, no label. On the point: hidden ("on point").
- Not seen at a real phone size yet (Kepu's look).
