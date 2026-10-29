-- MechaButtons v1.8 (Mecha Dino Arena) — the 2 mecha loadout buttons (touch), PC keys 1 / 2, and the Thrusters dash on the
-- owner's client. MDA-28, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 6, mockup docs/mockups/mecha_thrusters_options.html
-- option A "Thumb arc" (Kepu 2026-10-28).
-- Slots: player attributes SkillSlot1 / SkillSlot2 (SkillServer 1.1; path id or ""). A press on a slot holding "thrusters"
--   fires ReplicatedStorage.DinoDashRequest:FireServer(server time) (MechaServer 1.0 gates it). An empty slot does nothing.
-- Touch (UserInputService.TouchEnabled): ScreenGui "MechaButtons" (DisplayOrder 5), buttons Slot_1 / Slot_2, AnchorPoint
--   (1, 1), position and size in fractions of the screen like ArenaTouch 1.2:
--     AutoRun true  (RUN hidden):  Slot_1 right 21%, bottom 8%;   Slot_2 right 32.5%, bottom 18%; 9.5% of the width
--     AutoRun false (RUN shown):   Slot_1 right 33%, bottom 8%;   Slot_2 right 33%, bottom 28%;   9.5% of the width
--   Look: rounded square (corner 22%), panel (20, 20, 26) at 0.3, 2.5 px Engineer-orange (255, 155, 46) stroke.
--   Full slot: "DASH", charge pips top right (DashChargesLeft of DashCharges), a dark fill from the bottom showing the time
--   to the next charge (DashNextChargeAt, DashRecharge), key hint "1" / "2" (v1.1: "R" / "C", empty on touch); dimmed
--   (0.5) while DashEnabled is not true.
--   Empty slot: white stroke at 0.5, "+" and "slot n".
-- PC / no touch: no buttons; keys 1 and 2 (v1.1: R and C) press slot 1 and 2 (when the key is not used by a text box). Test hook: script
--   attribute MechaButtonsForceTouch (default nil / false) = true draws the touch buttons without touch (layout checks).
-- Dash physics (this client owns the character): on a new DashStartedAt, a LinearVelocity on the HumanoidRootPart
--   (VelocityConstraintMode Plane, world X / Z) at DashDistance / DashTime studs/s along the flat look direction, for
--   DashTime s; with DashHop > 0 the root also gets an upward speed sqrt(2 x gravity x DashHop) and the Humanoid is put in
--   Freefall. At the end the root's horizontal speed is set to 0 (keeps its vertical speed), so the dino stops where the
--   dash ends instead of sliding on.
-- Diagnostics (character attributes, this client): MechaButtonsVersion, MechaButtonsState ("on" touch / "keys"),
--   MechaButtonsLastPress ("slot1:thrusters" / "slot2:empty" ...), MechaDashLocal ("idle" / "dashing"), MechaDashLocalCount.
-- v1.1 (MDA-33; Kepu 2026-10-28 after trying it on PC: "what the hell was that ... make the thrusters actually last longer",
--   "1.5 s boost, steerable"; keys "shouldnt be the number 1 button ... assign it to Q or e or something" -> "R / C";
--   "make it visible on pc what ability you have gained" -> "New ability" popup):
--   * Keys: R = slot 1, C = slot 2 (RoarTest R / CreepTest C are off in Mecha, ArenaScope 1.2+); 1 / 2 no longer do
--     anything. Key hints on the buttons show R / C (empty on real touch devices).
--   * Boost: when the character has DashSpeedMul (SkillEffects 1.2), a new DashStartedAt starts a boost for DashTime s
--     (1.5 s; 2 s from III) at DashSpeedMul (2) x the run speed (max of MoveRunSpeed and Humanoid.WalkSpeed). Steerable:
--     every frame the direction is the Humanoid's MoveDirection (flat) while you move, else the last direction (first:
--     where the dino faces). The star hop works as in 1.0 (at the start). It ends early on death, a stun (StunnedUntil in
--     the future) or a pounce latch (PounceLatched). At the end the horizontal speed is set to 0 as in 1.0. Without
--     DashSpeedMul the 1.0 dash (DashDistance / DashTime straight ahead) is used.
--   * Popup (PC and touch): ScreenGui "MechaNews" (DisplayOrder 25, above the skill screen), top centre, 4 s: "⚙ NEW:
--     <PART NAME>" and "Press R to use it" / "Press C to use it" (PC) / "Tap its button to use it" (touch) / "Put it in a
--     LOADOUT slot (SKILLS)" when it is not in a slot. Shown when a loadout part's SkillPath_<id> goes from 0 to 1 or more
--     while this character exists (SkillTree.BUTTONS from ReplicatedStorage.SkillShared; not on join / respawn).
--     Diagnostics MechaNewsShown (path id), MechaBoostDir ("move" / "keep").
-- v1.2 (MDA-35; Kepu: "its an arcade game. i want these boosts to feel significant" -> camera punch, speed lines):
--   during a boost (this client) an envelope k goes 0 -> 1 in 0.15 s, stays 1 while boosting and goes back to 0 in 0.3 s
--   after it ends:
--   * camera punch: RenderStep "MechaBoostCam" at Camera priority + 2 (after ShoulderCam 1.5 and SkillScreen's mouse
--     bind): Camera.FieldOfView = the FOV at boost start + 15 x k, and a small shake (pitch / yaw up to 0.6 degrees x k,
--     from math.noise); the start FOV is put back and the bind removed when k is 0 again;
--   * speed lines: ScreenGui "MechaSpeedLines" (DisplayOrder 4) with 40 white streaks (100-220 x 4 px) flying outward
--     from around the middle of the screen toward the edges, transparency 1 - 0.65 x k (hidden at k 0).
--   Script attribute MechaBoostFxEnabled (default true; false = no punch and no lines). Diagnostic MechaBoostFx (k, 0.1).
-- v1.3 (air pounce, PounceTest 1.4): a boost also ends when this character starts a pounce (PounceLocalState "windup" or
--   "lunge"), so the boost's LinearVelocity (MaxForce infinite) does not hold the lunge back; the boost's end sets the
--   horizontal speed to 0 during the 0.1 s wind-up, then the lunge sets its own speed. Script attribute
--   MechaBoostPounceEnds (default true; false = 1.2 behaviour). Diagnostic (character): MechaBoostEnd ("pounce").
-- v1.4 (4 slots + Cloak, MDA-53, plans docs/plans/LOADOUT4_v1.0.md Task 2 + docs/plans/CLOAK_v1.0.md Task 5; Kepu
--   2026-10-29: eFootball-style tap-and-pull, look A "Sub-label", fire on release, PC T / V):
--   * Slots 1-4 (SkillSlot1..4, SkillTree 1.5 SLOTS 4): PC keys R / C / T / V press slots 1 / 2 / 3 / 4.
--   * Touch: button n (1, 2) holds a tap part (slot n) and a pull part (slot n + 2).
--       pull slot empty (or MechaButtonsPullEnabled false): presses slot n on InputBegan, as 1.3;
--       pull slot set: InputBegan keeps the start Y; the touch is "pulling" once it is >= PULL_PX below the start
--         (PULL_PX = clamp(0.22 x button height, 14, 24) px; tracked through UserInputService so it keeps working below the
--         button); while pulling the stroke is white 4 px and the pull label white; InputEnded presses slot n + 2 when
--         pulling, else slot n (fire on release).
--   * Pull label ("Pull"): "▼ NAME" along the bottom (y 0.78, 0.16 of the button), rgb(255, 217, 168), 0.5 while that
--     part is not ready; hidden when the pull slot is empty (the empty button's "slot n" text is then hidden too).
--   * Cloak (CloakServer 1.0): a press on a slot holding "cloak" fires ReplicatedStorage.DinoCloakRequest:FireServer(server
--     time). The button shows "CLOAK", ready while CloakEnabled is true, CloakedUntil <= now and now >= CloakReadyAt
--     (else 0.5); the dark fill is the cooldown left (CloakReadyAt - now) / CloakCooldown. No pips.
--   * NEW popup: looks up slots 1-4: "Press R / C / T / V to use it" (PC), "Tap its button" (slot 1 / 2) or "Tap and pull
--     down its button" (slot 3 / 4) (touch).
--   * Toggle: script attribute MechaButtonsPullEnabled (default true; false = 1.3 touch behaviour, slots 3 / 4 by T / V
--     only). Diagnostics: MechaButtonsLastPress "slot3:..." / "slot4:...", MechaButtonsLastGesture ("tap" / "pull" /
--     "press" = fired on InputBegan), MechaButtonsPullPx.
-- v1.5 (raptor parts batch 1, MDA-65, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 8): two more button parts, handled
--   like Cloak through TIMED_PARTS (part id -> attribute prefix, remote): "adrenaline" -> "Adrenaline",
--   DinoAdrenalineRequest (AdrenalineServer 1.0); "shield" -> "EnergyShield", DinoEnergyShieldRequest
--   (EnergyShieldServer 1.0). A press fires the remote with the server time. Ready while <Prefix>Enabled is true,
--   <Prefix>Until <= now and now >= <Prefix>ReadyAt (else 0.5); the dark fill is the cooldown left / <Prefix>Cooldown.
--   Button names "ADRENALINE" / "SHIELD". Thrusters / Cloak unchanged.
-- v1.6 (Kepu 2026-10-29: "if you jump and press the thruster it should boost you straight up unless you move the analog
--   forward. It would allow for more creative gameplay to get out of sticky situations" -> "About 30 studs", "Any
--   direction"): a Thrusters boost that starts in the air (Humanoid.FloorMaterial == Air) with no move input
--   (MoveDirection flat length < 0.1) goes straight up instead: a LinearVelocity (Vector mode, world) of
--   (0, MechaAirUpHeight / MechaAirUpTime, 0) for MechaAirUpTime s (script attributes, defaults 30 studs / 0.6 s), no
--   steering, no star hop; at the end the vertical speed is set to 0 so the rise peaks there and gravity takes over. Any
--   stick / key direction in the air gives the normal boost that way. Script attribute MechaAirUpEnabled (default
--   true). Diagnostics: character MechaBoostMode ("ground" / "air" / "up"), MechaAirUpCount.
--   v1.6 hover (Kepu: "just hit it and stay until the boost ends then drop"): after the MechaAirUpTime rise the
--   LinearVelocity holds (0, 0, 0) until DashTime ends (the whole boost), then it is removed and gravity takes over.
--   Diagnostic: MechaAirUpPhase ("rise" / "hover" / "done").
-- v1.7 (Kepu 2026-10-29, after v70: "I just jumped and pressed dash then tried to move forward but it didn't really push
--   forward once it hit the height ceiling"; 1.6 had no steering on the straight-up boost): during the straight-up
--   boost the stick / keys now steer it like the normal boost: with move input the sideways speed is the boost speed
--   (DashSpeedMul x run speed) in the move direction, without it 0; the up speed keeps the rise / hover profile, so the
--   height is held while flying until the boost ends, then the drop. MechaBoostDir "move" / "keep" as on the ground.
-- v1.8 (raptor parts batch 2, MDA-74 / MDA-75, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Tasks 6-7):
--   * TIMED_PARTS += scent ("Scent", DinoScentRequest, "SCENT"; ScentServer 1.0) and screech ("Screech",
--     DinoScreechRequest, "SCREECH"; ScreechServer 1.0). Scent is a normal press.
--   * Raptor Screech is hold-to-aim (Kepu: "it needs to be aimed" -> C "Hold to aim"): pressing its slot starts the aim;
--     an aim line "ScreechAim" (client-only red neon beam at the raptor's root height, where the bolt flies, along its
--     facing, with a Highlight that shows through grass and rocks)
--     grows from 0 to ScreechRange over AIM_TIME (1) s and stays at the max while held; letting go fires
--     DinoScreechRequest(server time, held range). PC: key down / key up (R / C / T / V). Touch: the slot's button
--     down / up; with a pull part on the same button, the aim follows the gesture: it aims the tap slot until the
--     touch counts as a pull, then the pull slot (if that is Screech), and the release fires the one aimed. Dying,
--     the character leaving or Screech leaving the slot cancels the aim.
--     Diagnostics: MechaScreechAim ("idle" / "aiming"), MechaScreechHeld (last held range, studs), MechaScreechFired.
--   * Jam (MDA-74): a new PartsJammedAt during a boost ends it (MechaBoostEnd "jammed").
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.8"
local PANEL = Color3.fromRGB(20, 20, 26)
local ORANGE = Color3.fromRGB(255, 155, 46)
local SPOTS = {
	[true] = {{0.21, 0.08}, {0.325, 0.18}},  -- AutoRun on: RUN's spot + the arc
	[false] = {{0.33, 0.08}, {0.33, 0.28}},  -- RUN shown: inner column
}
local SIZE = 0.095
local KEYS = {Enum.KeyCode.R, Enum.KeyCode.C, Enum.KeyCode.T, Enum.KeyCode.V} -- v1.1: slot 1 / slot 2 (was 1 / 2); v1.4: + T / V
local KEY_NAMES = {"R", "C", "T", "V"}
local PULL_COLOR = Color3.fromRGB(255, 217, 168) -- v1.4
if script:GetAttribute("MechaButtonsPullEnabled") == nil then script:SetAttribute("MechaButtonsPullEnabled", true) end -- v1.4
for k, v in pairs({MechaAirUpEnabled = true, MechaAirUpHeight = 30, MechaAirUpTime = 0.6}) do -- v1.6
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end

local char = script.Parent
local player = Players.LocalPlayer
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
char:SetAttribute("MechaButtonsVersion", VERSION)
char:SetAttribute("MechaDashLocal", "idle")
local remote = ReplicatedStorage:WaitForChild("DinoDashRequest", 20)
local cloakRemote -- v1.4: DinoCloakRequest (CloakServer 1.0), looked up on first use
local TIMED_PARTS = { -- v1.5: part id -> {attribute prefix, remote name, button name}
	adrenaline = {"Adrenaline", "DinoAdrenalineRequest", "ADRENALINE"},
	shield = {"EnergyShield", "DinoEnergyShieldRequest", "SHIELD"},
}
TIMED_PARTS.scent = {"Scent", "DinoScentRequest", "SCENT"} -- v1.8
TIMED_PARTS.screech = {"Screech", "DinoScreechRequest", "SCREECH"} -- v1.8 (hold-to-aim, see aimStart)
local AIM_TIME = 1 -- v1.8: s for the aim line to reach ScreechRange
local aim -- v1.8: {slot, t0, input, gesture, part}

local function slotPart(n)
	local v = player:GetAttribute("SkillSlot" .. n)
	return (type(v) == "string" and v ~= "") and v or nil
end

-- v1.8: Raptor Screech hold-to-aim
local function aimRange()
	if not aim then return 0 end
	local maxR = tonumber(char:GetAttribute("ScreechRange")) or 0
	return maxR * math.clamp((os.clock() - aim.t0) / AIM_TIME, 0, 1)
end
local function aimCancel()
	if aim and aim.part then aim.part:Destroy() end
	aim = nil
	char:SetAttribute("MechaScreechAim", "idle")
end
local function aimStart(n, input, isGesture)
	aimCancel()
	if not hrp then return end
	local line = Instance.new("Part")
	line.Name = "ScreechAim"
	line.Color = Color3.fromRGB(240, 90, 79)
	line.Material = Enum.Material.Neon
	line.Transparency = 0.25
	line.Anchored, line.CanCollide, line.CanQuery, line.CanTouch, line.CastShadow = true, false, false, false, false
	line.Size = Vector3.new(0.5, 0.5, 0.1)
	local hl = Instance.new("Highlight") -- Play: a ground strip was hidden by the rock steps; the beam shows through
	hl.FillColor, hl.OutlineColor = line.Color, Color3.new(1, 1, 1)
	hl.FillTransparency, hl.OutlineTransparency = 0.2, 0.6
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = line
	line.Parent = workspace
	aim = {slot = n, t0 = os.clock(), input = input, gesture = isGesture == true, part = line}
	char:SetAttribute("MechaScreechAim", "aiming")
end
local function aimRelease()
	if not aim then return end
	local range = aimRange()
	aimCancel()
	char:SetAttribute("MechaScreechHeld", math.floor(range * 10 + 0.5) / 10)
	local r = ReplicatedStorage:FindFirstChild("DinoScreechRequest")
	if r then
		r:FireServer(workspace:GetServerTimeNow(), range)
		char:SetAttribute("MechaScreechFired", (char:GetAttribute("MechaScreechFired") or 0) + 1)
	end
end
RunService.RenderStepped:Connect(function()
	if not aim then return end
	if not char.Parent or not hum or hum.Health <= 0 or slotPart(aim.slot) ~= "screech" then aimCancel() return end
	local len = math.max(0.1, aimRange())
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if look.Magnitude < 1e-3 then return end
	look = look.Unit
	local base = hrp.Position -- the bolt's height (ScreechServer starts it 4 studs ahead of the root)
	aim.part.Size = Vector3.new(0.5, 0.5, len)
	aim.part.CFrame = CFrame.lookAt(base + look * (4 + len / 2), base + look * (5 + len / 2))
end)

local function press(n, input)
	local id = slotPart(n)
	char:SetAttribute("MechaButtonsLastPress", ("slot%d:%s"):format(n, id or "empty"))
	if id == "screech" then -- v1.8: start the aim; the release fires
		aimStart(n, input, false)
		return
	end
	if id == "thrusters" and remote then remote:FireServer(workspace:GetServerTimeNow()) end
	if id == "cloak" then -- v1.4
		cloakRemote = cloakRemote or ReplicatedStorage:FindFirstChild("DinoCloakRequest")
		if cloakRemote then cloakRemote:FireServer(workspace:GetServerTimeNow()) end
	end
	local tp = id and TIMED_PARTS[id] -- v1.5
	if tp then
		local r = ReplicatedStorage:FindFirstChild(tp[2])
		if r then r:FireServer(workspace:GetServerTimeNow()) end
	end
end

-- v1.4: is a part ready to use, and how much of its cooldown is left (0..1)
local function partState(id)
	local now = workspace:GetServerTimeNow()
	if id == "cloak" then
		local ready = char:GetAttribute("CloakEnabled") == true and (tonumber(char:GetAttribute("CloakedUntil")) or 0) <= now
			and now >= (tonumber(char:GetAttribute("CloakReadyAt")) or 0)
		local cd = tonumber(char:GetAttribute("CloakCooldown")) or 0
		local left = (tonumber(char:GetAttribute("CloakReadyAt")) or 0) - now
		return ready, (cd > 0 and left > 0) and math.clamp(left / cd, 0, 1) or 0
	end
	local tp = TIMED_PARTS[id] -- v1.5
	if tp then
		local px = tp[1]
		local readyAt = tonumber(char:GetAttribute(px .. "ReadyAt")) or 0
		local ready = char:GetAttribute(px .. "Enabled") == true and (tonumber(char:GetAttribute(px .. "Until")) or 0) <= now
			and now >= readyAt
		local cd = tonumber(char:GetAttribute(px .. "Cooldown")) or 0
		local left = readyAt - now
		return ready, (cd > 0 and left > 0) and math.clamp(left / cd, 0, 1) or 0
	end
	local nextAt = tonumber(char:GetAttribute("DashNextChargeAt")) or 0
	local rc = tonumber(char:GetAttribute("DashRecharge")) or 8
	local frac = 0
	if id == "thrusters" and nextAt > 0 and rc > 0 then frac = math.clamp((nextAt - now) / rc, 0, 1) end
	return char:GetAttribute("DashEnabled") == true, frac
end
local function partName(id)
	if id == "thrusters" then return "DASH" end
	if TIMED_PARTS[id] then return TIMED_PARTS[id][3] end -- v1.5
	return string.upper(id)
end

-- dash physics --------------------------------------------------------------------------------------------------------
local lastDash = char:GetAttribute("DashStartedAt")

-- v1.2: boost feel (camera punch + speed lines) --------------------------------------------------------------------
local FX_BIND = "MechaBoostCam"
local fxBoosting, fxK, fxBaseFov, fxGui, fxLines, fxT = false, 0, nil, nil, nil, 0
local function fxOn() return script:GetAttribute("MechaBoostFxEnabled") ~= false end
local function pounceStarted() -- v1.3
	if script:GetAttribute("MechaBoostPounceEnds") == false then return false end
	local s = char:GetAttribute("PounceLocalState")
	return s == "windup" or s == "lunge"
end
local function fxBuild()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return end
	local old = pg:FindFirstChild("MechaSpeedLines")
	if old then old:Destroy() end
	fxGui = Instance.new("ScreenGui")
	fxGui.Name = "MechaSpeedLines"
	fxGui.ResetOnSpawn = true
	fxGui.DisplayOrder = 4
	fxGui.IgnoreGuiInset = true
	fxLines = {}
	for i = 1, 40 do -- 40 streaks (24 looked sparse in Play)
		local f = Instance.new("Frame")
		f.Name = "Line_" .. i
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Parent = fxGui
		fxLines[i] = {f = f, a = math.random() * math.pi * 2, r = 0.45 + math.random() * 0.55, len = 100 + math.random() * 120}
	end
	fxGui.Parent = pg
end
local function fxStep(dt)
	fxT += dt
	if fxBoosting then fxK = math.min(1, fxK + dt / 0.15) else fxK = math.max(0, fxK - dt / 0.3) end
	local cam = workspace.CurrentCamera
	if cam and fxBaseFov then
		cam.FieldOfView = fxBaseFov + 15 * fxK
		local amp = math.rad(0.6) * fxK
		cam.CFrame = cam.CFrame * CFrame.Angles(math.noise(fxT * 18, 1.3) * amp, math.noise(fxT * 18, 7.1) * amp, 0)
	end
	if fxGui and fxLines then
		local size = fxGui.AbsoluteSize
		local half = math.sqrt(size.X * size.X + size.Y * size.Y) / 2
		for _, l in ipairs(fxLines) do
			l.r += dt * 2.2
			if l.r > 1.05 then l.a, l.r, l.len = math.random() * math.pi * 2, 0.45 + math.random() * 0.2, 100 + math.random() * 120 end
			local x, y = size.X / 2 + math.cos(l.a) * l.r * half, size.Y / 2 + math.sin(l.a) * l.r * half
			l.f.Position = UDim2.fromOffset(x, y)
			l.f.Size = UDim2.fromOffset(l.len, 4)
			l.f.Rotation = math.deg(l.a)
			l.f.BackgroundTransparency = 1 - 0.65 * fxK
		end
		fxGui.Enabled = fxK > 0
	end
	local shown = math.floor(fxK * 10 + 0.5) / 10
	if char:GetAttribute("MechaBoostFx") ~= shown then char:SetAttribute("MechaBoostFx", shown) end
	if fxK <= 0 and not fxBoosting then
		if cam and fxBaseFov then cam.FieldOfView = fxBaseFov end
		fxBaseFov = nil
		pcall(function() RunService:UnbindFromRenderStep(FX_BIND) end)
	end
end
local function fxStart()
	if not fxOn() then return end
	fxBoosting = true
	if not fxBaseFov then
		fxBaseFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
		if not (fxGui and fxGui.Parent) then fxBuild() end
		pcall(function() RunService:UnbindFromRenderStep(FX_BIND) end)
		RunService:BindToRenderStep(FX_BIND, Enum.RenderPriority.Camera.Value + 2, fxStep)
	end
end
local function fxStop() fxBoosting = false end
char.AncestryChanged:Connect(function(_, parent)
	if parent then return end
	pcall(function() RunService:UnbindFromRenderStep(FX_BIND) end)
	local cam = workspace.CurrentCamera
	if cam and fxBaseFov then cam.FieldOfView = fxBaseFov end
	if fxGui then fxGui:Destroy() end
end)

local boostConn -- v1.1
local function boost() -- v1.1: steerable boost for DashTime s at DashSpeedMul x run speed
	if not (hrp and hum and hum.Health > 0) then return end
	local t = tonumber(char:GetAttribute("DashTime")) or 1.5
	local mul = tonumber(char:GetAttribute("DashSpeedMul")) or 2
	local hop = tonumber(char:GetAttribute("DashHop")) or 0
	local speed = math.max(tonumber(char:GetAttribute("MoveRunSpeed")) or 0, hum.WalkSpeed) * mul
	local dir = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if t <= 0 or speed <= 0 or dir.Magnitude < 1e-3 then return end
	dir = dir.Unit
	-- v1.6: in the air with no move input -> straight up
	local inAir = hum.FloorMaterial == Enum.Material.Air
	local still = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z).Magnitude < 0.1
	local up = false
	if script:GetAttribute("MechaAirUpEnabled") ~= false and inAir and still then up = true end
	local upH = math.max(0, tonumber(script:GetAttribute("MechaAirUpHeight")) or 30)
	local upT = math.max(0.05, tonumber(script:GetAttribute("MechaAirUpTime")) or 0.6)
	if up then
		t = math.max(t, upT) -- v1.6 hover: the rise, then hold the height until the boost ends
		char:SetAttribute("MechaAirUpPhase", "rise")
		char:SetAttribute("MechaBoostMode", "up")
		char:SetAttribute("MechaAirUpCount", (char:GetAttribute("MechaAirUpCount") or 0) + 1)
	elseif inAir then
		char:SetAttribute("MechaBoostMode", "air")
	else
		char:SetAttribute("MechaBoostMode", "ground")
	end
	if boostConn then boostConn:Disconnect() end
	local old = hrp:FindFirstChild("MechaDash")
	if old then old:Destroy() end
	local oldAt = hrp:FindFirstChild("MechaDashAt")
	if oldAt then oldAt:Destroy() end
	local at = Instance.new("Attachment")
	at.Name = "MechaDashAt"
	at.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Name = "MechaDash"
	lv.Attachment0 = at
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	if up then -- v1.6: straight up, no sideways speed
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.VectorVelocity = Vector3.new(0, upH / upT, 0)
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	lv.MaxForce = math.huge
	lv.Parent = hrp
	if hop > 0 and not up then -- v1.6: no star hop on the straight-up boost
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		local cur = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.sqrt(2 * workspace.Gravity * hop), cur.Z)
	end
	char:SetAttribute("MechaDashLocal", "dashing")
	char:SetAttribute("MechaDashLocalCount", (char:GetAttribute("MechaDashLocalCount") or 0) + 1)
	fxStart() -- v1.2
	local t0 = os.clock()
	local jam0 = char:GetAttribute("PartsJammedAt") -- v1.8
	local conn
	local function stop()
		fxStop() -- v1.2
		if conn then conn:Disconnect() end
		if boostConn == conn then boostConn = nil end
		lv:Destroy()
		at:Destroy()
		if hrp.Parent then
			local cur = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(0, up and math.min(cur.Y, 0) or cur.Y, 0) -- v1.6: the rise peaks here
		end
		if up and char.Parent then char:SetAttribute("MechaAirUpPhase", "done") end -- v1.6 hover
		if char.Parent then char:SetAttribute("MechaDashLocal", "idle") end
	end
	conn = RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		if pounceStarted() then -- v1.3
			char:SetAttribute("MechaBoostEnd", "pounce")
			stop()
			return
		end
		if char:GetAttribute("PartsJammedAt") ~= jam0 then -- v1.8: star Raptor Screech hit
			char:SetAttribute("MechaBoostEnd", "jammed")
			stop()
			return
		end
		if os.clock() - t0 >= t or not char.Parent or hum.Health <= 0 or char:GetAttribute("PounceLatched") == true
			or (tonumber(char:GetAttribute("StunnedUntil")) or 0) > now then
			stop()
			return
		end
		if up then -- v1.6: after the rise, hold the height; v1.7: steerable at boost speed while rising / hovering
			if os.clock() - t0 >= upT and char:GetAttribute("MechaAirUpPhase") == "rise" then
				char:SetAttribute("MechaAirUpPhase", "hover")
			end
			local vy = char:GetAttribute("MechaAirUpPhase") == "rise" and upH / upT or 0
			local umd = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
			local side = Vector3.zero
			if umd.Magnitude > 0.1 then
				side = umd.Unit * speed
				if char:GetAttribute("MechaBoostDir") ~= "move" then char:SetAttribute("MechaBoostDir", "move") end
			elseif char:GetAttribute("MechaBoostDir") ~= "keep" then
				char:SetAttribute("MechaBoostDir", "keep")
			end
			lv.VectorVelocity = Vector3.new(side.X, vy, side.Z)
			return
		end
		local md = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
		if md.Magnitude > 0.1 then
			dir = md.Unit
			if char:GetAttribute("MechaBoostDir") ~= "move" then char:SetAttribute("MechaBoostDir", "move") end
		elseif char:GetAttribute("MechaBoostDir") ~= "keep" then
			char:SetAttribute("MechaBoostDir", "keep")
		end
		lv.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	end)
	boostConn = conn
