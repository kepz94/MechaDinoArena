-- WaterSwim v1.0 (Mecha Dino Arena) — swimmable water for everyone (Script, ServerScriptService). MDA-467, plan
-- docs/plans/BOTS_V2_v1.0.md T2; Kepu 2026-11-11 20:39 "Fix the water make it swimable across. Bots keep getting stuck there",
-- pick "Swim for everyone".
-- Found in Studio 2026-11-11: the island's water is parts (Workspace.DinoIsland.Ground: "Water" / "LakeWater" surfaces, no collide,
--   top about -0.85; "Seabed" / "Shallows" floors below, tops -2.2 .. -45.8); a dino walks on the floor under the surface and
--   must climb 4-5 stud steps out; bots got stuck at the banks.
-- At start (and when the switch turns on): Terrain water is filled over every collidable Ground part whose top is below
--   WaterSwimFloorBelow (-0.8) and whose height is under 200: its footprint (the part's own yaw), from its top up to
--   WaterSwimSurface (-0.85). Every dino floats on it (players' and bots'); the swim itself is driven by SwimAssist / the bot
--   drive below. The look stays: Terrain WaterTransparency 1, WaterReflectance 0, WaterWaveSize 0,
--   WaterWaveSpeed 0 (the old values are kept on this script as WaterSwimOld_<name> and put back when the switch turns off).
-- Switch: script attribute WaterSwimEnabled (default true, read at start and live; false -> the filled water is removed
--   (ReplaceMaterial Water -> Air over each filled block) and the terrain look is put back).
-- Settings: WaterSwimSurface (-0.85), WaterSwimFloorBelow (-0.8). Diagnostics: WaterSwimVersion, WaterSwimState ("off" / "on"),
--   WaterSwimBlocks (blocks filled).
-- Found in Studio after the fill: a dino floats (root at the surface) but its Humanoid stays in Freefall, never Swimming, and
--   barely moves. Players get SwimAssist 1.0 (LocalScript); bots get the same drive here: every Heartbeat, for each model
--   with PracticeBot = true in Workspace.DinoIsland.Bots whose root is at most WaterSwimBotDepth (8) studs above Terrain water
--   and whose Humanoid is not on ground: flat velocity = its walk direction (Humanoid.MoveDirection, else toward WalkToPoint) x
--   WalkSpeed x WaterSwimBotSpeedMul (0.7); a bank (pushing at under 30% of that speed for 0.25 s) -> an up-kick of
--   WaterSwimBotClimbBoost (30), at most every 0.6 s. Model attribute BotSwimming (true while swimming) for PracticeBrain.
--   Switch: WaterSwimBotAssistEnabled (default true, read per frame). Diagnostic: WaterSwimBotKicks.
local VERSION = "1.0"
script:SetAttribute("WaterSwimVersion", VERSION)
if script:GetAttribute("WaterSwimEnabled") == nil then script:SetAttribute("WaterSwimEnabled", true) end
if script:GetAttribute("WaterSwimSurface") == nil then script:SetAttribute("WaterSwimSurface", -0.85) end
if script:GetAttribute("WaterSwimFloorBelow") == nil then script:SetAttribute("WaterSwimFloorBelow", -0.8) end
script:SetAttribute("WaterSwimState", "off")

local terrain = workspace.Terrain
local LOOK = {WaterTransparency = 1, WaterReflectance = 0, WaterWaveSize = 0, WaterWaveSpeed = 0}
local filled = {} -- {cf, size}
local busy = false

local function blocks()
	local island = workspace:WaitForChild("DinoIsland", 30)
	local ground = island and island:FindFirstChild("Ground")
	local out = {}
	if not ground then return out end
	local surface = tonumber(script:GetAttribute("WaterSwimSurface")) or -0.85
	local below = tonumber(script:GetAttribute("WaterSwimFloorBelow")) or -0.8
	for _, p in ipairs(ground:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide and p.Size.Y < 200 then
			local top = p.Position.Y + p.Size.Y / 2
			if top < below and top < surface then
				local h = surface - top
				local _, yaw = p.CFrame:ToOrientation()
				local cf = CFrame.new(p.Position.X, top + h / 2, p.Position.Z) * CFrame.Angles(0, yaw, 0)
				table.insert(out, {cf = cf, size = Vector3.new(p.Size.X, h, p.Size.Z)})
			end
		end
	end
	return out
end

local function on()
	if busy or #filled > 0 then return end
	busy = true
	for k, v in pairs(LOOK) do
		if script:GetAttribute("WaterSwimOld_" .. k) == nil then script:SetAttribute("WaterSwimOld_" .. k, terrain[k]) end
		terrain[k] = v
	end
	local list = blocks()
	for i, b in ipairs(list) do
		terrain:FillBlock(b.cf, b.size, Enum.Material.Water)
		table.insert(filled, b)
		if i % 25 == 0 then task.wait() end
	end
	script:SetAttribute("WaterSwimBlocks", #filled)
	script:SetAttribute("WaterSwimState", "on")
	busy = false
end

local function off()
	if busy then return end
	busy = true
	for i, b in ipairs(filled) do
		local half = b.size / 2
		local r = math.max(half.X, half.Z) * 1.42
		local c = b.cf.Position
		local region = Region3.new(c - Vector3.new(r, half.Y + 4, r), c + Vector3.new(r, half.Y + 4, r)):ExpandToGrid(4)
		pcall(function() terrain:ReplaceMaterial(region, 4, Enum.Material.Water, Enum.Material.Air) end)
		if i % 25 == 0 then task.wait() end
	end
	filled = {}
	for k in pairs(LOOK) do
		local old = script:GetAttribute("WaterSwimOld_" .. k)
		if old ~= nil then terrain[k] = old end
	end
	script:SetAttribute("WaterSwimBlocks", 0)
	script:SetAttribute("WaterSwimState", "off")
	busy = false
end

local function apply()
	if script:GetAttribute("WaterSwimEnabled") ~= false then on() else off() end
end
script:GetAttributeChangedSignal("WaterSwimEnabled"):Connect(apply)
apply()

-- ---------- bots swim (see the header) ----------
for k, v in pairs({WaterSwimBotAssistEnabled = true, WaterSwimBotDepth = 8, WaterSwimBotSpeedMul = 0.7, WaterSwimBotClimbBoost = 30}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local RunService = game:GetService("RunService")
local swimParams = RaycastParams.new()
swimParams.FilterType = Enum.RaycastFilterType.Include
swimParams.FilterDescendantsInstances = {terrain}
swimParams.IgnoreWater = false
local ON_GROUND = {[Enum.HumanoidStateType.Running] = true, [Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true, [Enum.HumanoidStateType.Climbing] = true, [Enum.HumanoidStateType.Seated] = true}
local botSwim = setmetatable({}, {__mode = "k"}) -- [model] = {blocked, lastKick}
RunService.Heartbeat:Connect(function(dt)
	if script:GetAttribute("WaterSwimBotAssistEnabled") == false or #filled == 0 then return end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	if not bots then return end
	local depth = tonumber(script:GetAttribute("WaterSwimBotDepth")) or 8
	local mul = tonumber(script:GetAttribute("WaterSwimBotSpeedMul")) or 0.7
	local boost = tonumber(script:GetAttribute("WaterSwimBotClimbBoost")) or 30
	for _, m in ipairs(bots:GetChildren()) do
		if m:GetAttribute("PracticeBot") == true then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local hrp = m:FindFirstChild("HumanoidRootPart")
			local swim = false
			if hum and hrp and not hrp.Anchored and not ON_GROUND[hum:GetState()] then
				local hit = workspace:Raycast(hrp.Position + Vector3.new(0, 1, 0), Vector3.new(0, -(depth + 1), 0), swimParams)
				if hit and hit.Material == Enum.Material.Water then
					swim = true
					local st = botSwim[m] or {blocked = 0, lastKick = 0}
					botSwim[m] = st
					local dir = hum.MoveDirection
					if dir.Magnitude < 0.05 then dir = hum.WalkToPoint - hrp.Position end
					dir = Vector3.new(dir.X, 0, dir.Z)
					local v = hrp.AssemblyLinearVelocity
					if dir.Magnitude > 0.05 then
						local want = dir.Unit * hum.WalkSpeed * mul
						if Vector3.new(v.X, 0, v.Z).Magnitude < want.Magnitude * 0.3 then st.blocked += dt else st.blocked = 0 end
						local vy = v.Y
						if st.blocked >= 0.25 and os.clock() - st.lastKick > 0.6 then
							vy, st.lastKick, st.blocked = boost, os.clock(), 0
							script:SetAttribute("WaterSwimBotKicks", (script:GetAttribute("WaterSwimBotKicks") or 0) + 1)
						end
						hrp.AssemblyLinearVelocity = Vector3.new(want.X, vy, want.Z)
					end
				end
			end
			if (m:GetAttribute("BotSwimming") == true) ~= swim then m:SetAttribute("BotSwimming", swim) end
		end
	end
end)
