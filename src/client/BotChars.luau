-- BotChars v1.0 (Mecha Dino Arena) — bot models as stand-in "players" for client effect scripts (ModuleScript,
-- StarterPlayerScripts). Filler Bots v1.0 T3 (MDA-576), plan docs/plans/FILLER_BOTS_v1.0.md. Found in the trailer shoot
-- 2026-11-25: the effect scripts watch Players only, so practice bots' parts, trails and emote props were never drawn.
-- Bots: every Model child of Workspace.DinoIsland.Bots (practice bots, filler bots), now and added later; dropped when it
--   leaves the folder.
-- Stand-in (one per model): Character = the model, Name, DisplayName (the model's DisplayName attribute, else its name),
--   UserId 0, IsBotStandIn true, Parent = the model's parent (read live), CharacterAdded / CharacterRemoving /
--   CharacterAppearanceLoaded = signals that never fire (a bot's next life is a new model, so a new stand-in),
--   :GetAttribute / :GetAttributeChangedSignal on the model, :IsA() false, :FindFirstChild() nil.
-- API:
--   watch(scriptInst, fn): fn(standIn) once for every bot model now and each one added later (task.spawn, errors kept to
--     that call), while scriptInst's BotFXEnabled ~= false (read at each call).
--   players(scriptInst) -> Players:GetPlayers() plus the stand-ins of the bots in the folder now (BotFXEnabled false ->
--     players only). A new table each call.
--   list() -> the stand-ins now.
local Players = game:GetService("Players")

local M = {}
M.VERSION = "1.0"

local SIG = {}
function SIG:Connect() return {Disconnect = function() end, Connected = true} end
function SIG:Once() return {Disconnect = function() end, Connected = true} end
function SIG:Wait() return nil end

local stands = {} -- [model] = stand-in
local order = {} -- stand-ins, folder order of arrival
local watchers = {} -- {scriptInst, fn}

local function make(model)
	local s = {Character = model, Name = model.Name, UserId = 0, IsBotStandIn = true,
		CharacterAdded = SIG, CharacterRemoving = SIG, CharacterAppearanceLoaded = SIG}
	s.DisplayName = model:GetAttribute("DisplayName") or model.Name
	function s:GetAttribute(k) return model:GetAttribute(k) end
	function s:GetAttributeChangedSignal(k) return model:GetAttributeChangedSignal(k) end
	function s:IsA() return false end
	function s:FindFirstChild() return nil end
	return setmetatable(s, {__index = function(_, k)
		if k == "Parent" then return model.Parent end
		return nil
	end})
end

local function on(scriptInst)
	return not (scriptInst and scriptInst:GetAttribute("BotFXEnabled") == false)
end

local function fire(w, s)
	if not on(w[1]) then return end
	task.spawn(w[2], s)
end

local function add(model)
	if not model:IsA("Model") or stands[model] then return end
	local s = make(model)
	stands[model] = s
	table.insert(order, s)
	for _, w in ipairs(watchers) do fire(w, s) end
end

local function remove(model)
	local s = stands[model]
	if not s then return end
	stands[model] = nil
	local i = table.find(order, s)
	if i then table.remove(order, i) end
end

task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 1e9)
	local f = isl and isl:WaitForChild("Bots", 1e9)
	if not f then return end
	f.ChildAdded:Connect(add)
	f.ChildRemoved:Connect(remove)
	for _, m in ipairs(f:GetChildren()) do add(m) end
end)

function M.watch(scriptInst, fn)
	local w = {scriptInst, fn}
	table.insert(watchers, w)
	for _, s in ipairs(order) do fire(w, s) end
end

function M.players(scriptInst)
	local list = Players:GetPlayers()
	if not on(scriptInst) then return list end
	for _, s in ipairs(order) do table.insert(list, s) end
	return list
end

function M.list()
	return table.clone(order)
end

return M
