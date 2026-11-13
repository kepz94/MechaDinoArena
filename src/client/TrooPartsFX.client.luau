-- TrooPartsFX v1.5 (Mecha Dino Arena) — the Troodon's mecha button parts, build 1: the layered VFX on every client.
-- MDA-351, plan docs/plans/TROODON_PARTS_v1.0.md ticket 7; spec tools/mockup/troodon_parts_looks.js ("VFX, in Roblox
-- pieces" per part; Kepu 2026-11-06 20:11 "real vfx ... consistent w the rest of the rosters"). Reads TrooMovesServer 1.x's
-- stamps (server time) on every troodon character and draws locally in Workspace.TrooPartsFX (never replicated). Every move:
-- wind-up -> action -> result -> recovery; no landing FX. Effects only on troodons and their targets.
-- * Mender Drone (green 8DFFB6, the Med-Station heal look): wind-up (TrooMenderAt .. + TrooPartsFX_menderWindup 0.45) the
--   dock pieces light up (PointLight) and sparkle; action: the carried drone pieces hide and a drone (dark shell, green Neon
--   eye, plate wings, Trail, PointLight) flies on an arc to TrooMenderTarget, arriving at TrooMenderArriveAt; result: it
--   orbits the target (radius TrooPartsFX_menderOrbit 3.5 x scale, 4 x scale up) with a green Beam every 0.25 s and a
--   MedWave-style ground ring every 1 s until the end; TrooMenderHopAt: flies to TrooMenderHopTo; recovery: at TrooMenderEndAt
--   it flies back to the dock (0.75 s) and the pieces come back with a sparkle.
-- * Arc Lantern (the raptor Shock Mine look: VOLT 127,233,255 / core 225,250,255): wind-up (.. + 0.42) the lantern piece
--   flickers (PointLight) and crackles (sparks); action: the piece hides, a lantern (volt Neon core, Glass shell, brass cap,
--   Trail, PointLight) flies TrooLanternFrom -> TrooLanternTo over TrooLanternFlight on an arc; result: it lands, opens (the
--   shell clears, the light grows) and every TrooLanternZapAt draws a jagged arc (6 Beams, re-drawn every 0.06 s for 0.3 s)
--   from the lantern / the last target to the newest name in TrooLanternChainList, a MineBurst ball and sparks on it;
--   recovery: TrooPartsFX_lanternLinger (0.9 s) after the last zap the lantern fades and the piece comes back.
-- * Sap Wall (the TrooFX pod look: FFC35A pod, FFE2A0 flash, FFB43A embers): wind-up (.. + 0.34) the pod piece glows and drips;
--   action: a sap pod (Neon, Trail) flies TrooSapFrom -> TrooSapTo over TrooSapFlight; result: a splat flash + embers, and
--   each new wall in Workspace.TrooWalls gets a wet amber sheen that sets (Transparency 0.45 -> 1 over 0.8 s) and a Neon rim at
--   its base; a hit the wall stops (WallBlockedAt on a wall part, SapWallBlock 1.1) flashes at WallBlockedPos; recovery: when
--   the wall goes, its segments crumble (amber chunks fall and fade), and the pod piece comes back 1.15 s after the press.
-- * Feather Shed (the Energy Shield dome + a shockwave ring + feathers): wind-up (TrooShedAt .. + 0.15) the release bolts flash
--   (white light); action: the shed plates are flung off (local clones, spinning, fading 0.7 s), a feather burst (40) and a flat
--   Neon ring out to TrooPartShedKnockRadius (or 6 x scale); result: a ForceField-material shell round the troodon until
--   TrooShedImmuneUntil; recovery: the plates come back at its end.
-- * Portal Feathers (TrooFX teal 2FE6C8 / A8FFF0, brass vanes): wind-up (.. + 0.4) the tail rings glow; action: ring A flies
--   to TrooPortalA (0.35 s), ring B (from + 0.52) to TrooPortalB (0.8 s), each with a Trail; result: TrooPortalOpenAt /
--   TrooPortalOpen2At open them (flash + ring wave) into standing rings (12 teal Neon blocks, 8 brass vanes, a spinning swirl
--   film) until TrooPortalUntil; any character's TrooPortalUsedAt flashes both ends (TrooPortalFrom / TrooPortalTo) with
--   feathers; recovery: at the end the rings shrink and fade and the tail pieces come back.
-- Carried pieces (TrooPartsServer 1.0 OPart_<id>, OPartRole carry / carry1 / carry2 / shed) are hidden with
-- LocalTransparencyModifier only (the server weld and fit are untouched).
-- Switches (script attributes, read at each event): TrooPartsFXEnabled, TrooPartsFX_omenderEnabled, _olanternEnabled,
--   _osapwallEnabled, _oshedEnabled, _oportalEnabled (default true each). Numbers: script attributes TrooPartsFX_<name> (see
--   CFG). Diagnostics: script TrooPartsFXVersion, TrooPartsFXLast ("<id>:<phase>"), TrooPartsFXEvents (count).
-- v1.1 (MDA-351, review of the B1 captures 2026-11-07: the Sap Wall almost invisible from the game camera, the portal rings read
--   as teal bursts, the lantern chain zap not visible) - the three looks brought up to the picked mockup v0.2
--   (tools/mockup/troodon_parts_looks.js sapTrack / portalTrack openPortal / zap + lanternTrack; sizes are the mockup's studs at
--   the 2x body x k = scale / 2; the wall follows the server wall's real size, Kepu's 50 studs):
--   * Sap Wall (switch TrooPartsFX_sapLookEnabled): each server wall part is hidden locally (LocalTransparencyModifier) and drawn
--     as a local slab (SmoothPlastic, wet FFB43A at Transparency 0.45) that rises from the ground over sapRise 0.3 s (back-out
--     ease), with a Neon amber core inside (the wet glow); sapHardenFrom 0.2 .. sapHarden 0.45 s after the splat it sets
--     (Transparency -> sapHardT 0.08, colour -> D9821C, the core fades); a full-width Neon rim FFE2A0 (0.5 x k high) along the
--     base with a PointLight; at the set a white sweep (1.2 x k wide, 0.55 x the wall high) runs across the front in 0.45 s; the
--     last 0.5 s the slabs shake (0.08 x k); the splat: a FFD27A ground ring out to 0.58 x the width, FFE2A0 flash, FFE7A8
--     motes rising along the width; the end: the slabs fly off (thrown up, falling, turning, shrinking, fading 0.6 s), 8
--     E8C08A dust puffs along the wall and 14 FFE7A8 sparks. Blocked-hit flashes as 1.0.
--   * Portal Feathers (switch TrooPartsFX_portalLookEnabled): the standing ring = a continuous teal Neon torus (8FF7E6,
--     portalRingR 4.2 x k, tube portalTube 0.32 x k, 28 blocks), 8 brass vanes (0.3 x 1.5 x 0.5 x k) at portalVaneR 5 x k, a
--     swirl film (a 2FE6C8 Neon disc at 0.55, a pale DCFFFA centre at 0.4 and 4 white arcs at 14 / 26 / 38 / 50 of 64 of the
--     radius, 2.2 rad long, turning 2 rad/s), centre portalCentre 4.8 x k above the ground, facing along A -> B; opening: scale
--     0.05 -> 1 over 0.3 s (back-out), a B8FFF0 flash (10), an A8FFF0 orb (5) and a 2FE6C8 ground ring (7); open: a teal
--     PointLight (range 11 x k) and A8FFF0 motes rising from its foot (10 / s); the flung ring spins and grows 1 -> 5 on its
--     arc (2.5 / 9 x k high); closing: shrinks over 0.35 s with an orb and sparks.
--   * Arc Lantern (switch TrooPartsFX_zapLookEnabled): each zap = the mockup's jagged arc, 9 segments whose points jitter by
--     sin(pi k) x length x 0.08 sideways and up, re-rolled every frame for zapLife 0.32 s: a CORE core Beam (0.35 x k) and a VOLT
--     glow Beam (2.2 x k, the mockup's glow sprites) on the same points; on each target a MineBurst-style VOLT orb (2 -> 12 x k
--     studs over 0.35 s), a flash, 3 small crackle arcs round it (0.45 s) and C8F8FF sparks; on landing a VOLT ground ring
--     (16 x k), an orb (8 x k) and 3 short arcs from the lantern; in the wind-up 4 tiny arcs round the hip lantern.
--   Numbers: TrooPartsFX_<name> as CFG; zapLife may be raised in a Play-only session to hold the arcs for a capture.
-- v1.2 (MDA-351, review of parts_1.1_mender_close.jpg 2026-11-09: the Mender Drone read as a dark puck with a thin beam, smaller
--   and dimmer than the picked mockup v0.2 look A "Shoulder Dock") - the flying drone, its glow and its heal beam brought up to
--   tools/mockup/troodon_parts_looks.js (H1 A pieces + menderTrack; the flying drone is the dock drone at worldM scale 2, so its
--   model units x 2 x k = x scale studs; k = scale / 2) (switch TrooPartsFX_menderLookEnabled, default true; false = 1.1's drone):
--   * drone (x menderDroneK 1): a gunmetal puck (cylinder 0.58 x 0.2 model units), a green Neon heal dome on top (0.42 x 0.25 x
--     0.42, +0.1), a brass ring round it (torus R 0.43, tube 0.055, 16 blocks), 4 dark struts, a steel rotor bar under it
--     spinning 40 rad/s, a green nose light and a brass tail fin (0.04 x 0.26 x 0.36, -30 deg); it yaws along its flight
--     (tilt 0.15 rad);
--   * glow: a heal-green (46E08A, the mockup's HEAL_GREEN) Neon halo ball menderHalo 3 x k (Transparency menderHaloT 0.88) and
--     an inner one 0.66 of it (0.9) round the drone (the mockup's glowAt 3 / 0.55; faint enough to show the drone inside), a PointLight (range 14 x k, brightness 3), a Trail menderTrailW 1.1 x k wide
--     (0.35 s, the mockup's trailOn 1.1) and green motes dripping from it (18 / s, falling 3 studs / s, 0.4 s); in the
--     wind-up a 3.5 x k halo on the dock; lift-off a 5 x k flash + a 2.5 x k orb; docking a 4 x k flash + sparks;
--   * orbit: radius menderOrbitR 4.5 x k, menderOrbitUp 5.5 x k above the target's root, 2.6 rad/s, bob 0.4 x k (the mockup's
--     orbitP); heal beam = a steady tether Beam (menderTether 0.36 x k wide, pulsing 0.35-0.65 opaque, the mockup's tether 0.18
--     radius) from the drone to the target plus, every menderPulse 0.75 s (the mockup's heal tick), a cone Beam 0.44 -> 1.2 x k
--     wide fading over 0.3 s and a green burst on the target; the MedWave ground ring every 1 s as 1.1. A hop moves the tether.
-- v1.3 (MDA-376, TrooMovesServer 1.8 tracks the lantern's target): when the troodon's TrooLanternTrack names a live model the
--   flying lantern homes on it: the flight's end is that model's root (flat) at TrooLanternTo's height, re-read every frame, so
--   it lands on the target where the server zaps it. Switch: script attribute TrooPartsFX_lanternTrackEnabled (default true,
--   read at each throw; false = 1.2's fixed flight to TrooLanternTo).
-- v1.4 (MDA-375, TrooMovesServer 1.10 Portal Rift) - the rift looks (switch TrooPartsFX_riftLookEnabled, default true, read at each
--   event; with TrooPortalRiftEnabled off on the server the old ring stamps and looks run as 1.3): wind-up (TrooRiftAt) the tail
--   rings glow 0.25 s; action: the carried rings hide and the picked Tail Rings ring (makeRing2, 1.1's open look) stands at
--   TrooRiftA facing the run, and a teal feather Trail (1.2 s) + falling feather sparks follow the troodon while TrooRiftPlacing;
--   result (TrooRiftOpenAt): the second ring opens at TrooRiftB facing along the path's end, and the rift line lies along
--   TrooRiftPath (teal Neon strips 0.5 x 0.25 x k at 0.35, 0.6 x k above the ground) with A8FFF0 motes rising along it until
--   TrooRiftUntil; a traveller (TrooRiftTravelAt on any dino) gets an entry flash at TrooRiftTravelFrom and a white-teal streak
--   (Trail 0.45 s + a glowing A8FFF0 ball with a PointLight) until TrooRiftTravelUntil, no landing FX; recovery (TrooRiftEndAt /
--   TrooRiftCancelAt): the rings shrink and fade with an orb + sparks, the line fades, the tail rings come back.
-- v1.5 (MDA-377, TrooMovesServer 1.11 stuns every zapped dino; Kepu 2026-11-09 21:25 "Raptor shock look") - the lantern's hit look
--   on each zapped dino (switch TrooPartsFX_lanternShockEnabled, default true, read at each zap; false = 1.4): result: the Shock
--   Cannon's hit look (ScreechServer 1.x): its impact burst (a VOLT Neon ball 2 -> 10 studs, 0.2 -> 1 transparent over 0.3 s) at
--   the target's root, and while the target's StunnedUntil lasts (capped at its TrooLanternStunUntil; it waits up to
--   TrooPartsFX_shockWait 0.25 s for the stun to replicate, none = immune: flash only) the cannon's stun crackle on the root (its
--   ShockStunSparks emitter: CORE -> VOLT, rate 70, life 0.15-0.35, speed 8-16, size 0.7 -> 0, all round; its ShockStunLight:
--   VOLT, range 14, brightness 3) plus electric arcs crawling over the body: TrooPartsFX_shockArcRate (24) arcs a second, each a
--   zap2 small arc (CORE core + VOLT glow Beams, x the target's size k) between two random points on its visible body parts
--   (nearby parts, the points ride the parts as they move), living TrooPartsFX_shockArcLife (0.16 s); recovery: when the stun
--   ends or is broken (Feather Shed / Antivenom / stun breakers set StunnedUntil back) the arcs stop, the sparks stop emitting
--   (the last ones die out) and the light fades over 0.15 s. No landing FX. Diagnostic: script TrooPartsFXShocks (count).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 sap wall / portal rings / lantern zap looks to mockup v0.2
VERSION = "1.2" -- v1.2 mender drone size / glow / heal beam to mockup v0.2
VERSION = "1.3" -- v1.3 the lantern homes on its tracked target (MDA-376)
VERSION = "1.4" -- v1.4 Portal Rift looks (MDA-375)
VERSION = "1.5" -- v1.5 lantern hit look: Shock Cannon stun look + body arcs (MDA-377)
VERSION = "1.6" -- v1.6 loud Arc Lantern: heavy chain bolts + hit flash + SHOCKED mark (MDA-508)
-- v1.6 (MDA-508, plan docs/plans/TROODON_SAP_LANTERN_v1.0.md Task 4, mockup docs/mockups/troodon_lantern_sap_v0.1.html pick "B ·
--   Shocked mark"; Kepu 2026-11-13 15:08 "show more electricity especially if it's bouncing on to other dinos, it needs to be
--   visibly obvious that the Dino took the hit and got a debuff"). While script attribute TrooPartsFX_lanternLoudEnabled ~= false
--   (default true, read at each zap; false = 1.5):
--   * each chain zap: the zap2 bolt is lanternBoltMul (2) x wider, lives lanternBoltLife (0.6 s) and its head travels from the
--     lantern / the last dino to the new one over lanternBoltTravel (0.08 s); lanternForks (3) short forks branch off it;
--   * each zapped dino flashes white (a Highlight, fill + outline white, lanternFlashTime 0.12 s);
--   * while its stun from the zap lasts (the 1.5 rules: only a stun that landed; immune = flash only): a flickering VOLT outline
--     (Highlight, DepthMode Occluded, fill VOLT 0.82) and a "⚡ SHOCKED" tag over its head (BillboardGui, 124 x 30 px, dark
--     panel + VOLT stroke, Silkscreen, a VOLT bar draining to the stun's end, MaxDistance shockTagMax 150; in PlayerGui, Adornee
--     the root, half the model's height + shockTagUp 5.5 studs up, over the name / health tag); both go when the
--     stun ends or is broken. Diagnostic: script TrooPartsFXShockMarks (count).
script:SetAttribute("TrooPartsFXVersion", VERSION)
local CFG = {menderWindup = 0.45, menderFly = 0.75, menderBack = 0.75, menderOrbit = 3.5, menderTick = 0.25, lanternWindup = 0.42,
	lanternLinger = 0.9, lanternArc = 6, sapWindup = 0.34, sapArc = 7, sapReturn = 1.15, shedWindup = 0.15, shedFling = 0.7,
	shedRadius = 6, portalWindup1 = 0.4, portalWindup2 = 0.52, portalFly1 = 0.35, portalFly2 = 0.8, portalRing = 3, portalUp = 3.5,
	sapRise = 0.3, sapHardenFrom = 0.2, sapHarden = 0.45, sapWetT = 0.45, sapHardT = 0.08, portalRingR = 4.2, portalTube = 0.32,
	portalVaneR = 5, portalCentre = 4.8, zapLife = 0.32, -- v1.1
	menderDroneK = 1, menderHalo = 3, menderHaloT = 0.88, menderTrailW = 1.1, menderOrbitR = 4.5, menderOrbitUp = 5.5, menderTether = 0.36,
	menderPulse = 0.75, -- v1.2
	shockWait = 0.25, shockArcRate = 24, shockArcLife = 0.16} -- v1.5
CFG.lanternBoltMul, CFG.lanternBoltLife, CFG.lanternBoltTravel, CFG.lanternForks = 2, 0.6, 0.08, 3 -- v1.6
CFG.lanternFlashTime, CFG.shockTagMax, CFG.shockTagUp = 0.12, 150, 5.5 -- v1.6
if script:GetAttribute("TrooPartsFX_lanternLoudEnabled") == nil then script:SetAttribute("TrooPartsFX_lanternLoudEnabled", true) end -- v1.6
for k, v in pairs(CFG) do
	if script:GetAttribute("TrooPartsFX_" .. k) == nil then script:SetAttribute("TrooPartsFX_" .. k, v) end
end
for _, k in ipairs({"TrooPartsFXEnabled", "TrooPartsFX_omenderEnabled", "TrooPartsFX_olanternEnabled", "TrooPartsFX_osapwallEnabled",
	"TrooPartsFX_oshedEnabled", "TrooPartsFX_oportalEnabled", "TrooPartsFX_sapLookEnabled", "TrooPartsFX_portalLookEnabled",
	"TrooPartsFX_zapLookEnabled", "TrooPartsFX_menderLookEnabled", "TrooPartsFX_lanternTrackEnabled", "TrooPartsFX_riftLookEnabled", "TrooPartsFX_lanternShockEnabled"}) do -- v1.5: + lanternShock -- v1.1: + the three look switches; v1.2: + menderLook; v1.3: + lanternTrack
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function cfg(k) return tonumber(script:GetAttribute("TrooPartsFX_" .. k)) or CFG[k] end
local function on(id) return script:GetAttribute("TrooPartsFXEnabled") ~= false and script:GetAttribute("TrooPartsFX_" .. id .. "Enabled") ~= false end
local function now() return workspace:GetServerTimeNow() end
local function diag(id, phase)
	script:SetAttribute("TrooPartsFXLast", id .. ":" .. phase)
	script:SetAttribute("TrooPartsFXEvents", (script:GetAttribute("TrooPartsFXEvents") or 0) + 1)
end

local GREEN, GREEN_L = Color3.fromHex("8DFFB6"), Color3.fromHex("D8FFE6")
local VOLT, CORE = Color3.fromRGB(127, 233, 255), Color3.fromRGB(225, 250, 255)
local AMBER, FLASH, EMBER = Color3.fromHex("FFC35A"), Color3.fromHex("FFE2A0"), Color3.fromHex("FFB43A")
local TEAL, TEAL_L, BRASS = Color3.fromHex("2FE6C8"), Color3.fromHex("A8FFF0"), Color3.fromHex("C8913A")
local DARK, PLATE = Color3.fromHex("23262C"), Color3.fromHex("5D544A")
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"

local folder = workspace:FindFirstChild("TrooPartsFX")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TrooPartsFX"
	folder.Parent = workspace
end

-- helpers ------------------------------------------------------------------------------------------------------------------
local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	if not props.Parent then p.Parent = folder end
	return p
end
local function ball(d, color, mat, tr)
	return part({Shape = Enum.PartType.Ball, Size = Vector3.one * d, Color = color, Material = mat or Enum.Material.Neon, Transparency = tr or 0})
end
local function light(p, color, range, br)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, br or 2, false
	l.Parent = p
	return l
end
local function trail(p, color, w)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, w / 2, 0), Vector3.new(0, -w / 2, 0)
	a0.Parent, a1.Parent = p, p
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = ColorSequence.new(color)
	t.Transparency = NumberSequence.new(0.2, 1)
	t.Lifetime, t.LightEmission, t.FaceCamera = 0.35, 1, true
	t.Parent = p
	return t
end
local function fade(p, dur, size)
	if not p or not p.Parent then return end
	local goal = {Transparency = 1}
	if size then goal.Size = size end
	TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	for _, l in ipairs(p:GetDescendants()) do
		if l:IsA("PointLight") then TweenService:Create(l, TweenInfo.new(dur), {Brightness = 0}):Play() end
	end
	Debris:AddItem(p, dur + 0.05)
end
local function burst(pos, color, n, speed, size, life)
	local p = part({Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(pos)})
	local e = Instance.new("ParticleEmitter")
	e.Texture, e.Color, e.LightEmission = SPARK_TEX, ColorSequence.new(color), 1
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0)})
	e.Transparency = NumberSequence.new(0, 1)
	e.Speed, e.SpreadAngle = NumberRange.new(speed * 0.5, speed), Vector2.new(180, 180)
	e.Lifetime, e.Drag, e.Rate, e.Enabled = NumberRange.new(life * 0.6, life), 2, 0, false
	e.Acceleration = Vector3.new(0, -8, 0)
	e.Parent = p
	e:Emit(n)
	Debris:AddItem(p, life + 0.2)
end
local function flashBall(pos, color, d0, d1, dur)
	local b = ball(d0, color)
	b.CFrame = CFrame.new(pos)
	b.Transparency = 0.1
	light(b, color, d1 * 2, 3)
	fade(b, dur, Vector3.one * d1)
end
local function groundRing(pos, color, r0, r1, dur)
	local d = part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, r0 * 2, r0 * 2), Color = color, Transparency = 0.35,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))})
	fade(d, dur, Vector3.new(0.15, r1 * 2, r1 * 2))
end
local function arcFly(p, from, to, dur, height, done)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not p.Parent then conn:Disconnect() return end
		local u = math.min(1, (os.clock() - t0) / math.max(0.01, dur))
		local tt = typeof(to) == "function" and to() or to -- v1.3: a moving end (the tracked lantern)
		local pos = from:Lerp(tt, u) + Vector3.new(0, 4 * height * u * (1 - u), 0)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(0, u * 6, 0)
		if u >= 1 then
			conn:Disconnect()
			if done then done() end
		end
	end)
