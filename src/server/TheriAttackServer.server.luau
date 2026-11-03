-- TheriAttackServer v1.0 (Mecha Dino Arena) — the Therizinosaurus' 3-hit claw combo (server authority). MDA-201, plan
-- docs/plans/THERIZINO_KIT_v1.0.md Task 4 (deterministic map), mockup docs/mockups/therizino_kit_options_v0.3.html
-- (Kepu 2026-11-02: attack "3-hit combo", payoff "Damage only", picks "A Reaper Sweeps"; animation "I like this one").
-- Pattern: TenoAttackServer 1.4's scratch path (request -> server checks -> hit resolved at a fixed delay in a front zone),
-- its target / mode / squad / shield / damage rules copied (not shared: TenoAttackServer is untouched).
-- Who: player characters with the model attribute TheriAttackEnabled == true (TherizinoModelData 1.3).
-- Remote ReplicatedStorage.DinoTheriAttack (RemoteEvent), client -> server: (stamp) = one ATTACK tap (TheriAttackTest 1.0).
--   Checks in order -> TheriAttackServerResult (+ TheriAttackServerResultAt): "badArg" (stamp not a number), "dead",
--   "disabled" (TheriAttackEnabled not true or the script switch off), "menu" (player InMenu), "stunned" (StunnedUntil),
--   "dazed" (DazedUntil), "pinned" (PinHeld), "recover" (within TheriFinisherRecover s of the finisher tap), "cooldown"
--   (within TheriMinGap s of the last tap) -> "ok".
-- Combo (server-owned, per character): step 0 = ready. An accepted tap is the next step when the last tap was step 1 or 2
--   and at most TheriChainWindow s ago; otherwise it is step 1 (also after the finisher's recovery). Step 1 = right cut,
--   2 = left cut, 3 = rear-up double chop (finisher).
-- Hit: at the tap's stamp (clamped to [now - delay, now]) + TheriHitDelayN (N = the step): every allowed target whose nearest
--   hitbox is within TheriReach x scale (step 3: TheriReach3) of the root and whose root is inside TheriCone degrees centred
--   on the facing takes TheriHitDamageN x takenMul (none while EnergyShieldUntil > now). Damage only (no shove, no stun).
--   A pending hit is cancelled (TheriComboCancelAt) when the therizino is dead / stunned / dazed / pinned at the hit time;
--   the combo then restarts at step 1.
-- Targets (TenoAttackServer 1.4 rules): players' characters and Workspace.DinoIsland.Bots models with Hitboxes, Bitable,
--   Species or IsBot, not self, not KO, alive; players only where ModeRules.canAffect allows; never a squadmate.
-- Numbers (model attributes; defaults below): TheriHitDamage1 / 2 / 3 9 / 9 / 20, TheriHitDelay1 / 2 / 3 0.30 / 0.33 / 0.55,
--   TheriReach 7, TheriReach3 8 (x the character's scale), TheriCone 100, TheriMinGap 0.33, TheriChainWindow 0.8,
--   TheriFinisherRecover 0.9.
-- Stamps (character): TheriComboStep (1-3), TheriComboAt (server time of the accepted tap, set last: poses / FX react to it);
--   at the hit: TheriHitStep, TheriHitTargets ("|" joined names), TheriHitPoint (in front of the root, for FX), TheriHitCount,
--   TheriHitAt (last). Kills: KilledWith "thericlaw".
-- Switches (script attributes): TheriAttackServerEnabled (default true, read at start), TheriAttackModeRulesEnabled (default
--   true; false = players can always be hit), TheriAttackSquadEnabled (default true).
-- Diagnostics: script TheriAttackServerVersion, TheriAttackRequests, TheriAttackTaps, TheriAttackHits, TheriAttackCancels,
--   TheriAttackSquadSkips, TheriAttackMode.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
local DEFAULTS = {TheriHitDamage1 = 9, TheriHitDamage2 = 9, TheriHitDamage3 = 20, TheriHitDelay1 = 0.3, TheriHitDelay2 = 0.33,
	TheriHitDelay3 = 0.55, TheriReach = 7, TheriReach3 = 8, TheriCone = 100, TheriMinGap = 0.33, TheriChainWindow = 0.8,
	TheriFinisherRecover = 0.9}
local MAX_DELAY = 0.6

script:SetAttribute("TheriAttackServerVersion", VERSION)
for _, k in ipairs({"TheriAttackRequests", "TheriAttackTaps", "TheriAttackHits", "TheriAttackCancels", "TheriAttackSquadSkips"}) do
	script:SetAttribute(k, 0)
end
for _, k in ipairs({"TheriAttackServerEnabled", "TheriAttackModeRulesEnabled", "TheriAttackSquadEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local enabled = script:GetAttribute("TheriAttackServerEnabled") ~= false

local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function get(char, k) return num(char, k, DEFAULTS[k]) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

-- mode + squad rules (TenoAttackServer 1.4) ------------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TheriAttackMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("TheriAttackSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		count("TheriAttackSquadSkips")
		return true
	end
	return false
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	if script:GetAttribute("TheriAttackModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end

-- targets (TenoAttackServer 1.4 rules) -------------------------------------------------------------------------------------
local function isTarget(m, self)
	if not (m:IsA("Model") and m ~= self and m:IsDescendantOf(workspace)) then return false end
	if not m:FindFirstChild("Hitboxes") or m:GetAttribute("Bitable") ~= true then return false end
	if m:GetAttribute("Species") == nil and m:GetAttribute("IsBot") ~= true then return false end
	if m:GetAttribute("DummyState") == "ko" then return false end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return false end
	return rootOf(m) ~= nil
end
local function bots()
	local isl = workspace:FindFirstChild("DinoIsland")
	local f = isl and isl:FindFirstChild("Bots")
	return f and f:GetChildren() or {}
end
local function candidates(self)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c and isTarget(c, self) and mayAffect(self, c) then table.insert(list, c) end
	end
	for _, b in ipairs(bots()) do
		if isTarget(b, self) and mayAffect(self, b) then table.insert(list, b) end
	end
	return list
end
local function gap(m, pos) -- nearest distance from a point to the target's hitboxes
	local best = math.huge
	local hb = m:FindFirstChild("Hitboxes")
	for _, p in ipairs(hb and hb:GetChildren() or {}) do
		if p:IsA("BasePart") then
			local lp = p.CFrame:PointToObjectSpace(pos)
			local h = p.Size / 2
			local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
			best = math.min(best, (lp - c).Magnitude)
		end
	end
	if best == math.huge then
		local r = rootOf(m)
		best = r and (r.Position - pos).Magnitude or math.huge
	end
	return best
end
local function shielded(m, t) return num(m, "EnergyShieldUntil", 0) > t end
local function takenMul(m, t)
	local mul = 1
	local u, dm = m:GetAttribute("DebuffUntil"), m:GetAttribute("DebuffDamageTakenMul")
	if typeof(u) == "number" and typeof(dm) == "number" and t < u then mul = dm end
	if num(m, "DazedUntil", 0) > t then mul *= math.max(1, num(m, "DazedDamageMul", 1)) end
	if num(m, "StunBreakImmuneUntil", 0) > t then mul = 0 end
	return mul
end
local function takeHealth(m, d, char, player, t)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player.UserId)
		m:SetAttribute("KilledWith", "thericlaw")
		m:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
	end
end

-- combo -------------------------------------------------------------------------------------------------------------------
local states = setmetatable({}, {__mode = "k"})
local function track(char)
	local st = states[char]
	if not st then
		st = {step = 0, lastTap = -math.huge, finisherAt = -math.huge}
		states[char] = st
	end
	return st
end
local function setResult(char, r, t)
	char:SetAttribute("TheriAttackServerResult", r)
	char:SetAttribute("TheriAttackServerResultAt", t)
end
local function blocked(player, char, t) -- the checks shared by the tap and the hit
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not rootOf(char) then return "dead" end
	if player:GetAttribute("InMenu") == true then return "menu" end
	if num(char, "StunnedUntil", 0) > t then return "stunned" end
	if num(char, "DazedUntil", 0) > t then return "dazed" end
	if char:GetAttribute("PinHeld") == true then return "pinned" end
	return nil
end

local function resolve(player, char, st, step)
	local ti = now()
	if not char.Parent then return end
	if blocked(player, char, ti) then
		st.step = 0
		count("TheriAttackCancels")
		char:SetAttribute("TheriComboCancelAt", ti)
		return
	end
	local root = rootOf(char)
	local s = char:GetScale()
	local fwd = flat(root.CFrame.LookVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.zAxis
	local reach = math.max(0, get(char, step == 3 and "TheriReach3" or "TheriReach")) * s
	local half = math.rad(math.clamp(get(char, "TheriCone"), 0, 360) / 2)
	local dmg = math.max(0, get(char, "TheriHitDamage" .. step))
	local n, names = 0, {}
	for _, m in ipairs(candidates(char)) do
		local v = flat(rootOf(m).Position - root.Position)
		if v.Magnitude > 1e-3 and math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= half and gap(m, root.Position) <= reach then
			if not shielded(m, ti) then takeHealth(m, dmg * takenMul(m, ti), char, player, ti) end
			n += 1
			table.insert(names, m.Name)
		end
	end
	count("TheriAttackHits", n)
	char:SetAttribute("TheriHitStep", step)
	char:SetAttribute("TheriHitTargets", table.concat(names, "|"))
	char:SetAttribute("TheriHitPoint", root.Position + fwd * reach * 0.6)
	char:SetAttribute("TheriHitCount", (char:GetAttribute("TheriHitCount") or 0) + 1)
	char:SetAttribute("TheriHitAt", ti) -- last: TheriFX reacts to this one
end

local remote = ReplicatedStorage:FindFirstChild("DinoTheriAttack")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoTheriAttack"
	remote.Parent = ReplicatedStorage
end

remote.OnServerEvent:Connect(function(player, stamp)
	count("TheriAttackRequests")
	local char = player.Character
	if not char then return end
	local t = now()
	local st = track(char)
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		r = "badArg"
	elseif not char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
		r = "dead"
	elseif not enabled or char:GetAttribute("TheriAttackEnabled") ~= true then
		r = "disabled"
	else
		r = blocked(player, char, t)
	end
	local since = t - st.lastTap
	if not r and st.step == 3 and t - st.finisherAt < math.max(0, get(char, "TheriFinisherRecover")) then
		r = "recover"
	elseif not r and since < math.max(0, get(char, "TheriMinGap")) then
		r = "cooldown"
	end
	if r then
		setResult(char, r, t)
		return
	end
	local step = 1
	if (st.step == 1 or st.step == 2) and since <= math.max(0, get(char, "TheriChainWindow")) then step = st.step + 1 end
	st.step, st.lastTap = step, t
	if step == 3 then st.finisherAt = t end
	count("TheriAttackTaps")
	setResult(char, "ok", t)
	char:SetAttribute("TheriComboStep", step)
	char:SetAttribute("TheriComboAt", t) -- last: poses + FX
	local d = math.clamp(get(char, "TheriHitDelay" .. step), 0, MAX_DELAY)
	local delay = math.clamp(math.min(stamp, t) + d - t, 0, d)
	task.delay(delay, resolve, player, char, st, step)
end)
