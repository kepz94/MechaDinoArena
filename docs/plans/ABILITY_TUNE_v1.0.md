# Mecha Dino Arena — Ability tune: Dilo mortar size + Sap Wall aim v1.0

**Ask (Kepu 2026-11-15 12:09):** "lets work on some of the abilities like the Dilo needs a bigger radius for the mortar also the sap wall for the troodon should have an arch show where its gonna land for better precision".
**Mockup:** docs/mockups/sapwall_aim_v0.1.html. Kepu's picks:
- Mortar: "+50% (18 / 22 / 27)".
- Sap Wall: "A · Hold to aim".
- Phone thumb drag: "Move the landing".

## Today (code facts)
- **Mortar size.** SkillTree 1.76 multiplies dMortarRadius by 1.5 (8 / 10 / 12 → 12 / 15 / 18). DiloMovesServer reads it as DiloPartMortarRadius (damage area, target ring, landing blast). DiloPartsVFX 1.0 sizes the cloud from R: box R × 1.8. Smoke rate is 30 × R / 18 and sparks a flat 12, so a bigger cloud gets thinner.
- **Sap Wall throw.** MechaButtons 1.50 sends a tap at once: `DinoTrooSapRequest(stamp, flat look, point)`. The point comes from bodyPoint (body facing × range, or the first hit), else Classic, else the crosshair hit.
- **Server landing.** TrooMovesServer `landing`:
  - The flat distance of the point is clamped to TrooPartSapRange, in its direction.
  - Ground Y comes from a ray from root Y + 60 down 200. The ray leaves out players, Bots, TallGrass and the FX folders.
  - The wall is square to the throw (`wallFrame`).
  - `occupied`: a dino root inside the footprint (width/2 + 3, H/2 + 4, 1 + 3) blocks the throw.
- **Pod flight (TrooPartsFX).** From the hand (root + 1.5 × scale up + look × 2 × scale) to the landing + 0.5. Peak = sapArc 7 × scale / 2. Height = 4 × peak × u × (1 − u).
- **Hold-to-aim** already exists for the Screech, the tether and the Sniper Scope (aimedPart / aimStart / aimRelease / aimCancel, the thumb-aim lock AIM_LOCK / AIM_DEAD, AIM_SMOOTH).

## Rules
1. **Mortar +50% (SkillTree 1.94, DiloPartsVFX 1.1).**
   - effects() multiplies dMortarRadius by DILO_MORTAR_RADIUS_MUL2 (1.5): 12 / 15 / 18 → 18 / 22.5 / 27.
   - The Lab texts become 36 / 45 / 54 studs wide.
   - The cloud smoke and sparks scale with area: × (R / 18)², capped at × 3.
   - Switches: DILO_MORTAR_BIG, DiloPartsVFX_mortarAreaRate.
2. **Sap Wall hold-to-aim (MechaButtons 1.51).**
   - **When it aims:** while the part is ready (a charge left, not silenced), pressing SAP WALL shows the aim and letting go throws.
   - **What you see:** a local model only you can see:
     - 20 amber dots on the pod's real arc.
     - A wall ghost at the real size (width × height × 2), square to the throw.
     - A landing disc.
     - The tag "NN STUDS · LET GO TO THROW".
     - When a dino stands in the spot (the server's occupied rule), the ghost turns red and the tag reads "BLOCKED".
   - **Phone:** the landing starts at the tap point. Thumb up / down moves it farther / nearer (5 … range). Left / right turns it up to 60°.
   - **PC:** the landing follows the ground under the screen centre.
   - **Quick tap** (under 0.2 s, or on the phone with no drag): throws exactly as 1.50.
   - **Not ready:** 1.50's tap path, unchanged.
   - Switch: MechaButtonsSapAimEnabled.

## Tasks
- MDA-548: rule 1.
- MDA-549: rule 2.

## Do-not-touch
TrooMovesServer (landing, occupied, charges), TrooPartsFX pod flight, DiloMovesServer, the Screech / tether / scope aim, the slot-button gesture code.

## Red-team (folded in)
- **"The ghost lies about where it lands."** The client uses the server's exact landing, groundY, wallFrame and occupied rules. The server re-clamps the point anyway.
- **"Hold breaks the quick throw."** A tap still sends 1.50's tap point.
- **"The phone drag fires another button."** Found in the Studio test: dragging left from SAP WALL slides onto ARC LANTERN, whose InputBegan started it and cancelled the aim. Fixed in 1.51: while the finger aims Sap Wall, any slot button it slides onto does not start (MechaSapAimSlideOver).
- **"A slot with no pull part has no gesture."** Found in the test: a plain button press had no thumb aim. Fixed in 1.51: a touch / click press on the slot button also gets the thumb-aim lock, with its own drag listener.
- **"A bigger cloud costs frames on phones."** The rate is capped at × 3 (67 smoke + 27 sparks at R 27), inside DiloPartsVFX's maxParts 350 trim.

## Build notes
SkillTree is over 200 000 characters, so `Source =` is refused. It was installed with ScriptEditorService:UpdateSourceAsync, hash-checked.

## Studio test (2026-11-15, bots match)
**Dilo (maxed):**
- effects 18 / 22.5 / 27, text misses 0.
- In the match, DiloPartMortarRadius 27. The cloud box is 48.6 wide, smoke 67, sparks 27.

**Troodon (maxed: width 100, height 30, range 80):**
- **PC hold R:** "camera" mode, 36 studs. Release put the server TrooSapTo exactly on the ghost (Δ 0), result "wall".
- **Blocked:** a bot moved into the spot → BLOCKED, red. Release → server "occupied", charge kept.
- **PC quick tap:** "tap", straight ahead (dot 1.000).
- **Phone (iPhone 17 Pro emulation):**
  - Plain press, drag left 79 px → yaw 35° left (expected 35.4). Drag down → 76 / 58 studs. Release threw there ("ok").
  - With a pull part (gesture path), drag across ARC LANTERN: the aim was kept (SlideOver 2) and released "wall" at 80. No lantern.
  - Quick tap: full range straight ahead.
- **Not seen in Studio captures:** the tool's screen capture does not draw BillboardGuis at all (a test billboard was also missing), so the tag text is checked by its properties only.
