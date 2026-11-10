-- TrooLastFeather v1.0 (Mecha Dino Arena) — the Troodon's Last Feather on the owner's client (LocalScript in
-- StarterCharacterScripts). MDA-349, plan docs/plans/TROODON_PARTS_v1.0.md ticket 5 (Kepu 2026-11-09 17:17 "Build all of
-- them" + "Use the references we chose from the previous mockups": Last Feather A "Tail-Base Cell"; mockup
-- tools/mockup/troodon_parts_looks.js lastTrack: "Bursts up and glides away").
-- * Dead state: while the character's TrooLastFeatherReady is true (TrooMovesServer 1.6) or its TrooLastFeatherUntil is after
--   now, this client's Humanoid has the Dead state switched off (the server does the same), so a killing hit that the server
--   turns into 1 HP never plays a death here; otherwise it is on again.
-- * Glide (step II): on a new TrooLastFeatherAt (within FRESH 1 s) with TrooLastFeatherGlide true, alive, not stunned / pinned:
--   the body bursts up LAUNCH_HEIGHT (script attribute TrooLastFeatherHeight, default 18 studs: the mockup's 9 at the 2x body)
--   with its flat speed kept; GliderTest 1.2's fall rule then starts the glide on the way down.
-- Switch: script attribute TrooLastFeatherClientEnabled (default true, read each event; false = nothing here: Dead state left
--   as Roblox has it). Diagnostics (character, this client): TrooLastFeatherVersion, TrooLastFeatherLocal ("ready" /
--   "spent" / "off" / "launched").
local Players = game:GetService("Players")

local VERSION = "1.0"
local FRESH = 1
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local player = Players.LocalPlayer
if Players:GetPlayerFromCharacter(char) ~= player then return end
char:SetAttribute("TrooLastFeatherVersion", VERSION)
if script:GetAttribute("TrooLastFeatherClientEnabled") == nil then script:SetAttribute("TrooLastFeatherClientEnabled", true) end
if script:GetAttribute("TrooLastFeatherHeight") == nil then script:SetAttribute("TrooLastFeatherHeight", 18) end

local function now() return workspace:GetServerTimeNow() end
local function on() return script:GetAttribute("TrooLastFeatherClientEnabled") ~= false end
local deadOff = false
local function sync()
	if not on() then return end
	local ready = char:GetAttribute("TrooLastFeatherReady") == true
	local window = (tonumber(char:GetAttribute("TrooLastFeatherUntil")) or 0) > now()
	local off = ready or window
	if off ~= deadOff then
		deadOff = off
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, not off) end)
	end
	local state = ready and "ready" or (char:GetAttribute("TrooLastFeatherUsed") == true and "spent" or "off")
	if char:GetAttribute("TrooLastFeatherLocal") ~= "launched" or not window then
		if char:GetAttribute("TrooLastFeatherLocal") ~= state then char:SetAttribute("TrooLastFeatherLocal", state) end
	end
end
for _, k in ipairs({"TrooLastFeatherReady", "TrooLastFeatherUntil", "TrooLastFeatherUsed"}) do
	char:GetAttributeChangedSignal(k):Connect(sync)
end
char:GetAttributeChangedSignal("TrooLastFeatherUntil"):Connect(function() -- the window's end turns the Dead state back on
	local untilT = tonumber(char:GetAttribute("TrooLastFeatherUntil")) or 0
	task.delay(math.max(0, untilT - now()) + 0.05, sync)
end)
char:GetAttributeChangedSignal("TrooLastFeatherAt"):Connect(function()
	sync()
	if not on() then return end
	local at = tonumber(char:GetAttribute("TrooLastFeatherAt")) or 0
	if math.abs(now() - at) > FRESH or char:GetAttribute("TrooLastFeatherGlide") ~= true then return end
	if hum.Health <= 0 or (tonumber(char:GetAttribute("StunnedUntil")) or 0) > now() or char:GetAttribute("PinHeld") == true then return end
	local h = math.max(1, tonumber(script:GetAttribute("TrooLastFeatherHeight")) or 18)
	local vy = math.sqrt(2 * workspace.Gravity * h)
	local v = hrp.AssemblyLinearVelocity
	pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end) -- JumpTest 1.x's launch order
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	hrp.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
	char:SetAttribute("TrooLastFeatherLocal", "launched")
	-- back to ready / spent once the window is over
	local untilT = tonumber(char:GetAttribute("TrooLastFeatherUntil")) or now()
	task.delay(math.max(0, untilT - now()) + 0.05, sync)
end)
sync()