end
local function dash()
	if not (hrp and hum and hum.Health > 0) then return end
	local dist = tonumber(char:GetAttribute("DashDistance")) or 0
	local t = tonumber(char:GetAttribute("DashTime")) or 0.35
	local hop = tonumber(char:GetAttribute("DashHop")) or 0
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if dist <= 0 or t <= 0 or look.Magnitude < 1e-3 then return end
	local v = look.Unit * (dist / t)
	local at = Instance.new("Attachment")
	at.Name = "MechaDashAt"
	at.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Name = "MechaDash"
	lv.Attachment0 = at
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(v.X, v.Z)
	lv.MaxForce = math.huge
	lv.Parent = hrp
	if hop > 0 then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		local cur = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.sqrt(2 * workspace.Gravity * hop), cur.Z)
	end
	char:SetAttribute("MechaDashLocal", "dashing")
	char:SetAttribute("MechaDashLocalCount", (char:GetAttribute("MechaDashLocalCount") or 0) + 1)
	task.delay(t, function()
		lv:Destroy()
		at:Destroy()
		-- stop the dash speed (measured in Play: without this the dino slid ~60 studs more after a 50-stud dash)
		if hrp.Parent then
			local cur = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(0, cur.Y, 0)
		end
		if char.Parent then char:SetAttribute("MechaDashLocal", "idle") end
	end)