end
local function zapArc(a, b, dur)
	local holder = part({Size = Vector3.one * 0.1, Transparency = 1, CFrame = CFrame.new()})
	local N = 7
	local atts, beams = {}, {}
	for i = 0, N do
		local at = Instance.new("Attachment")
		at.Parent = holder
		atts[i] = at
	end
	for i = 1, N do
		local bm = Instance.new("Beam")
		bm.Attachment0, bm.Attachment1 = atts[i - 1], atts[i]
		bm.Color = ColorSequence.new(CORE, VOLT)
		bm.Width0, bm.Width1, bm.LightEmission, bm.FaceCamera = 0.35, 0.25, 1, true
		bm.Parent = holder
		beams[i] = bm
	end
	local t0 = os.clock()
	local function redraw()
		local pa, pb = typeof(a) == "function" and a() or a, typeof(b) == "function" and b() or b
		if not (pa and pb) then return end
		for i = 0, N do
			local j = (i == 0 or i == N) and Vector3.zero or Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6
			atts[i].WorldPosition = pa:Lerp(pb, i / N) + j
		end
	end
	redraw()
	task.spawn(function()
		while os.clock() - t0 < dur and holder.Parent do
			task.wait(0.06)
			redraw()
		end
		holder:Destroy()
	end)
end
local function rootOf(m)
	if not m then return nil end
	local r = m:FindFirstChild("HumanoidRootPart")
	return r and r:IsA("BasePart") and r or nil
