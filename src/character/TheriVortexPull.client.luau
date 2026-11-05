-- TheriVortexPull v1.0 (Mecha Dino Arena) — a player caught in a therizino's Reaper Vortex is dragged toward its centre by its
-- own client (the player owns its body). Plan docs/plans/THERIZINO_MOVES_REWORK_v1.0.md (MDA-264); server TheriMovesServer 1.4
-- stamps this character: TheriVortexBy (the therizino), TheriVortexCenter, TheriVortexPull (studs/s), TheriVortexUntil (server
-- time, set last; now when it leaves the ring or the vortex ends). While TheriVortexUntil is in the future, every Heartbeat the
-- root moves TheriVortexPull x dt studs (flat) toward the centre, stopping 3 x scale studs from it (the player can walk out).
-- Switch: character attribute TheriVortexPullEnabled (default true). Diagnostics: TheriVortexPullVersion, TheriVortexPulled
-- (studs moved, last vortex).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
if not (hum and hrp) or Players:GetPlayerFromCharacter(char) ~= Players.LocalPlayer then return end
char:SetAttribute("TheriVortexPullVersion", VERSION)
local moved, wasOn = 0, false
RunService.Heartbeat:Connect(function(dt)
	local untilT = tonumber(char:GetAttribute("TheriVortexUntil")) or 0
	local c = char:GetAttribute("TheriVortexCenter")
	local on = char:GetAttribute("TheriVortexPullEnabled") ~= false and untilT > workspace:GetServerTimeNow()
		and typeof(c) == "Vector3" and hum.Health > 0 and hrp.Parent ~= nil
	if not on then
		if wasOn then char:SetAttribute("TheriVortexPulled", math.floor(moved * 10 + 0.5) / 10) end
		wasOn = false
		return
	end
	if not wasOn then moved = 0 end
	wasOn = true
	local d = Vector3.new(c.X - hrp.Position.X, 0, c.Z - hrp.Position.Z)
	local stop = 3 * char:GetScale()
	if d.Magnitude <= stop then return end
	local step = math.min((tonumber(char:GetAttribute("TheriVortexPull")) or 6) * dt, d.Magnitude - stop)
	hrp.CFrame += d.Unit * step
	moved += step
end)
