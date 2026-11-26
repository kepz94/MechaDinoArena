-- QuestServer v1.0 (Mecha Dino Arena) — daily quests and the stand specials: progress on every server, claims at the island Quest
-- Stand only (Script, ServerScriptService). Plan docs/plans/QUEST_STAND_v1.0.md Task 2; Kepu 2026-11-26 "3 daily quests ... as well as
-- special quests. this is the only place where you can claim them", "the daily quest rewards will be skill points"; picks "Claim at
-- the stand", "1 / 2 / 3 by difficulty", "Per player", "OK" (part uses = cooldown stamps), "Lost at reset", "Dailies + streak skins
-- first". Quest data / maths: ServerStorage.DinoArcade.QuestRules 1.0.
-- Store: DataStore QuestStoreName ("MDA_Quests_v1"), key "u<UserId>", value {v = 1, day, picks = {[1..3] = quest}, dp = {[id] = n},
--   dc = {[id] = true}, pc = {[specialId] = true}, pend = {[id] = true}}.
--   * Load at join (GetAsync, 3 tries 2 s apart). A value of another day keeps only pc (claimed specials); today's picks come from the
--     value when it has them (so every server uses the same 3), else QuestRules.pickDailies(day, UserId, OwnedDinos) and are saved.
--   * Progress is kept as unsaved deltas (add) / bests (max) and written with UpdateAsync (n = stored + delta, or max), 10 s after a
--     change, on leave and on close, so island and Arena servers add up. A stored value of an older day is replaced by today's; a
--     newer day (this server is behind) drops these deltas.
--   * At 00:00 UTC (checked every second) the player rolls to the new day: new picks, progress and claims of the old day are gone.
-- Events (only the player's current picks / specials care):
--   * Kills: the BindableEvents KillCredit of KillFeedServer and KillRegenServer (killer UserId, victim, KilledAt), one death counted
--     once (victim + KilledAt). ServerKind "hub" -> "ikill", other kinds -> "akill"; and "dkill" when the killer's character Species
--     is the dino quest's dino.
--   * Arena: player ArenaW / ArenaL going up while ArenaRecordReady was already true (the load itself does not count) -> "aplay"
--     (+ the rise), ArenaW -> also "awin".
--   * Island streak: player IslandStreak (SkinStats 1.1) -> "istreak" (max).
--   * Mecha parts: on the player's character a number attribute whose name ends in "ReadyAt" rising to a time in the future, or
--     DashCount rising -> "part" (+1).
-- Requests: RemoteFunction ReplicatedStorage.QuestRequest.
--   * ("state") -> {ok, day, secsToDay, dailies = {{id, diff, text, have, need, pts, claimed}}, specials = {{id, text, have, need,
--     skin, name, claimed}}, ready, ptsToday, near, state}. Does a fresh read of the store first (at most every 3 s), so progress
--     saved by an Arena server shows, and pays pending rewards.
--   * ("claim", id) -> result: "ok" / "notHub" / "notNear" / "notLoaded" / "unknown" / "notReady" / "claimed" / "busy" / "failed".
--     Only on a hub server (ServerKind "hub") with the player's HumanoidRootPart within QuestRange (24) + 6 studs (flat) of
--     Workspace.QuestStand's QuestStandFront. Writes the deltas, then one UpdateAsync sets the claim flag (dc / pc) and pend[id] only
--     if the stored progress (daily) or the player's StatIslandBest (special) still reaches need and it is not claimed. Then the
--     reward: daily -> ServerScriptService.SkillServer.SkillGrantPoints(player, pts, "quest"); special -> SkinServer.SkinGrant(player,
--     skin, "quest"). A paid reward clears pend[id]; an unpaid one stays in pend and is paid on the next state request.
-- Player attributes: QuestState ("loading" / "loaded" / "new" / "off" / "failed"), QuestDay, QuestReady (claimable now),
--   QuestLastResult, QuestLastClaim (id).
-- Switches / numbers (script attributes): QuestEnabled (true, read at start), QuestSaveEnabled (true, read at start; false = memory
--   only, nothing written: the Studio guard), QuestStoreName ("MDA_Quests_v1", read at start), QuestRange (24), QuestSaveGap (10),
--   QuestTestDayOffset (0; days added to the clock, Studio tests of the day roll).
-- Diagnostics: QuestServerVersion, QuestClaims, QuestEvents, QuestSaves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local VERSION = "1.0"
script:SetAttribute("QuestServerVersion", VERSION)
for k, v in pairs({QuestEnabled = true, QuestSaveEnabled = true, QuestStoreName = "MDA_Quests_v1", QuestRange = 24, QuestSaveGap = 10,
	QuestTestDayOffset = 0}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
for _, k in ipairs({"QuestClaims", "QuestEvents", "QuestSaves"}) do script:SetAttribute(k, 0) end
if script:GetAttribute("QuestEnabled") == false then return end

local Q = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("QuestRules"))
local saveOn = script:GetAttribute("QuestSaveEnabled") ~= false
local store
if saveOn then
	local ok, s = pcall(function() return DataStoreService:GetDataStore(tostring(script:GetAttribute("QuestStoreName"))) end)
	store = ok and s or nil
end
local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end
local function A(k, d) return tonumber(script:GetAttribute(k)) or d end
local function now() return workspace:GetServerTimeNow() + A("QuestTestDayOffset", 0) * Q.DAY end
local function today() return Q.day(now()) end
local function isHub() return ReplicatedStorage:GetAttribute("ServerKind") == "hub" end

local remote = ReplicatedStorage:FindFirstChild("QuestRequest")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "QuestRequest"
	remote.Parent = ReplicatedStorage
end

-- [player] = {loaded, day, picks, dp, dc, pc, pend, add = {[id] = n}, best = {[id] = n}, dirty, lastChange, lastRead, busy}
local states = {}

local function clean(v)
	v = type(v) == "table" and v or {}
	local out = {v = 1, day = tonumber(v.day), picks = type(v.picks) == "table" and v.picks or nil, dp = {}, dc = {}, pc = {}, pend = {}}
	for _, f in ipairs({"dp", "dc", "pc", "pend"}) do
		if type(v[f]) == "table" then for k, x in pairs(v[f]) do if type(k) == "string" then out[f][k] = x end end end
	end
	return out
end
local function picksValid(p)
	return type(p) == "table" and type(p[1]) == "table" and type(p[2]) == "table" and type(p[3]) == "table"
end
local function newPicks(player, day)
	return Q.pickDailies(day, player.UserId, Q.ownedList(player:GetAttribute("OwnedDinos")))
end

local function have(st, q)
	local base = tonumber(st.dp[q.id]) or 0
	if q.mode == "max" then return math.max(base, st.best[q.id] or 0) end
	return base + (st.add[q.id] or 0)
end
local function specialHave(player)
	return math.max(tonumber(player:GetAttribute("StatIslandBest")) or 0, tonumber(player:GetAttribute("IslandStreak")) or 0)
end
local function readyCount(player, st)
	local n = 0
	for _, q in ipairs(st.picks or {}) do if Q.claimable(q.need, have(st, q), st.dc[q.id]) then n += 1 end end
	for _, s in ipairs(Q.specials()) do if Q.claimable(s.need, specialHave(player), st.pc[s.id]) then n += 1 end end
	return n
end
local function publish(player)
	local st = states[player]
	if not st then return end
	player:SetAttribute("QuestDay", st.day)
	local n = st.loaded and readyCount(player, st) or 0
	if player:GetAttribute("QuestReady") ~= n then player:SetAttribute("QuestReady", n) end
end

-- adopt a stored value (already cleaned) for today
local function adopt(player, st, v)
	local d = today()
	st.pc = v.pc
	st.pend = v.pend
	if v.day == d then
		st.dp, st.dc = v.dp, v.dc
		if picksValid(v.picks) then st.picks = v.picks end
	else
		st.dp, st.dc = {}, {}
	end
	if not picksValid(st.picks) or st.day ~= d then
		st.picks = picksValid(v.picks) and v.day == d and v.picks or newPicks(player, d)
		st.dirty = true
	end
	st.day = d
end

local function save(player)
	local st = states[player]
	if not (st and st.loaded) then return true end
	st.lastChange = os.clock()
	if not store then st.dirty = false return true end
	local d = st.day
	local sentAdd, sentBest = table.clone(st.add), table.clone(st.best)
	local picks = st.picks
	local stored
	local ok = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			local v = clean(old)
			if (v.day or -1) > d then stored = v return v end -- this server is behind: keep the store, drop ours
			if v.day ~= d then v.day, v.picks, v.dp, v.dc = d, picks, {}, {} end
			if not picksValid(v.picks) then v.picks = picks end
			for id, n in pairs(sentAdd) do v.dp[id] = (tonumber(v.dp[id]) or 0) + n end
			for id, n in pairs(sentBest) do v.dp[id] = math.max(tonumber(v.dp[id]) or 0, n) end
			stored = v
			return v
		end)
	end)
	if not ok or not stored then
		player:SetAttribute("QuestState", "failed")
		return false
	end
	for id, n in pairs(sentAdd) do
		st.add[id] = (st.add[id] or 0) - n
		if st.add[id] <= 0 then st.add[id] = nil end
	end
	for id, n in pairs(sentBest) do if (st.best[id] or 0) <= n then st.best[id] = nil end end
	st.dirty = next(st.add) ~= nil or next(st.best) ~= nil
	adopt(player, st, stored)
	player:SetAttribute("QuestState", "loaded")
	bump("QuestSaves")
	publish(player)
	return true