end
local function findModel(name)
	if typeof(name) ~= "string" or name == "" then return nil end
	local pl = Players:FindFirstChild(name)
	if pl and pl:IsA("Player") and pl.Character then return pl.Character end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or nil
end
local function pieces(char, id, roles)
	local out = {}
	local m = char:FindFirstChild("OPart_" .. id)
	if not m then return out end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and roles[d:GetAttribute("OPartRole") or ""] then table.insert(out, d) end
	end
	return out
end
local function hide(list, yes)
	for _, p in ipairs(list) do p.LocalTransparencyModifier = yes and 1 or 0 end
end
local function centre(list, char)
	if #list == 0 then local r = rootOf(char) return r and r.Position or char:GetPivot().Position end
	local s = Vector3.zero
	for _, p in ipairs(list) do s += p.Position end
	return s / #list
end
local function windupGlow(list, color, dur, char)
	local anchor = list[1] or rootOf(char)
	if not anchor then return end
	local l = light(anchor, color, 10, 0)
	TweenService:Create(l, TweenInfo.new(dur * 0.8), {Brightness = 4}):Play()
	burst(centre(list, char), color, 10, 4, 0.5, 0.5)
	task.delay(dur + 0.1, function() if l.Parent then l:Destroy() end end)
end
local function delayTo(at, fn)
	task.delay(math.max(0, at - now()), fn)
end
local function num(v) return typeof(v) == "number" and v or nil end
-- v1.1 helpers --------------------------------------------------------------------------------------------------------------
local function lookOn(k) return script:GetAttribute("TrooPartsFX_" .. k .. "LookEnabled") ~= false end
local WARM, SET, DUST, MOTE = Color3.fromHex("FFB43A"), Color3.fromHex("D9821C"), Color3.fromHex("E8C08A"), Color3.fromHex("FFE7A8")
local function orb(pos, d1, color, dur) -- the mockup's orb / MineServer's MineBurst: a Neon ball that grows and fades
	local b = ball(d1 * 0.15, color)
	b.CFrame = CFrame.new(pos)
	b.Transparency = 0.3
	TweenService:Create(b, TweenInfo.new(dur, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Vector3.one * d1, Transparency = 1}):Play()
	Debris:AddItem(b, dur + 0.05)
end
local function rising(fnPos, color, dur, rate, size)
	task.spawn(function()
		local t0, acc, last = os.clock(), 0, os.clock()
		while os.clock() - t0 < dur do
			local t = os.clock()
			acc += (t - last) * rate
			last = t
			while acc >= 1 do
				acc -= 1
				local q = fnPos()
				if q then
					local m = ball(size * (0.7 + math.random() * 0.6), color)
					m.CFrame = CFrame.new(q)
					TweenService:Create(m, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {CFrame = CFrame.new(q + Vector3.new(0, 3 + math.random() * 4, 0)), Transparency = 1}):Play()
					Debris:AddItem(m, 0.85)
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)
end
local function zap2(a, b, life, k, small, wmul) -- the mockup's zap(): 9 jittered points re-rolled every frame, core + glow beams
	wmul = wmul or 1 -- v1.6: width multiplier (the loud lantern bolt)
	local holder = part({Size = Vector3.one * 0.1, Transparency = 1, CFrame = CFrame.new()})
	local N = 9
	local atts = {}
	for i = 0, N do
		local at = Instance.new("Attachment")
		at.Parent = holder
		atts[i] = at
	end
	local beams = {}
	for i = 1, N do
		for layer = 1, 2 do
			local bm = Instance.new("Beam")
			bm.Attachment0, bm.Attachment1 = atts[i - 1], atts[i]
			bm.FaceCamera, bm.LightEmission, bm.Segments = true, 1, 1
			if layer == 1 then
				bm.Color = ColorSequence.new(CORE)
				bm.Width0, bm.Width1 = (small and 0.2 or 0.35) * k * wmul, (small and 0.2 or 0.35) * k * wmul
			else
				bm.Color = ColorSequence.new(VOLT)
				bm.Width0, bm.Width1 = (small and 1.1 or 2.2) * k * wmul, (small and 1.1 or 2.2) * k * wmul
				bm.Transparency = NumberSequence.new(0.45)
			end
			bm.Parent = holder
			table.insert(beams, {bm = bm, layer = layer})
		end
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local u = (os.clock() - t0) / math.max(0.01, life)
		local pa, pb = typeof(a) == "function" and a() or a, typeof(b) == "function" and b() or b
		if u >= 1 or not holder.Parent or not (pa and pb) then conn:Disconnect() holder:Destroy() return end
		local d = pb - pa
		local L0 = d.Magnitude
		local side = Vector3.new(-d.Z, 0, d.X)
		side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
		for i = 0, N do
			local kk = i / N
			local w = math.sin(math.pi * kk) * L0 * 0.08
			atts[i].WorldPosition = pa:Lerp(pb, kk) + side * (math.random() - 0.5) * w * 2 + Vector3.new(0, (math.random() - 0.5) * w * 2, 0)
		end
		local op = (u < 0.7 and 1 or (1 - u) / 0.3) * (0.6 + 0.4 * math.random())
		for _, e in ipairs(beams) do
			e.bm.Transparency = NumberSequence.new(e.layer == 1 and (1 - op) or (1 - op * 0.55))
		end
	end)
end
local function crackle(fnPos, life, k)
	for i = 0, 2 do
		task.delay(i * 0.06, function()
			local q = function() local c = fnPos() return c and c + Vector3.new((math.random() - 0.5) * 5, (math.random() - 0.5) * 4, (math.random() - 0.5) * 5) * k end
			zap2(q, q, math.max(0.1, life - i * 0.06), k, true)
		end)
	end
end

-- Mender Drone -----------------------------------------------------------------------------------------------------------
local drones = {} -- [char] = {model, target, mode, ...}
local function makeDrone(s)
	local m = Instance.new("Model")
	m.Name = "MenderDrone"
	local shell = ball(1.5 * s / 2, DARK, Enum.Material.Metal)
	shell.Name = "Shell"
	shell.Parent = m
	local eye = ball(0.8 * s / 2, GREEN)
	eye.Parent = m
	local wl = part({Size = Vector3.new(1.6, 0.12, 0.7) * s / 2, Color = PLATE, Material = Enum.Material.SmoothPlastic, Parent = m})
	local wr = part({Size = Vector3.new(1.6, 0.12, 0.7) * s / 2, Color = PLATE, Material = Enum.Material.SmoothPlastic, Parent = m})
	light(eye, GREEN, 12, 2)
	trail(shell, GREEN, 0.6 * s / 2)
	m.Parent = folder
	local function place(cf, t)
		local flap = math.sin(t * 30) * 0.5
		shell.CFrame = cf
		eye.CFrame = cf * CFrame.new(0, 0, -0.45 * s / 2)
		wl.CFrame = cf * CFrame.new(-1.1 * s / 2, 0.1, 0) * CFrame.Angles(0, 0, flap)
		wr.CFrame = cf * CFrame.new(1.1 * s / 2, 0.1, 0) * CFrame.Angles(0, 0, -flap)
	end
	return m, place
end
-- v1.2: the mockup's look A drone (see the header); place(cf, t) with cf = position + heading
local DGUN, DSTEEL, HEAL = Color3.fromHex("3A3F47"), Color3.fromHex("9AA1AC"), Color3.fromHex("46E08A")
local function makeDrone2(s)
	local u = s * cfg("menderDroneK") -- studs per mockup model unit (flying drone = the dock drone x 2 x k)
	local k = s / 2
	local m = Instance.new("Model")
	m.Name = "MenderDrone"
	local list = {}
	local function add(p, off) p.Parent = m table.insert(list, {p = p, off = off}) return p end
	local puck = add(part({Name = "Shell", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.58, 0.58) * u, Color = DGUN,
		Material = Enum.Material.Metal}), CFrame.Angles(0, 0, math.rad(90)))
	local dome = part({Size = Vector3.new(0.42, 0.25, 0.42) * u, Color = GREEN})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = dome
	add(dome, CFrame.new(0, 0.1 * u, 0))
	local R, n = 0.43 * u, 16
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		add(part({Size = Vector3.new(0.11 * u, 0.11 * u, 2 * math.pi * R / n * 1.08), Color = BRASS, Material = Enum.Material.Metal}),
			CFrame.new(math.cos(a) * R, 0, math.sin(a) * R) * CFrame.Angles(0, -a, 0))
	end
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		add(part({Size = Vector3.new(0.12, 0.03, 0.05) * u, Color = DARK, Material = Enum.Material.Metal}),
			CFrame.new(math.cos(a) * 0.35 * u, 0, math.sin(a) * 0.35 * u) * CFrame.Angles(0, -a, 0))
	end
	local rotor = part({Size = Vector3.new(0.62, 0.016, 0.08) * u, Color = DSTEEL, Material = Enum.Material.Metal, Parent = m})
	add(part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.16, 0.16) * u, Color = GREEN}),
		CFrame.new(0, -0.01 * u, -0.3 * u) * CFrame.Angles(0, math.rad(90), 0))
	add(part({Size = Vector3.new(0.04, 0.26, 0.36) * u, Color = BRASS, Material = Enum.Material.Metal}),
		CFrame.new(0, 0.19 * u, 0.34 * u) * CFrame.Angles(math.rad(-30), 0, 0))
	local halo = ball(cfg("menderHalo") * k, HEAL, Enum.Material.Neon, cfg("menderHaloT"))
	halo.Name, halo.Parent = "Halo", m
	local inner = ball(cfg("menderHalo") * k * 0.66, HEAL, Enum.Material.Neon, 0.9)
	inner.Parent = m
	light(puck, GREEN, 14 * k, 3)
	local tr = trail(puck, GREEN, cfg("menderTrailW") * k)
	tr.Transparency = NumberSequence.new(0.1, 1)
	local drip = Instance.new("ParticleEmitter")
	drip.Texture, drip.Color, drip.LightEmission = SPARK_TEX, ColorSequence.new(GREEN), 1
	drip.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4 * k), NumberSequenceKeypoint.new(1, 0.1 * k)})
	drip.Transparency = NumberSequence.new(0, 1)
	drip.Speed, drip.SpreadAngle, drip.EmissionDirection = NumberRange.new(3 * k), Vector2.new(25, 25), Enum.NormalId.Bottom
	drip.Lifetime, drip.Rate = NumberRange.new(0.4), 18
	drip.Parent = halo
	m.Parent = folder
	local function place(cf, t)
		for _, e in ipairs(list) do e.p.CFrame = cf * e.off end
		rotor.CFrame = cf * CFrame.new(0, -0.05 * u, 0) * CFrame.Angles(0, t * 40, 0)
		halo.CFrame, inner.CFrame = CFrame.new(cf.Position), CFrame.new(cf.Position)
	end
	return m, place
