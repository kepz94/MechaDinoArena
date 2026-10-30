-- SkillEffects v1.18 (Mecha Dino Arena) — turns the bought skill-tree steps into game effects. MDA-13, plan
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
-- v1.5 (Cloak release, MDA-50, plan docs/plans/CLOAK_v1.0.md Task 2; SkillTree 1.5): Cloak Field. Character
--   CloakEnabled = effects on AND cloakTime > 0 AND "cloak" in any SkillSlot1..SLOTS (4); CloakTime, CloakCooldown,
--   CloakPounceMul (1 while off), CloakStill (false while off). Written with the dash attributes (same re-apply
--   triggers). CloakServer 1.0 / MechaButtons 1.4 / AbilityBar 1.2 read them.
-- v1.8 (raptor parts batch 2, MDA-71, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 2; SkillTree 1.9), written with the
--   other part attributes, only while the part is bought AND in a slot (0 / false otherwise):
--   * Scent Sense: ScentEnabled, ScentRadius, ScentMemory, ScentTime, ScentCooldown, ScentFresh, ScentBlood
--     (ScentServer 1.0 / ScentFX 1.0 read them).
--   * Raptor Screech: ScreechEnabled, ScreechRange, ScreechFlinch, ScreechCooldown, ScreechJam (ScreechServer 1.0 /
--     MechaButtons 1.8 read them).
-- v1.9 (raptor traps, MDA-80, plan docs/plans/RAPTOR_TRAPS_v1.0.md Task 2; SkillTree 1.12): Shock Mine (path "traps"),
--   only while bought AND slotted: MineEnabled, MineDamage, MineSlow (speed multiplier, 1 when off), MineSlowTime,
--   MineCooldown, MineMax, MineJam (MineServer 1.0 / MechaButtons 1.11 / AbilityBar 1.5 read them).
-- v1.10 (MDA-81; SkillTree 1.13): + MineLaunch (studs) and MineDaze (s), 0 when off (MineServer 1.1).
-- v1.15 (pachy Mecha Legs, MDA-123; SkillTree 1.22): on a pachy with the line bought: JumpBoost = SkillBase_JumpBoost x
--   legsBoostMul, JumpLaunchPower = SkillBase_JumpLaunchPower x legsPowerMul (bases kept at the first write), JumpCooldown =
--   legsCooldown x legsCdMul x moveCdMul (one cooldown for the leap and its double jump), JumpDoubleEnabled (star),
--   JumpDoubleMul 0.894 (80% of a leap's height), MechaLegsLook (star). Not bought / not a pachy / effects off -> the
--   bases back, JumpDoubleEnabled / MechaLegsLook false (JumpCooldown stays the 1.14 value). Switch: script attribute
--   SkillEffectsLegsEnabled (default true, read at start; false = 1.14).
-- v1.16 (Kepu 2026-10-30: "mecha legs should take up an ability slot"; SkillTree 1.23): Mecha Legs is on only while
--   "mechalegs" is in a slot (SkillSlot1-4), like the other parts. Character MechaLegsEnabled (true while on; the slot
--   tiles read it). Switch: script attribute SkillEffectsLegsSlotEnabled (default true, read at start; false = 1.15).
--   Also: JumpDoubleMul = e.legsDoubleMul (SkillTree 1.23: 1 = a full leap; 0.894 before) and JumpDoubleForward =
--   e.legsDoubleForward (studs/s, JumpTest 1.2; 0 when off).
-- v1.17 (pachy Blood Rush, MDA-124; SkillTree 1.24): on a pachy with "bloodrush" bought AND slotted: BloodRushEnabled
--   true, BloodRushCost (0.25), BloodRushMax (2), BloodRushDamageMul (II 1.25), BloodRushNoSelfSlow (III), BloodRushSlowMul /
--   BloodRushSlowTime (star 0.45 / 4); otherwise false / 0 / 0 / 1 / false / 1 / 0. HeadbuttServer 1.5, HeadbuttTest 1.1
--   and the HUD read them. Switch: script attribute SkillEffectsBloodEnabled (default true, read at start; false = 1.16).
-- v1.18 (Kepu 2026-10-30: "yes lets apply the bleeding to other players then. but shorten the time for bleeding so not
--   every pounce on another raptor is one shot"; earlier: "whatever works against bots works against players same
--   mechanic"): the Jaws III / Blade Claws III bleed also hits a player's dino. When the hit's target name is not a bot,
--   a Workspace player character with that name that ArenaPvP bridges (ArenaPvPBridged and Bitable true: the Arena only,
--   never in the menu) bleeds the same dps off its DummyHealth (ArenaPvP turns each drop into damage; an Energy Shield
--   blocks it there) for script attribute SkillBleedPlayerTime s (default 2; bots keep their 4 s), a new hit restarts
--   it, a killing tick stamps KilledBy / KilledByUserId / KilledWith "bleed" / KilledAt (last) and, for ArenaPvP's
--   credit, LastHitBy / LastHitAt. Target attributes SkillBleedUntil / SkillBleedBy as on bots. Switch: script
--   attribute SkillBleedPlayersEnabled (default true, read at start; false = 1.17, bots only). ArenaPvP's test target
--   (ArenaPvPTestTarget, bridged like a player) counts as a player's dino, for Studio checks.
-- v1.14 (pachy Grappling Hook, MDA-121; SkillTree 1.21): HookEnabled (bought, in a slot, Species "Pachy", effects on),
--   HookRange, HookCooldown, HookDamage (0 when off) and HookLook (= HookEnabled; the wrist claw is shown). HookServer 1.0
--   reads them. A new HookHitAt runs onHit like a bite (lifesteal). Switch: script attribute SkillEffectsHookEnabled
--   (default true, read at start; false = 1.13).
-- v1.13 (pachy Drop 2, Battering Dome; SkillTree 1.20): on a pachy character (Species "Pachy") the line is written as
--   HeadbuttDamageMul (1 / 1.25), HeadbuttShoveMul (1 / 1.3), HeadbuttRefillMul (1 / 0.7), HeadbuttExtraCharges (0 / 1)
--   and PachySpikes (false / true at the star); HeadbuttServer 1.1 / PachyLook 1.0 read them. Other species and effects
--   off -> 1 / 1 / 1 / 0 / false. Switch: script attribute SkillEffectsDomeEnabled (default true, read at start; false =
--   1.12, nothing written).
-- v1.12 (pachy headbutt, MDA-120, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 10): a new HeadbuttHitAt (HeadbuttServer
--   1.0, set last) counts as a hit like a bite: onHit with HeadbuttHitDamage / HeadbuttHitTarget (lifesteal heals
--   lifesteal x damage; Jaws' bleed / crush only if bought, and SkillTree 1.19 keeps Jaws off the pachy). Switch: script
--   attribute SkillEffectsHeadbuttEnabled (default true, read at start; false = 1.11).
-- v1.11 (MDA-83; SkillTree 1.14): + ScreechDamage (Shock Cannon star heavy shot, 30; 0 otherwise or when off).
-- v1.7 (Kepu 2026-10-29: thrusters "a little more of a speed boost" -> "2x run speed"): SkillDashSpeedMul default 2
--   (was 1.75).
-- v1.6 (raptor parts batch 1, MDA-59, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 2; SkillTree 1.6). Written with the
--   dash / cloak attributes (same re-apply triggers); everything is 0 / 1 / false while effects are off:
--   * Blade Claws (passive, bought is enough): BladeLook (steps >= 1), BladeLandBonus (0 / 0.35), BladeTickMul
--     (1 / 0.74), BladeBleedDps / BladeBleedTime (0 / 3 / 4), BladePinRefund (0 / 0.5). PounceServer 1.6 / BladeServer 1.0
--     read them. Pounce hits (PounceBiteAt) bleed with the stronger of Jaws' bleed and BladeBleedDps (time from the
--     same source); bites keep Jaws' bleed only.
--   * Adrenaline Injector (bought AND in any slot): AdrenalineEnabled, AdrenalineHeal, AdrenalineTime,
--     AdrenalineSpeedMul (1 while off), AdrenalineCooldown, AdrenalineStunClear. AdrenalineServer 1.0 reads them.
--   * Energy Shield (bought AND in any slot): EnergyShieldEnabled, EnergyShieldTime, EnergyShieldCooldown,
--     EnergyShieldSpeedMul (1 while off). EnergyShieldServer 1.0 / SprintTest 1.6 read them.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.18"
if script:GetAttribute("SkillBleedPlayersEnabled") == nil then script:SetAttribute("SkillBleedPlayersEnabled", true) end -- v1.18
local BLEED_PLAYERS = script:GetAttribute("SkillBleedPlayersEnabled") ~= false
if script:GetAttribute("SkillBleedPlayerTime") == nil then script:SetAttribute("SkillBleedPlayerTime", 2) end -- v1.18
if script:GetAttribute("SkillEffectsBloodEnabled") == nil then script:SetAttribute("SkillEffectsBloodEnabled", true) end -- v1.17
local BLOOD_ON = script:GetAttribute("SkillEffectsBloodEnabled") ~= false
if script:GetAttribute("SkillEffectsLegsEnabled") == nil then script:SetAttribute("SkillEffectsLegsEnabled", true) end -- v1.15
local LEGS_ON = script:GetAttribute("SkillEffectsLegsEnabled") ~= false
if script:GetAttribute("SkillEffectsLegsSlotEnabled") == nil then script:SetAttribute("SkillEffectsLegsSlotEnabled", true) end -- v1.16
local LEGS_SLOT = script:GetAttribute("SkillEffectsLegsSlotEnabled") ~= false
if script:GetAttribute("SkillEffectsHookEnabled") == nil then script:SetAttribute("SkillEffectsHookEnabled", true) end -- v1.14
local HOOK_ON = script:GetAttribute("SkillEffectsHookEnabled") ~= false
if script:GetAttribute("SkillEffectsDomeEnabled") == nil then script:SetAttribute("SkillEffectsDomeEnabled", true) end -- v1.13
local DOME_ON = script:GetAttribute("SkillEffectsDomeEnabled") ~= false
if script:GetAttribute("SkillEffectsHeadbuttEnabled") == nil then script:SetAttribute("SkillEffectsHeadbuttEnabled", true) end -- v1.12
local HEADBUTT_HITS = script:GetAttribute("SkillEffectsHeadbuttEnabled") ~= false
local TICK = 0.25
local BLEED_TICK = 0.5
local COOLDOWNS = {BiteCooldown = 0.8, PounceCooldown = 3, RamCooldown = 6, JumpCooldown = 0.5}
local KILL_REGEN_DEFAULT = 0.25
local ST = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("SkillTree"))

script:SetAttribute("SkillEffectsVersion", VERSION)
if script:GetAttribute("SkillEffectsEnabled") == nil then script:SetAttribute("SkillEffectsEnabled", true) end
local function on() return script:GetAttribute("SkillEffectsEnabled") ~= false end
for k, v in pairs({SkillDashTime = 0.35, SkillDashRecharge = 8, SkillDashSpeedMul = 2}) do -- v1.1; v1.2: + SkillDashSpeedMul; v1.3: 2 -> 3; v1.4: 3 -> 1.75; v1.7: 1.75 -> 2
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
	-- v1.5: Cloak Field (only while slotted)
	local cloakSlotted = false
	for n = 1, ST.SLOTS or 2 do
		if st.player:GetAttribute("SkillSlot" .. n) == "cloak" then cloakSlotted = true end
	end
	local cloakOn = live and (e.cloakTime or 0) > 0 and cloakSlotted
	char:SetAttribute("CloakEnabled", cloakOn)
	char:SetAttribute("CloakTime", cloakOn and e.cloakTime or 0)
	char:SetAttribute("CloakCooldown", cloakOn and e.cloakCooldown or 0)
	char:SetAttribute("CloakPounceMul", cloakOn and (e.cloakPounceMul or 1) or 1)
	char:SetAttribute("CloakStill", cloakOn and e.cloakStill == true or false)
	-- v1.6: raptor batch 1
	local function inSlot(id)
		for n = 1, ST.SLOTS or 2 do
			if st.player:GetAttribute("SkillSlot" .. n) == id then return true end
		end
		return false
	end
	local bladeOn = live and (e.bladeLandBonus or 0) > 0
	char:SetAttribute("BladeLook", bladeOn)
	char:SetAttribute("BladeLandBonus", bladeOn and e.bladeLandBonus or 0)
	char:SetAttribute("BladeTickMul", bladeOn and (e.bladeTickMul or 1) or 1)
	char:SetAttribute("BladeBleedDps", bladeOn and (e.bladeBleedDps or 0) or 0)
	char:SetAttribute("BladeBleedTime", bladeOn and (e.bladeBleedTime or 0) or 0)
	char:SetAttribute("BladePinRefund", bladeOn and (e.bladePinRefund or 0) or 0)
	local adOn = live and (e.adrenTime or 0) > 0 and inSlot("adrenaline")
	char:SetAttribute("AdrenalineEnabled", adOn)
	char:SetAttribute("AdrenalineHeal", adOn and e.adrenHeal or 0)
	char:SetAttribute("AdrenalineTime", adOn and e.adrenTime or 0)
	char:SetAttribute("AdrenalineSpeedMul", adOn and (e.adrenSpeedMul or 1) or 1)
	char:SetAttribute("AdrenalineCooldown", adOn and e.adrenCooldown or 0)
	char:SetAttribute("AdrenalineStunClear", adOn and e.adrenStunClear == true or false)
	local shOn = live and (e.eshieldTime or 0) > 0 and inSlot("shield")
	char:SetAttribute("EnergyShieldEnabled", shOn)
	char:SetAttribute("EnergyShieldTime", shOn and e.eshieldTime or 0)
	char:SetAttribute("EnergyShieldCooldown", shOn and e.eshieldCooldown or 0)
	char:SetAttribute("EnergyShieldSpeedMul", shOn and (e.eshieldSpeedMul or 1) or 1)
	-- v1.8: Scent Sense / Raptor Screech (booleans with explicit if/else)
	local scOn = false
	if live and (e.scentTime or 0) > 0 and inSlot("scent") then scOn = true end
	char:SetAttribute("ScentEnabled", scOn)
	char:SetAttribute("ScentRadius", scOn and e.scentRadius or 0)
	char:SetAttribute("ScentMemory", scOn and e.scentMemory or 0)
	char:SetAttribute("ScentTime", scOn and e.scentTime or 0)
	char:SetAttribute("ScentCooldown", scOn and e.scentCooldown or 0)
	local fresh, blood = false, false
	if scOn and e.scentFresh == true then fresh = true end
	if scOn and e.scentBlood == true then blood = true end
	char:SetAttribute("ScentFresh", fresh)
	char:SetAttribute("ScentBlood", blood)
	local srOn = false
	if live and (e.screechRange or 0) > 0 and inSlot("screech") then srOn = true end
	char:SetAttribute("ScreechEnabled", srOn)
	char:SetAttribute("ScreechRange", srOn and e.screechRange or 0)
	char:SetAttribute("ScreechFlinch", srOn and e.screechFlinch or 0)
	char:SetAttribute("ScreechCooldown", srOn and e.screechCooldown or 0)
	local jam = false
	if srOn and e.screechJam == true then jam = true end
	char:SetAttribute("ScreechJam", jam)
	char:SetAttribute("ScreechDamage", srOn and (e.screechDamage or 0) or 0) -- v1.11
	-- v1.9: Shock Mine (path "traps")
	local mnOn = false
	if live and (e.mineMax or 0) > 0 and inSlot("traps") then mnOn = true end
	char:SetAttribute("MineEnabled", mnOn)
	char:SetAttribute("MineDamage", mnOn and e.mineDamage or 0)
	char:SetAttribute("MineSlow", mnOn and (e.mineSlow or 1) or 1)
	char:SetAttribute("MineSlowTime", mnOn and e.mineSlowTime or 0)
	char:SetAttribute("MineCooldown", mnOn and e.mineCooldown or 0)
	char:SetAttribute("MineMax", mnOn and e.mineMax or 0)
	local mjam = false
	if mnOn and e.mineJam == true then mjam = true end
	char:SetAttribute("MineJam", mjam)
	char:SetAttribute("MineLaunch", mnOn and (e.mineLaunch or 0) or 0) -- v1.10
	char:SetAttribute("MineDaze", mnOn and (e.mineDaze or 0) or 0) -- v1.10
	if DOME_ON then -- v1.13: Battering Dome (pachy only)
		local bdOn = live and char:GetAttribute("Species") == "Pachy"
		char:SetAttribute("HeadbuttDamageMul", bdOn and (e.hbDamageMul or 1) or 1)
		char:SetAttribute("HeadbuttShoveMul", bdOn and (e.hbShoveMul or 1) or 1)
		char:SetAttribute("HeadbuttRefillMul", bdOn and (e.hbRefillMul or 1) or 1)
		char:SetAttribute("HeadbuttExtraCharges", bdOn and (e.hbExtraCharges or 0) or 0)
		char:SetAttribute("PachySpikes", bdOn and e.pachySpikes == true)
	end
	if HOOK_ON then -- v1.14: Grappling Hook (pachy only, in a slot)
		local hkOn = live and char:GetAttribute("Species") == "Pachy" and (e.hookRange or 0) > 0 and inSlot("hookarm")
		char:SetAttribute("HookEnabled", hkOn)
		char:SetAttribute("HookRange", hkOn and e.hookRange or 0)
		char:SetAttribute("HookCooldown", hkOn and e.hookCooldown or 0)
		char:SetAttribute("HookDamage", hkOn and e.hookDamage or 0)
		char:SetAttribute("HookLook", hkOn)
	end
	if LEGS_ON then -- v1.15: Mecha Legs (pachy only, passive)
		local mlOn = live and char:GetAttribute("Species") == "Pachy" and (e.legsCooldown or 0) > 0
			and (not LEGS_SLOT or inSlot("mechalegs")) -- v1.16: only while slotted
		char:SetAttribute("MechaLegsEnabled", mlOn) -- v1.16
		for _, k in ipairs({"JumpBoost", "JumpLaunchPower"}) do
			if char:GetAttribute("SkillBase_" .. k) == nil and char:GetAttribute(k) ~= nil then
				char:SetAttribute("SkillBase_" .. k, char:GetAttribute(k))
			end
		end
		local bBoost, bPower = char:GetAttribute("SkillBase_JumpBoost"), char:GetAttribute("SkillBase_JumpLaunchPower")
		if bBoost then writeOwn(st, char, "JumpBoost", round(bBoost * (mlOn and e.legsBoostMul or 1), 0.01)) end
		if bPower then writeOwn(st, char, "JumpLaunchPower", round(bPower * (mlOn and e.legsPowerMul or 1), 0.01)) end
		if mlOn then
			writeOwn(st, char, "JumpCooldown", round(e.legsCooldown * (e.legsCdMul or 1) * (e.moveCdMul or 1), 0.01))
		end
		char:SetAttribute("JumpDoubleEnabled", mlOn and e.doubleJump == true)
		char:SetAttribute("JumpDoubleMul", e.legsDoubleMul or 0.894) -- v1.16 (was 0.894)
		char:SetAttribute("JumpDoubleForward", mlOn and e.legsDoubleForward or 0) -- v1.16
		char:SetAttribute("MechaLegsLook", mlOn and e.legsLook == true)
	end
	if BLOOD_ON then -- v1.17: Blood Rush (pachy only, slotted)
		local brOn = live and char:GetAttribute("Species") == "Pachy" and e.bloodRush == true and inSlot("bloodrush")
		char:SetAttribute("BloodRushEnabled", brOn == true)
		char:SetAttribute("BloodRushCost", brOn and e.bloodCost or 0)
		char:SetAttribute("BloodRushMax", brOn and e.bloodMax or 0)
		char:SetAttribute("BloodRushDamageMul", brOn and e.bloodDamageMul or 1)
		char:SetAttribute("BloodRushNoSelfSlow", brOn and e.bloodNoSelfSlow == true or false)
		char:SetAttribute("BloodRushSlowMul", brOn and e.bloodSlowMul or 1)
		char:SetAttribute("BloodRushSlowTime", brOn and e.bloodSlowTime or 0)
	end
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
local function findBridgedPlayer(name, attacker) -- v1.18: a player's dino ArenaPvP bridges (Arena only)
	if not BLEED_PLAYERS or type(name) ~= "string" then return nil end
	local m = workspace:FindFirstChild(name)
	if m and m ~= attacker and m:IsA("Model")
		and (game:GetService("Players"):GetPlayerFromCharacter(m) or m:GetAttribute("ArenaPvPTestTarget") == true)
		and m:GetAttribute("ArenaPvPBridged") == true and m:GetAttribute("Bitable") == true then
		return m
	end
	return nil
end
local crushed = setmetatable({}, {__mode = "k"}) -- [bot] = last crush time

local function onHit(char, st, damage, targetName, isPounce) -- v1.6: + isPounce
	if not on() then return end
	local e = st.e
	if e.lifesteal > 0 and type(damage) == "number" and damage > 0 then heal(char, st, e.lifesteal * damage, "lifesteal") end
	local bleedDps, bleedTime = e.bleedDps, e.bleedTime
	if isPounce and (e.bladeBleedDps or 0) > bleedDps then bleedDps, bleedTime = e.bladeBleedDps, e.bladeBleedTime end -- v1.6
	if bleedDps <= 0 and e.crushStun <= 0 then return end
	local bot = findBot(targetName)
	local isPlayer = false
	if not bot then -- v1.18: a player's dino (bleed only; the crushing hit stays bots only)
		bot = findBridgedPlayer(targetName, char)
		isPlayer = bot ~= nil
		if isPlayer then bleedTime = math.min(bleedTime, tonumber(script:GetAttribute("SkillBleedPlayerTime")) or 2) end
	end
	if not bot or (tonumber(bot:GetAttribute("DummyHealth")) or 0) <= 0 then return end
	local t = now()
	if isPlayer and bleedDps <= 0 then return end
	if bleedDps > 0 then
		bleeds[bot] = {char = char, player = st.player, dps = bleedDps, untilT = t + bleedTime, isPlayer = isPlayer}
		bot:SetAttribute("SkillBleedUntil", t + bleedTime)
		bot:SetAttribute("SkillBleedBy", char.Name)
	end
	if not isPlayer and e.crushStun > 0 and t - (crushed[bot] or -math.huge) >= e.crushCooldown then
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
			if b.isPlayer and hp - d <= 0 then -- v1.18: credit for ArenaPvP on a player's dino
				bot:SetAttribute("LastHitBy", b.char.Name)
				bot:SetAttribute("LastHitAt", t)
			end
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
		onHit(char, st, char:GetAttribute("PounceHitDamage"), char:GetAttribute("PounceLatchTarget"), true) -- v1.6: pounce
	end)
	if HEADBUTT_HITS then -- v1.12: pachy headbutt
		char:GetAttributeChangedSignal("HeadbuttHitAt"):Connect(function()
			onHit(char, st, char:GetAttribute("HeadbuttHitDamage"), char:GetAttribute("HeadbuttHitTarget"))
		end)
	end
	if HOOK_ON then -- v1.14: the hook smash counts as a hit (lifesteal)
		char:GetAttributeChangedSignal("HookHitAt"):Connect(function()
			onHit(char, st, char:GetAttribute("HookHitDamage"), char:GetAttribute("HookHitTarget"))
		end)
	end
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
