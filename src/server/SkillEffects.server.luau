-- SkillEffects v1.4 (Mecha Dino Arena) — turns the bought skill-tree steps into game effects. MDA-13, plan
-- docs/plans/SKILLTREES_v1.0.md Task 3, ADR "Skill trees own XP and replace class stat points".
-- Reads each player's SkillPath_<pathId> attributes (SkillServer 1.0) through ServerStorage.DinoArcade.SkillTree
-- .effects and writes only attributes existing scripts already read, plus its own shield / bleed bookkeeping:
--   * Stat points (Kepu: the paths replace the class stat points): player StatAdded_Attack / StatAdded_Defense /
--     StatAdded_Speed = attackPts / defensePts / speedPts (StatServer 1.0 re-applies on change; Jaws I +1 Attack,
--     Thick Hide I +1 Defense, Sprint Legs I / II / star +1 / +5 / +1 Speed: II = run speed x1.5).
--   * Cooldowns: at spawn the character's own BiteCooldown / PounceCooldown / RamCooldown / JumpCooldown (else the move
--     scripts' defaults 0.8 / 3 / 6 / 0.5) are kept as SkillBase_<name>; written = base x multiplier. The main attack is
--     the bite while BiteEnabled ~= false, else the pounce (Kepu: Jaws upgrades the main attack): it gets mainCdMul.
--     PounceCooldown / RamCooldown / JumpCooldown get moveCdMul (Sprint Legs III).
--   * Kill heal: KillRegenFraction = SkillBase_KillRegenFraction (the character's own, else 0.25) + killRegenAdd.
--   * Regeneration: every TICK s, while health is below max and at least regenDelay s passed since the last health
--     drop, heal regenRate x MaxHealth per second.
--   * Lifesteal: a new BiteHitAt heals lifesteal x BiteHitDamage; a new PounceBiteAt heals lifesteal x PounceHitDamage.
--   * Overheal shield (Lifesteal star): healing from this script past full health goes into SkillShield (at most
--     shieldMax x MaxHealth), SkillShieldUntil = now + shieldTime (refreshed by each add); at that time it is 0. A
--     health drop while SkillShield > 0 is given back from the shield (a killing blow is not: the dino is already dead).
--   * Stuns (Thick Hide III / star): when StunnedUntil (ShakeOffServer) is set into the future: health above
--     stunImmuneAbove x MaxHealth -> StunnedUntil = now (no stun, SkillStunTrimmed "immune"); else stunMul < 1 -> what
--     is left is scaled by stunMul ("trimmed").
--   * Less knockback (Thick Hide II): when StunTossDistance is set, it is multiplied by tossMul ("tossTrimmed").
--   * Bleed (Jaws III) and crushing hit (Jaws star), on a bite or pounce hit on a bot (IsBot; found by the hit's
--     BiteHitTarget / PounceLatchTarget model name, first in DinoIsland.Bots): bleed = bleedDps per second off the bot's
--     DummyHealth for bleedTime s (a new hit restarts it); if bleed takes DummyHealth from above 0 to 0 it stamps
--     KilledBy, KilledByUserId, KilledWith = "bleed" and, last, KilledAt, exactly like BiteServer 1.6 (so SkillServer XP
--     and KillRegenServer count it). Crushing hit = the bot's StunnedUntil = now + crushStun (BotServer 1.2+ makes a
--     stunned bot lie down), at most once per crushCooldown s per bot.
-- Off: script attribute SkillEffectsEnabled = false -> StatAdded_* 0, every SkillBase_* value written back, shield 0,
--   no regen / lifesteal / stun or toss changes / bleed / crush (SkillEffectsState "off").
-- Diagnostics: script SkillEffectsVersion; character SkillEffectsState ("ready" / "off"), SkillRegenActive,
--   SkillLastHeal ("regen +3" / "lifesteal +2"), SkillShield, SkillShieldUntil, SkillStunTrimmed ("immune" / "trimmed" /
--   "tossTrimmed"), SkillBase_<name>; bot SkillBleedUntil, SkillBleedBy, SkillCrushedAt.
-- v1.1 (mecha Thrusters, MDA-26, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 3; Kepu: dash free, part only while
--   slotted): character DashEnabled = effects on AND dashCharges > 0 AND "thrusters" in SkillSlot1 / SkillSlot2
--   (SkillServer 1.1); DashCharges (0 while off), DashDistance (dashDist), DashHop (0 while off), DashTime and
--   DashRecharge (script attributes SkillDashTime 0.35 / SkillDashRecharge 8). Re-applied when a SkillPath_ or a
--   SkillSlot attribute changes. MechaServer 1.0 / MechaButtons 1.0 read them.
-- v1.2 (Thrusters boost, MDA-31; Kepu: "1.5 s boost, steerable"): DashTime = SkillTree 1.2 dashTime (1.5 s; 2 s from III)
--   while the dash is on (SkillDashTime is the fallback while off); new DashSpeedMul = script attribute SkillDashSpeedMul
--   (default 2: the boost runs at 2x the dino's run speed, MechaButtons 1.1).
-- v1.3 (MDA-35; Kepu: "its an arcade game. i want these boosts to feel significant" -> "Faster: 3x run speed"):
--   SkillDashSpeedMul default 3 (was 2).
-- v1.4 (MDA-36; Kepu: "a little too fast. maybe just make it 1.75 my run speed and 1 second long"): SkillDashSpeedMul
--   default 1.75 (boost length: SkillTree 1.4).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.4"
local TICK = 0.25
local BLEED_TICK = 0.5
local COOLDOWNS = {BiteCooldown = 0.8, PounceCooldown = 3, RamCooldown = 6, JumpCooldown = 0.5}
local KILL_REGEN_DEFAULT = 0.25
local ST = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("SkillTree"))

