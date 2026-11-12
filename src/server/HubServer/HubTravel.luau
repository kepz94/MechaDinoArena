-- HubTravel v1.0 (Mecha Dino Arena) — the island hub's trips: the save wait and the teleport (ModuleScript, child of
-- ServerScriptService.HubServer; MDA-457, plan docs/plans/ISLAND_HUB_v1.0.md Task 6, ADR-011). Used by HubServer 1.0 (portals)
-- and ModeServer 1.3 (BACK TO ISLAND).
-- go(players, mode, data) -> ok, reason. Studio -> false, "studio" (teleports don't run in Studio). mode:
--   "arena"  -> TeleportService:TeleportAsync(ModeRules.ARENA_PLACE_ID, players, options with TeleportData = data);
--   "bots"   -> TeleportService:ReserveServer(ModeRules.SANDBOX_PLACE_ID), then TeleportAsync to that reserved server
--               (options.ReservedServerAccessCode) — a private copy of the Sandbox place: kind "practice" (HubRules.kind);
--   "island" -> TeleportAsync(ModeRules.SANDBOX_PLACE_ID, players, options) — a public Sandbox server: kind "hub".
--   No players -> false, "nobody"; unknown mode -> false, "badArg"; ReserveServer error -> false, "reserveFailed"; teleport
--   error -> false, "failed" (TeleportService.TeleportInitFailed can still fire later per player; the caller listens).
-- saveWait(players, onSaving) -> waits for skill saves (SkillServer is not changed; ModeServer 1.0's rule): a player whose last
--   skill change (a SkillRequest from them, or their SkillLastXp attribute changing) was less than HubRules.SAVE_WAIT (12) s
--   ago is waited for until their SkillSaveState turns "saved" after it, or SAVE_WAIT s have passed since it. onSaving() is
--   called once if any wait happens. Returns the players still here.
-- track() starts the change watch (once; HubServer calls it at start; go / saveWait also call it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")

local M = {}
M.VERSION = "1.0"

local arcade = ServerStorage:WaitForChild("DinoArcade")
local ModeRules = require(arcade:WaitForChild("ModeRules"))
local HubRules = require(arcade:WaitForChild("HubRules"))

local lastChange = {} -- [player] = os.clock()
local savedAt = {} -- [player] = os.clock()
local tracking = false

local function watch(p)
	p:GetAttributeChangedSignal("SkillLastXp"):Connect(function() lastChange[p] = os.clock() end)
	p:GetAttributeChangedSignal("SkillSaveState"):Connect(function()
		if p:GetAttribute("SkillSaveState") == "saved" then savedAt[p] = os.clock() end
	end)
end

function M.track()
	if tracking then return end
	tracking = true
	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
	Players.PlayerRemoving:Connect(function(p) lastChange[p], savedAt[p] = nil, nil end)
	task.spawn(function()
		local r = ReplicatedStorage:WaitForChild("SkillRequest", 30)
		if r then r.OnServerEvent:Connect(function(p) lastChange[p] = os.clock() end) end
	end)
end

function M.saveWait(players, onSaving)
	M.track()
	local told = false
	while true do
		local waiting = false
		for _, p in ipairs(players) do
			local last = lastChange[p]
			if p.Parent and last and os.clock() - last < HubRules.SAVE_WAIT and not ((savedAt[p] or 0) > last) then waiting = true end
		end
		if not waiting then break end
		if not told and onSaving then told = true onSaving() end
		task.wait(0.25)
	end
	local here = {}
	for _, p in ipairs(players) do
		if p.Parent then table.insert(here, p) end
	end
	return here
end

function M.go(players, mode, data)
	M.track()
	if not HubRules.MODES[mode] then return false, "badArg" end
	if type(players) ~= "table" or #players == 0 then return false, "nobody" end
	if RunService:IsStudio() then return false, "studio" end
	local options = Instance.new("TeleportOptions")
	if type(data) == "table" then options:SetTeleportData(data) end
	local target = mode == "arena" and ModeRules.ARENA_PLACE_ID or ModeRules.SANDBOX_PLACE_ID
	if mode == "bots" then
		local okR, code = pcall(function() return TeleportService:ReserveServer(ModeRules.SANDBOX_PLACE_ID) end)
		if not okR or type(code) ~= "string" then return false, "reserveFailed" end
		options.ReservedServerAccessCode = code
	end
	local ok = pcall(function() TeleportService:TeleportAsync(target, players, options) end)
	if not ok then return false, "failed" end
	return true, "teleporting"
end

return M
