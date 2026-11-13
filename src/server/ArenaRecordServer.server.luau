-- ArenaRecordServer v1.0 (Mecha Dino Arena) — each player's Arena win-loss record (Script, ServerScriptService). MDA-482, plan
-- docs/plans/PREGAME_LINEUP_v1.0.md T2, ADR-012, mockup docs/mockups/pregame_v0.4.html (W-L on the lineup plaques and intros).
-- Kepu 2026-11-12: W-L counts Arena matches only (D1); shipped in two parts (D10): Part 1 loads and shows the record, Part 2
--   writes it (switch ArenaRecordWriteEnabled, default false until then).
-- Rules: ServerStorage.DinoArcade.ArenaRecordRules 1.0 (outcome / apply / clean).
-- Store: DataStore STORE "MDA_ArenaRecord_v1", key "u" .. UserId, value {w, l, lastMatch}.
-- On join (and for players already in at start): GetAsync, up to TRIES (3) tries LOAD_GAP (2) s apart -> player attributes
--   ArenaW, ArenaL (whole numbers) and ArenaRecordReady = true. Never loaded (DataStore down, saves off) -> ArenaRecordReady
--   false and ArenaW / ArenaL nil: screens show "-".
-- Writes (server-only BindableFunction "ArenaRecordReport", child of this script; nothing a client can reach):
--   Invoke("left", matchId, player, eligible) -> outcome = ArenaRecordRules.outcome(eligible, nil, nil, true) ("l" when
--     eligible) written now (the leaver is leaving; call it from PlayerRemoving or before a trip away).
--   Invoke("result", matchId, {{player = Player, team = "A" / "B"}}, winner, eligible, leaverTeams = {A = bool, B = bool}) ->
--     per entry outcome(eligible, winner, team, false, leaverTeams[team]) written.
--   A write = UpdateAsync(key, ArenaRecordRules.apply(old, outcome, matchId)) (dedupe by matchId), then the player's ArenaW /
--     ArenaL updated when the player is still here. Returns "ok" / "off" (writes off) / "badArg" / "noStore".
-- BindToClose: nothing extra (leavers are written when they leave; an unfinished match counts for nobody).
-- Switches (script attributes): ArenaRecordEnabled (true; read at start: false -> nothing loads, the hook answers "off"),
--   ArenaRecordWriteEnabled (false in Part 1; read per write), ArenaRecordSaveEnabled (true; false = no DataStore calls at all,
--   for Studio testing: records stay unloaded).
-- Diagnostics: ArenaRecordServerVersion, ArenaRecordState ("off" / "noStore" / "on" / "saveOff"), ArenaRecordLoads,
--   ArenaRecordWrites, ArenaRecordFails, ArenaRecordLast (last write: "<name> w|l <matchId>" or the error).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
local STORE = "MDA_ArenaRecord_v1"
local TRIES, LOAD_GAP = 3, 2

script:SetAttribute("ArenaRecordServerVersion", VERSION)
for k, v in pairs({ArenaRecordEnabled = true, ArenaRecordWriteEnabled = false, ArenaRecordSaveEnabled = true}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function bump(name) script:SetAttribute(name, (script:GetAttribute(name) or 0) + 1) end

local R
do
	local mod = ServerStorage:FindFirstChild("DinoArcade") and ServerStorage.DinoArcade:FindFirstChild("ArenaRecordRules")
	local ok, m = pcall(function() return require(mod) end)
	R = ok and m or nil
end

local hook = Instance.new("BindableFunction")
hook.Name = "ArenaRecordReport"
hook.Parent = script

if script:GetAttribute("ArenaRecordEnabled") == false or not R then
	script:SetAttribute("ArenaRecordState", "off")
	hook.OnInvoke = function() return "off" end
	return
end

local store = nil
if script:GetAttribute("ArenaRecordSaveEnabled") ~= false then
	local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE) end)
	store = ok and s or nil
end
script:SetAttribute("ArenaRecordState", script:GetAttribute("ArenaRecordSaveEnabled") == false and "saveOff" or (store and "on" or "noStore"))

local function show(player, rec)
	if not player or player.Parent ~= Players then return end
	rec = R.clean(rec)
	player:SetAttribute("ArenaW", rec.w)
	player:SetAttribute("ArenaL", rec.l)
	player:SetAttribute("ArenaRecordReady", true)
end

local function load(player)
	player:SetAttribute("ArenaRecordReady", false)
	if not store or script:GetAttribute("ArenaRecordSaveEnabled") == false then return end
	for try = 1, TRIES do
		local ok, value = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if player.Parent ~= Players then return end
		if ok then
			show(player, value)
			bump("ArenaRecordLoads")
			return
		end
		bump("ArenaRecordFails")
		script:SetAttribute("ArenaRecordLast", "load " .. player.Name .. ": " .. tostring(value))
		if try < TRIES then task.wait(LOAD_GAP) end
	end
end

local function write(player, userId, name, out, matchId)
	if out ~= "w" and out ~= "l" then return end
	local newRec
	local ok, err = pcall(function()
		store:UpdateAsync("u" .. userId, function(old)
			newRec = R.apply(old, out, matchId)
			return newRec
		end)
	end)
	if ok then
		bump("ArenaRecordWrites")
		script:SetAttribute("ArenaRecordLast", ("%s %s %s"):format(name, out, matchId))
		if newRec then show(player, newRec) end
	else
		bump("ArenaRecordFails")
		script:SetAttribute("ArenaRecordLast", "write " .. name .. ": " .. tostring(err))
	end
end

hook.OnInvoke = function(action, matchId, a, b, c, d)
	if script:GetAttribute("ArenaRecordWriteEnabled") ~= true then return "off" end
	if not store or script:GetAttribute("ArenaRecordSaveEnabled") == false then return "noStore" end
	if type(matchId) ~= "string" or matchId == "" then return "badArg" end
	if action == "left" then
		local player = a
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return "badArg" end
		write(player, player.UserId, player.Name, R.outcome(b == true, nil, nil, true, false), matchId)
		return "ok"
	elseif action == "result" then
		local list, winner, eligible, leavers = a, b, c == true, type(d) == "table" and d or {}
		if type(list) ~= "table" then return "badArg" end
		for _, e in ipairs(list) do
			local p = type(e) == "table" and e.player
			if typeof(p) == "Instance" and p:IsA("Player") then
				local out = R.outcome(eligible, winner, e.team, false, leavers[e.team] == true)
				task.spawn(write, p, p.UserId, p.Name, out, matchId)
			end
		end
		return "ok"
	end
	return "badArg"
end

Players.PlayerAdded:Connect(load)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(load, p) end