end

local function load(player)
	local st = {loaded = false, day = today(), picks = nil, dp = {}, dc = {}, pc = {}, pend = {}, add = {}, best = {}, dirty = false,
		lastChange = 0, lastRead = 0, busy = false}
	states[player] = st
	player:SetAttribute("QuestState", "loading")
	if not store then
		adopt(player, st, clean(nil))
		st.loaded = true
		player:SetAttribute("QuestState", "off")
		publish(player)
		return
	end
	for i = 1, 3 do
		if not player.Parent then return end
		local ok, value = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if ok then
			adopt(player, st, clean(value))
			st.loaded = true
			st.lastRead = os.clock()
			player:SetAttribute("QuestState", value == nil and "new" or "loaded")
			publish(player)
			return
		end
		if i < 3 then task.wait(2) end
	end
	player:SetAttribute("QuestState", "failed")
end

-- progress
local function add(player, ev, n, value)
	local st = states[player]
	if not (st and st.loaded and st.picks) then return end
	local hit = false
	for _, q in ipairs(st.picks) do
		if q.ev == ev and not st.dc[q.id] then
			if q.mode == "max" then
				if (value or 0) > (st.best[q.id] or 0) then st.best[q.id] = value hit = true end
			else
				st.add[q.id] = (st.add[q.id] or 0) + n
				hit = true
			end
		end
	end
	if hit then
		st.dirty = true
		st.lastChange = os.clock()
		bump("QuestEvents")
		publish(player)
	end