end
char:GetAttributeChangedSignal("DashStartedAt"):Connect(function()
	local s = char:GetAttribute("DashStartedAt")
	if s == lastDash then return end
	lastDash = s
	if char:GetAttribute("DashSpeedMul") ~= nil then boost() else dash() end -- v1.1
end)

-- PC keys ------------------------------------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	for n, k in ipairs(KEYS) do -- v1.1: R / C (was 1 / 2); v1.4: + T / V (slots 3 / 4)
		if input.KeyCode == k then press(n, input) break end
	end
end)
UserInputService.InputEnded:Connect(function(input) -- v1.8: let go of the key / touch that started a Screech aim
	if aim and not aim.gesture then
		if (aim.input and input == aim.input) or (input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == KEYS[aim.slot]) then
			aimRelease()
		end
	end
end)

-- v1.1: "new ability" popup ----------------------------------------------------------------------------------------
local pgNews = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:FindFirstChild("SkillShared")
local okST, ST = pcall(function() return require(shared:WaitForChild("SkillTree", 10)) end)
local isTouch = UserInputService.TouchEnabled
local function showNews(id)
	local p = okST and ST.PATHS[id]
	if not p then return end
	local slot
	for n = 1, 4 do if slotPart(n) == id then slot = n break end end -- v1.4: 4 slots
	local how = not slot and "Put it in a LOADOUT slot (SKILLS)"
		or isTouch and (slot <= 2 and "Tap its button to use it" or "Tap and pull down its button to use it")
		or ("Press %s to use it"):format(KEY_NAMES[slot])
	local old = pgNews:FindFirstChild("MechaNews")
	if old then old:Destroy() end
	local g = Instance.new("ScreenGui")
	g.Name = "MechaNews"
	g.ResetOnSpawn = true
	g.DisplayOrder = 25
	local f = Instance.new("Frame")
	f.Name = "Box"
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.new(0.5, 0, 0, 60)
	f.Size = UDim2.fromOffset(320, 70)
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.1
	f.Parent = g
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = f
	local st = Instance.new("UIStroke")
	st.Color, st.Thickness = ORANGE, 2.5
	st.Parent = f
	local function line(text, y, h, size, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(12, y)
		l.Size = UDim2.new(1, -24, 0, h)
		l.Font = Enum.Font.FredokaOne
		l.Text = text
		l.TextSize = size
		l.TextColor3 = color
		l.Parent = f
		return l
	end
	line("⚙ NEW: " .. string.upper(p.name), 8, 28, 22, ORANGE).Name = "Title"
	line(how, 38, 22, 16, Color3.new(1, 1, 1)).Name = "How"
	g.Parent = pgNews
	char:SetAttribute("MechaNewsShown", id)
	task.delay(4, function() if g.Parent then g:Destroy() end end)
end
local known = {}
if okST then
	for id in pairs(ST.BUTTONS or {}) do known[id] = player:GetAttribute("SkillPath_" .. id) or 0 end
	player.AttributeChanged:Connect(function(name)
		local id = name:sub(1, 10) == "SkillPath_" and name:sub(11) or nil
		if not id or known[id] == nil then return end
		local n = player:GetAttribute(name) or 0
		local was = known[id]
		known[id] = n
		if was == 0 and n >= 1 then
			task.delay(0.3, function() showNews(id) end) -- the slot (SkillSlot1..4) arrives with the same buy
		end
	end)
end

-- test hook: script attribute MechaButtonsForceTouch = true draws the touch buttons on PC too (Studio layout checks)
if not UserInputService.TouchEnabled and script:GetAttribute("MechaButtonsForceTouch") ~= true then
	char:SetAttribute("MechaButtonsState", "keys")
	return
end
char:SetAttribute("MechaButtonsState", "on")

-- touch buttons ------------------------------------------------------------------------------------------------------
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("MechaButtons")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "MechaButtons"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5

local function label(parent, text, pos, size, maxSize, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position, l.Size = pos, size
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
	return l
end

local slots = {}
local draw -- v1.4: forward
-- v1.4: tap-and-pull gesture ------------------------------------------------------------------------------------------
local function pullOn() return script:GetAttribute("MechaButtonsPullEnabled") ~= false end
local gesture -- {n, input, y0, pulling, px}
local function setPulling(on)
	local s = gesture and slots[gesture.n]
	if not s or gesture.pulling == on then return end
	gesture.pulling = on
	if on then
		s.stroke.Color, s.stroke.Transparency, s.stroke.Thickness = Color3.new(1, 1, 1), 0, 4
		s.pull.TextColor3, s.pull.TextTransparency = Color3.new(1, 1, 1), 0
	else
		s.stroke.Thickness = 2.5
		s.pull.TextColor3 = PULL_COLOR
		draw()
	end
end
local function beginGesture(n, input)
	local s = slots[n]
	local h = s and s.b.AbsoluteSize.Y or 60
	local px = math.clamp(0.22 * h, 14, 24)
	gesture = {n = n, input = input, y0 = input.Position.Y, pulling = false, px = px}
	char:SetAttribute("MechaButtonsPullPx", math.floor(px * 10 + 0.5) / 10)
	if slotPart(n) == "screech" then aimStart(n, input, true) end -- v1.8: aim the tap slot until it becomes a pull
end
local function endGesture()
	local g = gesture
	if not g then return end
	local pulled = g.pulling
	setPulling(false)
	gesture = nil
	local s = slots[g.n]
	if s then s.scale.Scale = 1 end
	char:SetAttribute("MechaButtonsLastGesture", pulled and "pull" or "tap")
	local chosen = pulled and g.n + 2 or g.n
	if slotPart(chosen) == "screech" then -- v1.8: the release fires the aimed Screech
		char:SetAttribute("MechaButtonsLastPress", ("slot%d:screech"):format(chosen))
		if aim and aim.slot == chosen then aimRelease() else aimCancel() end
		return
	end
	aimCancel()
	press(chosen)
end
UserInputService.InputChanged:Connect(function(input)
	if not gesture then return end
	if input == gesture.input or (gesture.input.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseMovement) then
		setPulling(input.Position.Y - gesture.y0 >= gesture.px)
		local want = gesture.pulling and gesture.n + 2 or gesture.n -- v1.8: aim the slot the gesture would fire
		if slotPart(want) == "screech" then
			if not (aim and aim.slot == want) then aimStart(want, gesture.input, true) end
		elseif aim and aim.gesture then
			aimCancel()
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if gesture and input == gesture.input then endGesture() end
end)

for n = 1, 2 do
	local b = Instance.new("TextButton")
	b.Name = "Slot_" .. n
	b.AnchorPoint = Vector2.new(1, 1)
	b.Size = UDim2.fromScale(SIZE, SIZE)
	b.SizeConstraint = Enum.SizeConstraint.RelativeXX
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = 0.3
	b.AutoButtonColor = false
	b.Text = ""
	b.ClipsDescendants = true
	b.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.22, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local cd = Instance.new("Frame")
	cd.Name = "Cooldown"
	cd.AnchorPoint = Vector2.new(0, 1)
	cd.Position = UDim2.fromScale(0, 1)
	cd.Size = UDim2.fromScale(1, 0)
	cd.BackgroundColor3 = Color3.new(0, 0, 0)
	cd.BackgroundTransparency = 0.45
	cd.BorderSizePixel = 0
	cd.Parent = b
	local cdCorner = Instance.new("UICorner") -- ClipsDescendants does not follow the button's rounded corners
	cdCorner.CornerRadius = UDim.new(0.22, 0)
	cdCorner.Parent = cd
	local main = label(b, "DASH", UDim2.fromScale(0.1, 0.3), UDim2.fromScale(0.8, 0.4), 18)
	main.Name = "Main"
	local sub = label(b, "", UDim2.fromScale(0.1, 0.68), UDim2.fromScale(0.8, 0.22), 11)
	sub.Name = "Sub"
	sub.TextTransparency = 0.25
	local pull = label(b, "", UDim2.fromScale(0.04, 0.78), UDim2.fromScale(0.92, 0.16), 12, PULL_COLOR) -- v1.4
	pull.Name = "Pull"
	local key = label(b, UserInputService.TouchEnabled and "" or KEY_NAMES[n], UDim2.fromScale(0.08, 0.04), UDim2.fromScale(0.22, 0.22), 10, -- v1.1: R / C
		Color3.fromRGB(154, 160, 173))
	key.Name = "Key"
	local pips = Instance.new("Frame")
	pips.Name = "Pips"
	pips.BackgroundTransparency = 1
	pips.AnchorPoint = Vector2.new(1, 0)
	pips.Position = UDim2.fromScale(0.92, 0.07)
	pips.Size = UDim2.fromScale(0.4, 0.12)
	pips.Parent = b
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Padding = UDim.new(0.08, 0)
	list.Parent = pips
	local pipFrames = {}
	for i = 1, 2 do
		local p = Instance.new("Frame")
		p.Name = "Pip_" .. i
		p.Size = UDim2.fromScale(1, 1) -- a circle as tall as the pip row
		p.SizeConstraint = Enum.SizeConstraint.RelativeYY
		p.BorderSizePixel = 0
		p.Parent = pips
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0.5, 0)
		pc.Parent = p
		pipFrames[i] = p
	end
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		scale.Scale = 0.92
		if pullOn() and slotPart(n + 2) then -- v1.4: decide on release
			beginGesture(n, input)
		else
			char:SetAttribute("MechaButtonsLastGesture", "press")
			press(n, input)
		end
	end)
	b.InputEnded:Connect(function() scale.Scale = 1 end)
	slots[n] = {b = b, stroke = stroke, cd = cd, main = main, sub = sub, pull = pull, pips = pipFrames, scale = scale}