end
local function menderStart(char, at)
	if not on("omender") then return end
	diag("omender", "windup")
	local s = char:GetScale()
	local k = s / 2
	local look2 = lookOn("mender") -- v1.2
	local carry = pieces(char, "omender", {carry = true})
	windupGlow(carry, GREEN, cfg("menderWindup"), char)
	if look2 then -- v1.2: the dock halo (mockup glowAt 3.5)
		local hb = ball(3.5 * k, GREEN, Enum.Material.Neon, 0.82)
		hb.CFrame = CFrame.new(centre(carry, char))
		fade(hb, cfg("menderWindup") + 0.2)
	end
	delayTo(at + cfg("menderWindup"), function()
		if not char.Parent or char:GetAttribute("TrooMenderAt") ~= at then return end
		diag("omender", "action")
		local old = drones[char]
		if old then old.model:Destroy() end
		hide(carry, true)
		local m, place
		if look2 then m, place = makeDrone2(s) else m, place = makeDrone(s) end
		local st = {model = m, place = place, carry = carry, from = centre(carry, char), fromT = os.clock(),
			dur = math.max(0.1, (num(char:GetAttribute("TrooMenderArriveAt")) or (now() + cfg("menderFly"))) - now()),
			target = findModel(char:GetAttribute("TrooMenderTarget")) or char, mode = "fly", nextTick = 0, nextRing = 0, look2 = look2}
		drones[char] = st
		if look2 then -- v1.2: lift-off flash + orb
			flashBall(st.from, GREEN, 1, 5 * k, 0.3)
			orb(st.from, 2.5 * k, GREEN_L, 0.3)
		end
		local lastPos, yaw = st.from, 0
		local function place2(pos, t)
			if look2 then
				local v = pos - lastPos
				if Vector3.new(v.X, 0, v.Z).Magnitude > 1e-3 then yaw = math.atan2(-v.X, -v.Z) end
				lastPos = pos
				place(CFrame.new(pos) * CFrame.fromEulerAnglesYXZ(0.15, yaw, 0), t)
			end
		end
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if drones[char] ~= st or not m.Parent then conn:Disconnect() if st.tether then st.tether:Destroy() end return end
			local t = os.clock()
			local tr = rootOf(st.target)
			local orbitPos
			if look2 then
				orbitPos = tr and (tr.Position + Vector3.new(math.cos(t * 2.6) * cfg("menderOrbitR") * k,
					(cfg("menderOrbitUp") + math.sin(t * 5) * 0.4) * k, math.sin(t * 2.6) * cfg("menderOrbitR") * k)) or st.from
			else
				orbitPos = tr and (tr.Position + Vector3.new(math.cos(t * 2.2) * cfg("menderOrbit") * s / 2, 4 * s / 2,
					math.sin(t * 2.2) * cfg("menderOrbit") * s / 2)) or st.from
			end
			if st.mode == "fly" or st.mode == "back" then
				local goal = st.mode == "back" and centre(carry, char) or orbitPos
				local u = math.min(1, (t - st.fromT) / st.dur)
				local pos = st.from:Lerp(goal, u) + Vector3.new(0, 3 * u * (1 - u) * s / 2, 0)
				if look2 then place2(pos, t) else place(CFrame.lookAt(pos, goal + Vector3.new(0, 0.01, 0)), t) end
				if u >= 1 then
					if st.mode == "back" then
						conn:Disconnect()
						drones[char] = nil
						m:Destroy()
						hide(carry, false)
						burst(goal, GREEN_L, 12, 4, 0.4, 0.5)
						if look2 then flashBall(goal, GREEN, 1, 4 * k, 0.3) end -- v1.2
						diag("omender", "recovery")
						return
					end
					st.mode = "orbit"
					diag("omender", "result")
				end
			elseif look2 then -- v1.2: orbit with the tether + heal pulses
				place2(orbitPos, t)
				if tr then
					if not st.tether or st.tetherTo ~= tr then
						if st.tether then st.tether:Destroy() end
						local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
						a0.Parent, a1.Parent = m.Shell, tr
						local bm = Instance.new("Beam")
						bm.Attachment0, bm.Attachment1 = a0, a1
						bm.Color, bm.LightEmission, bm.FaceCamera = ColorSequence.new(GREEN_L, GREEN), 1, true
						bm.Width0, bm.Width1 = cfg("menderTether") * k, cfg("menderTether") * k
						bm.Parent = m.Shell
						a1:SetAttribute("TrooMenderTether", true)
						bm.Destroying:Connect(function() a1:Destroy() end)
						st.tether, st.tetherTo = bm, tr
					end
					st.tether.Transparency = NumberSequence.new(1 - (0.5 + 0.15 * math.sin(t * 30)))
					if t >= st.nextTick then
						st.nextTick = t + cfg("menderPulse")
						local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
						a0.Parent, a1.Parent = m.Shell, tr
						local bm = Instance.new("Beam")
						bm.Attachment0, bm.Attachment1 = a0, a1
						bm.Color, bm.LightEmission, bm.FaceCamera = ColorSequence.new(GREEN_L, GREEN), 1, true
						bm.Width0, bm.Width1 = 0.44 * k, 1.2 * k
						bm.Transparency = NumberSequence.new(0.4)
						bm.Parent = m.Shell
						burst(tr.Position, GREEN_L, 8, 5, 0.5 * k, 0.5)
						task.spawn(function()
							local t0 = os.clock()
							while os.clock() - t0 < 0.3 and bm.Parent do
								bm.Transparency = NumberSequence.new(0.4 + 0.6 * (os.clock() - t0) / 0.3)
								RunService.Heartbeat:Wait()
							end
							bm:Destroy() a0:Destroy() a1:Destroy()
						end)
					end
					if t >= st.nextRing then
						st.nextRing = t + 1
						groundRing(tr.Position - Vector3.new(0, 3 * s / 2, 0), GREEN, 1.5 * s / 2, 5 * s / 2, 0.6)
					end
				end
			else
				place(CFrame.lookAt(orbitPos, tr and tr.Position or orbitPos + Vector3.zAxis), t)
				if tr and t >= st.nextTick then
					st.nextTick = t + cfg("menderTick")
					local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
					a0.Parent, a1.Parent = m.Shell, tr
					local bm = Instance.new("Beam")
					bm.Attachment0, bm.Attachment1 = a0, a1
					bm.Color, bm.LightEmission, bm.FaceCamera = ColorSequence.new(GREEN_L, GREEN), 1, true
					bm.Width0, bm.Width1 = 0.3, 0.6
					bm.Parent = m.Shell
					task.delay(0.3, function() bm:Destroy() a0:Destroy() a1:Destroy() end)
				end
				if tr and t >= st.nextRing then
					st.nextRing = t + 1
					local g = tr.Position - Vector3.new(0, 3 * s / 2, 0)
					groundRing(g, GREEN, 1.5 * s / 2, 5 * s / 2, 0.6)
				end
			end
		end)
	end)
end
local function menderHop(char)
	local st = drones[char]
	if not st then return end
	local nt = findModel(char:GetAttribute("TrooMenderHopTo"))
	if not nt then return end
	st.from = st.model.Shell.Position
	st.fromT, st.dur, st.target, st.mode = os.clock(), 0.5, nt, "fly"
	if st.tether then st.tether:Destroy() st.tether, st.tetherTo = nil, nil end -- v1.2
	diag("omender", "hop")
end
local function menderEnd(char)
	local st = drones[char]
	if not st then return end
	st.from = st.model.Shell.Position
	st.fromT, st.dur, st.mode = os.clock(), cfg("menderBack"), "back"
	if st.tether then st.tether:Destroy() st.tether, st.tetherTo = nil, nil end -- v1.2
end

-- Arc Lantern ------------------------------------------------------------------------------------------------------------
local lanterns = {} -- [char] = {model core, lastZap, names}
local function lanternStart(char, at)
	if not on("olantern") then return end
	diag("olantern", "windup")
	local s = char:GetScale()
	local carry = pieces(char, "olantern", {carry = true})
	windupGlow(carry, VOLT, cfg("lanternWindup"), char)
	if lookOn("zap") then -- v1.1: 4 tiny arcs round the hip lantern
		local k0 = char:GetScale() / 2
		for i = 0, 3 do
			task.delay(i * 0.09, function()
				local q = function() return centre(carry, char) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6 * k0 end
				zap2(q, q, 0.08, k0, true)
			end)
		end
	end
	delayTo(at + cfg("lanternWindup"), function()
		if not char.Parent or char:GetAttribute("TrooLanternAt") ~= at then return end
		diag("olantern", "action")
		hide(carry, true)
		local old = lanterns[char]
		if old and old.core.Parent then old.core:Destroy() end
		local core = ball(0.9 * s / 2, VOLT)
		local shell = ball(1.5 * s / 2, CORE, Enum.Material.Glass, 0.45)
		local cap = part({Size = Vector3.new(0.9, 0.3, 0.9) * s / 2, Color = BRASS, Material = Enum.Material.Metal})
		local l = light(core, VOLT, 10, 2)
		trail(core, VOLT, 0.5 * s / 2)
		local st = {core = core, light = l, at = at, lastZap = 0, names = {}, carry = carry}
		lanterns[char] = st
		local from = centre(carry, char)
		local to = char:GetAttribute("TrooLanternTo")
		if typeof(to) ~= "Vector3" then to = from end
		to += Vector3.new(0, 0.8 * s / 2, 0)
		local follow = RunService.Heartbeat:Connect(function()
			if core.Parent then
				shell.CFrame = core.CFrame
				cap.CFrame = core.CFrame * CFrame.new(0, 0.8 * s / 2, 0)
			end
		end)
		local function finish()
			follow:Disconnect()
			fade(core, 0.4) fade(shell, 0.4) fade(cap, 0.4)
			if lanterns[char] == st then lanterns[char] = nil end
			hide(carry, false)
			diag("olantern", "recovery")
		end
		local flight = num(char:GetAttribute("TrooLanternFlight")) or 0.55
		local endFn = to -- v1.3: home on the tracked target
		local trk = script:GetAttribute("TrooPartsFX_lanternTrackEnabled") ~= false and rootOf(findModel(char:GetAttribute("TrooLanternTrack"))) or nil
		if trk then
			local y = to.Y
			endFn = function()
				if trk.Parent then to = Vector3.new(trk.Position.X, y, trk.Position.Z) end
				return to
			end
		end
		arcFly(core, from, endFn, flight, cfg("lanternArc") * s / 2, function()
			diag("olantern", "result")
			core.CFrame = CFrame.new(to)
			TweenService:Create(shell, TweenInfo.new(0.25), {Transparency = 0.8}):Play()
			TweenService:Create(l, TweenInfo.new(0.25), {Range = 18, Brightness = 4}):Play()
			burst(to, VOLT, 14, 6, 0.4, 0.4)
			if lookOn("zap") then -- v1.1: the mockup's landing: orb 4, ground ring 16, 3 short arcs from the lantern
				local k0 = s / 2
				orb(to, 8 * k0, VOLT, 0.3)
				groundRing(to - Vector3.new(0, 0.8 * k0, 0), VOLT, 2 * k0, 16 * k0, 0.5)
				for i = 0, 2 do
					task.delay(0.12 + i * 0.06, function()
						local q = function() return to + Vector3.new((math.random() - 0.5) * 4, 1 + math.random() * 2, (math.random() - 0.5) * 4) * k0 end
						zap2(function() return core.Parent and core.Position + Vector3.new(0, 1.5 * k0, 0) or to end, q, 0.1, k0, true)
					end)
				end
			end
			st.lastZap = os.clock()
			task.spawn(function()
				while core.Parent and os.clock() - st.lastZap < cfg("lanternLinger") + (st.names[1] and 0 or 0.6) do
					l.Brightness = 3 + math.random() * 2
					task.wait(0.05)
				end
				finish()
			end)
		end)
	end)
