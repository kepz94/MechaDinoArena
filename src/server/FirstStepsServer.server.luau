-- FirstStepsServer v1.0 (Mecha Dino Arena) — the FIRST STEPS checklist: progress, saves and rewards (Script, ServerScriptService).
-- Kepu 2026-11-27 12:45 "when a new user loads in ... There's no direction"; 12:48 "Okay let's do A with C checklist"; 14:15 pick "A"
--   on docs/mockups/first_steps_v0.1.html (corner PLAY + side checklist); the other picks are the recommended ones (standing rule
--   "whatever the recommended option is ... just choose that"): the steps and rewards as in the mockup table, players who already
--   played get what they already did ticked, the ARENA portal stays. Client side: FirstSteps 1.0 (StarterPlayerScripts).
-- Steps (index: what finishes it; reward = SkillServer.SkillGrantPoints(player, pts, "firststeps"), FsPts "1,1,1,2"):
--   1 PLAY YOUR FIRST MATCH       player ArenaW or ArenaL goes up while ArenaRecordReady was already true (any server kind; bot
--                                  matches count, as ArenaRecordServer counts them)
--   2 SPEND A POINT IN THE LAB    a SkillRequest("buy", ...) whose SkillLastResult reads "ok" 0.3 s later, while TutStep is 0 (the
--                                  tutorial's own spend does not count)
--   3 CLAIM A QUEST AT THE STAND  player QuestLastClaim changes to a new id (QuestServer: a daily or special claimed)
--   4 WIN AN ARENA MATCH          player ArenaW goes up (as in 1)
--   All 4 done -> FsBonus (3) more points once; then FsFinished = true.
-- Store: DataStore FsStoreName ("MDA_FirstSteps_v1"), key "u<UserId>", value {v = 1, d = "1010" (done, one digit per step),
--   p = "1000" (paid), b = true (bonus paid), vet = true (made from an older player's history)}. Load at join (GetAsync, 3 tries 2 s apart). Every
--   change is merged with UpdateAsync (done / paid / bonus flags only ever turn on), so the hub and Arena servers add up.
--   No value yet: a new record. Older player = (ArenaW + ArenaL) > 0 once ArenaRecordReady is true (waited up to FsVetWait (15) s;
--   not ready by then = treated as new): step 1 ticked, step 4 ticked when ArenaW > 0, step 2 ticked when SkillSpent > 0; these
--   ticks are marked paid without a reward (nothing is paid for history); the bonus still comes when the last step is finished.
-- Rewards: a step marked done is paid at once; a grant that is not "ok" (SkillServer not loaded yet, ...) is retried every 5 s while
--   the player is here, and on the next join (done but not paid).
-- Player attributes: FsLoaded (bool), FsDone ("1010": one digit per step), FsFinished (bool), FsLast ("<step>|<pts>|<server time>",
--   step "bonus" for the bonus; the client's toast), FsVet (bool).
-- Switches (script attributes): FsEnabled (true, read at start; false = nothing), FsSaveEnabled (true, read at start; false = kept in
--   memory on this server only, for Studio), FsStoreName, FsPts ("1,1,1,2"), FsBonus (3), FsVetWait (15).
-- Diagnostics: FirstStepsServerVersion, FsState ("off" / "saveOff" / "on" / "noStore"), FsLoads, FsFails, FsMarks, FsGrants,
--   FsGrantFails, FsLastEvent.
-- Test hook (server-only BindableFunction FsTest): Invoke("mark", player, step) -> as if the step happened; Invoke("state", player)
--   -> {done, paid, bonus, vet}; Invoke("reset", player) -> this server forgets the player's record and writes an empty one
--   (Studio / FsSaveEnabled false only: memory).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VERSION = "1.0"
script:SetAttribute("FirstStepsServerVersion", VERSION)
local DEFAULTS = {FsEnabled = true, FsSaveEnabled = true, FsStoreName = "MDA_FirstSteps_v1", FsPts = "1,1,1,2", FsBonus = 3, FsVetWait = 15}
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function A(k) local v = script:GetAttribute(k) if v == nil then return DEFAULTS[k] end return v end
local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end
if A("FsEnabled") == false then script:SetAttribute("FsState", "off") return end
local N = 4
local TRIES, GAP, RETRY = 3, 2, 5

local store
if A("FsSaveEnabled") ~= false then
	local ok, s = pcall(function() return DataStoreService:GetDataStore(A("FsStoreName")) end)
	store = ok and s or nil
end
script:SetAttribute("FsState", A("FsSaveEnabled") == false and "saveOff" or (store and "on" or "noStore"))
local memory = {} -- [userId] = value (FsSaveEnabled false)

local function ptsOf(i)
	local list = {}
	for n in string.gmatch(tostring(A("FsPts")), "%d+") do table.insert(list, tonumber(n)) end
	return math.clamp(list[i] or 1, 1, 100)
end
local function bits(s) -- "1010" -> {true, nil, true, nil}
	local out = {}
	s = type(s) == "string" and s or ""
	for i = 1, N do if s:sub(i, i) == "1" then out[i] = true end end
	return out
end
local function str(t)
	local s = ""
	for i = 1, N do s ..= t[i] and "1" or "0" end
	return s
end
local function clean(v) -- in memory: d / p as tables {[i] = true}
	v = type(v) == "table" and v or {}
	return {v = 1, d = bits(v.d), p = bits(v.p), b = v.b == true, vet = v.vet == true}
end
local function stored(v) -- for the store: d / p as strings
	return {v = 1, d = str(v.d), p = str(v.p), b = v.b, vet = v.vet}
end

local states = {} -- [player] = {done, paid, bonus, vet, loaded, busy}
local function publish(player)
	local st = states[player]
	if not st or player.Parent ~= Players then return end
	local s = ""
	local all = true
	for i = 1, N do
		s ..= st.done[i] and "1" or "0"
		if not st.done[i] then all = false end
	end
	player:SetAttribute("FsDone", s)
	player:SetAttribute("FsFinished", all and st.bonus)
	player:SetAttribute("FsVet", st.vet)
	player:SetAttribute("FsLoaded", st.loaded)
end
local function adopt(st, v)
	for i = 1, N do
		st.done[i] = st.done[i] or v.d[i] == true
		st.paid[i] = st.paid[i] or v.p[i] == true
	end
	st.bonus = st.bonus or v.b
	st.vet = st.vet or v.vet
end
local function save(player)
	local st = states[player]
	if not st then return false end
	local function merge(old)
		local v = clean(old)
		for i = 1, N do
			if st.done[i] then v.d[i] = true end
			if st.paid[i] then v.p[i] = true end
		end
		if st.bonus then v.b = true end
		if st.vet then v.vet = true end
		return v
	end
	if not store then
		memory[player.UserId] = stored(merge(memory[player.UserId]))
		return true
	end
	local after
	local ok, err = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			after = merge(old)
			return stored(after)
		end)
	end)
	if ok and after then
		adopt(st, after)
		return true
	end
	bump("FsFails")
	script:SetAttribute("FsLastEvent", "save " .. player.Name .. ": " .. tostring(err))
	return false
end

local function grant(player, amount)
	local sk = ServerScriptService:FindFirstChild("SkillServer")
	local fn = sk and sk:FindFirstChild("SkillGrantPoints")
	if not fn then return false end
	local ok, r = pcall(function() return fn:Invoke(player, amount, "firststeps") end)
	if ok and r == "ok" then bump("FsGrants") return true end
	bump("FsGrantFails")
	script:SetAttribute("FsLastEvent", "grant " .. player.Name .. ": " .. tostring(r))
	return false
end
local function stamp(player, what, pts)
	player:SetAttribute("FsLast", ("%s|%d|%.2f"):format(what, pts, workspace:GetServerTimeNow()))
end

-- pays every done-but-unpaid step and the bonus; true when nothing is left to pay
local function payDue(player)
	local st = states[player]
	if not st or not st.loaded or player.Parent ~= Players then return true end
	local changed, left = false, false
	for i = 1, N do
		if st.done[i] and not st.paid[i] then
			if grant(player, ptsOf(i)) then
				st.paid[i] = true
				changed = true
				stamp(player, tostring(i), ptsOf(i))
			else
				left = true
			end
		end
	end
	local all = true
	for i = 1, N do if not st.done[i] then all = false end end
	if all and not st.bonus and not left then
		local b = math.clamp(tonumber(A("FsBonus")) or 3, 0, 100)
		if b == 0 or grant(player, b) then
			st.bonus = true
			changed = true
			if b > 0 then task.delay(2.6, function() if player.Parent then stamp(player, "bonus", b) end end) end
		else
			left = true
		end
	end
	if changed then save(player) publish(player) end
	return not left
end
local function retryLoop(player)
	local st = states[player]
	if not st or st.retrying then return end
	st.retrying = true
	task.spawn(function()
		while player.Parent == Players and states[player] == st do
			if payDue(player) then break end
			task.wait(RETRY)
		end
		st.retrying = false
	end)
end

local function mark(player, i, why)
	local st = states[player]
	if not st or not st.loaded or st.done[i] then return end
	st.done[i] = true
	bump("FsMarks")
	script:SetAttribute("FsLastEvent", ("mark %s %d %s"):format(player.Name, i, why or ""))
	save(player)
	publish(player)
	retryLoop(player)
end

local function waitFor(cond, secs)
	local t0 = os.clock()
	while not cond() and os.clock() - t0 < secs do task.wait(0.25) end
	return cond()
end

local function load(player)
	local st = {done = {}, paid = {}, bonus = false, vet = false, loaded = false}
	states[player] = st
	publish(player)
	local value, got = nil, false
	if store then
		for try = 1, TRIES do
			local ok, v = pcall(function() return store:GetAsync("u" .. player.UserId) end)
			if player.Parent ~= Players then return end
			if ok then value, got = v, true break end
			bump("FsFails")
			script:SetAttribute("FsLastEvent", "load " .. player.Name .. ": " .. tostring(v))
			if try < TRIES then task.wait(GAP) end
		end
		if not got then return end -- no load: nothing shows and nothing is marked on this server
	else
		value = memory[player.UserId]
	end
	bump("FsLoads")
	if value ~= nil then
		adopt(st, clean(value))
	else
		-- a new record: an older player's history is ticked (not paid)
		waitFor(function() return player.Parent ~= Players or player:GetAttribute("ArenaRecordReady") == true end, tonumber(A("FsVetWait")) or 15)
		if player.Parent ~= Players then return end
		local w = tonumber(player:GetAttribute("ArenaW")) or 0
		local l = tonumber(player:GetAttribute("ArenaL")) or 0
		if player:GetAttribute("ArenaRecordReady") == true and w + l > 0 then
			st.vet = true
			st.done[1], st.paid[1] = true, true
			if w > 0 then st.done[4], st.paid[4] = true, true end
			if (tonumber(player:GetAttribute("SkillSpent")) or 0) > 0 then st.done[2], st.paid[2] = true, true end
		end
	end
	st.loaded = true
	if value == nil then save(player) end
	publish(player)
	retryLoop(player)
end

-- events
local function watch(player)
	local last = {}
	local function arena(k)
		local function check()
			local v = tonumber(player:GetAttribute(k))
			local ready = player:GetAttribute("ArenaRecordReady") == true
			local was = last[k]
			last[k] = v
			if not (ready and was and v and v > was) then return end
			mark(player, 1, k)
			if k == "ArenaW" then mark(player, 4, k) end
		end
		player:GetAttributeChangedSignal(k):Connect(check)
		player:GetAttributeChangedSignal("ArenaRecordReady"):Connect(function()
			if player:GetAttribute("ArenaRecordReady") ~= true then last[k] = nil else last[k] = tonumber(player:GetAttribute(k)) end
		end)
		if player:GetAttribute("ArenaRecordReady") == true then last[k] = tonumber(player:GetAttribute(k)) end
	end
	arena("ArenaW")
	arena("ArenaL")
	local lastClaim = player:GetAttribute("QuestLastClaim")
	player:GetAttributeChangedSignal("QuestLastClaim"):Connect(function()
		local c = player:GetAttribute("QuestLastClaim")
		if c ~= nil and c ~= lastClaim then mark(player, 3, "quest") end
		lastClaim = c
	end)
end

task.spawn(function()
	local skillRemote = ReplicatedStorage:FindFirstChild("SkillRequest") or ReplicatedStorage:WaitForChild("SkillRequest", 30)
	if not skillRemote then script:SetAttribute("FsLastEvent", "no SkillRequest") return end
	skillRemote.OnServerEvent:Connect(function(player, action)
		if action ~= "buy" then return end
		if (tonumber(player:GetAttribute("TutStep")) or 0) > 0 then return end
		task.delay(0.3, function()
			if player.Parent == Players and player:GetAttribute("SkillLastResult") == "ok" then mark(player, 2, "buy") end
		end)
	end)
end)

local function added(player)
	watch(player)
	task.spawn(load, player)
end
Players.PlayerAdded:Connect(added)
for _, p in ipairs(Players:GetPlayers()) do added(p) end
Players.PlayerRemoving:Connect(function(p) states[p] = nil end)

-- test hook
local hook = script:FindFirstChild("FsTest")
if not hook then
	hook = Instance.new("BindableFunction")
	hook.Name = "FsTest"
	hook.Parent = script
end
hook.OnInvoke = function(action, player, step)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return "badArg" end
	local st = states[player]
	if action == "mark" then
		if type(step) ~= "number" or step < 1 or step > N then return "badArg" end
		mark(player, step, "test")
		return "ok"
	elseif action == "state" then
		return st and {done = st.done, paid = st.paid, bonus = st.bonus, vet = st.vet, loaded = st.loaded} or "none"
	elseif action == "reset" then
		if store then return "storeOn" end
		memory[player.UserId] = nil
		if st then
			st.done, st.paid, st.bonus, st.vet = {}, {}, false, false
			publish(player)
		end
		return "ok"
	end
	return "badArg"
end
