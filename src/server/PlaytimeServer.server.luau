-- PlaytimeServer v1.0 (Mecha Dino Arena) — session playtime rewards (Script, ServerScriptService).
-- Kepu 2026-11-26 16:31 "Let's play time rewards instead. So you get skill points and a skin the longer you play in a session. I've
--   seen it as a new thing in Roblox instead of daily and weekly."; mockup docs/mockups/playtime_rewards_v0.1.html, 16:35 pick "A"
--   (gift chip + track); skin Overtime and the track numbers: standing pick, recommended.
-- Session: one per player while they stay in the game. Every server (hub, Arena match) reads and writes the same MemoryStore hash map
--   entry PlaytimeStoreName ("MDA_Playtime_v1"), key "u<UserId>", value {a = seconds played, c = "100000" (claimed flags per reward)},
--   kept PlaytimeTTL (600) s after the last write, so a trip to an Arena match and back keeps the session, and the session ends 10 min
--   after the player leaves the game. Seconds count while the player is in a server (x PlaytimeTestSpeed, Studio test only).
--   Writes: every PlaytimeSaveGap (30) s and when the player leaves. Store errors: the server keeps counting in memory
--   (PlaytimeStoreKind "memory"); PlaytimeTestMemory (Studio) = memory only.
-- Track (TRACK, seconds): 300 +1 pt, 600 +1 pt, 1200 +2 pts, 1800 +2 pts, 2700 +3 pts, 3600 the Overtime skin (3 pts if owned).
-- Claim: RemoteFunction ReplicatedStorage.PlaytimeRequest:
--   ("state") -> {ok, played, at (server time), claimed = {bool x6}, track = {{t, pts, skin}}}
--   ("claim", i) -> "ok" / "notLoaded" / "badArg" / "notReady" / "claimed" / "busy" / "failed" / "tryAgain", reward text.
--   A claim first sets the flag in the store (UpdateAsync; a flag already set there = "claimed", so two servers cannot pay twice),
--   then pays: points -> ServerScriptService.SkillServer.SkillGrantPoints(player, pts, "playtime"); skin ->
--   ServerScriptService.SkinServer.SkinGrant(player, "overtime", "playtime") ("owned" -> SkillGrantPoints 3 instead). A payment that
--   fails clears the flag again ("tryAgain").
-- Player attributes: PlaytimeBase (seconds at PlaytimeAt), PlaytimeAt (server time; the client adds the time since), PlaytimeClaimed
--   ("100000"), PlaytimeLoaded (bool), PlaytimeLast ("<i>:<result>").
-- Switches / numbers (script attributes): PlaytimeEnabled (true, read at start), PlaytimeStoreName, PlaytimeTTL (600), PlaytimeSaveGap
--   (30), PlaytimeTestSpeed (1), PlaytimeTestMemory (false). Diagnostics: PlaytimeServerVersion, PlaytimeStoreKind ("store" /
--   "memory"), PlaytimeClaims, PlaytimeSaves, PlaytimeStoreErrors.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local SSS = game:GetService("ServerScriptService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 track capped at 30 min
-- v1.1 (Kepu 2026-11-26 16:44 "Nah this is too crazy, cap out at 30 minutes to get the overtime skin"; points spread: standing pick, recommended): TRACK = 300 +1 pt, 600 +1 pt, 900 +1 pt, 1200 +2 pts, 1500 +2 pts, 1800 the Overtime skin (3 pts if owned).
--   Switch: script attribute PlaytimeShortTrackEnabled (true, read at start; false = the 1.0 60 min track). Claimed flags keep their
--   slot numbers (6 rewards either way).
script:SetAttribute("PlaytimeServerVersion", VERSION)
for k, v in pairs({PlaytimeEnabled = true, PlaytimeStoreName = "MDA_Playtime_v1", PlaytimeTTL = 600, PlaytimeSaveGap = 30,
	PlaytimeTestSpeed = 1, PlaytimeTestMemory = false, PlaytimeClaims = 0, PlaytimeSaves = 0, PlaytimeStoreErrors = 0}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
if script:GetAttribute("PlaytimeEnabled") == false then return end

local TRACK = {{t = 300, pts = 1}, {t = 600, pts = 1}, {t = 1200, pts = 2}, {t = 1800, pts = 2}, {t = 2700, pts = 3},
	{t = 3600, skin = "overtime", alt = 3}}
if script:GetAttribute("PlaytimeShortTrackEnabled") == nil then script:SetAttribute("PlaytimeShortTrackEnabled", true) end -- v1.1
if script:GetAttribute("PlaytimeShortTrackEnabled") ~= false then
	TRACK = {{t = 300, pts = 1}, {t = 600, pts = 1}, {t = 900, pts = 1}, {t = 1200, pts = 2}, {t = 1500, pts = 2},
		{t = 1800, skin = "overtime", alt = 3}}
end
local N = #TRACK

local map
if script:GetAttribute("PlaytimeTestMemory") ~= true then
	local ok, m = pcall(function() return MemoryStoreService:GetHashMap(script:GetAttribute("PlaytimeStoreName")) end)
	if ok then map = m end
end
script:SetAttribute("PlaytimeStoreKind", map and "store" or "memory")
local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end
local function ttl() return math.clamp(tonumber(script:GetAttribute("PlaytimeTTL")) or 600, 60, 3600) end
local function keyOf(p) return "u" .. p.UserId end
local function flags(s)
	local out = {}
	for i = 1, N do out[i] = type(s) == "string" and s:sub(i, i) == "1" end
	return out
end
local function flagStr(c)
	local s = ""
	for i = 1, N do s ..= c[i] and "1" or "0" end
	return s
end

local st = {} -- [player] = {a, c, loaded, lastSave, busy}
local function publish(p)
	local s = st[p]
	if not s then return end
	p:SetAttribute("PlaytimeBase", math.floor(s.a))
	p:SetAttribute("PlaytimeAt", workspace:GetServerTimeNow())
	p:SetAttribute("PlaytimeClaimed", flagStr(s.c))
	p:SetAttribute("PlaytimeLoaded", s.loaded == true)
end
local function save(p)
	local s = st[p]
	if not (s and s.loaded and map) then return end
	local a, c = s.a, s.c
	local ok = pcall(function()
		map:UpdateAsync(keyOf(p), function(old)
			local oc = flags(type(old) == "table" and old.c)
			for i = 1, N do oc[i] = oc[i] or c[i] end -- never un-claim from here
			local oa = type(old) == "table" and tonumber(old.a) or 0
			return {a = math.max(a, oa), c = flagStr(oc)}
		end, ttl())
	end)
	if ok then bump("PlaytimeSaves") else bump("PlaytimeStoreErrors") end
	s.lastSave = os.clock()
end

local function onJoin(p)
	local s = {a = 0, c = flags(nil), loaded = false, lastSave = os.clock(), busy = false}
	st[p] = s
	if map then
		local ok, v = false, nil
		for _ = 1, 3 do
			ok, v = pcall(function() return map:GetAsync(keyOf(p)) end)
			if ok then break end
			task.wait(1)
		end
		if ok and type(v) == "table" then
			s.a = math.max(s.a, tonumber(v.a) or 0)
			s.c = flags(v.c)
		elseif not ok then
			bump("PlaytimeStoreErrors")
		end
	end
	if st[p] ~= s then return end
	s.loaded = true
	publish(p)
end
Players.PlayerAdded:Connect(onJoin)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end
Players.PlayerRemoving:Connect(function(p)
	save(p)
	st[p] = nil
end)

-- the clock
task.spawn(function()
	local last = os.clock()
	local pubAt = 0
	while true do
		task.wait(1)
		local now = os.clock()
		local dt = math.min(5, now - last) * math.max(0, tonumber(script:GetAttribute("PlaytimeTestSpeed")) or 1)
		last = now
		local doPub = now - pubAt >= 5
		if doPub then pubAt = now end
		for p, s in pairs(st) do
			s.a += dt
			if doPub or (tonumber(script:GetAttribute("PlaytimeTestSpeed")) or 1) ~= 1 then publish(p) end
			if s.loaded and now - s.lastSave >= (tonumber(script:GetAttribute("PlaytimeSaveGap")) or 30) then task.spawn(save, p) end
		end
	end
end)

local function grantPoints(p, n)
	local fn = SSS:FindFirstChild("SkillServer") and SSS.SkillServer:FindFirstChild("SkillGrantPoints")
	if not fn then return "noSkill" end
	local ok, r = pcall(function() return fn:Invoke(p, n, "playtime") end)
	return ok and r or "failed"
end
local function grantSkin(p, id)
	local fn = SSS:FindFirstChild("SkinServer") and SSS.SkinServer:FindFirstChild("SkinGrant")
	if not fn then return "noSkin" end
	local ok, r = pcall(function() return fn:Invoke(p, id, "playtime") end)
	return ok and r or "failed"
end
-- set / clear one claimed flag in the store; returns true when this call set it
local function storeFlag(p, i, on)
	local s = st[p]
	if not map then return true end
	local won = false
	local ok = pcall(function()
		map:UpdateAsync(keyOf(p), function(old)
			local oc = flags(type(old) == "table" and old.c)
			if on and oc[i] then won = false return nil end
			oc[i] = on
			won = true
			local oa = type(old) == "table" and tonumber(old.a) or 0
			return {a = math.max(s and s.a or 0, oa), c = flagStr(oc)}
		end, ttl())
	end)
	if not ok then bump("PlaytimeStoreErrors") return nil end
	return won
end

local function claim(p, i)
	local s = st[p]
	if not (s and s.loaded) then return "notLoaded" end
	if type(i) ~= "number" or i ~= math.floor(i) or i < 1 or i > N then return "badArg" end
	if s.c[i] then return "claimed" end
	local r = TRACK[i]
	if s.a < r.t then return "notReady" end
	if s.busy then return "busy" end
	s.busy = true
	local set = storeFlag(p, i, true)
	if set == false then
		s.c[i] = true
		s.busy = false
		publish(p)
		return "claimed"
	elseif set == nil then
		s.busy = false
		return "tryAgain"
	end
	s.c[i] = true
	local res, text
	if r.skin then
		local g = grantSkin(p, r.skin)
		if g == "ok" then res, text = "ok", "OVERTIME SKIN UNLOCKED"
		elseif g == "owned" then
			local g2 = grantPoints(p, r.alt)
			if g2 == "ok" then res, text = "ok", "+" .. r.alt .. " SKILL POINTS" else res = "failed" end
		else res = "failed" end
	else
		local g = grantPoints(p, r.pts)
		if g == "ok" then res, text = "ok", "+" .. r.pts .. (r.pts == 1 and " SKILL POINT" or " SKILL POINTS") else res = "failed" end
	end
	if res ~= "ok" then
		s.c[i] = false
		storeFlag(p, i, false)
		res = "tryAgain"
	else
		bump("PlaytimeClaims")
	end
	s.busy = false
	publish(p)
	p:SetAttribute("PlaytimeLast", i .. ":" .. res)
	return res, text
end

local req = ReplicatedStorage:FindFirstChild("PlaytimeRequest") or Instance.new("RemoteFunction")
req.Name = "PlaytimeRequest"
req.Parent = ReplicatedStorage
local lastReq = {}
req.OnServerInvoke = function(p, action, i)
	if os.clock() - (lastReq[p] or 0) < 0.25 then return "busy" end
	lastReq[p] = os.clock()
	if action == "claim" then return claim(p, i) end
	local s = st[p]
	local track = {}
	for k, r in ipairs(TRACK) do track[k] = {t = r.t, pts = r.pts, skin = r.skin} end
	return {ok = s ~= nil and s.loaded == true, played = s and math.floor(s.a) or 0, at = workspace:GetServerTimeNow(),
		claimed = s and table.clone(s.c) or flags(nil), track = track}
end
Players.PlayerRemoving:Connect(function(p) lastReq[p] = nil end)
game:BindToClose(function()
	for p in pairs(st) do task.spawn(save, p) end
	task.wait(2)
end)