script:SetAttribute("SkillEffectsVersion", VERSION)
if script:GetAttribute("SkillEffectsEnabled") == nil then script:SetAttribute("SkillEffectsEnabled", true) end
local function on() return script:GetAttribute("SkillEffectsEnabled") ~= false end
for k, v in pairs({SkillDashTime = 0.35, SkillDashRecharge = 8, SkillDashSpeedMul = 1.75}) do -- v1.1; v1.2: + SkillDashSpeedMul; v1.3: 2 -> 3; v1.4: 3 -> 1.75
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end

local function now() return workspace:GetServerTimeNow() end
local function round(x, step) return math.floor(x / step + 0.5) * step end

local function effectsOf(player)
	local steps = {}
	for _, id in ipairs(ST.PATH_ORDER) do steps[id] = player:GetAttribute("SkillPath_" .. id) end
	return ST.effects(steps)
end

local chars = {} -- [char] = {player, hum, e, lastDrop, lastHealth, writing = {[attr] = value last written here}}

-- own writes: the value written is remembered, so the (deferred) change signal it causes is recognised and skipped
local function writeOwn(st, char, attr, value)
	st.writing[attr] = value
	char:SetAttribute(attr, value)
end

-- stat points (player attributes; StatServer applies them)
local function applyStats(player, e)
	local live = on()
	player:SetAttribute("StatAdded_Attack", live and e.attackPts or 0)
	player:SetAttribute("StatAdded_Defense", live and e.defensePts or 0)
	player:SetAttribute("StatAdded_Speed", live and e.speedPts or 0)
end

-- cooldowns and kill heal (character attributes, from the captured bases)
local function applyChar(char, st)
	local e, live = st.e, on()
	local mainIsBite = char:GetAttribute("BiteEnabled") ~= false
	for name in pairs(COOLDOWNS) do
		local mul = 1
		if live then
			if name == "BiteCooldown" and mainIsBite then mul *= e.mainCdMul end
			if name == "PounceCooldown" and not mainIsBite then mul *= e.mainCdMul end
			if name ~= "BiteCooldown" then mul *= e.moveCdMul end
		end
		writeOwn(st, char, name, round(char:GetAttribute("SkillBase_" .. name) * mul, 0.01))
	end
	writeOwn(st, char, "KillRegenFraction", char:GetAttribute("SkillBase_KillRegenFraction") + (live and e.killRegenAdd or 0))
	if not live or e.shieldMax <= 0 then
		char:SetAttribute("SkillShield", 0)
		char:SetAttribute("SkillShieldUntil", nil)
	end
	char:SetAttribute("SkillEffectsState", live and "ready" or "off")
	-- v1.1: Thrusters dash (only while slotted)
	local slotted = false
	for n = 1, ST.SLOTS or 2 do
		if st.player:GetAttribute("SkillSlot" .. n) == "thrusters" then slotted = true end
	end
	local dashOn = live and (e.dashCharges or 0) > 0 and slotted
	char:SetAttribute("DashEnabled", dashOn)
	char:SetAttribute("DashCharges", dashOn and e.dashCharges or 0)
	char:SetAttribute("DashDistance", e.dashDist or 0)
	char:SetAttribute("DashHop", dashOn and e.dashHop or 0)
	char:SetAttribute("DashTime", (dashOn and (e.dashTime or 0) > 0) and e.dashTime or script:GetAttribute("SkillDashTime")) -- v1.2
	char:SetAttribute("DashSpeedMul", script:GetAttribute("SkillDashSpeedMul")) -- v1.2
	char:SetAttribute("DashRecharge", script:GetAttribute("SkillDashRecharge"))
