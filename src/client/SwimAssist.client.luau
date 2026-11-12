-- SwimAssist v1.0 (Mecha Dino Arena) — your dino swims across water (LocalScript, StarterPlayerScripts). MDA-467, plan
-- docs/plans/BOTS_V2_v1.0.md T2; Kepu 2026-11-11 20:39 "Fix the water make it swimable across", pick "Swim for everyone".
-- WaterSwim 1.0 (server) fills Terrain water under the island's water parts. Found in Studio 2026-11-11: a dino floats on it
--   (its root at the surface, y about -0.5) but the Humanoid stays in Freefall (never Swimming: the root is not under water),
--   so it barely moves (3 studs in 6 s). This script drives the swim: every frame, while your character's root is at most
--   SwimAssistDepth (8) studs above Terrain water (a ray down that ends on Water) and the Humanoid is not standing on ground
--   (state Freefall / Swimming / FallingDown / Jumping), the flat velocity = Humanoid.MoveDirection x WalkSpeed x
--   SwimAssistSpeedMul (0.7); the up / down speed is left to the water (it floats).
--   Climbing out: pushing (MoveDirection set) while the flat speed is under 30% of the wanted speed for SwimAssistClimbAfter
--   (0.25) s -> one up-kick of SwimAssistClimbBoost (30) studs / s, at most every 0.6 s (a bank higher than the surface).
-- Studio: 32 studs / s across the south lake and out onto the west bank.
-- Switch: script attribute SwimAssistEnabled (default true, read per frame). Diagnostics: player attribute SwimAssistState
--   ("swim" / "land"), SwimAssistKicks.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local player = Players.LocalPlayer
player:SetAttribute("SwimAssistVersion", VERSION)
for k, v in pairs({SwimAssistEnabled = true, SwimAssistDepth = 8, SwimAssistSpeedMul = 0.7, SwimAssistClimbAfter = 0.25,
	SwimAssistClimbBoost = 30}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {workspace.Terrain}
params.IgnoreWater = false
local SWIM_STATES = {[Enum.HumanoidStateType.Freefall] = true, [Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.FallingDown] = true, [Enum.HumanoidStateType.Jumping] = true}

local blockedFor, lastKick, state = 0, 0, "land"
RunService.Heartbeat:Connect(function(dt)
	local swim = false
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if script:GetAttribute("SwimAssistEnabled") ~= false and hum and hrp and hum.Health > 0 and SWIM_STATES[hum:GetState()]
		and not hrp.Anchored then
		local depth = tonumber(script:GetAttribute("SwimAssistDepth")) or 8
		local hit = workspace:Raycast(hrp.Position + Vector3.new(0, 1, 0), Vector3.new(0, -(depth + 1), 0), params)
		if hit and hit.Material == Enum.Material.Water then
			swim = true
			local dir = hum.MoveDirection
			dir = Vector3.new(dir.X, 0, dir.Z)
			local v = hrp.AssemblyLinearVelocity
			if dir.Magnitude > 0.05 then
				local want = dir.Unit * hum.WalkSpeed * (tonumber(script:GetAttribute("SwimAssistSpeedMul")) or 0.7)
				local flatV = Vector3.new(v.X, 0, v.Z)
				if flatV.Magnitude < want.Magnitude * 0.3 then blockedFor += dt else blockedFor = 0 end
				local vy = v.Y
				if blockedFor >= (tonumber(script:GetAttribute("SwimAssistClimbAfter")) or 0.25) and os.clock() - lastKick > 0.6 then
					vy = tonumber(script:GetAttribute("SwimAssistClimbBoost")) or 30
					lastKick, blockedFor = os.clock(), 0
					player:SetAttribute("SwimAssistKicks", (player:GetAttribute("SwimAssistKicks") or 0) + 1)
				end
				hrp.AssemblyLinearVelocity = Vector3.new(want.X, vy, want.Z)
			else
				blockedFor = 0
				hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.9, v.Y, v.Z * 0.9)
			end
		end
	end
	local s = swim and "swim" or "land"
	if s ~= state then state = s player:SetAttribute("SwimAssistState", s) end
end)
