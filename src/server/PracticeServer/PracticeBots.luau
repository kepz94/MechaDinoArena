-- PracticeBots v1.0 (Mecha Dino Arena) — builds a practice bot of any of the 8 dinos. MDA-406, plan
-- docs/plans/PRACTICE_MATCH_v1.0.md Task 2 (ModuleScript, child of PracticeServer).
-- Body: the species' ModelData built with DinoModelBuilder (the SpeciesServer / BotServer way; built once and cloned), the T-Rex
--   = a clone of StarterPlayer.StarterCharacter with its scripts removed. Copies of the StarterCharacterScripts that run on
--   every client (CLIENT_SCRIPTS: animation, badges, hit / pounce / roar / stun effects) are added, so a bot looks like a
--   player's dino. Server-owned physics (SetNetworkOwner(nil)); parent = the folder given (Workspace.DinoIsland.Bots, so
--   StepAssistServer lifts it up steps).
-- Attributes on the bot: IsBot, PracticeBot, Bitable (players' attacks hit it), Species, BotSpecies, DisplayName (the bot's
--   name), DummyMaxHealth = DummyHealth = DinoMaxHealth or the species health (as DinoHealthServer gives a player), HardpointBotTeam
--   ("A" / "B"), SkillXpMul (opts.xpMul: 0.1, red-team 3), PracticeLoadout (JSON of the loadout ids), SkillPath_<id> (its steps),
--   BotState "spawned". Model name "PBot_<name>" (never a player's name, so no kill credit lands on a real player by name).
-- Speed: Humanoid.WalkSpeed = (MoveRunSpeed or MoveWalkSpeed x 1.8 or 30) x ArenaRules.ArenaSpeedScale (default 0.65) x
--   speedMul (opts, default 0.95): bots run like players do.
-- API: template(species) -> Model? (cached); spawn(spec, team, groundCFrame, folder, opts) -> model? , reason;
--   runSpeed(model) -> number.
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local HttpService = game:GetService("HttpService")

local M = {}
M.Version = "1.0"

local MODEL_DATA = {Raptor = "RaptorModelData", Pachy = "PachyModelData", Herrera = "HerreraModelData", Teno = "TenoModelData",
	Therizino = "TherizinoModelData", Dilo = "DiloModelData", Troodon = "TroodonModelData"}
local MAX_BY_SPECIES = {TRex = 200, Raptor = 60}
local CLIENT_SCRIPTS = {"IdleAnimation", "StatusBadges", "PounceFX", "StunFX", "BiteFX", "RoarFX"}

local templates = {}

function M.template(species)
	if templates[species] ~= nil then return templates[species] or nil end
	local ok, t = pcall(function()
		if species == "TRex" then
			local sc = StarterPlayer:FindFirstChild("StarterCharacter")
			local was = sc.Archivable
			sc.Archivable = true
			local c = sc:Clone()
			sc.Archivable = was
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("BaseScript") then d:Destroy() end
			end
			if c:GetAttribute("Species") == nil then c:SetAttribute("Species", "TRex") end
			return c
		end
		local DA = ServerStorage:WaitForChild("DinoArcade")
		local Builder = require(DA:WaitForChild("DinoModelBuilder"))
		local data = require(DA:WaitForChild("Models"):WaitForChild(MODEL_DATA[species]))
		local m = Builder.build(data, {name = species})
		if m:GetAttribute("Species") == nil then m:SetAttribute("Species", species) end
		return m
	end)
	templates[species] = ok and t or false
	if not ok then warn("PracticeBots: template " .. tostring(species) .. ": " .. tostring(t)) end
	return ok and t or nil
end

function M.runSpeed(model)
	local run = tonumber(model:GetAttribute("MoveRunSpeed"))
	if not run then
		local walk = tonumber(model:GetAttribute("MoveWalkSpeed"))
		run = walk and walk * 1.8 or 30
	end
	local ar = game:GetService("ServerScriptService"):FindFirstChild("ArenaRules")
	local scale = ar and tonumber(ar:GetAttribute("ArenaSpeedScale")) or 0.65
	return run * scale
end

function M.spawn(spec, team, groundCFrame, folder, opts)
	opts = opts or {}
	local t = M.template(spec.species)
	if not t then return nil, "noTemplate" end
	local model = t:Clone()
	model.Name = "PBot_" .. spec.name
	for _, n in ipairs(CLIENT_SCRIPTS) do
		local s = StarterPlayer.StarterCharacterScripts:FindFirstChild(n)
		if s then s:Clone().Parent = model end
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then model:Destroy() return nil, "noRoot" end
	local max = tonumber(model:GetAttribute("DinoMaxHealth")) or MAX_BY_SPECIES[spec.species] or 100
	model:SetAttribute("IsBot", true)
	model:SetAttribute("PracticeBot", true)
	model:SetAttribute("Bitable", true)
	model:SetAttribute("Species", spec.species)
	model:SetAttribute("BotSpecies", spec.species)
	model:SetAttribute("DisplayName", spec.name)
	model:SetAttribute("DummyMaxHealth", max)
	model:SetAttribute("DummyHealth", max)
	model:SetAttribute("HardpointBotTeam", team)
	model:SetAttribute("SkillXpMul", opts.xpMul or 0.1)
	local ids = {}
	for n, id in ipairs(spec.loadout or {}) do ids[n] = id or "" end
	model:SetAttribute("PracticeLoadout", HttpService:JSONEncode(ids))
	for id, n in pairs(spec.steps or {}) do
		if n > 0 then model:SetAttribute("SkillPath_" .. id, n) end
	end
	model:SetAttribute("BotState", "spawned")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	hum.AutoRotate = true
	hum.UseJumpPower = true
	hum.JumpPower = 40
	hum.WalkSpeed = M.runSpeed(model) * (opts.speedMul or 0.95)
	local offset = model:GetPivot():ToObjectSpace(hrp.CFrame)
	local want = groundCFrame + Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight + 0.3, 0)
	model:PivotTo(want * offset:Inverse())
	hrp.Anchored = false
	model.Parent = folder
	pcall(function() hrp:SetNetworkOwner(nil) end)
	return model
end

return M
