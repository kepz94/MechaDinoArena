-- SprintTest v1.8 (Dino Arcade) — TEST ONLY. Hold Shift (keyboard), L3 (gamepad) or the on-screen
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
	return mul, (#names > 0 and table.concat(names, "+") or "none"), ends
end
local scheduledPartEnds = {} -- v1.6: [end time] = true once a re-apply is scheduled

local sprinting = false
local runRemote = ReplicatedStorage:WaitForChild("DinoRunRequest", 10) -- v1.4
local runSent -- v1.4: last run key state sent to the server
local scheduledUntil -- v1.3: debuff end time an expiry re-apply is already scheduled for
local function running() return sprinting or char:GetAttribute("AutoRun") == true end -- v1.5
local apply
function apply()
	local source
	local run = running() -- v1.5
	if char:GetAttribute("Roaring") then
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
for _, a in ipairs({"AdrenalineUntil", "AdrenalineSpeedMul", "EnergyShieldUntil", "EnergyShieldSpeedMul", "ScreechSlowUntil",
	"MineSlowUntil", "MineSlowMul"}) do -- v1.6; v1.7: + ScreechSlowUntil; v1.8: + MineSlowUntil / MineSlowMul
	char:GetAttributeChangedSignal(a):Connect(apply)
end
apply()

local function cleanup()
	ContextActionService:UnbindAction(ACTION)
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