end
-- v1.6: the loud lantern (see the header)
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local function loudOn() return script:GetAttribute("TrooPartsFX_lanternLoudEnabled") ~= false end
local function loudBolt(fromFn, toFn, k0)
	local t0 = os.clock()
	local travel = math.max(0.01, cfg("lanternBoltTravel"))
	local headFn = function()
		local a, b = fromFn(), toFn()
		if not (a and b) then return nil end
		return a:Lerp(b, math.min(1, (os.clock() - t0) / travel))
	end
	zap2(fromFn, headFn, cfg("lanternBoltLife"), k0, false, cfg("lanternBoltMul"))
	for i = 1, math.floor(cfg("lanternForks")) do
		task.delay(travel + (i - 1) * 0.05, function()
			local a, b = fromFn(), toFn()
			if not (a and b) then return end
			local p = a:Lerp(b, 0.2 + 0.6 * math.random())
			local e = p + Vector3.new((math.random() - 0.5) * 8, 2 + math.random() * 5, (math.random() - 0.5) * 8) * k0
			zap2(p, e, cfg("lanternBoltLife") * 0.5, k0, true, 1.4)
		end)
	end
end
local function hitFlash(model)
	if not model then return end
	local h = Instance.new("Highlight")
	h.Name = "TrooLanternFlash"
	h.Adornee = model
	h.FillColor, h.OutlineColor = Color3.new(1, 1, 1), Color3.new(1, 1, 1)
	h.FillTransparency, h.OutlineTransparency = 0, 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = folder
	TweenService:Create(h, TweenInfo.new(cfg("lanternFlashTime")), {FillTransparency = 1, OutlineTransparency = 1}):Play()
	Debris:AddItem(h, cfg("lanternFlashTime") + 0.05)
end
local function shockMark(model, stunEnd)
	script:SetAttribute("TrooPartsFXShockMarks", (script:GetAttribute("TrooPartsFXShockMarks") or 0) + 1)
	local root = rootOf(model)
	local h = Instance.new("Highlight")
	h.Name = "TrooLanternShocked"
	h.Adornee = model
	h.FillColor, h.OutlineColor = VOLT, VOLT
	h.FillTransparency, h.OutlineTransparency = 0.82, 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Name = "TrooLanternShockedTag"
	bb.Adornee = root
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(124, 30)
	bb.MaxDistance = cfg("shockTagMax")
	bb.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y * 0.5 + cfg("shockTagUp"), 0) -- above the name / health tag
	bb.ResetOnSpawn = false
	bb.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or folder -- a BillboardGui draws from PlayerGui (Adornee = the root)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(13, 18, 24)
	panel.BackgroundTransparency = 0.15
	panel.Parent = bb
	local st = Instance.new("UIStroke")
	st.Color, st.Thickness = VOLT, 2
	st.Parent = panel
	local lb = Instance.new("TextLabel")
	lb:SetAttribute("FontSwap", "keep")
	lb.BackgroundTransparency = 1
	lb.Size = UDim2.new(1, 0, 1, -5)
	lb.FontFace = SILK
	lb.TextSize = 15
	lb.TextColor3 = VOLT
	lb.Text = "⚡ SHOCKED"
	lb.Parent = panel
	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = VOLT
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, 4)
	bar.Parent = panel
	local startT, endT = now(), stunEnd()
	local span = math.max(0.05, endT - startT)
	return {
		tick = function()
			h.OutlineTransparency = math.random() * 0.45
			h.FillTransparency = 0.72 + math.random() * 0.2
			bar.Size = UDim2.new(math.clamp((stunEnd() - now()) / span, 0, 1), 0, 0, 4)
		end,
		stop = function()
			h:Destroy()
			bb:Destroy()
		end,
	}
end
local function bodyParts(model) -- v1.5: the visible body (no root, hitboxes or see-through parts)
	local hb = model:FindFirstChild("Hitboxes")
	local out = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.9 and d.Size.Magnitude > 0.3
			and not (hb and d:IsDescendantOf(hb)) then table.insert(out, d) end
	end
	return out