end

local seen = setmetatable({}, {__mode = "k"})
local function onKill(userId, victim, at)
	local player = Players:GetPlayerByUserId(tonumber(userId) or 0)
	if not (player and states[player]) then return end
	if typeof(victim) == "Instance" then
		local key = type(at) == "number" and at or "fb"
		local s = seen[victim]
		if not s then s = {} seen[victim] = s end
		if s[key] then return end
		s[key] = true
	end
	add(player, isHub() and "ikill" or "akill", 1)
	local st = states[player]
	local sp = player.Character and player.Character:GetAttribute("Species")
	if st and st.picks then
		for _, q in ipairs(st.picks) do
			if q.ev == "dkill" and q.dino == sp and not st.dc[q.id] then
				st.add[q.id] = (st.add[q.id] or 0) + 1
				st.dirty = true
				st.lastChange = os.clock()
				publish(player)
			end
		end
	end
end
for _, name in ipairs({"KillFeedServer", "KillRegenServer"}) do
	task.spawn(function()
		local src = ServerScriptService:WaitForChild(name, 60)
		local ev = src and src:WaitForChild("KillCredit", 60)
		if ev and ev:IsA("BindableEvent") then ev.Event:Connect(onKill) end
	end)
end

local function hookCharacter(player, c)
	local last = {}
	for k, v in pairs(c:GetAttributes()) do if type(v) == "number" then last[k] = v end end
	c.AttributeChanged:Connect(function(name)
		local v = c:GetAttribute(name)
		if type(v) ~= "number" then last[name] = nil return end
		local was = last[name]
		last[name] = v
		if name == "DashCount" then
			if v > (was or 0) then add(player, "part", 1) end -- the first dash sets DashCount from nothing to 1
		elseif name:sub(-7) == "ReadyAt" and (was == nil or v > was) and v > workspace:GetServerTimeNow() + 0.05 then
			add(player, "part", 1)
		end
	end)
