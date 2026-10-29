-- CloakFX v1.1 (Mecha Dino Arena) — draws the Cloak Field on this client (LocalScript, StarterPlayerScripts).
-- MDA-52, plan docs/plans/CLOAK_v1.0.md Task 4 (Kepu 2026-10-29: a faint shimmer others can just make out).
-- A character is cloaked while its CloakedUntil (server time, CloakServer 1.0) is in the future and its Humanoid is
-- alive. Every render frame (bound after the camera, so the camera's own fade never overrides it):
--   your own cloaked dino   - LocalTransparencyModifier SELF_LTM (0.6) on every BasePart except HumanoidRootPart;
--   another cloaked dino    - LocalTransparencyModifier OTHER_MID +- OTHER_AMP on a SHIMMER_PERIOD sine (0.88-0.94,
--                             0.6 s), and its BillboardGuis (badges / tags) and Humanoid name + health display hidden.
--   The Mecha_Cloak fins are part of the character, so they fade with the body.
-- Restore (the cloak ended, the dino died, or CloakFXEnabled went false): LocalTransparencyModifier 0 on every part,
--   each hidden BillboardGui back to its own Enabled value, the Humanoid DisplayDistanceType back to its own value.
--   A removed character is just forgotten (nothing left to restore).
-- Toggle: script attribute CloakFXEnabled (default true; false = nothing drawn, everything restored).
-- Diagnostics (local character attributes, this client): CloakFXVersion, CloakFXSeen (cloaks seen start, any dino),
--   CloakFXShown (dinos drawn cloaked right now), CloakFXSelf (true while your own dino is drawn cloaked).
-- v1.1 (MDA-56, plan docs/plans/CLOAK_LOOK_v1.1.md Task 2; Kepu 2026-10-29: "it also doesnt have an animation to show
--   when it turns on" -> option C "Camo plates", hex dissolve): turn-on / turn-off animation on every client, timed from
--   the replicated stamps (script attribute CloakFXAnimEnabled, default true; false = the 1.0 instant look). Phases:
--     "turningOn"  cloaked and 0 <= now - CloakStartedAt < ON_T (0.56 s);
--     "on"         cloaked after that;
--     "turningOff" not cloaked and 0 <= now - CloakedUntil < OFF_T (0.35 s) for this cloak (CloakedUntil >= CloakStartedAt);
--     "off"        otherwise (restored as 1.0).
--   Plates (CloakServer 1.1 Mecha_Cloak Plate_n_*): plate n turns 180 degrees about the spine through its centre
--     (Weld PlateHinge C0 = BaseC0 x rotation about Z), turning on front to back (start (n - 1) x 0.06 s, 0.12 s each),
--     turning off back to front ((4 - n) x 0.05 s, 0.12 s each); past half-way its Body parts show the open face
--     rgb(18, 58, 68). Plate parts fade at 0.30 s (turning on) and show at once (turning off).
--   Body blocks ("hex cells"): every other visible part (Transparency < 1, not in a "Hitboxes" folder) gets an order
--     thr = clamp(0.75 x distance to the nearest plate / (0.62 x body length) + 0.25 x jitter, 0, 1), jitter from a hash
--     of its full name (the same on every client). Turning on: visible until 0.12 + 0.36 x thr s, then FLASH_T (0.08 s)
--     neon cyan at LTM 0.25, then the cloak LTM. Turning off: cloak LTM until 0.25 x (1 - thr) s, then the flash, then
--     LTM 0. Invisible parts and hitboxes only take the LTM, never the flash.
--   Restore also puts back every flashed part's Color / Material and each plate's C0 and colour (the closed colour is
--   the one first seen for that part, kept across re-collects: a re-collect mid-animation read the open teal before).
--   Diagnostic: CloakFXPhase on each drawn dino (this client; "off" after the restore).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
local SELF_LTM = 0.6
local OTHER_MID, OTHER_AMP = 0.91, 0.03
local SHIMMER_PERIOD = 0.6
local ON_T, OFF_T, FLASH_T = 0.56, 0.35, 0.08 -- v1.1
local PLATE_FADE_AT = 0.30 -- v1.1
local FLASH_COLOR = Color3.fromRGB(95, 243, 255) -- v1.1
local PLATE_OPEN = Color3.fromRGB(18, 58, 68) -- v1.1

if script:GetAttribute("CloakFXEnabled") == nil then script:SetAttribute("CloakFXEnabled", true) end
if script:GetAttribute("CloakFXAnimEnabled") == nil then script:SetAttribute("CloakFXAnimEnabled", true) end -- v1.1
local me = Players.LocalPlayer

local states = {} -- [char] = {parts = {BasePart}, dirty = bool, guis = {[gui] = wasEnabled}, hum, display, conns}
local seen, lastShown, lastSelf = 0, -1, nil

local function myChar() return me.Character end
local function diag(k, v)
	local c = myChar()
	if c and c:GetAttribute(k) ~= v then c:SetAttribute(k, v) end
end
local function animOn() return script:GetAttribute("CloakFXAnimEnabled") ~= false end -- v1.1

local function cloakedNow(char, t)
	local u = char:GetAttribute("CloakedUntil")
	if typeof(u) ~= "number" or u <= t then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

-- v1.1: which phase a dino is in, and the seconds into it
local function phaseOf(char, t)
	local u, s0 = char:GetAttribute("CloakedUntil"), char:GetAttribute("CloakStartedAt")
	if cloakedNow(char, t) then
		if animOn() and typeof(s0) == "number" and t - s0 >= 0 and t - s0 < ON_T then return "turningOn", t - s0 end
		return "on", 0
	end
	if animOn() and typeof(u) == "number" and typeof(s0) == "number" and u >= s0 and t - u >= 0 and t - u < OFF_T then
		return "turningOff", t - u
	end
	return "off", 0
end

local function jitterOf(s) -- 0..1 from a string, the same on every client
	local h = 7
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 1000003 end
	return (h % 1000) / 1000
end

local function collect(st, char)
	st.parts = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then st.parts[#st.parts + 1] = d end
	end
	st.dirty = false
	-- v1.1: plates and the dissolve order
	st.plates = {}
	st.closed = st.closed or {} -- [plate body part] = its colour when first seen (closed), kept across re-collects
	local m = char:FindFirstChild("Mecha_Cloak")
	for n = 1, 4 do
		local root = m and m:FindFirstChild(("Plate_%d_Body_0"):format(n))
		local hinge = root and root:FindFirstChild("PlateHinge")
		if hinge and typeof(hinge:GetAttribute("BaseC0")) == "CFrame" then
			local bodies = {}
			for k = 0, 2 do
				local b = m:FindFirstChild(("Plate_%d_Body_%d"):format(n, k))
				if b then
					bodies[#bodies + 1] = b
					if st.closed[b] == nil then st.closed[b] = b.Color end
				end
			end
			st.plates[n] = {hinge = hinge, base = hinge:GetAttribute("BaseC0"), bodies = bodies, pos = root.Position, closed = st.closed}
		end
	end
	local centres = {}
	for _, p in pairs(st.plates) do centres[#centres + 1] = p.pos end
	if #centres == 0 then centres[1] = char:GetPivot().Position end
	local ext = char:GetExtentsSize()
	local len = math.max(1, ext.X, ext.Z)
	st.info = st.info or {}
	for _, p in ipairs(st.parts) do
		local inf = st.info[p] or {}
		local d = math.huge
		for _, c in ipairs(centres) do d = math.min(d, (p.Position - c).Magnitude) end
		inf.thr = math.clamp(0.75 * d / (0.62 * len) + 0.25 * jitterOf(p:GetFullName()), 0, 1)
		inf.plate = m ~= nil and p:IsDescendantOf(m) and p.Name:sub(1, 6) == "Plate_"
		local hb = p.Parent and p.Parent.Name == "Hitboxes"
		inf.flashOk = not inf.plate and not hb and p.Transparency < 1
		st.info[p] = inf
	end
end

local function begin(char, isMe)
	local st = {guis = {}, conns = {}, isMe = isMe}
	collect(st, char)
	st.conns[1] = char.DescendantAdded:Connect(function() st.dirty = true end)
	if not isMe then
		st.hum = char:FindFirstChildOfClass("Humanoid")
		if st.hum then
			st.display = st.hum.DisplayDistanceType
			st.hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	states[char] = st
	seen += 1
	diag("CloakFXSeen", seen)
	return st
end

-- v1.1: flash on / off for one part (original Color / Material kept)
local function setFlash(p, inf, on)
	if on and not inf.flashing then
		inf.flashing = true
		inf.color, inf.material = p.Color, p.Material
		p.Color, p.Material = FLASH_COLOR, Enum.Material.Neon
	elseif not on and inf.flashing then
		inf.flashing = false
		if p.Parent then p.Color, p.Material = inf.color, inf.material end
	end
end
-- v1.1: plate n at flip f (0 closed .. 1 open)
local function setPlate(pl, f)
	if not pl.hinge.Parent then return end
	pl.hinge.C0 = pl.base * CFrame.Angles(0, 0, math.pi * f)
	local open = f >= 0.5
	for _, b in ipairs(pl.bodies) do
		if b.Parent and pl.closed[b] then b.Color = open and PLATE_OPEN or pl.closed[b] end
	end
end

local function finish(char, st)
	for _, c in ipairs(st.conns) do c:Disconnect() end
	states[char] = nil
	if not char.Parent then return end -- removed: nothing to restore
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
	end
	for gui, was in pairs(st.guis) do
		if gui.Parent then gui.Enabled = was end
	end
	if st.hum and st.hum.Parent and st.display then st.hum.DisplayDistanceType = st.display end
	for p, inf in pairs(st.info or {}) do setFlash(p, inf, false) end -- v1.1
	for _, pl in pairs(st.plates or {}) do setPlate(pl, 0) end -- v1.1
	char:SetAttribute("CloakFXPhase", "off") -- v1.1
end

local function draw(char, st, t, phase, e)
	if st.dirty then collect(st, char) end
	local ltm = SELF_LTM
	if not st.isMe then
		ltm = OTHER_MID + OTHER_AMP * math.sin(t * 2 * math.pi / SHIMMER_PERIOD)
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BillboardGui") and st.guis[d] == nil then
				st.guis[d] = d.Enabled
				d.Enabled = false
			end
		end
	end
	if st.phase ~= phase then -- v1.1
		st.phase = phase
		char:SetAttribute("CloakFXPhase", phase)
	end
	if phase == "on" or phase == nil then
		for _, p in ipairs(st.parts) do
			if p.Parent then p.LocalTransparencyModifier = ltm end
		end
		if phase == "on" and animOn() then -- v1.1: steady state after the turn-on
			for p, inf in pairs(st.info) do if inf.flashing then setFlash(p, inf, false) end end
			for _, pl in pairs(st.plates) do setPlate(pl, 1) end
		end
		return
	end
	-- v1.1: turning on / off
	for n, pl in pairs(st.plates) do
		local f
		if phase == "turningOn" then f = math.clamp((e - (n - 1) * 0.06) / 0.12, 0, 1)
		else f = 1 - math.clamp((e - (4 - n) * 0.05) / 0.12, 0, 1) end
		setPlate(pl, f)
	end
	for _, p in ipairs(st.parts) do
		local inf = st.info[p]
		if p.Parent and inf then
			local v, flash
			if phase == "turningOn" then
				local tp = inf.plate and PLATE_FADE_AT or (0.12 + 0.36 * inf.thr)
				if e < tp then v, flash = 0, false
				elseif e < tp + FLASH_T and inf.flashOk then v, flash = 0.25, true
				else v, flash = ltm, false end
			else
				local tp = inf.plate and 0 or 0.25 * (1 - inf.thr)
				if e < tp then v, flash = ltm, false
				elseif e < tp + FLASH_T and inf.flashOk then v, flash = 0.25, true
				else v, flash = 0, false end
			end
			p.LocalTransparencyModifier = v
			setFlash(p, inf, flash)
		end
	end
end

RunService:BindToRenderStep("CloakFX", Enum.RenderPriority.Camera.Value + 2, function()
	local t = workspace:GetServerTimeNow()
	local on = script:GetAttribute("CloakFXEnabled") ~= false
	local shown, selfOn = 0, false
	local live = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local char = pl.Character
		if char and char.Parent then
			live[char] = true
			local st = states[char]
			local phase, e = "off", 0 -- v1.1
			if on then phase, e = phaseOf(char, t) end
			if phase ~= "off" then
				st = st or begin(char, pl == me)
				draw(char, st, t, phase, e)
				shown += 1
				if pl == me then selfOn = true end
			elseif st then
				finish(char, st)
			end
		end
	end
	for char, st in pairs(states) do
		if not live[char] then finish(char, st) end -- respawned / left: the old body is gone or on its way out
	end
	if shown ~= lastShown then lastShown = shown; diag("CloakFXShown", shown) end
	if selfOn ~= lastSelf then lastSelf = selfOn; diag("CloakFXSelf", selfOn) end
end)

me.CharacterAdded:Connect(function(c)
	c:SetAttribute("CloakFXVersion", VERSION)
	lastShown, lastSelf = -1, nil
end)
if me.Character then me.Character:SetAttribute("CloakFXVersion", VERSION) end