end
local function shockLook(model, root) -- v1.5 (MDA-377): the Shock Cannon hit look + body arcs while the stun lasts
	script:SetAttribute("TrooPartsFXShocks", (script:GetAttribute("TrooPartsFXShocks") or 0) + 1)
	local b = ball(2, VOLT) -- ScreechServer burst(pos, 10, VOLT)
	b.CFrame = CFrame.new(root.Position)
	b.Transparency = 0.2
	TweenService:Create(b, TweenInfo.new(0.3), {Size = Vector3.one * 10, Transparency = 1}):Play()
	Debris:AddItem(b, 0.35)
	task.spawn(function()
		local function stunEnd()
			local su, lu = num(model:GetAttribute("StunnedUntil")) or 0, num(model:GetAttribute("TrooLanternStunUntil"))
			return lu and math.min(su, lu) or su
		end
		local t0 = os.clock()
		while stunEnd() <= now() do -- the stun may replicate a frame after the zap stamp
			if os.clock() - t0 > cfg("shockWait") or not root.Parent then return end
			RunService.Heartbeat:Wait()
		end
		local parts = bodyParts(model)
		local size = model:GetExtentsSize()
		local k = math.clamp(size.Magnitude / 25, 0.35, 1.6)
		local pe = Instance.new("ParticleEmitter") -- ScreechServer ShockStunSparks
		pe.Name = "TrooLanternShockSparks"
		pe.Color = ColorSequence.new(CORE, VOLT)
		pe.LightEmission = 1
		pe.Rate = 70
		pe.Lifetime = NumberRange.new(0.15, 0.35)
		pe.Speed = NumberRange.new(8, 16)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.7, 0)
		pe.Parent = root
		local li = Instance.new("PointLight") -- ScreechServer ShockStunLight
		li.Name = "TrooLanternShockLight"
		li.Color, li.Range, li.Brightness = VOLT, 14, 3
		li.Parent = root
		local function pointOn(p) -- a random point on the part's surface, riding the part
			local h = p.Size / 2
			local o = Vector3.new((math.random() * 2 - 1) * h.X, (math.random() * 2 - 1) * h.Y, (math.random() * 2 - 1) * h.Z)
			local ax = math.random(3)
			local sgn = math.random() < 0.5 and -1 or 1
			if ax == 1 then o = Vector3.new(sgn * h.X, o.Y, o.Z) elseif ax == 2 then o = Vector3.new(o.X, sgn * h.Y, o.Z) else o = Vector3.new(o.X, o.Y, sgn * h.Z) end
			return function() return p.Parent and (p.CFrame * o) or nil end
		end
		local mark = loudOn() and shockMark(model, stunEnd) or nil -- v1.6
		local acc, last = 0, os.clock()
		while root.Parent and now() < stunEnd() and #parts > 0 and script:GetAttribute("TrooPartsFX_lanternShockEnabled") ~= false do
			if mark then mark.tick() end -- v1.6
			local t = os.clock()
			acc += (t - last) * cfg("shockArcRate")
			last = t
			while acc >= 1 do
				acc -= 1
				local pa = parts[math.random(#parts)]
				local near = {}
				for _, q in ipairs(parts) do
					if q ~= pa and (q.Position - pa.Position).Magnitude <= 5 * k + pa.Size.Magnitude / 2 then table.insert(near, q) end
				end
				local pb = near[1] and near[math.random(#near)] or pa
				zap2(pointOn(pa), pointOn(pb), cfg("shockArcLife") * (0.7 + math.random() * 0.6), k, true)
			end
			RunService.Heartbeat:Wait()
		end
		if mark then mark.stop() end -- v1.6
		pe.Enabled = false
		Debris:AddItem(pe, 0.4)
		TweenService:Create(li, TweenInfo.new(0.15), {Brightness = 0}):Play()
		Debris:AddItem(li, 0.2)
		diag("olantern", "shockEnd")
	end)
end
local function lanternZap(char)
	local st = lanterns[char]
	if not on("olantern") then return end
	local list = string.split(tostring(char:GetAttribute("TrooLanternChainList") or ""), "|")
	local name = list[#list]
	local tgt = findModel(name)
	local tr = rootOf(tgt)
	if not tr then return end
	local prev = list[#list - 1] and rootOf(findModel(list[#list - 1]))
	local fromFn = function()
		if prev and prev.Parent then return prev.Position end
		if st and st.core.Parent then return st.core.Position end
		return nil
	end
	if lookOn("zap") then -- v1.1: the mockup's chain zap + MineBurst-style orb, flash, crackle, sparks
		local k0 = char:GetScale() / 2
		if loudOn() then -- v1.6: heavy travelling bolt + forks + white flash
			loudBolt(fromFn, function() return tr.Parent and tr.Position or nil end, k0)
			hitFlash(tgt)
		else
			zap2(fromFn, function() return tr.Parent and tr.Position or nil end, cfg("zapLife"), k0, false)
		end
		orb(tr.Position, 12 * k0, VOLT, 0.35)
		flashBall(tr.Position, CORE, 2 * k0, 6 * k0, 0.16)
		crackle(function() return tr.Parent and tr.Position or nil end, math.max(0.45, cfg("zapLife") + 0.13), k0)
		burst(tr.Position, Color3.fromHex("C8F8FF"), 10, 10, 0.35, 0.6)
	else
		zapArc(fromFn, function() return tr.Parent and tr.Position or nil end, 0.3)
		flashBall(tr.Position, VOLT, 1.5, 5, 0.3)
		burst(tr.Position, CORE, 16, 10, 0.35, 0.4)
	end
	if script:GetAttribute("TrooPartsFX_lanternShockEnabled") ~= false then shockLook(tgt, tr) end -- v1.5 (MDA-377)
	if st then
		st.lastZap = os.clock()
		table.insert(st.names, name)
	end
	diag("olantern", "zap")
end

-- Sap Wall ---------------------------------------------------------------------------------------------------------------
local function sapStart(char, at)
	if not on("osapwall") then return end
	diag("osapwall", "windup")
	local s = char:GetScale()
	local carry = pieces(char, "osapwall", {carry = true})
	windupGlow(carry, AMBER, cfg("sapWindup"), char)
	delayTo(at + cfg("sapWindup"), function()
		if not char.Parent or char:GetAttribute("TrooSapAt") ~= at then return end
		diag("osapwall", "action")
		hide(carry, true)
		local pod = ball(1.1 * s / 2, AMBER)
		light(pod, AMBER, 8, 2)
		trail(pod, EMBER, 0.6 * s / 2)
		local from = centre(carry, char)
		local to = char:GetAttribute("TrooSapTo")
		if typeof(to) ~= "Vector3" then to = from end
		arcFly(pod, from, to + Vector3.new(0, 0.5, 0), num(char:GetAttribute("TrooSapFlight")) or 0.5, cfg("sapArc") * s / 2, function()
			diag("osapwall", "result")
			flashBall(to + Vector3.new(0, 1, 0), FLASH, 2 * s / 2, 9 * s / 2, 0.35)
			groundRing(to, AMBER, 2 * s / 2, 10 * s / 2, 0.45)
			burst(to + Vector3.new(0, 1, 0), EMBER, 24, 12, 0.5, 0.7)
			pod:Destroy()
		end)
		delayTo(at + cfg("sapReturn"), function() hide(carry, false) end)
	end)
end
local function watchWall2(m) -- v1.1: the mockup's sap wall (rise, wet -> set, rim, sweep, shake, crumble)
	local parts = {}
	for _, p in ipairs(m:GetChildren()) do if p:IsA("BasePart") then table.insert(parts, p) end end
	if #parts == 0 then return end
	local owner = workspace:FindFirstChild(tostring(m:GetAttribute("SapWallOwner") or ""))
	local k = (owner and owner:IsA("Model")) and owner:GetScale() / 2 or 1
	local t0 = os.clock()
	local untilT = num(m:GetAttribute("SapWallUntil"))
	-- the wall's frame: the parts share one frame (X along, Z across)
	local cf0 = parts[1].CFrame
	local lo, hi, bottom, top = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(parts) do
		local q = cf0:PointToObjectSpace(p.Position)
		lo, hi = math.min(lo, q.X - p.Size.X / 2), math.max(hi, q.X + p.Size.X / 2)
		local b = (p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0)).Position
		bottom = math.min(bottom, cf0:PointToObjectSpace(b).Y)
		top = math.max(top, cf0:PointToObjectSpace(p.Position).Y + p.Size.Y / 2)
	end
	local width, H = hi - lo, top - bottom
	local base = cf0 * CFrame.new((lo + hi) / 2, bottom, 0) -- ground centre, wall frame
	local slabs = {}
	for _, p in ipairs(parts) do
		p.LocalTransparencyModifier = 1
		local foot = p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0)
		local sl = part({Size = Vector3.new(p.Size.X, 0.05, p.Size.Z), CFrame = foot * CFrame.new(0, 0.025, 0), Color = WARM,
			Material = Enum.Material.SmoothPlastic, Transparency = cfg("sapWetT")})
		local core = part({Size = Vector3.new(p.Size.X * 0.86, 0.05, p.Size.Z * 0.5), CFrame = sl.CFrame, Color = AMBER, Transparency = 0.55})
		table.insert(slabs, {p = p, sl = sl, core = core, foot = foot, size = p.Size})
		p:GetAttributeChangedSignal("WallBlockedAt"):Connect(function()
			local pos = p:GetAttribute("WallBlockedPos")
			if typeof(pos) == "Vector3" and on("osapwall") then
				flashBall(pos, FLASH, 1, 6 * k, 0.25)
				burst(pos, EMBER, 12, 8, 0.35, 0.4)
				diag("osapwall", "blocked")
			end
		end)
	end
	local rim = part({Size = Vector3.new(width * 1.02, 0.5 * k, (parts[1].Size.Z) * 1.17), CFrame = base * CFrame.new(0, 0.25 * k, 0), Color = FLASH})
	light(rim, AMBER, math.max(12, width * 0.4), 1.5)
	-- the splat on the wall's line
	local g = base.Position
	groundRing(g, Color3.fromHex("FFD27A"), 1 * k, width * 0.58, 0.45)
	flashBall(g + Vector3.new(0, 1 * k, 0), FLASH, 2 * k, 12 * k, 0.16)
	rising(function() return (base * CFrame.new((math.random() - 0.5) * width * 0.95, math.random() * H * 0.7, 0)).Position end, MOTE, 0.8, 30, 0.5 * k)
	local swept = false
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not m.Parent then conn:Disconnect() return end
		local t = os.clock() - t0
		local u = math.clamp(t / math.max(0.01, cfg("sapRise")), 0, 1)
		local c1, c3 = 1.70158, 2.70158
		local grow = math.max(0.01, 1 + c3 * (u - 1) ^ 3 + c1 * (u - 1) ^ 2) -- back-out (the mockup's E.back)
		local hd = math.clamp((t - cfg("sapHardenFrom")) / math.max(0.01, cfg("sapHarden") - cfg("sapHardenFrom")), 0, 1)
		local shake = 0
		if untilT and untilT - now() < 0.5 then shake = math.sin(t * 70) * 0.08 * k end
		for _, e in ipairs(slabs) do
			local h = math.max(0.05, e.size.Y * grow)
			e.sl.Size = Vector3.new(e.size.X, h, e.size.Z)
			e.sl.CFrame = e.foot * CFrame.new(shake, h / 2, 0)
			e.core.Size = Vector3.new(e.size.X * 0.86, math.max(0.05, h * 0.9), e.size.Z * 0.5)
			e.core.CFrame = e.sl.CFrame
			e.sl.Transparency = cfg("sapWetT") + (cfg("sapHardT") - cfg("sapWetT")) * hd
			e.sl.Color = hd > 0.5 and SET or WARM
			e.core.Transparency = 0.55 + 0.45 * hd
		end
		if not swept and t >= cfg("sapHarden") then
			swept = true
			diag("osapwall", "set")
			local sw = part({Size = Vector3.new(1.2 * k, H * 0.55, 0.1), Color = Color3.new(1, 1, 1), Transparency = 0.3})
			local face = base * CFrame.new(0, H * 0.5, -(parts[1].Size.Z / 2 + 0.15))
			local s0 = os.clock()
			local sc
			sc = RunService.Heartbeat:Connect(function()
				local v = math.clamp((os.clock() - s0) / 0.45, 0, 1)
				sw.CFrame = face * CFrame.new(-width / 2 + width * v, 0, 0)
				sw.Transparency = 1 - 0.7 * math.sin(math.pi * v)
				if v >= 1 then sc:Disconnect() sw:Destroy() end
			end)
		end
	end)
	m.AncestryChanged:Connect(function(_, parent)
		if parent then return end
		conn:Disconnect()
		fade(rim, 0.3)
		for _, e in ipairs(slabs) do
			e.core:Destroy()
			local c = e.sl
			local v = Vector3.new((math.random() - 0.5) * 6, 4 + math.random() * 6, (math.random() - 0.5) * 6) * k
			local c0, cf, s1 = os.clock(), c.CFrame, c.Size
			local cc
			cc = RunService.Heartbeat:Connect(function(dt)
				local uu = (os.clock() - c0) / 0.6
				if uu >= 1 or not c.Parent then cc:Disconnect() c:Destroy() return end
				v += Vector3.new(0, -30 * k * dt, 0)
				cf = (cf + v * dt) * CFrame.Angles(dt * 2, 0, 0)
				c.CFrame, c.Size, c.Transparency = cf, s1 * (1 - uu * 0.8), 1 - (1 - cfg("sapHardT")) * 0.8 * (1 - uu)
			end)
		end
		for i = 0, 7 do
			local q = (base * CFrame.new(-width * 0.42 + i * width * 0.12, (1 + math.random() * 3) * k, 0)).Position
			local d = part({Shape = Enum.PartType.Ball, Size = Vector3.one * 3 * k, CFrame = CFrame.new(q), Color = DUST, Material = Enum.Material.SmoothPlastic, Transparency = 0.5})
			TweenService:Create(d, TweenInfo.new(0.9), {CFrame = CFrame.new(q + Vector3.new(0, 2 * k, 0)), Size = Vector3.one * 5 * k, Transparency = 1}):Play()
			Debris:AddItem(d, 0.95)
		end
		burst((base * CFrame.new(0, 4 * k, 0)).Position, MOTE, 14, 10, 0.4, 0.6)
		diag("osapwall", "recovery")
	end)
end
local function watchWall(m)
	if not (m:IsA("Model") and m.Name == "SapWall") or not on("osapwall") then return end
	if lookOn("sap") then watchWall2(m) return end -- v1.1
	local segs = {}
	local rims = {}
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(segs, {cf = p.CFrame, size = p.Size})
			local wet = part({Size = p.Size * 1.03, CFrame = p.CFrame, Color = FLASH, Material = Enum.Material.Glass, Transparency = 0.45})
			TweenService:Create(wet, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {Transparency = 1}):Play()
			Debris:AddItem(wet, 0.85)
			local rim = part({Size = Vector3.new(p.Size.X, 0.35, p.Size.Z + 0.3), Color = AMBER,
				CFrame = p.CFrame * CFrame.new(0, -p.Size.Y / 2 + 0.2, 0)})
			light(rim, AMBER, 6, 1)
			table.insert(rims, rim)
			p:GetAttributeChangedSignal("WallBlockedAt"):Connect(function()
				local pos = p:GetAttribute("WallBlockedPos")
				if typeof(pos) == "Vector3" and on("osapwall") then
					flashBall(pos, FLASH, 1, 4, 0.25)
					burst(pos, EMBER, 12, 8, 0.35, 0.4)
					diag("osapwall", "blocked")
				end
			end)
		end
	end
	m.AncestryChanged:Connect(function(_, parent)
		if parent then return end
		for _, r in ipairs(rims) do fade(r, 0.3) end
		for _, sg in ipairs(segs) do
			for i = 1, 3 do
				local c = part({Size = Vector3.new(sg.size.X / 3, sg.size.Y / 4, sg.size.Z), Color = AMBER, Material = Enum.Material.Glass,
					Transparency = 0.3, CFrame = sg.cf * CFrame.new((i - 2) * sg.size.X / 3, sg.size.Y * (0.35 - i * 0.12), 0)})
				local goal = c.CFrame * CFrame.new(0, -sg.size.Y * 0.4, 0) * CFrame.Angles(math.random() - 0.5, 0, math.random() - 0.5)
				TweenService:Create(c, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = goal, Transparency = 1}):Play()
				Debris:AddItem(c, 0.65)
			end
		end
		diag("osapwall", "recovery")
	end)
end

-- Feather Shed -----------------------------------------------------------------------------------------------------------
local function shedStart(char, at)
	if not on("oshed") then return end
	diag("oshed", "windup")
	local s = char:GetScale()
	local plates = pieces(char, "oshed", {shed = true})
	local root = rootOf(char)
	if root then
		local l = light(root, Color3.new(1, 1, 1), 12, 5)
		Debris:AddItem(l, cfg("shedWindup") + 0.05)
	end
	for _, p in ipairs(plates) do burst(p.Position, Color3.new(1, 1, 1), 3, 2, 0.3, 0.2) end
	delayTo(at + cfg("shedWindup"), function()
		if not char.Parent or char:GetAttribute("TrooShedAt") ~= at then return end
		diag("oshed", "action")
		local r = rootOf(char)
		local c = r and r.Position or char:GetPivot().Position
		for _, p in ipairs(plates) do
			local cl = part({Size = p.Size, CFrame = p.CFrame, Color = p.Color, Material = p.Material, Shape = p.Shape})
			local dir = (p.Position - c)
			dir = (dir.Magnitude > 1e-3 and dir.Unit or Vector3.yAxis) + Vector3.new(0, 0.8, 0)
			local goal = p.CFrame + dir * 6 * s / 2
			TweenService:Create(cl, TweenInfo.new(cfg("shedFling"), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{CFrame = goal * CFrame.Angles(math.random() * 4, math.random() * 4, 0), Transparency = 1}):Play()
			Debris:AddItem(cl, cfg("shedFling") + 0.05)
		end
		hide(plates, true)
		burst(c, Color3.fromHex("FFF4DC"), 40, 18, 0.7, 0.9)
		burst(c, AMBER, 14, 12, 0.5, 0.6)
		local kr = tonumber(char:GetAttribute("TrooPartShedKnockRadius")) or 0
		groundRing(c - Vector3.new(0, 3 * s / 2, 0), Color3.new(1, 1, 1), 1.5 * s / 2, kr > 0 and kr or cfg("shedRadius") * s / 2, 0.35)
		local untilT = num(char:GetAttribute("TrooShedImmuneUntil")) or (now() + 1)
		local ext = char:GetExtentsSize()
		local shell = part({Shape = Enum.PartType.Ball, Size = Vector3.one * math.max(ext.X, ext.Y, ext.Z) * 0.8, Color = TEAL_L,
			Material = Enum.Material.ForceField, Transparency = 0.1})
		diag("oshed", "result")
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local rr = rootOf(char)
			if not rr or now() >= untilT or not shell.Parent then
				conn:Disconnect()
				fade(shell, 0.2)
				hide(plates, false)
				diag("oshed", "recovery")
				return
			end
			shell.CFrame = rr.CFrame
		end)
	end)
end

-- Portal Feathers --------------------------------------------------------------------------------------------------------
local portals = {} -- [char] = {rings}
local function makeRing(s)
	local m = Instance.new("Model")
	m.Name = "FeatherRing"
	local R = cfg("portalRing") * s / 2
	local blocks = {}
	for i = 1, 12 do
		local b = part({Size = Vector3.new(0.45, R * 0.56, 0.45) * Vector3.new(s / 2, 1, s / 2), Color = TEAL, Parent = m})
		table.insert(blocks, {p = b, a = (i - 1) / 12 * math.pi * 2, kind = "rim"})
	end
	for i = 1, 8 do
		local v = part({Size = Vector3.new(0.25, 0.9, 0.12) * s, Color = BRASS, Material = Enum.Material.Metal, Parent = m})
		table.insert(blocks, {p = v, a = (i - 1) / 8 * math.pi * 2, kind = "vane"})
	end
	local film = part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, R * 1.9, R * 1.9), Color = TEAL_L, Transparency = 0.6, Parent = m})
	light(film, TEAL, 14, 1.5)
	trail(film, TEAL, 0.6 * s / 2)
	m.Parent = folder
	local scaleK = 0.25
	local function place(cf, spin, k)
		scaleK = k or scaleK
		for _, b in ipairs(blocks) do
			local rr = (b.kind == "rim" and R or R * 1.25) * scaleK
			b.p.CFrame = cf * CFrame.Angles(0, 0, b.a + (b.kind == "vane" and spin * 0.3 or 0)) * CFrame.new(0, rr, 0)
		end
		film.Size = Vector3.new(0.1, R * 1.9 * scaleK, R * 1.9 * scaleK)
		film.CFrame = cf * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(spin, 0, 0)
	end
	return m, place, film
