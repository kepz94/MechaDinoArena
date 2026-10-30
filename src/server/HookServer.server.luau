-- HookServer v1.5 (Mecha Dino Arena) — the pachy's Grappling Hook (right-arm wrist claw). MDA-121, plan
-- docs/plans/PACHY_PARTS_v1.0.md Drop A, mockup docs/mockups/pachy_parts_options.html ("A · Wrist claw", crosshair + aim help).
-- Kepu 2026-10-30: "a grappling hook that can hook to players and bring them in for a headsmash at 10 damage ... pull
--   them in then the pachy would dip its head for a smash which knocks them back without the slowed effect" · "connected
--   to its right arm ... something he lifts his arm to shoot" · "dont allow the grappling hook to work on objects ... this
--   will be strictly for pvp or bots".
-- Settings (character attributes, SkillEffects 1.14): HookEnabled, HookRange, HookCooldown, HookDamage, HookLook.
-- Remote DinoHookRequest(stamp, aimDir) (MechaButtons 1.15 sends the camera look). Checks in order: "badArg", "dead",
--   "disabled" (switch / HookEnabled), "menu", "stunned", "pinned", "busy" (own hook running, or a headbutt charge running:
--   HeadbuttStartedAt newer than HeadbuttEndedAt), "cooldown" (HookReadyAt) -> the shot. Result in HookServerResult.
-- The shot: origin = the right arm (segment ArmR Root, else the HumanoidRootPart). Only dinos can be grabbed: models in
--   Workspace with a Hitboxes folder, Bitable true, a Species or IsBot, not self, not KO (DummyState "ko"). Along the aim,
--   up to HookRange studs, the first dino whose hitbox comes within AIM_HELP x scale studs of the line is the
--   target ("crosshair + aim help"). The world (terrain, trees, rocks, props; every character / bot / tall grass excluded)
--   blocks: a world hit nearer than the target, or a wall between the arm and the target, = "blocked". Nothing found = "miss".
--   Target with Energy Shield up (EnergyShieldUntil) = "shielded". Every shot starts the cooldown (HookReadyAt).
--   Pachy stamps: HookAimDir, HookAimEnd (where the claw goes), HookTargetName (or ""), HookResult ("hit" / "miss" /
--   "blocked" / "shielded"), HookLaunchAt (= start + WINDUP, the arm is up), HookContactAt (claw arrives; 0 on a miss),
--   HookSmashAt (pull ends; 0 on a miss), HookStartedAt (set last; clients react to it). HookCount.
-- On a hit: the target is held and pulled for PULL_TIME to GAP_LEN x scale in front of the pachy (followed live):
--   a player's dino gets HookPullBy (pachy name), HookPullGap, HookPullTime, HookPullAt (last; HookPull 1.0 moves it on its
--   client); a bot is slid by this script (anchored, then released). Both get HookHeldUntil (StatusBadges / poses).
-- Smash at HookSmashAt: the pachy's head must be within (16 + 2) x scale of the target's hitboxes (else "escaped").
--   Damage = HookDamage x the roar debuff, off DummyHealth (ArenaPvP bridges it for players); killing blow -> KilledBy,
--   KilledByUserId, KilledWith "hook", KilledAt (last). Knockback SHOVE studs, no slow: players get HeadbuttShoveFrom /
--   HeadbuttShoveDist / HeadbuttShoveTime / HeadbuttShoveAt (HeadbuttShove 1.0 pushes them), bots are slid away. Energy
--   Shield up at the smash = no knockback. Pachy: HookHitDamage, HookHitTarget, HookHitCount, HookHitAt (last),
--   HookSmashResult ("smash" / "escaped" / "gone").
-- Look: while HookLook is true the pachy carries "Mecha_HookArm" (a slim steel wrist cuff + claw on ArmR, colours no skin
--   role uses); removed when false. HookBusyUntil (server time) while a shot runs (HeadbuttServer 1.2 refuses then).
-- v1.1 (Kepu 2026-10-30: "the grappling hook should be on the right arm of the dino. it should wear like a forearm attachment
--   that the dino lifts to shoot. rn it shoots at the ground because the dino arm doesnt lift straight"): the aim keeps the
--   camera's heading but its pitch is held within PITCH_MIN .. PITCH_MAX (-8 .. +25 deg; the camera looks down at the dino,
--   which sent shots into the ground). The look is a slim launcher worn along the right forearm: a steel sleeve over
--   ArmR_fore (along the forearm toward the hand), a dark barrel running past the hand, two claw prongs at its tip (HookFX
--   fires from the barrel tip; HookPose 1.1 lifts the arm level along the shot).
-- v1.2: PITCH_MIN -8 -> -2 deg (Studio test: a -8 deg shot from shoulder height met flat ground ~33-50 studs out, inside
--   the 60 / 80 range, so level shots at a dino ahead still ended in the ground).
-- v1.3 (Kepu 2026-10-30: "what it should do is replace the right arm with this grappling hook arm when it is attached",
--   with a prosthesis reference picture): with HookLook the pachy's right forearm, hand and claws are hidden (Transparency
--   1; each part keeps its old value in HookArmOrigT and gets it back when the look goes) and a hook-arm prosthesis takes
--   their place, welded to ArmR_fore and running from the elbow along the forearm (L = 1.8 x the forearm length): a leather
--   strap with a steel buckle at the elbow, a dark steel socket collar, a brass housing, an open frame of four thin brass
--   rails ending in a brass front yoke (top + bottom), a rope spool inside (steel nut behind it, red ring in front), a short
--   steel rod,
--   and at the front the steel hook (model "Hook": Shank, Bend, Barb, Point; HookFX 1.2 hides it while it flies). An
--   invisible "Barrel" runs from the elbow to the yoke (0.95 L) so the claw still leaves from its tip. Our own blocky
--   design in the game's style (brass / rope / hook idea from the reference, not a copy of that art). Switch: script
--   attribute HookArmReplaceEnabled (default true, read at start; false = the v1.1 forearm launcher). Diagnostics
--   (character): HookArmHidden (parts hidden), HookLookBuilt.
-- v1.4 (Kepu 2026-10-30: "You have the hook on the wrong side of the Dino. I need it on the right side of the Dino. The
--   right arm because that's the default shoulder view on mobile so I can see it"): the pachy rig's "ArmR" segment sits on
--   the dino's LEFT (torso space: the head is +X, the arm joints at Z -0.7 (ArmR) / +0.7 (ArmL); right = forward x up =
--   +Z), so the hook now goes on the segment named by script attribute HookArmSide (default "ArmL" = the dino's real right
--   arm; "ArmR" = 1.3). Every arm use follows it: the shot origin (Root), the hidden parts (<seg>_fore / _hand /
--   _claw1-3), the prosthesis / launcher (<seg>_fore, _hand, _upper). Character attribute HookArmSeg (the segment, set
--   when the character comes in) tells HookPose 1.2 which arm to lift.
-- v1.5 (Kepu 2026-10-30: "You need to be able to do this crap for every Dino and its mech parts ... Plug and play"):
--   BindableFunction "BuildPreview_hookarm" under this script (server only) for the Lab card (LabPreviewServer 1.2 finds
--   it by name): Invoke(pachy mannequin) sets HookLook true on it, runs the same setLook as on a player and returns its
--   "Mecha_HookArm" model (nil when nothing was built). The live hook is unchanged. Switch: script attribute
--   HookServerPreviewEnabled (default true; false -> returns nil).
-- Switch: script attribute HookServerEnabled (default true, read at start). Diagnostics: script HookServerVersion,
--   HookShots, HookHits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.5"
local PITCH_MIN, PITCH_MAX = math.rad(-2), math.rad(25) -- v1.1 clamp; v1.2 min -8 -> -2
local WINDUP = 0.15        -- s arm raise before the claw flies
local CLAW_SPEED = 220     -- studs/s (world)
local PULL_TIME = 0.5      -- s
local GAP_LEN = 9          -- studs x scale: where the target ends up in front of the pachy's root
local AIM_HELP = 4         -- studs x scale around the aim line
local SMASH_TOL = 18       -- studs x scale head-to-hitbox for the smash
local SHOVE, SHOVE_TIME = 30, 0.35
local STEEL, STEEL_DARK = Color3.fromRGB(154, 166, 184), Color3.fromRGB(93, 104, 120)
local BRASS, LEATHER = Color3.fromRGB(201, 163, 74), Color3.fromRGB(110, 72, 40)        -- v1.3 prosthesis
local ROPE, RING_RED = Color3.fromRGB(196, 160, 110), Color3.fromRGB(180, 40, 40)
local ARM_HIDE = {"ArmR_fore", "ArmR_hand", "ArmR_claw1", "ArmR_claw2", "ArmR_claw3"}

