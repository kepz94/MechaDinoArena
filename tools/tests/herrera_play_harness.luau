-- herrera_play_harness v1.0 (Mecha Dino Arena) — Studio-only test tool (plan docs/plans/HERRERA_SCURRY_v1.0.md Task 5).
-- Run with execute_luau on the Server datamodel during Play: makes the first player a Herrerasaurus without SpeciesServer
-- (the Herrera is not a pickable species yet). Same steps as SpeciesServer 1.3 spawnPachy: a body built from
-- ServerStorage.DinoArcade.Models.HerreraModelData with DinoModelBuilder, clones of every StarterCharacterScripts child,
-- scaled 2x (as RaptorScale does for the raptor / pachy; RaptorScale does not know the Herrera), standing where the old
-- body stood, then player.Character (so DinoHitboxes, ScurryHitbox and every CharacterAdded hook see it).
-- Nothing is installed in the place; stopping Play removes it. Returns a one-line summary.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local SCALE = 2
local player = Players:GetPlayers()[1]
if not player then return "no player" end
local da = game.ServerStorage.DinoArcade
local Builder = require(da.DinoModelBuilder)
local src = da.Models.HerreraModelData
local c = src:Clone()
c.Parent = src.Parent
local data = require(c)
c:Destroy()

local char = Builder.build(data, {name = player.Name})
for _, s in ipairs(StarterPlayer.StarterCharacterScripts:GetChildren()) do
	s:Clone().Parent = char
end
char:ScaleTo(SCALE)
local hrp = char.HumanoidRootPart
local hum = char:FindFirstChildOfClass("Humanoid")
local old = player.Character
local oldHrp = old and old:FindFirstChild("HumanoidRootPart")
local oldHum = old and old:FindFirstChildOfClass("Humanoid")
local base
if oldHrp and oldHum then
	local ground = oldHrp.Position.Y - (oldHrp.Size.Y / 2 + oldHum.HipHeight)
	local look = Vector3.new(oldHrp.CFrame.LookVector.X, 0, oldHrp.CFrame.LookVector.Z)
	local pos = Vector3.new(oldHrp.Position.X, ground, oldHrp.Position.Z)
	base = CFrame.lookAt(pos, pos + (look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)))
else
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	base = CFrame.new(spawn and (spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0)) or Vector3.zero)
end
char:PivotTo(base + Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight, 0))
char.Parent = workspace
player.Character = char
if old and old ~= char then old:Destroy() end
player:SetAttribute("HerreraHarness", "1.0")
return ("herrera for %s at %.0f %.0f %.0f, scale %.2f, hip %.2f"):format(player.Name, hrp.Position.X, hrp.Position.Y,
	hrp.Position.Z, char:GetScale(), hum.HipHeight)