end
local function makeRing2(s) -- v1.1: the mockup's openPortal(): torus + 8 vanes + swirl film
	local k = s / 2
	local m = Instance.new("Model")
	m.Name = "FeatherRing"
	local R, tube, VR = cfg("portalRingR") * k, cfg("portalTube") * k, cfg("portalVaneR") * k
	local TEALG = Color3.fromHex("8FF7E6")
	local items = {}
	local NT = 28
	for i = 1, NT do
		local a = (i - 0.5) / NT * math.pi * 2
		local seg = part({Size = Vector3.new(2 * math.pi * R / NT * 1.12, tube * 2, tube * 2), Color = TEALG, Parent = m})
		table.insert(items, {p = seg, a = a, r = R, kind = "rim"})
	end
	for i = 1, 8 do
		local a = (i - 1) * math.pi / 4
		local v = part({Size = Vector3.new(0.3 * k, 1.5 * k, 0.5 * k), Color = BRASS, Material = Enum.Material.Metal, Parent = m})
		table.insert(items, {p = v, a = a, r = VR, kind = "vane"})
	end
	local film = part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, R * 1.9, R * 1.9), Color = TEAL, Transparency = 0.55, Parent = m})
	local mid = part({Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, R * 0.8, R * 0.8), Color = Color3.fromHex("DCFFFA"), Transparency = 0.4, Parent = m})
	local arcs = {}
	for j = 0, 3 do
		local rr = R * 0.95 * (14 + j * 12) / 64
		for n = 0, 5 do
			local a = j + 2.2 * n / 5
			local b = part({Size = Vector3.new(math.max(0.12, 2.2 / 5 * rr * 1.1), 0.18 * k, 0.12), Color = Color3.new(1, 1, 1), Transparency = 0.45, Parent = m})
			table.insert(arcs, {p = b, a = a, r = rr})
		end
	end
	local l = light(film, TEAL, 11 * k, 1.2)
	trail(film, TEAL, 0.6 * k)
	m.Parent = folder
	local scaleK = 0.05
	local function place(cf, spin, kk)
		scaleK = kk or scaleK
		local q = math.max(0.01, scaleK)
		for _, it in ipairs(items) do
			if it.kind == "rim" then
				it.p.CFrame = cf * CFrame.Angles(0, 0, it.a) * CFrame.new(0, it.r * q, 0)
				it.p.Size = Vector3.new(2 * math.pi * R / NT * 1.12 * q, tube * 2 * q, tube * 2 * q)
			else
				it.p.CFrame = cf * CFrame.Angles(0, 0, it.a) * CFrame.new(0, it.r * q, 0)
				it.p.Size = Vector3.new(0.3 * k, 1.5 * k, 0.5 * k) * q
			end
		end
		film.Size = Vector3.new(0.08, R * 1.9 * q, R * 1.9 * q)
		film.CFrame = cf * CFrame.Angles(0, math.rad(90), 0)
		mid.Size = Vector3.new(0.1, R * 0.8 * q, R * 0.8 * q)
		mid.CFrame = cf * CFrame.new(0, 0, -0.05) * CFrame.Angles(0, math.rad(90), 0)
		for _, e in ipairs(arcs) do
			e.p.CFrame = cf * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, 0, e.a + spin) * CFrame.new(0, e.r * q, 0)
			e.p.Size = Vector3.new(math.max(0.12, 2.2 / 5 * e.r * 1.1) * q, 0.18 * k * q, 0.12)
		end
		l.Range = 11 * k * q
	end
	return m, place, film
end
local function portalStart(char, at)
	if not on("oportal") then return end
	diag("oportal", "windup")
	local s = char:GetScale()
	local c1, c2 = pieces(char, "oportal", {carry1 = true}), pieces(char, "oportal", {carry2 = true})
	local both = {}
	for _, p in ipairs(c1) do table.insert(both, p) end
	for _, p in ipairs(c2) do table.insert(both, p) end
	windupGlow(both, TEAL, cfg("portalWindup2"), char)
	local old = portals[char]
	if old then for _, rg in ipairs(old.rings) do rg.m:Destroy() end end
	local st = {rings = {}, at = at, carry = both}
	portals[char] = st
	local function fling(carry, key, openKey, wind, fly)
		delayTo(at + wind, function()
			if portals[char] ~= st or not char.Parent then return end
			diag("oportal", "action")
			hide(carry, true)
			local spot = char:GetAttribute(key)
			if typeof(spot) ~= "Vector3" then return end
			local look2 = lookOn("portal") -- v1.1
			local m, place
			if look2 then m, place = makeRing2(s) else m, place = makeRing(s) end
			local rg = {m = m, place = place, k = look2 and 0.05 or 0.25, open = false, look2 = look2}
			table.insert(st.rings, rg)
			local from = centre(carry, char)
			local up = Vector3.new(0, (rg.look2 and cfg("portalCentre") or cfg("portalUp")) * s / 2, 0)
			local r0 = rootOf(char)
			local look = r0 and Vector3.new(r0.CFrame.LookVector.X, 0, r0.CFrame.LookVector.Z) or Vector3.zAxis
			look = look.Magnitude > 1e-3 and look.Unit or Vector3.zAxis
			local pA, pB = char:GetAttribute("TrooPortalA"), char:GetAttribute("TrooPortalB")
			if rg.look2 and typeof(pA) == "Vector3" and typeof(pB) == "Vector3" then -- v1.1: face along the A -> B line (walk through it)
				local dAB = Vector3.new(pB.X - pA.X, 0, pB.Z - pA.Z)
				if dAB.Magnitude > 1e-3 then look = dAB.Unit end
			end
			local t0 = os.clock()
			local conn
			local arcH = rg.look2 and ((key == "TrooPortalA" and 2.5 or 9) * s / 2) or 3 -- v1.1: the mockup's 2.5 / 9 flight arcs
			conn = RunService.Heartbeat:Connect(function()
				if not m.Parent then conn:Disconnect() return end
				local u = math.min(1, (os.clock() - t0) / fly)
				local pos = u < 1 and (from:Lerp(spot + up, u) + Vector3.new(0, 4 * arcH * u * (1 - u), 0)) or (spot + up)
				local openAt = num(char:GetAttribute(openKey))
				if not rg.open and openAt and openAt >= at and now() >= openAt then
					rg.open = true
					rg.openT = os.clock()
					if rg.look2 then -- v1.1: flash 10, orb 5, ground ring 7, motes from its foot
						flashBall(spot + up, Color3.fromHex("B8FFF0"), 2 * s / 2, 10 * s / 2, 0.16)
						orb(spot + up, 10 * s / 2, TEAL_L, 0.3)
						groundRing(spot, TEAL, 1 * s / 2, 7 * s / 2, 0.5)
						local untilT = num(char:GetAttribute("TrooPortalUntil")) or (now() + 6)
						rising(function() return m.Parent and (spot + Vector3.new((math.random() - 0.5) * 7, 0.2, (math.random() - 0.5) * 7) * s / 2) or nil end,
							TEAL_L, math.max(0.1, untilT - now()), 10, 0.5 * s / 2)
					else
						flashBall(spot + up, TEAL_L, 2 * s / 2, 8 * s / 2, 0.3)
						groundRing(spot, TEAL, 1 * s / 2, 7 * s / 2, 0.5)
					end
					diag("oportal", "result")
				end
				if rg.look2 then
					if rg.open then
						local v = math.clamp((os.clock() - rg.openT) / 0.3, 0, 1)
						rg.k = math.max(0.05, 1 + 2.70158 * (v - 1) ^ 3 + 1.70158 * (v - 1) ^ 2)
					else
						rg.k = 0.05 * (1 + 4 * u) -- the flung ring grows 1 -> 5 x on its arc
					end
					local face = u < 1 and CFrame.lookAt(pos, pos + look) * CFrame.Angles(0, (os.clock() - t0) * 12, 0) or CFrame.lookAt(pos, pos + look)
					place(face, os.clock() * 2, rg.k)
				else
					rg.k = rg.open and math.min(1, rg.k + 0.12) or 0.25
					place(CFrame.lookAt(pos, pos + look), os.clock() * 2.5, rg.k)
				end
			end)
		end)
	end
	fling(c1, "TrooPortalA", "TrooPortalOpenAt", cfg("portalWindup1"), cfg("portalFly1"))
	fling(c2, "TrooPortalB", "TrooPortalOpen2At", cfg("portalWindup2"), cfg("portalFly2"))