end

local function layout()
	local spots = SPOTS[char:GetAttribute("AutoRun") == true]
	for n, s in ipairs(slots) do
		s.b.Position = UDim2.new(1 - spots[n][1], 0, 1 - spots[n][2], 0)
	end
end

draw = function()
	local ready = char:GetAttribute("DashEnabled") == true
	local max = math.clamp(tonumber(char:GetAttribute("DashCharges")) or 0, 0, 2)
	local left = tonumber(char:GetAttribute("DashChargesLeft")) or 0
	for n, s in ipairs(slots) do
		if gesture and gesture.n == n and gesture.pulling then continue end -- v1.4: keep the pulling look
		local id = slotPart(n)
		if id == "cloak" or TIMED_PARTS[id] then ready = (partState(id)) else ready = char:GetAttribute("DashEnabled") == true end -- v1.4; v1.5: + timed parts
		if id then
			s.stroke.Color, s.stroke.Transparency = ORANGE, ready and 0 or 0.5
			s.main.Text = partName(id) -- v1.4 (was: thrusters -> DASH, else the id)
			s.main.TextTransparency = ready and 0 or 0.5
			s.sub.Text = ""
			for i, p in ipairs(s.pips) do
				p.Visible = id == "thrusters" and i <= max -- v1.4: pips are the dash charges only
				p.BackgroundColor3 = i <= left and ORANGE or Color3.fromRGB(85, 85, 85)
			end
		else
			s.stroke.Color, s.stroke.Transparency = Color3.new(1, 1, 1), 0.5
			s.main.Text, s.main.TextTransparency = "+", 0.4
			s.sub.Text = "slot " .. n
			for _, p in ipairs(s.pips) do p.Visible = false end
			s.cd.Size = UDim2.fromScale(1, 0)
		end
		-- v1.4: pull part sub-label
		local pid = pullOn() and slotPart(n + 2) or nil
		if pid then
			local pready = partState(pid)
			s.pull.Text = "▼ " .. partName(pid)
			s.pull.TextTransparency = pready and 0 or 0.5
			if not id then s.sub.Text = "" end
		else
			s.pull.Text = ""
		end
	end
