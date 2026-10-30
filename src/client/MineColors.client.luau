-- MineColors v1.0 (Mecha Dino Arena) — Shock Mine colours on this player's screen (LocalScript in StarterPlayerScripts).
-- Kepu 2026-10-30: "Enemy mines will be red friendly mines blue" -> "Yours blue, enemies' red".
-- MineServer 1.6 builds every mine cyan and puts MineOwner (owner name) on the Model "ShockMine" and on its "MineBurst".
-- Here, for each of them in the Workspace (now and as they appear): owner == this player's name -> BLUE, anything else
--   (other players, bots, test drops) -> RED:
--   * Model "ShockMine": parts "Ring" and "TriggerRing" -> MAIN, "Light" -> CORE, its PointLight -> MAIN;
--   * Part "MineBurst" -> MAIN, its ParticleEmitter -> CORE to MAIN.
--   Only Color is changed (MineServer's blink and fades use Transparency and Size, so they still play). The Lab card
--   model (not in the Workspace) keeps the cyan look.
-- Colours: BLUE MAIN (60, 130, 255) / CORE (200, 225, 255); RED MAIN (255, 60, 50) / CORE (255, 210, 200).
-- Switch: script attribute MineColorsEnabled (default true, read at start; false = every mine stays cyan).
-- Diagnostics (LocalPlayer attributes, this client): MineColorsVersion, MineColorsPainted (count of mines / bursts
--   painted).
local Players = game:GetService("Players")

local VERSION = "1.0"
local BLUE = {main = Color3.fromRGB(60, 130, 255), core = Color3.fromRGB(200, 225, 255)}
local RED = {main = Color3.fromRGB(255, 60, 50), core = Color3.fromRGB(255, 210, 200)}

local player = Players.LocalPlayer
player:SetAttribute("MineColorsVersion", VERSION)
if script:GetAttribute("MineColorsEnabled") == nil then script:SetAttribute("MineColorsEnabled", true) end
if script:GetAttribute("MineColorsEnabled") == false then return end

local painted = 0
local function paint(inst)
	local owner = inst:GetAttribute("MineOwner")
	if type(owner) ~= "string" then return end
	local c = owner == player.Name and BLUE or RED
	if inst:IsA("Model") and inst.Name == "ShockMine" then
		for _, n in ipairs({"Ring", "TriggerRing"}) do
			local p = inst:FindFirstChild(n)
			if p and p:IsA("BasePart") then p.Color = c.main end
		end
		local light = inst:FindFirstChild("Light")
		if light and light:IsA("BasePart") then
			light.Color = c.core
			local pl = light:FindFirstChildOfClass("PointLight")
			if pl then pl.Color = c.main end
		end
	elseif inst:IsA("BasePart") and inst.Name == "MineBurst" then
		inst.Color = c.main
		local pe = inst:FindFirstChildOfClass("ParticleEmitter")
		if pe then pe.Color = ColorSequence.new(c.core, c.main) end
	else
		return
	end
	painted += 1
	player:SetAttribute("MineColorsPainted", painted)
end

-- a mine's parts may stream in after the model: paint again when a child arrives
local function watch(inst)
	if inst:IsA("Model") and inst.Name == "ShockMine" then
		paint(inst)
		inst.ChildAdded:Connect(function() paint(inst) end)
		inst:GetAttributeChangedSignal("MineOwner"):Connect(function() paint(inst) end)
	elseif inst:IsA("BasePart") and inst.Name == "MineBurst" then
		paint(inst)
		inst.ChildAdded:Connect(function() paint(inst) end)
		inst:GetAttributeChangedSignal("MineOwner"):Connect(function() paint(inst) end)
	end
end

for _, d in ipairs(workspace:GetDescendants()) do watch(d) end
workspace.DescendantAdded:Connect(watch)
