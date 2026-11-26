-- FillerNameCheck v1.0 (Mecha Dino Arena) — a filler bot name that is not a real Roblox username (ModuleScript,
-- ServerStorage.DinoArcade.FillerNameCheck, server only). Filler Bots v1.0 T1b (MDA-574), plan docs/plans/FILLER_BOTS_v1.0.md
-- red-team R4 (Kepu 2026-11-25 21:33 "Check and reroll").
-- pick(rng, used) -> name (yields: one web call per try; call it from a task):
--   up to TRIES (5) times: name = FillerRules.name(rng, used); Players:GetUserIdFromNameAsync(name) in pcall.
--   success with an id (a real account) -> the name stays in `used` (never tried again) and a new one is rolled; an error (no such user, or the
--   web is down) -> the name is accepted. After TRIES real accounts: the last name + 2 random digits, unchecked (FillerRules
--   rules kept: cut to 20 characters). Results are cached per server (cache[name] = "real" / "free").
-- test(name) -> bool: true when the name is free (not a real account), the same check as pick. Studio test hook.
-- Diagnostics (module fields): Checks, Rerolls.
local Players = game:GetService("Players")
local FR = require(script.Parent:WaitForChild("FillerRules"))

local M = {}
M.VERSION = "1.0"
M.TRIES = 5
M.Checks = 0
M.Rerolls = 0

local cache = {}

local function isFree(name)
	if cache[name] ~= nil then return cache[name] == "free" end
	M.Checks += 1
	local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
	local free = not (ok and type(id) == "number" and id > 0)
	cache[name] = free and "free" or "real"
	return free
end

function M.test(name)
	return isFree(tostring(name))
end

function M.pick(rng, used)
	used = used or {}
	local name
	for _ = 1, M.TRIES do
		name = FR.name(rng, used)
		if isFree(name) then return name end
		M.Rerolls += 1
	end
	local n = name .. tostring(rng:NextInteger(10, 99))
	if #n > 20 then n = n:sub(#n - 19) end
	if n:sub(1, 1) == "_" then n = "x" .. n:sub(3) end
	if not FR.valid(n) or used[n] then n = FR.name(rng, used) end
	used[n] = true
	return n
end

return M