end

local lastCloakReady -- v1.4: redraw when the cloak's readiness flips (cooldown runs out)
local lastTimedReady = {} -- v1.5: the same for the timed parts
RunService.RenderStepped:Connect(function()
	local nextAt = tonumber(char:GetAttribute("DashNextChargeAt")) or 0
	local rc = tonumber(char:GetAttribute("DashRecharge")) or 8
	local frac = 0
	if nextAt > 0 and rc > 0 then frac = math.clamp((nextAt - workspace:GetServerTimeNow()) / rc, 0, 1) end
	local cReady, cFrac = partState("cloak") -- v1.4
	local redraw = false
	for n, s in ipairs(slots) do
		local id = slotPart(n)
		local tFrac = 0
		if id and TIMED_PARTS[id] then -- v1.5
			local r, f = partState(id)
			tFrac = f
			if r ~= lastTimedReady[id] then lastTimedReady[id] = r; redraw = true end
		end
		s.cd.Size = UDim2.fromScale(1, id == "thrusters" and frac or id == "cloak" and cFrac or tFrac)
	end
	if cReady ~= lastCloakReady then lastCloakReady = cReady; redraw = true end
	if redraw then draw() end
end)

local WATCH = {DashEnabled = true, DashCharges = true, DashChargesLeft = true, AutoRun = true,
	CloakEnabled = true, CloakState = true, CloakReadyAt = true} -- v1.4: + cloak
for _, tp in pairs(TIMED_PARTS) do -- v1.5
	for _, k in ipairs({"Enabled", "Until", "ReadyAt"}) do WATCH[tp[1] .. k] = true end
end
char.AttributeChanged:Connect(function(name)
	if name == "AutoRun" then layout() end
	if WATCH[name] then draw() end
end)
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 9) == "SkillSlot" then draw() end -- v1.4: slots 1-4 (was 1 / 2)
end)
layout()
draw()
gui.Parent = pg