script:SetAttribute("HookServerVersion", VERSION)
script:SetAttribute("HookShots", 0)
script:SetAttribute("HookHits", 0)
if script:GetAttribute("HookServerEnabled") == nil then script:SetAttribute("HookServerEnabled", true) end
local enabled = script:GetAttribute("HookServerEnabled") ~= false
if script:GetAttribute("HookArmReplaceEnabled") == nil then script:SetAttribute("HookArmReplaceEnabled", true) end
local armReplace = script:GetAttribute("HookArmReplaceEnabled") ~= false -- v1.3
if script:GetAttribute("HookArmSide") == nil then script:SetAttribute("HookArmSide", "ArmL") end -- v1.4
local HOOK_SEG = script:GetAttribute("HookArmSide") == "ArmR" and "ArmR" or "ArmL" -- v1.4: ArmL = the dino's right arm
for i, name in ipairs(ARM_HIDE) do ARM_HIDE[i] = (name:gsub("^ArmR", HOOK_SEG)) end -- v1.4

local remote = ReplicatedStorage:FindFirstChild("DinoHookRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoHookRequest"
	remote.Parent = ReplicatedStorage
end

local function now() return workspace:GetServerTimeNow() end

local function armOrigin(char)
	local seg = char:FindFirstChild(HOOK_SEG) -- v1.4
	local root = seg and (seg:IsA("BasePart") and seg or seg:FindFirstChild("Root"))
	if root and root:IsA("BasePart") then return root.Position end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function headPos(char)
	local hb = char:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxSegment") == "Head" then return p.Position end
		end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function closestOnBox(part, pos)
	local lp = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
	return part.CFrame:PointToWorldSpace(c)
end

local function gapTo(pos, hb)
	local best = math.huge
	for _, p in ipairs(hb:GetChildren()) do
		if p:IsA("BasePart") then best = math.min(best, (closestOnBox(p, pos) - pos).Magnitude) end
	end
	return best
end

local function isTarget(m, self)
	if not (m:IsA("Model") and m ~= self and m:IsDescendantOf(workspace)) then return nil end
	local hb = m:FindFirstChild("Hitboxes")
	if not hb or m:GetAttribute("Bitable") ~= true then return nil end
	if m:GetAttribute("Species") == nil and m:GetAttribute("IsBot") ~= true then return nil end
	if m:GetAttribute("DummyState") == "ko" then return nil end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return nil end
	return hb
end

local function candidates(self)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c then local hb = isTarget(c, self) if hb then table.insert(list, {m = c, hb = hb}) end end
	end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	if bots then
		for _, b in ipairs(bots:GetChildren()) do
			local hb = isTarget(b, self) if hb then table.insert(list, {m = b, hb = hb}) end
		end
	end
	return list
end

local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
local function worldExclude()
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	local fx = workspace:FindFirstChild("DinoFX_Local")
	if fx then table.insert(ex, fx) end
	for _, d in ipairs(workspace:GetChildren()) do
		if d:IsA("Model") and (d:FindFirstChild("Hitboxes") or d:FindFirstChildOfClass("Humanoid")) then table.insert(ex, d) end
	end
	worldParams.FilterDescendantsInstances = ex
	return worldParams
end

-- v1.3: hide / restore the real right forearm, hand and claws
local function hideArm(char, hide)
	local seg = char:FindFirstChild(HOOK_SEG) -- v1.4
	local n = 0
	if seg then
		for _, name in ipairs(ARM_HIDE) do
			local p = seg:FindFirstChild(name, true)
			if p and p:IsA("BasePart") then
				if hide then
					if p:GetAttribute("HookArmOrigT") == nil then p:SetAttribute("HookArmOrigT", p.Transparency) end
					p.Transparency = 1
					n += 1
				elseif p:GetAttribute("HookArmOrigT") ~= nil then
					p.Transparency = p:GetAttribute("HookArmOrigT")
					p:SetAttribute("HookArmOrigT", nil)
				end
			end
		end
	end
	char:SetAttribute("HookArmHidden", n)
end

-- v1.3: the hook-arm prosthesis in place of the forearm (see header)
local function buildProsthesis(char, seg, fore, hand)
	local upper = seg:FindFirstChild(HOOK_SEG .. "_upper")
	local up = fore.CFrame.UpVector * fore.Size.Y / 2
	local e1, e2 = fore.Position + up, fore.Position - up
	local elbow, far = e1, e2
	if upper and upper:IsA("BasePart") and (e2 - upper.Position).Magnitude < (e1 - upper.Position).Magnitude then elbow, far = e2, e1 end
	if (hand.Position - far).Magnitude > (hand.Position - elbow).Magnitude then elbow, far = far, elbow end
	local axis = (far - elbow).Unit
	local w = math.min(fore.Size.X, fore.Size.Z)
	local L = fore.Size.Y * 1.8
	local m = Instance.new("Model")
	m.Name = "Mecha_HookArm"
	local hookM = Instance.new("Model")
	hookM.Name = "Hook"
	hookM.Parent = m
	local base = CFrame.lookAt(elbow, elbow + axis) -- Look = along the arm, Up = world-up side, Right = side
	local function part(name, size, color, at, opts, parent)
		-- at = Vector3(right, up, along) in w / w / L units from the elbow
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = (opts and opts.mat) or Enum.Material.Metal
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		local cf = base * CFrame.new(at.X * w, at.Y * w, -at.Z * L)
		if opts and opts.cyl then
			p.Shape = Enum.PartType.Cylinder
			cf = cf * CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis (X) along the arm
		end
		p.CFrame = cf
		if opts and opts.invisible then p.Transparency = 1 end
		p.Parent = parent or m
		local wc = Instance.new("WeldConstraint")
		wc.Part0, wc.Part1 = fore, p
		wc.Parent = p
		return p
	end
	local cyl = {cyl = true}
	part("Strap", Vector3.new(1.75 * w, 1.75 * w, 0.16 * L), LEATHER, Vector3.new(0, 0, 0.06), {mat = Enum.Material.Leather})
	part("Buckle", Vector3.new(0.5 * w, 0.22 * w, 0.1 * L), STEEL, Vector3.new(0, 0.95, 0.06))
	part("Socket", Vector3.new(1.5 * w, 1.5 * w, 0.1 * L), STEEL_DARK, Vector3.new(0, 0, 0.17))
	part("Housing", Vector3.new(1.45 * w, 1.45 * w, 0.12 * L), BRASS, Vector3.new(0, 0, 0.27))
	for _, c in ipairs({{"TL", -1, 1}, {"TR", 1, 1}, {"BL", -1, -1}, {"BR", 1, -1}}) do -- open frame: the spool shows from every side
		part("Rail" .. c[1], Vector3.new(0.2 * w, 0.2 * w, 0.66 * L), BRASS, Vector3.new(c[2] * 0.62, c[3] * 0.62, 0.6))
	end
	part("Nut", Vector3.new(0.07 * L, 1.0 * w, 1.0 * w), STEEL_DARK, Vector3.new(0, 0, 0.36), cyl)
	part("Spool", Vector3.new(0.34 * L, 0.88 * w, 0.88 * w), ROPE, Vector3.new(0, 0, 0.56), {cyl = true, mat = Enum.Material.Fabric})
	part("RedRing", Vector3.new(0.06 * L, 0.96 * w, 0.96 * w), RING_RED, Vector3.new(0, 0, 0.73), {cyl = true, mat = Enum.Material.SmoothPlastic})
	part("Rod", Vector3.new(0.2 * w, 0.2 * w, 0.18 * L), STEEL, Vector3.new(0, 0, 0.84))
	part("YokeTop", Vector3.new(1.6 * w, 0.26 * w, 0.1 * L), BRASS, Vector3.new(0, 0.62, 0.93))
	part("YokeBottom", Vector3.new(1.6 * w, 0.26 * w, 0.1 * L), BRASS, Vector3.new(0, -0.62, 0.93))
	part("Barrel", Vector3.new(0.3 * w, 0.3 * w, 0.95 * L), STEEL_DARK, Vector3.new(0, 0, 0.475), {invisible = true})
	-- the hook: shank forward out of the yoke, bends down, barb back, point up
	part("Shank", Vector3.new(0.3 * w, 0.3 * w, 0.2 * L), STEEL, Vector3.new(0, 0, 1.03), nil, hookM)
	part("Bend", Vector3.new(0.3 * w, 1.3 * w, 0.3 * w), STEEL, Vector3.new(0, -0.5, 1.12), nil, hookM)
	part("Barb", Vector3.new(0.3 * w, 0.3 * w, 0.2 * L), STEEL, Vector3.new(0, -1.05, 1.03), nil, hookM)
	part("Point", Vector3.new(0.26 * w, 0.6 * w, 0.26 * w), STEEL, Vector3.new(0, -0.85, 0.94), nil, hookM)
	m.Parent = char
	hideArm(char, true)
	char:SetAttribute("HookLookBuilt", true)
end

-- the look: slim cuff + claw on the right wrist
local function setLook(char)
	if char:GetAttribute("HookArmSeg") ~= HOOK_SEG then char:SetAttribute("HookArmSeg", HOOK_SEG) end -- v1.4
	local want = char:GetAttribute("HookLook") == true and char:GetAttribute("Species") == "Pachy"
	local old = char:FindFirstChild("Mecha_HookArm")
	if not want then
		if old then old:Destroy() end
		hideArm(char, false) -- v1.3
		return
	end
	if old then return end
	local seg = char:FindFirstChild(HOOK_SEG) -- v1.4
	local root = seg and (seg:IsA("BasePart") and seg or seg:FindFirstChild("Root"))
	if not (root and root:IsA("BasePart")) then return end
	-- v1.1: a forearm launcher: sleeve over ArmR_fore pointing toward the hand, barrel past the hand, claw prongs at the tip
	local fore = seg:FindFirstChild(HOOK_SEG .. "_fore")
	local hand = seg:FindFirstChild(HOOK_SEG .. "_hand")
	if not (fore and fore:IsA("BasePart") and hand and hand:IsA("BasePart")) then return end
	if armReplace then return buildProsthesis(char, seg, fore, hand) end -- v1.3
	local toHand = hand.Position - fore.Position
	if toHand.Magnitude < 1e-3 then return end
	local axis = toHand.Unit
	local width = math.min(fore.Size.X, fore.Size.Z)
	local foreLen = math.max(fore.Size.X, fore.Size.Y, fore.Size.Z)
	local m = Instance.new("Model")
	m.Name = "Mecha_HookArm"
	local function part(name, size, color, center)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.Metal
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CFrame = CFrame.lookAt(center, center + axis)
		p.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = fore, p
		w.Parent = p
		return p
	end
	local sleeveLen = foreLen * 0.8
	part("Sleeve", Vector3.new(width * 1.3, width * 1.3, sleeveLen), STEEL, fore.Position)
	local barrelLen = toHand.Magnitude + width * 1.2
	local barrelCenter = fore.Position + axis * (barrelLen / 2)
	local barrel = part("Barrel", Vector3.new(width * 0.45, width * 0.45, barrelLen), STEEL_DARK, barrelCenter)
	local tip = fore.Position + axis * barrelLen
	local sideV = barrel.CFrame.RightVector * width * 0.28
	part("ClawL", Vector3.new(width * 0.16, width * 0.16, width * 0.5), STEEL, tip - sideV)
	part("ClawR", Vector3.new(width * 0.16, width * 0.16, width * 0.5), STEEL, tip + sideV)
	m.Parent = char
	char:SetAttribute("HookLookBuilt", true)
end

-- bot slides (anchored, followed live); a newer slide on the same bot takes over (the smash shove right after the pull)
local slides = setmetatable({}, {__mode = "k"}) -- [model] = token of the running slide
local function slide(model, goalFn, time, done)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Anchored and not slides[model]) then return false end
	local my = {}
	slides[model] = my
	local start = hrp.Position
	local rot = hrp.CFrame - hrp.Position
	hrp.Anchored = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < time do
			if not hrp.Parent or slides[model] ~= my then return end
			local u = math.clamp((os.clock() - t0) / time, 0, 1)
			local e = 1 - (1 - u) * (1 - u)
			local g = goalFn()
			hrp.CFrame = CFrame.new(start:Lerp(Vector3.new(g.X, start.Y, g.Z), e)) * rot
			RunService.Heartbeat:Wait()
		end
		if hrp.Parent and slides[model] == my then
			local g = goalFn()
			hrp.CFrame = CFrame.new(Vector3.new(g.X, start.Y, g.Z)) * rot
			hrp.Anchored = false
			slides[model] = nil
		end
		if done then done() end
	end)
	return true