end

local function onPlayer(player)
	task.spawn(load, player)
	local arena = {}
	local function arenaWatch(k)
		player:GetAttributeChangedSignal(k):Connect(function()
			local v = tonumber(player:GetAttribute(k))
			local was = arena[k]
			arena[k] = v
			if not (v and was and player:GetAttribute("ArenaRecordReady") == true) or v <= was then return end
			add(player, "aplay", v - was)
			if k == "ArenaW" then add(player, "awin", v - was) end
		end)
	end
	local function snap()
		if player:GetAttribute("ArenaRecordReady") == true then
			arena.ArenaW, arena.ArenaL = tonumber(player:GetAttribute("ArenaW")), tonumber(player:GetAttribute("ArenaL"))
		end
	end
	player:GetAttributeChangedSignal("ArenaRecordReady"):Connect(snap)
	snap()
	arenaWatch("ArenaW")
	arenaWatch("ArenaL")
	player:GetAttributeChangedSignal("IslandStreak"):Connect(function()
		local v = tonumber(player:GetAttribute("IslandStreak")) or 0
		if v > 0 then add(player, "istreak", 0, v) end
		publish(player)
	end)
	player:GetAttributeChangedSignal("StatIslandBest"):Connect(function() publish(player) end)
	player.CharacterAdded:Connect(function(c) hookCharacter(player, c) end)
	if player.Character then hookCharacter(player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerRemoving:Connect(function(player)
	local st = states[player]
	if st and st.loaded and st.dirty then save(player) end
	states[player] = nil
end)
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local st = states[player]
		if st and st.loaded and st.dirty then save(player) end
	end
end)
task.spawn(function()
	while true do
		task.wait(1)
		local d = today()
		for player, st in pairs(states) do
			if st.loaded and st.day ~= d then -- the day rolled: today's picks, the old day's progress and claims are gone
				st.add, st.best = {}, {}
				adopt(player, st, {v = 1, day = d, dp = {}, dc = {}, pc = st.pc, pend = st.pend})
				publish(player)
			end
			if st.loaded and st.dirty and not st.busy and os.clock() - st.lastChange >= A("QuestSaveGap", 10) then
				task.spawn(save, player)
			end
		end
	end
end)

-- rewards
local function grant(player, id)
	if id:sub(1, 2) == "s_" then
		local sk
		for _, s in ipairs(Q.specials()) do if s.id == id then sk = s.skin end end
		local ss = ServerScriptService:FindFirstChild("SkinServer")
		local fn = ss and ss:FindFirstChild("SkinGrant")
		if not (sk and fn) then return false end
		local ok, r = pcall(function() return fn:Invoke(player, sk, "quest") end)
		return ok and (r == "ok" or r == "owned")
	end
	local st = states[player]
	local pts
	for _, q in ipairs(st and st.picks or {}) do if q.id == id then pts = q.pts end end
	if not pts then local diff = tonumber(id:match("^d%d+_(%d)_")) pts = diff and Q.PTS[diff] end
	local sk = ServerScriptService:FindFirstChild("SkillServer")
	local fn = sk and sk:FindFirstChild("SkillGrantPoints")
	if not (pts and fn) then return false end
	local ok, r = pcall(function() return fn:Invoke(player, pts, "quest") end)
	return ok and r == "ok"
end
local function clearPend(player, id)
	local st = states[player]
	if not st then return end
	st.pend[id] = nil
	if not store then return end
	pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			local v = clean(old)
			v.pend[id] = nil
			return v
		end)
	end)
end
local function payPending(player)
	local st = states[player]
	if not st then return end
	for id in pairs(table.clone(st.pend)) do
		if grant(player, id) then clearPend(player, id) end
	end
end