end

-- healing (regen / lifesteal), overflow into the shield
local function heal(char, st, amount, source)
	local hum = st.hum
	if amount <= 0 or hum.Health <= 0 then return end
	local room = hum.MaxHealth - hum.Health
	local toHealth = math.min(room, amount)
	if toHealth > 0 then
		st.lastHealth = hum.Health + toHealth -- our own raise, not a drop
		hum.Health += toHealth
	end
	local over = amount - toHealth
	if over > 0 and st.e.shieldMax > 0 then
		local cap = st.e.shieldMax * hum.MaxHealth
		local shield = math.min(cap, (char:GetAttribute("SkillShield") or 0) + over)
		char:SetAttribute("SkillShield", round(shield, 0.1))
		char:SetAttribute("SkillShieldUntil", now() + st.e.shieldTime)
	end
	char:SetAttribute("SkillLastHeal", ("%s +%d"):format(source, math.floor(amount + 0.5)))
end

-- bots hit by a player
local function findBot(name)
	if type(name) ~= "string" then return nil end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	local m = bots and bots:FindFirstChild(name)
	if m and m:GetAttribute("IsBot") == true then return m end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == name and d:GetAttribute("IsBot") == true then return d end
	end
	return nil
end

local bleeds = {} -- [bot] = {char, player, dps, untilT}
local crushed = setmetatable({}, {__mode = "k"}) -- [bot] = last crush time

local function onHit(char, st, damage, targetName)
	if not on() then return end
	local e = st.e
	if e.lifesteal > 0 and type(damage) == "number" and damage > 0 then heal(char, st, e.lifesteal * damage, "lifesteal") end
	if e.bleedDps <= 0 and e.crushStun <= 0 then return end
	local bot = findBot(targetName)
	if not bot or (tonumber(bot:GetAttribute("DummyHealth")) or 0) <= 0 then return end
	local t = now()
	if e.bleedDps > 0 then
		bleeds[bot] = {char = char, player = st.player, dps = e.bleedDps, untilT = t + e.bleedTime}
		bot:SetAttribute("SkillBleedUntil", t + e.bleedTime)
		bot:SetAttribute("SkillBleedBy", char.Name)
	end
	if e.crushStun > 0 and t - (crushed[bot] or -math.huge) >= e.crushCooldown then
		crushed[bot] = t
		bot:SetAttribute("StunnedUntil", math.max(bot:GetAttribute("StunnedUntil") or 0, t + e.crushStun))
		bot:SetAttribute("SkillCrushedAt", t)
	end
end

-- bleed ticks
task.spawn(function()
	while true do
		task.wait(BLEED_TICK)
		local t = now()
		for bot, b in pairs(bleeds) do
			local hp = tonumber(bot:GetAttribute("DummyHealth"))
			if not bot.Parent or not on() or not hp or hp <= 0 or t > b.untilT then
				bleeds[bot] = nil
				if bot.Parent then bot:SetAttribute("SkillBleedUntil", nil) end
				continue
			end
			local d = b.dps * BLEED_TICK
			bot:SetAttribute("DummyHealth", math.max(0, hp - d))
			if hp - d <= 0 then -- killing blow, stamped like BiteServer 1.6
				bot:SetAttribute("KilledBy", b.char.Name)
				bot:SetAttribute("KilledByUserId", b.player and b.player.UserId or 0)
				bot:SetAttribute("KilledWith", "bleed")
				bot:SetAttribute("KilledAt", t) -- last: SkillServer / KillRegenServer react to this one
				bleeds[bot] = nil
				bot:SetAttribute("SkillBleedUntil", nil)
			end
		end
	end
end)