end

local busy = {} -- [char] = true while a shot runs

local function smash(char, player, target, hb)
	local t = now()
	local result
	if not char.Parent or not target.Parent or not isTarget(target, char) then
		result = "gone"
	else
		local hp = headPos(char)
		local s = char:GetScale()
		if not hp or gapTo(hp, hb) > SMASH_TOL * s then result = "escaped" end
	end
	char:SetAttribute("HookSmashResult", result or "smash")
	if result then return end
	local mul = 1
	local untilT, dmul = target:GetAttribute("DebuffUntil"), target:GetAttribute("DebuffDamageTakenMul")
	if typeof(untilT) == "number" and typeof(dmul) == "number" and t < untilT then mul = dmul end
	local d = math.floor((tonumber(char:GetAttribute("HookDamage")) or 10) * mul + 0.5)
	local hpv = target:GetAttribute("DummyHealth")
	if typeof(hpv) == "number" then target:SetAttribute("DummyHealth", math.max(0, hpv - d)) end
	if typeof(hpv) == "number" and hpv > 0 and hpv - d <= 0 then
		target:SetAttribute("KilledBy", char.Name)
		target:SetAttribute("KilledByUserId", player.UserId)
		target:SetAttribute("KilledWith", "hook")
		target:SetAttribute("KilledAt", t)
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local from = root and root.Position or target:GetPivot().Position
	local shielded = (tonumber(target:GetAttribute("EnergyShieldUntil")) or 0) > t
	if not shielded then
		local dist = SHOVE
		if Players:GetPlayerFromCharacter(target) then
			target:SetAttribute("HeadbuttShoveFrom", from)
			target:SetAttribute("HeadbuttShoveDist", dist)
			target:SetAttribute("HeadbuttShoveTime", SHOVE_TIME)
			target:SetAttribute("HeadbuttShoveAt", t) -- HeadbuttShove 1.0 pushes it; no slow stamps
		else
			local thrp = target:FindFirstChild("HumanoidRootPart")
			if thrp then
				local away = (thrp.Position - from) * Vector3.new(1, 0, 1)
				away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
				local goal = thrp.Position + away * dist
				slide(target, function() return goal end, SHOVE_TIME)
			end
		end
	end
	target:SetAttribute("HookSmashedBy", char.Name)
	char:SetAttribute("HookHitDamage", d)
	char:SetAttribute("HookHitTarget", target.Name)
	char:SetAttribute("HookHitCount", (char:GetAttribute("HookHitCount") or 0) + 1)
	char:SetAttribute("HookHitAt", t) -- last: ArenaPvP / SkillEffects / clients
	script:SetAttribute("HookHits", (script:GetAttribute("HookHits") or 0) + 1)