local function nearStand(player)
	local stand = workspace:FindFirstChild("QuestStand")
	local f = stand and stand:GetAttribute("QuestStandFront")
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (typeof(f) == "Vector3" and hrp) then return false end
	return Vector3.new(hrp.Position.X - f.X, 0, hrp.Position.Z - f.Z).Magnitude <= A("QuestRange", 24) + 6
end

local function claim(player, id)
	local st = states[player]
	if not isHub() then return "notHub" end
	if not (st and st.loaded) then return "notLoaded" end
	if type(id) ~= "string" then return "unknown" end
	if not nearStand(player) then return "notNear" end
	if st.busy then return "busy" end
	local q, special
	for _, x in ipairs(st.picks or {}) do if x.id == id then q = x end end
	for _, s in ipairs(Q.specials()) do if s.id == id then q, special = s, true end end
	if not q then return "unknown" end
	st.busy = true
	if st.dirty and not save(player) then st.busy = false return "failed" end
	local result = "failed"
	if not store then -- memory only
		if special then
			if st.pc[id] then result = "claimed" elseif specialHave(player) < q.need then result = "notReady" else st.pc[id], st.pend[id], result = true, true, "ok" end
		else
			if st.dc[id] then result = "claimed" elseif have(st, q) < q.need then result = "notReady" else st.dc[id], st.pend[id], result = true, true, "ok" end
		end
	else
		local best = specialHave(player)
		local d = st.day
		local stored
		local ok = pcall(function()
			store:UpdateAsync("u" .. player.UserId, function(old)
				local v = clean(old)
				stored, result = v, "failed"
				if special then
					if v.pc[id] then result = "claimed" return nil end
					if best < q.need then result = "notReady" return nil end
					v.pc[id] = true
				else
					if v.day ~= d then result = "notReady" return nil end
					if v.dc[id] then result = "claimed" return nil end
					local n = tonumber(v.dp[id]) or 0
					if n < q.need then result = "notReady" return nil end
					v.dc[id] = true
				end
				v.pend[id] = true
				result = "ok"
				return v
			end)
		end)
		if not ok then result = "failed" end
		if result == "ok" and stored then adopt(player, st, stored) end
	end
	st.busy = false
	if result == "ok" then
		bump("QuestClaims")
		player:SetAttribute("QuestLastClaim", id)
		if grant(player, id) then clearPend(player, id) end
	end
	publish(player)
	return result
end

local function view(player)
	local st = states[player]
	if not (st and st.loaded) then return {ok = false, state = player:GetAttribute("QuestState")} end
	local out = {ok = true, day = st.day, secsToDay = math.floor(Q.secsToDay(now())), dailies = {}, specials = {}, ptsToday = 0,
		near = nearStand(player), state = player:GetAttribute("QuestState")}
	for _, q in ipairs(st.picks or {}) do
		local h = have(st, q)
		table.insert(out.dailies, {id = q.id, diff = q.diff, text = q.text, have = math.min(h, q.need), need = q.need, pts = q.pts,
			claimed = st.dc[q.id] == true})
		if st.dc[q.id] then out.ptsToday += q.pts end
	end
	local best = specialHave(player)
	for _, s in ipairs(Q.specials()) do
		table.insert(out.specials, {id = s.id, text = s.text, have = math.min(best, s.need), need = s.need, skin = s.skin, name = s.name,
			claimed = st.pc[s.id] == true})
	end
	out.ready = readyCount(player, st)
	return out
end

local lastReq = setmetatable({}, {__mode = "k"})
remote.OnServerInvoke = function(player, action, id)
	if os.clock() - (lastReq[player] or 0) < 0.25 then return action == "claim" and "busy" or view(player) end
	lastReq[player] = os.clock()
	if action == "claim" then
		local r = claim(player, id)
		player:SetAttribute("QuestLastResult", r)
		return r, view(player)
	end
	local st = states[player]
	if st and st.loaded and store and not st.busy and os.clock() - st.lastRead >= 3 then
		st.lastRead = os.clock()
		if st.dirty then save(player) else
			local ok, value = pcall(function() return store:GetAsync("u" .. player.UserId) end)
			if ok then adopt(player, st, clean(value)) end
		end
	end
	if st and st.loaded and next(st.pend) then payPending(player) end
	publish(player)
	return view(player)
end
