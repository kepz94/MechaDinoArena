-- SprintTest v1.21 (Dino Arcade) — TEST ONLY. Hold Shift (keyboard), L3 (gamepad) or the on-screen
-- Run button (touch) to run. No stamina yet; to be replaced by the real sprint/stamina system.
-- Speeds come from the character's attributes: MoveWalkSpeed (default 16), MoveRunSpeed (default 28).
-- Shift is taken at high priority, so Roblox's Shift-Lock camera toggle does not fire while this runs.
-- v1.1: while the character attribute Roaring is true (set by RoarTest), speed is MoveRoarSpeed (default 4).
-- v1.2: while the character attribute CreepInput is true (C held, set by CreepTest), speed is MoveCreepSpeed
--       (default 10). Priority: Roaring (MoveRoarSpeed) > Sprinting (MoveRunSpeed) > CreepInput
--       (MoveCreepSpeed) > walk (MoveWalkSpeed). Run breaks creep: CreepTest stands up while Sprinting.
-- v1.3: roar debuff speed. While DebuffUntil (server time, set by RoarServer 1.1) is in the future, the speed
--       chosen above is multiplied by DebuffSpeedMul (e.g. 1.1 = +10%). Re-applied when the debuff starts,
--       is refreshed, and when it runs out.
-- v1.4: stamina (StaminaServer 1.0). The run key state is sent as DinoRunRequest:FireServer(held) on every change
--       (the server drains stamina only while the dino really runs). While Exhausted (replicated, set by
--       StaminaServer) running is blocked: speed is MoveCreepSpeed, source "exhausted", Sprinting = false (so
--       CreepTest does not treat the held key as running). Priority: roar > exhausted > run > creep > walk.
-- v1.5 (Mecha Dino Arena auto-run; Kepu 2026-10-28: "Let's make it auto run. Forget walking"): while the character
--       attribute AutoRun is true (set by ArenaRules 1.1), the dino runs as if the run key were held (Sprinting true,
--       source "run", DinoRunRequest true); roar and exhausted still take priority. AutoRun false / absent = v1.4.
-- v1.6 (raptor parts batch 1, MDA-64, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 7): mecha part speed on top of the
--   chosen speed (after the roar debuff): x AdrenalineSpeedMul while AdrenalineUntil > now (AdrenalineServer 1.0; 1.3),
--   x EnergyShieldSpeedMul while EnergyShieldUntil > now (EnergyShieldServer 1.0; 0.5, 0.68 at star). Both multiply.
--   Re-applied when either starts and right after it ends. MoveSpeedMul is the product of all multipliers;
--   new diagnostic MoveSpeedParts ("none" / "adrenaline" / "shield" / "adrenaline+shield").
-- v1.7 (raptor parts batch 2, MDA-73): a Raptor Screech hit on a T-Rex (ScreechSlowUntil, ScreechServer 1.0) multiplies
--   the speed by SCREECH_SLOW (0.5) until then, with the other part multipliers; MoveSpeedParts can include "screech".
-- v1.8 (raptor traps, MDA-80, plan docs/plans/RAPTOR_TRAPS_v1.0.md Task 4): a Shock Mine hit (MineSlowUntil /
--   MineSlowMul, MineServer 1.0) multiplies the speed by MineSlowMul until then, with the other part multipliers;
--   MoveSpeedParts can include "mine".
-- v1.9 (pachy headbutt, MDA-119, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 7; HeadbuttServer 1.0): a headbutt hit
--   (HeadbuttSlowUntil / HeadbuttSlowMul on the hit dino) and the pachy's own slow after its last charge
--   (HeadbuttSelfSlowUntil / HeadbuttSelfSlowMul) multiply the speed like the mine slow; MoveSpeedParts can include
--   "headbutt" / "headbuttSelf". Switch: script attribute SprintHeadbuttSlowEnabled (default true).
-- v1.10 (pachy Overclocked Servo Dash, MDA-126; ServoDashServer 1.0): while ServoDashUntil > now the chosen speed is
--   MoveRunSpeed (top speed, even without Shift) x ServoDashSpeedMul (1.6), source "servodash"; the headbutt self-slow
--   (HeadbuttSelfSlowUntil) is skipped while the dash runs (Kepu: "instantly overrides the headbutt ... speed debuff");
--   other slows and the roar debuff still apply. MoveSpeedParts can include "servodash". Switch: script attribute
--   SprintServoDashEnabled (default true, read each apply; false = 1.9).
-- v1.11 (Tether Spike aim mode, MechaButtons 1.22): while the character attribute TetherAiming is true the dino never runs
--   (Shift / AutoRun ignored, Sprinting false, so no stamina drain) and moves at MoveWalkSpeed (or slower: roar, exhausted,
--   creep and the slows still apply). Switch: script attribute SprintTetherAimEnabled (default true, read each apply;
--   false = 1.10).
-- v1.12 (Herrerasaurus slash, MDA-141, plan docs/plans/HERRERA_KIT_v1.0.md Task 9 — the plan named this 1.11, taken by the
--   Tether Spike aim mode): the slash's speed burst (SlashBurstUntil / SlashBurstMul, SlashServer 1.1, stamped at the
--   dash end) multiplies the speed while SlashBurstUntil > now, with the other part multipliers; MoveSpeedParts can
--   include "slashBurst". Switch: script attribute SprintSlashBurstEnabled (default true, read each apply; false = 1.11).
-- v1.13 (Herrera Blood Frenzy I, SkillTree 1.37, plan docs/plans/STAT_LINES_v1.0.md): while SlashFrenzyUntil > now
--   (SlashServer 1.3 keeps it 0.5 s ahead while a bleeding dino is near) the speed is multiplied by SlashFrenzyMul
--   (SkillEffects 1.26: 1.1), with the other part multipliers; MoveSpeedParts can include "frenzy". Switch: script
--   attribute SprintFrenzyEnabled (default true, read each apply; false = 1.12).
-- v1.14 (Herrera Iron Claw, MDA-149): while IronClawEnabled (SkillEffects 1.27) the speed is multiplied by
--   IronClawSpeedMul (0.95 / 0.90 / 0.85 / 0.75), with the other part multipliers; MoveSpeedParts can include "ironclaw".
--   Switch: script attribute SprintIronClawEnabled (default true, read each apply; false = 1.13).
-- v1.15 (Herrera Smoke Pods, MDA-152, HerreraMovesServer 1.0): while SmokeRunUntil > now the speed is x SmokeRunMul (III:
--   1.25, the owner inside its own cloud; MoveSpeedParts "smoke"); while SmokeSlowUntil > now it is x SmokeSlowMul (star:
--   0.75, an enemy inside the cloud; MoveSpeedParts "smokeSlow"). Both with the other part multipliers. Switch: script
--   attribute SprintSmokeEnabled (default true, read each apply; false = 1.14).
-- v1.16 (Herrera parts pass 3, MDA-165 / MDA-166, HerreraMovesServer 1.2): while CaltropSlowUntil > now the speed is x
--   CaltropSlowMul (a Razor Caltrops spike; MoveSpeedParts "caltrop"); while GooSlowUntil > now it is x GooSlowMul (inside a
--   goo puddle; "goo"). Switch: script attribute SprintPass3SlowEnabled (default true, read each apply; false = 1.15).
-- v1.17 (Tenontosaurus Charge Up, plan docs/plans/TENO_STATS_v1.0.md): the speed is multiplied by TenoChargeMul
--   (TenoStatsServer 1.0: 1.1 after 2 s of running, 1.2 after 3 s; 1 otherwise) when it is not 1, with the other part
--   multipliers; MoveSpeedParts can include "charge". Switch: script attribute SprintTenoChargeEnabled (default true, read
--   each apply; false = 1.16).
-- v1.18 (teno stats part 2, TenoAttackServer 1.3: Heavy Tail / Front Claws stars): while TenoSlowUntil > now the speed is x
--   TenoSlowMul with the other part multipliers; MoveSpeedParts can include "tenoSlow". Switch: script attribute
--   SprintTenoSlowEnabled (default true, read each apply; false = 1.17).
-- v1.19 (teno abilities build 2, Herd Bellow; TenoMovesServer 1.3): while TenoBellowedUntil > now the speed is x
--   TenoBellowedRunMul (clamped 1..3) with the other part multipliers; MoveSpeedParts can include "bellow". Switch: script
--   attribute SprintTenoBellowEnabled (default true, read each apply; false = 1.18).
-- v1.20 (therizino Overclock Joints, MDA-247, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 7; TheriMovesServer 1.2): while
--   TheriClockUntil > now the part speed is x TheriClockRunMul (clamped 1..3); MoveSpeedParts can include "overclock". With
--   TheriClockNoSlow true (the star) the slow factors are taken back out while it lasts: ScreechSlowUntil (x SCREECH_SLOW),
--   MineSlow, TenoSlow, SmokeSlow, CaltropSlow, GooSlow, HeadbuttSlow (not the self-slow) and the roar debuff's speed, each
--   only while active and below 1; MoveSpeedParts then adds "noSlow". Switch: script attribute SprintTheriClockEnabled
--   (default true, read each apply; false = 1.19).
-- v1.21 (dilo parts build 2, MDA-321, plan docs/plans/DILO_PARTS_v1.0.md Task 8; DiloMovesServer 1.1 Antivenom Pump star):
--   while DiloImmuneUntil > now the slow factors are taken back out (the v1.20 slowBack list: ScreechSlow, MineSlow,
--   TenoSlow, SmokeSlow, CaltropSlow, GooSlow, HeadbuttSlow) and a roar-debuff speed below 1 counts as 1; MoveSpeedParts then
--   adds "immune". Re-applied when DiloImmuneUntil changes and when it ends. Switch: script attribute SprintDiloImmuneEnabled
--   (default true, read each apply; false = 1.20).
-- Diagnostics: character attributes Sprinting (true/false), MoveSpeedSource ("roar"/"exhausted"/"run"/"creep"/"walk"),
--   MoveSpeedMul (1 = no debuff; v1.3).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")

