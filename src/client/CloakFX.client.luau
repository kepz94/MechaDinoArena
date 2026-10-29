-- CloakFX v1.0 (Mecha Dino Arena) — draws the Cloak Field on this client (LocalScript, StarterPlayerScripts).
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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local SELF_LTM = 0.6
local OTHER_MID, OTHER_AMP = 0.91, 0.03
local SHIMMER_PERIOD = 0.6

if script:GetAttribute("CloakFXEnabled") == nil then script:SetAttribute("CloakFXEnabled", true) end
local me = Players.LocalPlayer

local states = {} -- [char] = {parts = {BasePart}, dirty = bool, guis = {[gui] = wasEnabled}, hum, display, conns}
local seen, lastShown, lastSelf = 0, -1, nil

local function myChar() return me.Character end
local function diag(k, v)
	local c = myChar()
	if c and c:GetAttribute(k) ~= v then c:SetAttribute(k, v) end
end

local function cloakedNow(char, t)
	local u = char:GetAttribute("CloakedUntil")
	if typeof(u) ~= "number" or u <= t then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function collect(st, char)
	st.parts = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then st.parts[#st.parts + 1] = d end
	end
	st.dirty = false
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
end

local function draw(char, st, t)
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
	for _, p in ipairs(st.parts) do
		if p.Parent then p.LocalTransparencyModifier = ltm end
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
			if on and cloakedNow(char, t) then
				st = st or begin(char, pl == me)
				draw(char, st, t)
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