end
local function portalEnd(char)
	local st = portals[char]
	if not st then return end
	portals[char] = nil
	for _, rg in ipairs(st.rings) do
		if rg.look2 then -- v1.1: closing orb + sparks
			local c = rg.m:GetBoundingBox().Position
			orb(c, 8, TEAL_L, 0.3)
			burst(c, TEAL_L, 10, 8, 0.4, 0.6)
		end
		for _, p in ipairs(rg.m:GetDescendants()) do
			if p:IsA("BasePart") then fade(p, 0.4, p.Size * 0.3) end
		end
		Debris:AddItem(rg.m, 0.5)
	end
	hide(st.carry, false)
	diag("oportal", "recovery")
end
local function portalUsed(user)
	if not on("oportal") then return end
	local a, b = user:GetAttribute("TrooPortalFrom"), user:GetAttribute("TrooPortalTo")
	for _, p in ipairs({a, b}) do
		if typeof(p) == "Vector3" then
			flashBall(p + Vector3.new(0, 3, 0), TEAL_L, 2, 7, 0.3)
			burst(p + Vector3.new(0, 3, 0), TEAL, 20, 10, 0.5, 0.6)
		end
	end
	diag("oportal", "travel")
end

-- Portal Rift (v1.4, MDA-375; see the v1.4 notes) ------------------------------------------------------------------------
local rifts = {} -- [char] = {rings = {}, segs = {}, trail, emit, conns = {}, carry}
local function riftLook() return on("oportal") and script:GetAttribute("TrooPartsFX_riftLookEnabled") ~= false end
local function standRing(spot, look, s) -- the picked Tail Rings ring (makeRing2) standing at an end, opening with a flash
	local m, place = makeRing2(s)
	local pos = spot + Vector3.new(0, cfg("portalCentre") * s / 2, 0)
	look = (look and look.Magnitude > 1e-3) and look.Unit or Vector3.zAxis
	local t0 = os.clock()
	flashBall(pos, Color3.fromHex("B8FFF0"), 2 * s / 2, 10 * s / 2, 0.16)
	orb(pos, 10 * s / 2, TEAL_L, 0.3)
	groundRing(spot, TEAL, 1 * s / 2, 7 * s / 2, 0.5)
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not m.Parent then conn:Disconnect() return end
		local v = math.clamp((os.clock() - t0) / 0.3, 0, 1)
		place(CFrame.lookAt(pos, pos + look), os.clock() * 2, math.max(0.05, 1 + 2.70158 * (v - 1) ^ 3 + 1.70158 * (v - 1) ^ 2))
	end)
	rising(function() return m.Parent and (spot + Vector3.new((math.random() - 0.5) * 7, 0.2, (math.random() - 0.5) * 7) * s / 2) or nil end,
		TEAL_L, 40, 8, 0.5 * s / 2)
	return {m = m, close = function()
		conn:Disconnect()
		if not m.Parent then return end
		orb(pos, 8, TEAL_L, 0.3)
		burst(pos, TEAL_L, 10, 8, 0.4, 0.6)
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then fade(p, 0.4, p.Size * 0.3) end
		end
		Debris:AddItem(m, 0.5)
	end}
end
local function riftClear(char, closing)
	local st = rifts[char]
	if not st then return end
	rifts[char] = nil
	for _, c in ipairs(st.conns) do c:Disconnect() end
	for _, rg in ipairs(st.rings) do rg.close() end
	for _, p in ipairs(st.segs) do fade(p, closing and 0.6 or 0.3) end
	if st.trail and st.trail.Parent then st.trail.Enabled = false; Debris:AddItem(st.trail, 0.6) end
	if st.emit and st.emit.Parent then st.emit.Enabled = false; Debris:AddItem(st.emit, 1) end
	hide(st.carry, false)
	diag("oportal", "recovery")
end
local function riftStart(char, at) -- wind-up: the tail rings glow; action: ring A stands at the troodon, a feather trail follows it
	if not riftLook() then return end
	riftClear(char, false)
	diag("oportal", "windup")
	local s = char:GetScale()
	local both = {}
	for _, p in ipairs(pieces(char, "oportal", {carry1 = true, carry2 = true})) do table.insert(both, p) end
	windupGlow(both, TEAL, 0.25, char)
	local st = {rings = {}, segs = {}, conns = {}, carry = both, at = at}
	rifts[char] = st
	local a = char:GetAttribute("TrooRiftA")
	local r0 = rootOf(char)
	if typeof(a) ~= "Vector3" or not r0 then return end
	hide(both, true)
	diag("oportal", "action")
	local lv = Vector3.new(r0.CFrame.LookVector.X, 0, r0.CFrame.LookVector.Z)
	table.insert(st.rings, standRing(a, lv, s))
	-- the feather trail while placing: a teal Trail on the root + feathers shed behind it
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 1.2 * s / 2, 0), Vector3.new(0, -1.6 * s / 2, 0)
	a0.Parent, a1.Parent = r0, r0
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(TEAL_L, TEAL)
	tr.Transparency = NumberSequence.new(0.15, 1)
	tr.Lifetime, tr.LightEmission, tr.FaceCamera = 1.2, 1, true
	tr.Parent = r0
	st.trail = tr
	local em = Instance.new("ParticleEmitter")
	em.Texture, em.Color, em.LightEmission = SPARK_TEX, ColorSequence.new(TEAL_L), 0.8
	em.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5 * s / 2), NumberSequenceKeypoint.new(1, 0)})
	em.Transparency = NumberSequence.new(0.1, 1)
	em.Speed, em.SpreadAngle, em.Lifetime, em.Rate = NumberRange.new(1, 3), Vector2.new(60, 60), NumberRange.new(0.8, 1.4), 30
	em.Acceleration = Vector3.new(0, -2, 0)
	em.Parent = a1
	st.emit = em
	table.insert(st.conns, char:GetAttributeChangedSignal("TrooRiftPlacing"):Connect(function()
		if char:GetAttribute("TrooRiftPlacing") ~= true then
			tr.Enabled = false
			em.Enabled = false
		end
	end))
end
local function riftOpen(char) -- result: ring B opens at the far end and the rift line lies along the walked path
	local st = rifts[char]
	if not st or not riftLook() then return end
	local s = char:GetScale()
	local pts = {}
	for x, y, z in string.gmatch(tostring(char:GetAttribute("TrooRiftPath") or ""), "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
		table.insert(pts, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
	end
	local b = char:GetAttribute("TrooRiftB")
	if typeof(b) ~= "Vector3" or #pts < 2 then return end
	local endDir = pts[#pts] - pts[#pts - 1]
	table.insert(st.rings, standRing(b, Vector3.new(endDir.X, 0, endDir.Z), s))
	local lift = 0.6 * s / 2
	for i = 2, #pts do
		local p0, p1 = pts[i - 1] + Vector3.new(0, lift, 0), pts[i] + Vector3.new(0, lift, 0)
		local L = (p1 - p0).Magnitude
		if L > 0.05 then
			local seg = part({Size = Vector3.new(0.5 * s / 2, 0.25 * s / 2, L + 0.3), CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
				Color = TEAL, Transparency = 0.35})
			table.insert(st.segs, seg)
		end
	end
	local untilT = num(char:GetAttribute("TrooRiftUntil")) or (now() + 30)
	rising(function()
		if rifts[char] ~= st then return nil end
		return pts[math.random(1, #pts)] + Vector3.new(0, lift, 0)
	end, TEAL_L, math.max(0.1, untilT - now()), 12, 0.4 * s / 2)
	diag("oportal", "result")
end
local function riftTravel(m) -- any dino on the rift: a teal streak on it until TrooRiftTravelUntil; an entry flash, no landing FX
	if not riftLook() then return end
	local r = rootOf(m)
	local from = m:GetAttribute("TrooRiftTravelFrom")
	if not r then return end
	local s = m:GetScale()
	if typeof(from) == "Vector3" then flashBall(from + Vector3.new(0, 3 * s / 2, 0), TEAL_L, 2, 8 * s / 2, 0.25) end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 1.5 * s / 2, 0), Vector3.new(0, -1.5 * s / 2, 0)
	a0.Parent, a1.Parent = r, r
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1), TEAL)
	tr.Transparency = NumberSequence.new(0, 1)
	tr.Lifetime, tr.LightEmission, tr.FaceCamera = 0.45, 1, true
	tr.Parent = r
	local glow = ball(3 * s / 2, TEAL_L)
	glow.Transparency = 0.55
	light(glow, TEAL, 12, 3)
	local untilT = num(m:GetAttribute("TrooRiftTravelUntil")) or (now() + 1)
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not r.Parent or now() >= untilT then
			conn:Disconnect()
			glow:Destroy()
			tr.Enabled = false
			Debris:AddItem(tr, 0.5)
			Debris:AddItem(a0, 0.5)
			Debris:AddItem(a1, 0.5)
			return
		end
		glow.CFrame = r.CFrame
	end)
	diag("oportal", "travel")
end

-- wiring -----------------------------------------------------------------------------------------------------------------
local function watch(char)
	local function hook(attr, fn)
		char:GetAttributeChangedSignal(attr):Connect(function()
			if script:GetAttribute("TrooPartsFXEnabled") == false then return end
			local v = char:GetAttribute(attr)
			if char:GetAttribute("Species") ~= "Troodon" and attr ~= "TrooPortalUsedAt" and attr ~= "TrooRiftTravelAt" then return end -- v1.4: + rift travel
			if typeof(v) == "number" and now() - v > 2 then return end
			fn(char, v)
		end)
	end
	hook("TrooMenderAt", menderStart)
	hook("TrooMenderHopAt", function(c) menderHop(c) end)
	hook("TrooMenderEndAt", function(c) menderEnd(c) end)
	hook("TrooLanternAt", lanternStart)
	hook("TrooLanternZapAt", function(c) lanternZap(c) end)
	hook("TrooSapAt", sapStart)
	hook("TrooShedAt", shedStart)
	hook("TrooPortalAt", portalStart)
	hook("TrooPortalEndAt", function(c) portalEnd(c) end)
	hook("TrooPortalUsedAt", function(c) portalUsed(c) end)
	hook("TrooRiftAt", riftStart) -- v1.4
	hook("TrooRiftOpenAt", function(c) riftOpen(c) end)
	hook("TrooRiftEndAt", function(c) riftClear(c, true) end)
	hook("TrooRiftCancelAt", function(c) riftClear(c, false) end)
	hook("TrooRiftTravelAt", function(c) riftTravel(c) end)
	char.AncestryChanged:Connect(function(_, parent)
		if parent then return end
		local d = drones[char]
		if d then d.model:Destroy() drones[char] = nil end
		local l = lanterns[char]
		if l and l.core.Parent then l.core:Destroy() end
		lanterns[char] = nil
		portalEnd(char)
		riftClear(char, false) -- v1.4
	end)
end
local function onPlayer(pl)
	if pl.Character then watch(pl.Character) end
	pl.CharacterAdded:Connect(watch)
end
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
Players.PlayerAdded:Connect(onPlayer)
local walls = workspace:FindFirstChild("TrooWalls") or workspace:WaitForChild("TrooWalls", 30)
if walls then
	for _, m in ipairs(walls:GetChildren()) do watchWall(m) end
	walls.ChildAdded:Connect(function(m) task.defer(watchWall, m) end)
end