-- regen + shield expiry
task.spawn(function()
	while true do
		task.wait(TICK)
		local t = now()
		for char, st in pairs(chars) do
			if not char.Parent or st.hum.Health <= 0 then continue end
			local e = st.e
			local regenOn = on() and e.regenRate > 0 and st.hum.Health < st.hum.MaxHealth and t - st.lastDrop >= e.regenDelay
			if char:GetAttribute("SkillRegenActive") ~= regenOn then char:SetAttribute("SkillRegenActive", regenOn) end
			if regenOn then heal(char, st, e.regenRate * st.hum.MaxHealth * TICK, "regen") end
			local untilT = char:GetAttribute("SkillShieldUntil")
			if typeof(untilT) == "number" and t >= untilT then
				char:SetAttribute("SkillShield", 0)
				char:SetAttribute("SkillShieldUntil", nil)
			end
		end
	end
end)

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum or not char.Parent then return end
	-- bases: the character's own values, else the move scripts' defaults
	for name, default in pairs(COOLDOWNS) do
		char:SetAttribute("SkillBase_" .. name, char:GetAttribute(name) or default)
	end
	char:SetAttribute("SkillBase_KillRegenFraction", char:GetAttribute("KillRegenFraction") or KILL_REGEN_DEFAULT)
	local st = {player = player, hum = hum, e = effectsOf(player), lastDrop = -math.huge, lastHealth = hum.Health,
		writing = {}}
	chars[char] = st
	char:SetAttribute("SkillShield", 0)
	applyChar(char, st)

	hum.HealthChanged:Connect(function(h)
		if h < st.lastHealth - 1e-6 then
			st.lastDrop = now()
			local shield = char:GetAttribute("SkillShield") or 0
			if h > 0 and shield > 0 and on() then
				local back = math.min(shield, st.lastHealth - h)
				char:SetAttribute("SkillShield", round(shield - back, 0.1))
				st.lastHealth = h + back
				hum.Health = h + back
				return
			end
		end
		st.lastHealth = h
	end)
	char:GetAttributeChangedSignal("BiteHitAt"):Connect(function()
		onHit(char, st, char:GetAttribute("BiteHitDamage"), char:GetAttribute("BiteHitTarget"))
	end)
	char:GetAttributeChangedSignal("PounceBiteAt"):Connect(function()
		onHit(char, st, char:GetAttribute("PounceHitDamage"), char:GetAttribute("PounceLatchTarget"))
	end)
	char:GetAttributeChangedSignal("BiteEnabled"):Connect(function() applyChar(char, st) end)
	char:GetAttributeChangedSignal("StunnedUntil"):Connect(function()
		local untilT, t = char:GetAttribute("StunnedUntil"), now()
		if untilT == st.writing.StunnedUntil or not on() then return end
		if typeof(untilT) ~= "number" or untilT <= t then return end
		local e = st.e
		if e.stunImmuneAbove > 0 and hum.Health > e.stunImmuneAbove * hum.MaxHealth then
			writeOwn(st, char, "StunnedUntil", t)
			char:SetAttribute("SkillStunTrimmed", "immune")
		elseif e.stunMul < 1 then
			writeOwn(st, char, "StunnedUntil", t + (untilT - t) * e.stunMul)
			char:SetAttribute("SkillStunTrimmed", "trimmed")
		end
	end)
	char:GetAttributeChangedSignal("StunTossDistance"):Connect(function()
		local d = char:GetAttribute("StunTossDistance")
		if d == st.writing.StunTossDistance or not on() or st.e.tossMul >= 1 then return end
		if typeof(d) ~= "number" then return end
		writeOwn(st, char, "StunTossDistance", d * st.e.tossMul)
		char:SetAttribute("SkillStunTrimmed", "tossTrimmed")
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

local function refresh(player)
	local e = effectsOf(player)
	applyStats(player, e)
	for char, st in pairs(chars) do
		if st.player == player then
			st.e = e
			applyChar(char, st)
		end
	end
end

local function onPlayer(player)
	applyStats(player, effectsOf(player))
	player.AttributeChanged:Connect(function(name)
		if name:sub(1, 10) == "SkillPath_" or name:sub(1, 9) == "SkillSlot" then refresh(player) end -- v1.1: + SkillSlot
	end)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

script:GetAttributeChangedSignal("SkillEffectsEnabled"):Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do refresh(p) end
end)