end

local function setResult(char, r)
	char:SetAttribute("HookServerResult", r)
	char:SetAttribute("HookServerResultAt", now())
end

remote.OnServerEvent:Connect(function(player, stamp, aimDir)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or typeof(aimDir) ~= "Vector3" or aimDir.Magnitude < 0.5 or aimDir.Magnitude > 1.5 then
		r = "badArg"
	elseif not hum or hum.Health <= 0 then
		r = "dead"
	elseif not enabled or char:GetAttribute("HookEnabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif busy[char] or (tonumber(char:GetAttribute("HeadbuttStartedAt")) or 0) > (tonumber(char:GetAttribute("HeadbuttEndedAt")) or 0) then
		r = "busy"
	elseif t < (tonumber(char:GetAttribute("HookReadyAt")) or 0) then
		r = "cooldown"
	end
	if r then setResult(char, r) return end
	setResult(char, "ok")
	busy[char] = true
	local s = char:GetScale()
	local dir = aimDir.Unit
	do -- v1.1: heading from the camera, pitch held near level
		local flat = Vector3.new(dir.X, 0, dir.Z)
		if flat.Magnitude < 1e-3 then
			local hrp0 = char:FindFirstChild("HumanoidRootPart")
			flat = hrp0 and hrp0.CFrame.LookVector * Vector3.new(1, 0, 1) or Vector3.zAxis
		end
		local pitch = math.clamp(math.asin(math.clamp(dir.Y, -1, 1)), PITCH_MIN, PITCH_MAX)
		dir = flat.Unit * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	end
	local origin = armOrigin(char) or char:GetPivot().Position
	local range = tonumber(char:GetAttribute("HookRange")) or 60
	local params = worldExclude()
	local wall = workspace:Raycast(origin, dir * range, params)
	local wallDist = wall and (wall.Position - origin).Magnitude or math.huge
	-- first dino near the line
	local best, bestT, bestHb, bestPoint
	for _, c in ipairs(candidates(char)) do
		for _, p in ipairs(c.hb:GetChildren()) do
			if p:IsA("BasePart") then
				local tt = math.clamp((p.Position - origin):Dot(dir), 0, range)
				local onLine = origin + dir * tt
				local cp = closestOnBox(p, onLine)
				if (cp - onLine).Magnitude <= AIM_HELP * s and tt > 0 and (not bestT or tt < bestT) then
					best, bestT, bestHb, bestPoint = c.m, tt, c.hb, cp
				end
			end
		end
	end
	local result, aimEnd = "miss", origin + dir * math.min(range, wallDist)
	if best then
		if bestT > wallDist then
			result = "blocked"
		else
			local los = workspace:Raycast(origin, bestPoint - origin, params)
			if los then
				result, aimEnd = "blocked", los.Position
			elseif (tonumber(best:GetAttribute("EnergyShieldUntil")) or 0) > t then
				result, aimEnd = "shielded", bestPoint
			else
				result, aimEnd = "hit", bestPoint
			end
		end
	elseif wall then
		result = "miss"
	end
	local fly = (aimEnd - origin).Magnitude / CLAW_SPEED
	local launchAt = t + WINDUP
	local contactAt = result == "hit" and (launchAt + fly) or 0
	local smashAt = result == "hit" and (contactAt + PULL_TIME) or 0
	local endAt = result == "hit" and smashAt + 0.3 or (launchAt + fly * 2 + 0.1)
	char:SetAttribute("HookReadyAt", t + math.max(0.5, tonumber(char:GetAttribute("HookCooldown")) or 8))
	char:SetAttribute("HookBusyUntil", endAt)
	char:SetAttribute("HookAimDir", dir)
	char:SetAttribute("HookAimEnd", aimEnd)
	char:SetAttribute("HookTargetName", result == "hit" and best.Name or "")
	char:SetAttribute("HookResult", result)
	char:SetAttribute("HookLaunchAt", launchAt)
	char:SetAttribute("HookContactAt", contactAt)
	char:SetAttribute("HookSmashAt", smashAt)
	char:SetAttribute("HookCount", (char:GetAttribute("HookCount") or 0) + 1)
	char:SetAttribute("HookStartedAt", t) -- last
	script:SetAttribute("HookShots", (script:GetAttribute("HookShots") or 0) + 1)
	if result == "hit" then
		local target, hb = best, bestHb
		task.delay(contactAt - t, function()
			if not (char.Parent and target.Parent) then busy[char] = nil return end
			local s2 = char:GetScale()
			local function goal()
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if not hrp then return target:GetPivot().Position end
				local f = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
				f = f.Magnitude > 1e-3 and f.Unit or Vector3.zAxis
				return hrp.Position + f * GAP_LEN * s2
			end
			target:SetAttribute("HookHeldUntil", smashAt)
			if Players:GetPlayerFromCharacter(target) then
				target:SetAttribute("HookPullBy", char.Name)
				target:SetAttribute("HookPullGap", GAP_LEN * s2)
				target:SetAttribute("HookPullTime", PULL_TIME)
				target:SetAttribute("HookPullAt", now()) -- last: HookPull 1.0 on that player's client
			else
				slide(target, goal, PULL_TIME)
			end
		end)
		task.delay(smashAt - t, function()
			busy[char] = nil
			local player2 = Players:GetPlayerFromCharacter(char)
			if player2 then smash(char, player2, target, hb) end
		end)
	else
		task.delay(endAt - t, function() busy[char] = nil end)
	end
end)

local function onCharacter(char)
	char:GetAttributeChangedSignal("HookLook"):Connect(function() setLook(char) end)
	task.defer(setLook, char)
	char.AncestryChanged:Connect(function(_, parent) if not parent then busy[char] = nil end end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- v1.5: the Lab card model (plug and play: LabPreviewServer 1.2 finds BuildPreview_<pathId>)
if script:GetAttribute("HookServerPreviewEnabled") == nil then script:SetAttribute("HookServerPreviewEnabled", true) end
do
	local fn = Instance.new("BindableFunction")
	fn.Name = "BuildPreview_hookarm"
	fn.OnInvoke = function(model)
		if script:GetAttribute("HookServerPreviewEnabled") == false or typeof(model) ~= "Instance" then return nil end
		model:SetAttribute("Species", "Pachy")
		model:SetAttribute("HookLook", true)
		setLook(model)
		return model:FindFirstChild("Mecha_HookArm")
	end
	fn.Parent = script
end
