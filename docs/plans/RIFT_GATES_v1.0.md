# Mecha Dino Arena — Rift Gates v1.0 (islet portal look + walk-in effect)

**Goal:** the two islet portals look like real portals: a mecha ring with a live vortex, and walking in has a moment.
**Kepu 2026-11-12 16:16:** "the portals themselves need some better designing and vfx"; **16:20** pick "I like the the rift
gates" (mockup docs/mockups/portal_look_v0.1.html, artifact Dt8CYFwvxg34P3GPw3W9af, option **A · Rift Gate**).
**Architecture:** the islet is built in Studio Edit by tools/build/PortalIslet.build.luau into ServerStorage.PortalIslet;
HubServer clones it into Workspace on hub servers. The build adds a `Rift` folder to each portal and keeps the 1.1 parts
(tagged `Legacy`). A new client script animates the rift; the server marks a portal when a trip starts from it so every
client plays the flare.

## Global constraints
- Additive: the 1.1 portal parts stay in the model; PortalFX hides them (LocalTransparencyModifier-style: Transparency
  set on the client) only while its switch is on. Switch off = the 1.1 look.
- Trigger box unchanged (50 × 64 × 16, attribute HubPortal). Opening stays at least 50 wide × 62 tall (Therizino 33 × 27).
- Colours unchanged: ARENA orange rgb(255,155,46) (neon rgb(255,100,18)), VS BOTS yellow rgb(255,200,50) (neon
  rgb(255,196,40)); sign text keeps the HUD colour.
- No new uploaded assets needed: the vortex is Beams (no texture) + neon parts; the hum sound only if Kepu gives an id.
- Phone: particles × 0.5 and no extra lights when the device is touch-only or graphics quality ≤ 4.
- Version branding in headers, VERSIONS.md, ATTRIBUTES.md. Every number an attribute.

## Do-not-touch
- HubServer trip logic, HubTravel, HubRules (only one new attribute write in T3, behind a switch).
- PortalHUD's loader hand-off (EggLoader / SetTeleportGui), the safe zones, the bridge, spawns, the edge ring.

## Tasks

### T1 — PortalIslet.build 1.2: the Rift model · Wired
- Per portal, folder `Rift` (all anchored, no collide unless stated, CastShadow false on glow parts):
  - Plinth: 2 stacked blocks (Metal, rgb(60,70,86)), 64 wide, collidable (you walk over it).
  - Ring: octagon, 8 Metal blocks rgb(74,84,102) around an ellipse (inner 27 × 31 studs half-sizes, 7 thick, 6 deep), 8
    bolts (small cylinders), 8 Neon conduit strips on the ring face (`Conduit1..8`, colour = neon tone, Transparency 0.6).
  - Vortex: part `VortexHub` (invisible, centre of the opening) with 6 Attachments on the inner rim and 1 at the centre;
    6 Beams rim → centre (Width0 7, Width1 0.5, CurveSize0 14, LightEmission 1, Transparency 0.2 → 0.9, colour neon tone);
    a disc `VortexDisc` (Cylinder, Neon, Transparency 0.35, fills the opening) behind them; `VortexCore` (white Neon,
    Transparency 0.5, small disc).
  - Sparks: ParticleEmitter on VortexHub (Rate 22, Speed −18, Drag 2, Lifetime 1.2, Size 0.6, LightEmission 1,
    SpreadAngle 180, the mode colour).
  - Floor ring: `RuneRing` (flat Cylinder, Neon, 0.2 thick, 48 across) in front of the plinth + `RuneInner` (32 across).
  - PointLight on VortexHub (Range 60, Brightness 2) — the 1.1 light is in Legacy.
- 1.1 parts in each portal get attribute `Legacy = true` (pillars, trims, glows, arch, swirl, core, 1.1 light). Sign,
  SignEdge, SignPost and Trigger are shared (no tag).
- Model attribute PortalIsletVersion "1.2". Build constant RIFT (default true; false = 1.1 build).
- **Acceptance:** rebuilt model in ServerStorage; Studio screenshots of both portals; the Therizino walks through the
  opening without touching the ring; trigger unchanged.

### T2 — PortalFX 1.0 (new LocalScript, StarterPlayerScripts) · Wired
- On hub servers (Workspace has the islet): hides every `Legacy` part (Transparency 1, keeps it) and shows `Rift`.
- Each frame (only while the islet is within 400 studs of the camera): VortexHub turns 70°/s around its facing axis (Beams
  follow); conduits light in turn (2 lit at once, 6 steps/s: Transparency 0 lit / 0.6 off); RuneRing Transparency
  0.15 + 0.35 × (0.5 + 0.5 sin 3t); RuneInner size pulses ±6%.
- Phone budget as the global constraint (emitter Rate × 0.5).
- Switch: script attribute PortalFXEnabled (default true, read per frame; false = 1.1 look shown, rift hidden).
  Diagnostics: player PortalFXVersion, PortalFXState ("rift" / "legacy" / "far").
- **Acceptance:** both portals animate in Studio; switch off shows 1.1 exactly; client ms < 0.3 with both on screen.

### T3 — Walk-in flare · Wired
- HubServer 1.3 (one write, switch HubPortalFlareEnabled): when a trip starts from a portal, the portal model gets
  attribute `PortalFlareAt = server time`.
- PortalFX on PortalFlareAt: 0.6 s flare (VortexDisc Transparency → 0, light Brightness 2 → 6 → 2), floor shock ring
  (a Neon ring growing 10 → 90 across over 0.5 s, fading), sparks Emit(40) (phone 18).
- The local traveller also gets a 0.25 s white flash (ScreenGui, DisplayOrder below the EggLoader's 100) right as the
  loader comes up.
- **Acceptance:** walking in shows the flare to you and to a second client; the loader still comes up straight away.

### T4 — QA + docs · Wired
- Studio check both portals PC + phone emulation; VERSIONS / ATTRIBUTES rows; reference screenshots
  docs/reference/hub/islet_rift_v1.2.jpg; live check on Dev Hub.

## Red-team (folded in)
1. *The vortex looks flat without a swirl texture.* Layered Beams with curve + LightEmission and a translucent disc behind
   carry it; acceptance needs Kepu's look at Studio screenshots before publish. If it still reads flat, a swirl Decal is a
   later add (needs one uploaded image).
2. *Rebuilding the islet risks the live hub.* The build only writes ServerStorage.PortalIslet; HubServer clones on hub
   servers. Hash and part-count check after the build; 1.1 parts kept, so switch-off is the exact old look.
3. *Client cost on phones.* Two portals, 12 Beams, ~45 particles each, 2 parts turned per frame; the far check (400
   studs) stops the work off the islet. Measured in T2.
4. *Hum sound.* No asset id in hand; left out until Kepu gives one (not a blocker).
5. *Others seeing the flare.* Needs the server write (T3); without it only the traveller sees it — accepted fallback.