local DEFAULTS = {MoveWalkSpeed = 16, MoveRunSpeed = 28, MoveRoarSpeed = 4, MoveCreepSpeed = 10}
local SCREECH_SLOW = 0.5 -- v1.7
local ACTION = "DinoRunTest"

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

-- v1.3: speed multiplier from an active roar debuff (1 when none or expired), and its end time
local function debuffSpeed()
	local untilT, mul = char:GetAttribute("DebuffUntil"), char:GetAttribute("DebuffSpeedMul")
	if typeof(untilT) == "number" and typeof(mul) == "number" and workspace:GetServerTimeNow() < untilT then
		return mul, untilT
	end
	return 1, nil
end

-- v1.6: mecha part speed multipliers active now, and the end times to re-apply at
local function partSpeed()
	local t = workspace:GetServerTimeNow()
	local mul, names, ends = 1, {}, {}
	for _, p in ipairs({{"adrenaline", "AdrenalineUntil", "AdrenalineSpeedMul"}, {"shield", "EnergyShieldUntil", "EnergyShieldSpeedMul"}}) do
		local untilT, m = char:GetAttribute(p[2]), char:GetAttribute(p[3])
		if typeof(untilT) == "number" and typeof(m) == "number" and t < untilT then
			mul *= m
			table.insert(names, p[1])
			table.insert(ends, untilT)
		end
	end
	local slowUntil = char:GetAttribute("ScreechSlowUntil") -- v1.7
	if typeof(slowUntil) == "number" and t < slowUntil then
		mul *= SCREECH_SLOW
		table.insert(names, "screech")
		table.insert(ends, slowUntil)
	end
	local mineUntil, mineMul = char:GetAttribute("MineSlowUntil"), char:GetAttribute("MineSlowMul") -- v1.8
	if typeof(mineUntil) == "number" and typeof(mineMul) == "number" and t < mineUntil then
		mul *= math.clamp(mineMul, 0.05, 1)
		table.insert(names, "mine")
		table.insert(ends, mineUntil)
	end
	local dashUntil = char:GetAttribute("ServoDashUntil") -- v1.10
	local dashing = script:GetAttribute("SprintServoDashEnabled") ~= false and typeof(dashUntil) == "number" and t < dashUntil
	if dashing then
		local m = tonumber(char:GetAttribute("ServoDashSpeedMul")) or 1
		mul *= m
		table.insert(names, "servodash")
		table.insert(ends, dashUntil)
	end
	local burstUntil, burstMul = char:GetAttribute("SlashBurstUntil"), char:GetAttribute("SlashBurstMul") -- v1.12
	if script:GetAttribute("SprintSlashBurstEnabled") ~= false and typeof(burstUntil) == "number" and typeof(burstMul) == "number"
		and t < burstUntil then
		mul *= math.max(0, burstMul)
		table.insert(names, "slashBurst")
		table.insert(ends, burstUntil)
	end
	local frUntil, frMul = char:GetAttribute("SlashFrenzyUntil"), char:GetAttribute("SlashFrenzyMul") -- v1.13
	if script:GetAttribute("SprintFrenzyEnabled") ~= false and typeof(frUntil) == "number" and typeof(frMul) == "number"
		and t < frUntil and frMul ~= 1 then
		mul *= math.max(0, frMul)
		table.insert(names, "frenzy")
		table.insert(ends, frUntil)
	end
	if script:GetAttribute("SprintIronClawEnabled") ~= false and char:GetAttribute("IronClawEnabled") == true then -- v1.14
		local m = tonumber(char:GetAttribute("IronClawSpeedMul")) or 1
		if m ~= 1 then
			mul *= math.clamp(m, 0.05, 1)
			table.insert(names, "ironclaw")
		end
	end
	if script:GetAttribute("SprintTenoChargeEnabled") ~= false then -- v1.17
		local m = tonumber(char:GetAttribute("TenoChargeMul")) or 1
		if m ~= 1 then
			mul *= math.clamp(m, 0.05, 3)
			table.insert(names, "charge")
		end
	end
	if script:GetAttribute("SprintTenoSlowEnabled") ~= false then -- v1.18
		local untilT, m = char:GetAttribute("TenoSlowUntil"), char:GetAttribute("TenoSlowMul")
		if typeof(untilT) == "number" and typeof(m) == "number" and t < untilT and m ~= 1 then
			mul *= math.clamp(m, 0.05, 1)
			table.insert(names, "tenoSlow")
			table.insert(ends, untilT)
		end
	end
	if script:GetAttribute("SprintTenoBellowEnabled") ~= false then -- v1.19
		local untilT, m = char:GetAttribute("TenoBellowedUntil"), char:GetAttribute("TenoBellowedRunMul")
		if typeof(untilT) == "number" and typeof(m) == "number" and t < untilT and m ~= 1 then
			mul *= math.clamp(m, 1, 3)
			table.insert(names, "bellow")
			table.insert(ends, untilT)
		end
	end
	if script:GetAttribute("SprintSmokeEnabled") ~= false then -- v1.15
		for _, h in ipairs({{"smoke", "SmokeRunUntil", "SmokeRunMul", 1, 3}, {"smokeSlow", "SmokeSlowUntil", "SmokeSlowMul", 0.05, 1}}) do
			local untilT, m = char:GetAttribute(h[2]), char:GetAttribute(h[3])
			if typeof(untilT) == "number" and typeof(m) == "number" and t < untilT and m ~= 1 then
				mul *= math.clamp(m, h[4], h[5])
				table.insert(names, h[1])
				table.insert(ends, untilT)
			end
		end
	end
	if script:GetAttribute("SprintPass3SlowEnabled") ~= false then -- v1.16
		for _, h in ipairs({{"caltrop", "CaltropSlowUntil", "CaltropSlowMul"}, {"goo", "GooSlowUntil", "GooSlowMul"}}) do
			local untilT, m = char:GetAttribute(h[2]), char:GetAttribute(h[3])
			if typeof(untilT) == "number" and typeof(m) == "number" and t < untilT and m ~= 1 then
				mul *= math.clamp(m, 0.05, 1)
				table.insert(names, h[1])
				table.insert(ends, untilT)
			end
		end
	end
	if script:GetAttribute("SprintHeadbuttSlowEnabled") ~= false then -- v1.9
		for _, h in ipairs({{"headbutt", "HeadbuttSlowUntil", "HeadbuttSlowMul"}, {"headbuttSelf", "HeadbuttSelfSlowUntil", "HeadbuttSelfSlowMul"}}) do
			local untilT, m = char:GetAttribute(h[2]), char:GetAttribute(h[3])
			if dashing and h[1] == "headbuttSelf" then untilT = nil end -- v1.10: the dash overrides the self-slow
			if typeof(untilT) == "number" and typeof(m) == "number" and t < untilT then
				mul *= math.clamp(m, 0.05, 1)
				table.insert(names, h[1])
				table.insert(ends, untilT)
			end
		end
	end
	return mul, (#names > 0 and table.concat(names, "+") or "none"), ends
end
-- v1.20: Overclock Joints (see the header)
if script:GetAttribute("SprintTheriClockEnabled") == nil then script:SetAttribute("SprintTheriClockEnabled", true) end
local function clockOn(t)
	return script:GetAttribute("SprintTheriClockEnabled") ~= false and (tonumber(char:GetAttribute("TheriClockUntil")) or 0) > t
end
local function slowBack(t) -- the product of the active slow factors (< 1), to divide back out
	local back = 1
	local su = char:GetAttribute("ScreechSlowUntil")
	if typeof(su) == "number" and t < su then back *= SCREECH_SLOW end
	for _, h in ipairs({{"MineSlowUntil", "MineSlowMul"}, {"TenoSlowUntil", "TenoSlowMul"}, {"SmokeSlowUntil", "SmokeSlowMul"},
		{"CaltropSlowUntil", "CaltropSlowMul"}, {"GooSlowUntil", "GooSlowMul"}, {"HeadbuttSlowUntil", "HeadbuttSlowMul"}}) do
		local u, m = char:GetAttribute(h[1]), char:GetAttribute(h[2])
		if typeof(u) == "number" and typeof(m) == "number" and t < u and m < 1 then back *= math.clamp(m, 0.05, 1) end
	end
	return back
end
do
	local partSpeedV119 = partSpeed
	partSpeed = function()
		local mul, names, ends = partSpeedV119()
		local t = workspace:GetServerTimeNow()
		if clockOn(t) then
			local untilT = tonumber(char:GetAttribute("TheriClockUntil"))
			mul *= math.clamp(tonumber(char:GetAttribute("TheriClockRunMul")) or 1, 1, 3)
			names = (names == "none" and "" or names .. "+") .. "overclock"
			if char:GetAttribute("TheriClockNoSlow") == true then
				local back = slowBack(t)
				if back < 1 then mul /= back end
				names ..= "+noSlow"
			end
			table.insert(ends, untilT)
		end
		return mul, names, ends
	end
	local debuffSpeedV119 = debuffSpeed
	debuffSpeed = function()
		local m, u = debuffSpeedV119()
		local t = workspace:GetServerTimeNow()
		if clockOn(t) and char:GetAttribute("TheriClockNoSlow") == true and m < 1 then return 1, u end
		return m, u
	end
end
-- v1.21: Antivenom Pump immunity (see the header)
if script:GetAttribute("SprintDiloImmuneEnabled") == nil then script:SetAttribute("SprintDiloImmuneEnabled", true) end
local function immuneOn(t)
	return script:GetAttribute("SprintDiloImmuneEnabled") ~= false and (tonumber(char:GetAttribute("DiloImmuneUntil")) or 0) > t
end
do
	local partSpeedV120 = partSpeed
	partSpeed = function()
		local mul, names, ends = partSpeedV120()
		local t = workspace:GetServerTimeNow()
		if immuneOn(t) and not (clockOn(t) and char:GetAttribute("TheriClockNoSlow") == true) then
			local back = slowBack(t)
			if back < 1 then mul /= back end
			names = (names == "none" and "" or names .. "+") .. "immune"
			table.insert(ends, tonumber(char:GetAttribute("DiloImmuneUntil")))
		end
		return mul, names, ends
	end
	local debuffSpeedV120 = debuffSpeed
	debuffSpeed = function()
		local m, u = debuffSpeedV120()
		if immuneOn(workspace:GetServerTimeNow()) and m < 1 then return 1, u end
		return m, u
	end
end
local scheduledPartEnds = {} -- v1.6: [end time] = true once a re-apply is scheduled

local sprinting = false
local runRemote = ReplicatedStorage:WaitForChild("DinoRunRequest", 10) -- v1.4
local runSent -- v1.4: last run key state sent to the server
local scheduledUntil -- v1.3: debuff end time an expiry re-apply is already scheduled for
local function running() -- v1.5; v1.11: never while aiming the Tether Spike
	if char:GetAttribute("TetherAiming") == true and script:GetAttribute("SprintTetherAimEnabled") ~= false then return false end
	return sprinting or char:GetAttribute("AutoRun") == true
end
local apply
function apply()
	local source
	local run = running() -- v1.5
	local dashU = char:GetAttribute("ServoDashUntil") -- v1.10: the dash runs at top speed
	if script:GetAttribute("SprintServoDashEnabled") ~= false and typeof(dashU) == "number" and workspace:GetServerTimeNow() < dashU
		and not char:GetAttribute("Roaring") then
		source = "servodash"
		hum.WalkSpeed = get("MoveRunSpeed")
	elseif char:GetAttribute("Roaring") then
		source = "roar"
		hum.WalkSpeed = get("MoveRoarSpeed")
	elseif char:GetAttribute("Exhausted") == true then -- v1.4: out of stamina: crouch-walk, no running
		source = "exhausted"
		hum.WalkSpeed = get("MoveCreepSpeed")
	elseif run then -- v1.5: held or AutoRun
		source = "run"
		hum.WalkSpeed = get("MoveRunSpeed")
	elseif char:GetAttribute("CreepInput") then
		source = "creep"
		hum.WalkSpeed = get("MoveCreepSpeed")
	else
		source = "walk"
		hum.WalkSpeed = get("MoveWalkSpeed")
	end
	-- v1.3: roar debuff speed on top of the chosen speed
	local mul, untilT = debuffSpeed()
	if mul ~= 1 then hum.WalkSpeed = hum.WalkSpeed * mul end
	local pmul, pnames, pends = partSpeed() -- v1.6
	if pmul ~= 1 then hum.WalkSpeed = hum.WalkSpeed * pmul end
	for _, e in ipairs(pends) do
		if not scheduledPartEnds[e] then
			scheduledPartEnds[e] = true
			task.delay(math.max(0, e - workspace:GetServerTimeNow()) + 0.02, function()
				if char.Parent then apply() end
			end)
		end
	end
	char:SetAttribute("MoveSpeedParts", pnames)
	char:SetAttribute("MoveSpeedMul", mul * pmul)
	if untilT and scheduledUntil ~= untilT then
		scheduledUntil = untilT
		task.delay(math.max(0, untilT - workspace:GetServerTimeNow()) + 0.02, function()
			if char.Parent then apply() end
		end)
	end
	char:SetAttribute("Sprinting", run and char:GetAttribute("Exhausted") ~= true) -- v1.4: not while exhausted; v1.5: run
	if runRemote and runSent ~= run then -- v1.4; v1.5: run
		runSent = run
		runRemote:FireServer(run)
	end
	char:SetAttribute("MoveSpeedSource", source)
end

local function onRun(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		sprinting = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		sprinting = false
	end
	apply()
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(ACTION, onRun, true, Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle(ACTION, "Run")
char:GetAttributeChangedSignal("MoveWalkSpeed"):Connect(apply)
char:GetAttributeChangedSignal("MoveRunSpeed"):Connect(apply)
char:GetAttributeChangedSignal("MoveRoarSpeed"):Connect(apply)
char:GetAttributeChangedSignal("Roaring"):Connect(apply)
char:GetAttributeChangedSignal("MoveCreepSpeed"):Connect(apply)
char:GetAttributeChangedSignal("CreepInput"):Connect(apply)
char:GetAttributeChangedSignal("DebuffUntil"):Connect(apply)    -- v1.3
char:GetAttributeChangedSignal("DebuffSpeedMul"):Connect(apply) -- v1.3
char:GetAttributeChangedSignal("Exhausted"):Connect(apply)      -- v1.4
char:GetAttributeChangedSignal("AutoRun"):Connect(apply)        -- v1.5
char:GetAttributeChangedSignal("TetherAiming"):Connect(apply)   -- v1.11
for _, a in ipairs({"AdrenalineUntil", "AdrenalineSpeedMul", "EnergyShieldUntil", "EnergyShieldSpeedMul", "ScreechSlowUntil",
	"MineSlowUntil", "MineSlowMul", "HeadbuttSlowUntil", "HeadbuttSlowMul", "HeadbuttSelfSlowUntil", "HeadbuttSelfSlowMul",
	"ServoDashUntil", "ServoDashSpeedMul", "SlashBurstUntil", "SlashBurstMul", "SlashFrenzyUntil", "SlashFrenzyMul", "IronClawEnabled", "IronClawSpeedMul",
	"SmokeRunUntil", "SmokeRunMul", "SmokeSlowUntil", "SmokeSlowMul",
	"CaltropSlowUntil", "CaltropSlowMul", "GooSlowUntil", "GooSlowMul", "TenoChargeMul", "TenoSlowUntil", "TenoSlowMul"}) do -- v1.18: + TenoSlow* -- v1.17: + TenoChargeMul -- v1.16: + Caltrop* / Goo* -- v1.15: + Smoke* -- v1.6; v1.7: + ScreechSlowUntil; v1.8: + MineSlowUntil / MineSlowMul; v1.9: + Headbutt*; v1.10: + ServoDash*
	char:GetAttributeChangedSignal(a):Connect(apply)
end
for _, a in ipairs({"TenoBellowedUntil", "TenoBellowedRunMul"}) do -- v1.19
	char:GetAttributeChangedSignal(a):Connect(apply)
end
for _, a in ipairs({"TheriClockUntil", "TheriClockRunMul", "TheriClockNoSlow"}) do -- v1.20
	char:GetAttributeChangedSignal(a):Connect(apply)
end
char:GetAttributeChangedSignal("DiloImmuneUntil"):Connect(apply) -- v1.21
apply()

local function cleanup()
	ContextActionService:UnbindAction(ACTION)
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
