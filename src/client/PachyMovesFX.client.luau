-- PachyMovesFX v1.0 (Mecha Dino Arena) — the pachy animation pass effects on this client (LocalScript,
-- StarterPlayerScripts). MDA-313 (+ the FX parts of MDA-304 / 305 / 306 / 308 / 310 / 311), plan
-- docs/plans/PACHY_MOVES_ANIM_v1.0.md; Kepu 2026-11-05 23:34 "A for everything"; red-team: no landing FX (the pistons
-- squash, nothing else), keep the tail + dome tells; mockup docs/mockups/pachy_moves_anim.html v0.1.
-- Every player character and every bot (Workspace.DinoIsland.Bots) with Species "Pachy" is watched. Script switches
-- (default true, read at each event / frame); local folder Workspace.PachyFX_Local; everything is cleaned up:
--   PachyFXBullEnabled       Bull Charge (HeadbuttStartedAt): a snort puff at the nostrils (+0.03 s) and a dust scrape at the
--                            back foot (+0.08 s); HeadbuttHitAt: sparks off the dome.
--   PachyFXPactEnabled       Blood Pact (HeadbuttSacrificeAt): a red burst at the neck; your own pachy: a short red screen
--                            edge; red sparks trail off the pachy for 0.6 s.
--   PachyFXPistonEnabled     Mecha Legs (Mecha_Legs built): the PistonL / PistonR pieces are shown as local copies that slide
--                            along the shin: compress in the leap crouch (JumpStartedAt / JumpPredictedAt, JumpWindup), punch
--                            out at the push and at the double jump (JumpDoubleAt / JumpDoublePredictedAt), compress 0.25 s
--                            at touchdown (Humanoid Landed on this client, or the vertical speed settling); the vents glow
--                            orange while firing. No dust / steam at the landing.
--   PachyFXHookEnabled       Brace & Reel: a white flash at the claw at HookLaunchAt; sparks off the spool every 0.08 s while
--                            reeling (HookContactAt .. HookSmashAt).
--   PachyFXServoEnabled      Thruster Kick: the bells glow up through the squat (ServoDashStartedAt .. ServoDashBlastAt);
--                            at ServoDashUntil a skid (dust behind the feet for 0.3 s) and steam puffs off the bells.
--   PachyFXInkEnabled        Shoulder Cannon: the tank's window brightens while it pumps (InkStartedAt .. InkFireAt); at
--                            InkFireAt a muzzle flash and a black smoke ring off the barrel.
--   PachyFXTetherEnabled     Tail Sling: a puff off the launcher at TetherStartedAt; the launcher's Tip is hidden while the
--                            spike is out (TetherStartedAt .. TetherLandAt + 3.6 s or the next stamp).
--   PachyFXLastStandEnabled  Battle Roar: at PachyLastStandAt a red-gold ring (16 x scale/2 studs) and a flash; the dome glows
--                            red while health is under PachyLastStandBelow; a gold shell while PachyLastStandUntil runs.
--   PachyFXHeadDownEnabled   Steel Dome: while charging a headbutt with PachyHeadDownMul < 1 the dome glows steel-blue; a hit
--                            (LastHitAt) while charging throws blue sparks off the dome.
-- Diagnostics: script PachyFXEvents (count), PachyFXParts (live parts).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.0"
script:SetAttribute("PachyMovesFXVersion", VERSION)
for _, k in ipairs({"PachyFXBullEnabled", "PachyFXPactEnabled", "PachyFXPistonEnabled", "PachyFXHookEnabled", "PachyFXServoEnabled",
	"PachyFXInkEnabled", "PachyFXTetherEnabled", "PachyFXLastStandEnabled", "PachyFXHeadDownEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
script:SetAttribute("PachyFXEvents", 0)
local function on(k) return script:GetAttribute("PachyMovesFXEnabled") ~= false and script:GetAttribute(k) ~= false end
local function ev() script:SetAttribute("PachyFXEvents", (script:GetAttribute("PachyFXEvents") or 0) + 1) end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k) local v = m:GetAttribute(k) return typeof(v) == "number" and v == v and v or nil end
local me = Players.LocalPlayer

local folder = workspace:FindFirstChild("PachyFX_Local")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "PachyFX_Local"
	folder.Parent = workspace
end
local live = 0
local function part(size, color, material, cf, transp, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = transp or 0
	if shape then p.Shape = shape end
	p.CFrame = cf
	p.Parent = folder
	live += 1
	p.Destroying:Connect(function() live -= 1 end)
	return p
end
local function scaleK(m) return (m:IsA("Model") and m:GetScale() or 2) / 2 end
-- a particle burst at a point
local function burst(pos, c0, c1, n, speed, size, life, spread, dir, accel)
	local holder = part(Vector3.new(0.2, 0.2, 0.2), c0, Enum.Material.SmoothPlastic, dir and CFrame.lookAt(pos, pos + dir) or CFrame.new(pos), 1)
	local a = Instance.new("Attachment")
	a.Parent = holder
	local pe = Instance.new("ParticleEmitter")
	pe.Enabled = false
	pe.Color = ColorSequence.new(c0, c1 or c0)
	pe.LightEmission = 0.6
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.2)})
	pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	pe.Speed = NumberRange.new(speed * 0.6, speed)
	pe.SpreadAngle = Vector2.new(spread or 180, spread or 180)
	pe.Lifetime = NumberRange.new(life * 0.6, life)
	pe.EmissionDirection = Enum.NormalId.Front
	pe.Acceleration = accel or Vector3.zero
	pe.Drag = 3
	pe.Parent = a
	pe:Emit(n)
	Debris:AddItem(holder, life + 0.2)
end
local function flash(pos, size, color, life)
	local p = part(Vector3.one * size * 0.4, color, Enum.Material.Neon, CFrame.new(pos), 0.1, Enum.PartType.Ball)
	TweenService:Create(p, TweenInfo.new(life or 0.18), {Size = Vector3.one * size, Transparency = 1}):Play()
	Debris:AddItem(p, (life or 0.18) + 0.05)
end
local function ring(center, diameter, color, life)
	local p = part(Vector3.new(0.2, 2, 2), color, Enum.Material.Neon, CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), 0.2, Enum.PartType.Cylinder)
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0.2, diameter, diameter), Transparency = 1}):Play()
	Debris:AddItem(p, life + 0.05)
end
local function feetY(m)
	local r = m:FindFirstChild("HumanoidRootPart")
	if not r then return nil end
	local hum = m:FindFirstChildOfClass("Humanoid")
	return r.Position.Y - r.Size.Y / 2 - (hum and hum.HipHeight or 0)
end
local function find(m, name) return m:FindFirstChild(name, true) end
local function partOf(m, model, name)
	local mm = m:FindFirstChild(model)
	local p = mm and mm:FindFirstChild(name, true)
	return p and p:IsA("BasePart") and p or nil
end

-- ---------------------------------------------------------------- per-pachy watch
local W = setmetatable({}, {__mode = "k"}) -- [model] = state
local function domeParts(m)
	local head = m:FindFirstChild("Head")
	local list = {}
	if head then for _, p in ipairs(head:GetDescendants()) do if p:IsA("BasePart") and p.Name:match("^Head_dome") then table.insert(list, p) end end end
	return list
end
local function watch(m)
	if W[m] or m:GetAttribute("Species") ~= "Pachy" then return end
	local st = {dome = nil, domeCol = {}, pistons = {}, landAt = nil, wasAir = false}
	W[m] = st
	local k = function() return scaleK(m) end
	-- Bull Charge
	m:GetAttributeChangedSignal("HeadbuttStartedAt"):Connect(function()
		if not on("PachyFXBullEnabled") or m:GetAttribute("BullChargeEnabled") == false then return end
		local s = num(m, "HeadbuttStartedAt")
		if not s or now() - s > 0.5 then return end
		task.delay(0.03, function()
			local n = find(m, "Head_nostrilL") or find(m, "Head_beak")
			if n and n:IsA("BasePart") then burst(n.Position, Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 220), 8, 6 * k(), 0.9 * k(), 0.45, 25, -n.CFrame.UpVector) end
		end)
		task.delay(0.08, function()
			local y = feetY(m)
			local r = m:FindFirstChild("HumanoidRootPart")
			if y and r then burst(Vector3.new(r.Position.X, y + 0.4, r.Position.Z) + r.CFrame.LookVector * -2 * k(), Color3.fromRGB(214, 196, 150), Color3.fromRGB(190, 176, 140), 10, 9 * k(), 1.6 * k(), 0.6, 70, -r.CFrame.LookVector + Vector3.yAxis) end
		end)
		ev()
	end)
	m:GetAttributeChangedSignal("HeadbuttHitAt"):Connect(function()
		if not on("PachyFXBullEnabled") or m:GetAttribute("BullChargeEnabled") == false then return end
		local d = find(m, "Head_domefront") or find(m, "Head_dome1")
		local r = m:FindFirstChild("HumanoidRootPart")
		if d and d:IsA("BasePart") then burst(d.Position, Color3.fromRGB(255, 244, 200), Color3.fromRGB(255, 170, 60), 14, 30 * k(), 0.5 * k(), 0.35, 60, r and r.CFrame.LookVector or nil, Vector3.new(0, -60, 0)) end
		ev()
	end)
	-- Blood Pact
	m:GetAttributeChangedSignal("HeadbuttSacrificeAt"):Connect(function()
		if not on("PachyFXPactEnabled") or m:GetAttribute("BloodPactEnabled") == false then return end
		local s = num(m, "HeadbuttSacrificeAt")
		if not s or now() - s > 0.5 then return end
		local neck = m:FindFirstChild("Neck")
		local nr = neck and neck:FindFirstChild("Root")
		if nr and nr:IsA("BasePart") then burst(nr.Position, Color3.fromRGB(220, 20, 40), Color3.fromRGB(110, 0, 18), 22, 18 * k(), 0.8 * k(), 0.5, 180, nil, Vector3.new(0, -50, 0)) end
		if m == me.Character then
			local pg = me:FindFirstChildOfClass("PlayerGui")
			if pg then
				local g = Instance.new("ScreenGui")
				g.Name = "PachyPactEdge"
				g.IgnoreGuiInset = true
				g.ResetOnSpawn = false
				local f = Instance.new("ImageLabel")
				f.Size = UDim2.fromScale(1, 1)
				f.BackgroundTransparency = 1
				f.Image = "rbxasset://textures/ui/vignette.png"
				f.ImageColor3 = Color3.fromRGB(200, 0, 0)
				f.ImageTransparency = 0.25
				f.Parent = g
				local fr = Instance.new("Frame")
				fr.Size = UDim2.fromScale(1, 1)
				fr.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
				fr.BackgroundTransparency = 0.82
				fr.BorderSizePixel = 0
				fr.Parent = g
				g.Parent = pg
				TweenService:Create(f, TweenInfo.new(0.45), {ImageTransparency = 1}):Play()
				TweenService:Create(fr, TweenInfo.new(0.45), {BackgroundTransparency = 1}):Play()
				Debris:AddItem(g, 0.5)
			end
		end
		st.redUntil = os.clock() + 0.6
		ev()
	end)
	-- Hook
	m:GetAttributeChangedSignal("HookStartedAt"):Connect(function()
		if not on("PachyFXHookEnabled") or m:GetAttribute("HookBraceEnabled") == false then return end
		local L = num(m, "HookLaunchAt")
		if not L then return end
		task.delay(math.max(0, L - now()), function()
			local p = partOf(m, "Mecha_HookArm", "Point") or partOf(m, "Mecha_HookArm", "Housing")
			if p then flash(p.Position, 3 * k(), Color3.new(1, 1, 1)) end
		end)
		ev()
	end)
	-- Ink
	m:GetAttributeChangedSignal("InkFireAt"):Connect(function()
		if not on("PachyFXInkEnabled") then return end
		local f = num(m, "InkFireAt")
		if not f then return end
		local win = partOf(m, "Mecha_InkTank", "Window")
		if win then
			local c = win.Color
			win.Color = Color3.fromRGB(110, 90, 255)
			win.Material = Enum.Material.Neon
			task.delay(math.max(0.05, f - now()), function() if win.Parent then win.Color = c; win.Material = Enum.Material.Glass end end)
		end
		task.delay(math.max(0, f - now()), function()
			if (num(m, "InkCancelAt") or 0) >= (num(m, "InkStartedAt") or 1e18) then return end
			local b = partOf(m, "Mecha_InkTank", "Barrel")
			if not b then return end
			local tip = b.CFrame * CFrame.new(0, 0, -b.Size.Z / 2)
			flash(tip.Position, 3 * k(), Color3.fromRGB(170, 150, 255), 0.14)
			burst(tip.Position, Color3.fromRGB(30, 28, 38), Color3.fromRGB(70, 70, 80), 16, 8 * k(), 1.4 * k(), 0.6, 40, tip.LookVector)
		end)
		ev()
	end)
	-- Tether
	m:GetAttributeChangedSignal("TetherStartedAt"):Connect(function()
		if not on("PachyFXTetherEnabled") then return end
		local s = num(m, "TetherStartedAt")
		local b = partOf(m, "Mecha_TetherLauncher", "Barrel")
		if b then burst((b.CFrame * CFrame.new(0, 0, -b.Size.Z / 2)).Position, Color3.fromRGB(220, 220, 220), Color3.fromRGB(150, 150, 150), 12, 6 * k(), 1.2 * k(), 0.7, 50, b.CFrame.LookVector) end
		st.tipHideUntil = (num(m, "TetherLandAt") or (s or now()) + 0.8) + 3.6
		ev()
	end)
	-- Servo end: skid + steam
	m:GetAttributeChangedSignal("ServoDashUntil"):Connect(function()
		local u = num(m, "ServoDashUntil")
		if not u or not on("PachyFXServoEnabled") then return end
		local my = u
		task.delay(math.max(0, u - now()), function()
			if num(m, "ServoDashUntil") ~= my or not on("PachyFXServoEnabled") then return end
			local r = m:FindFirstChild("HumanoidRootPart")
			local y = feetY(m)
			for i = 0, 5 do
				task.delay(i * 0.05, function()
					if r and r.Parent and y then burst(Vector3.new(r.Position.X, feetY(m) + 0.3, r.Position.Z), Color3.fromRGB(214, 196, 150), nil, 5, 6 * k(), 1.4 * k(), 0.5, 60, Vector3.yAxis) end
				end)
			end
			for _, n in ipairs({"Bell_L", "Bell_R"}) do
				local b = partOf(m, "Mecha_ServoDash", n)
				if b then burst(b.Position, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200), 8, 5 * k(), 1 * k(), 0.9, 30, Vector3.yAxis) end
			end
			ev()
		end)
	end)
	-- Last Stand ring
	m:GetAttributeChangedSignal("PachyLastStandAt"):Connect(function()
		if not on("PachyFXLastStandEnabled") then return end
		local s = num(m, "PachyLastStandAt")
		if not s or now() - s > 0.5 then return end
		task.delay(0.25, function()
			local r = m:FindFirstChild("HumanoidRootPart")
			local y = feetY(m)
			if r and y then ring(Vector3.new(r.Position.X, y + 0.2, r.Position.Z), 32 * k(), Color3.fromRGB(255, 176, 48), 0.6) end
			local d = find(m, "Head_dome3") or find(m, "Head_dome1")
			if d and d:IsA("BasePart") then flash(d.Position, 10 * k(), Color3.fromRGB(255, 192, 64), 0.25) end
		end)
		ev()
	end)
	-- Head Down hit sparks
	m:GetAttributeChangedSignal("LastHitAt"):Connect(function()
		if not on("PachyFXHeadDownEnabled") or (num(m, "PachyHeadDownMul") or 1) >= 1 or not st.charging then return end
		local d = find(m, "Head_domefront") or find(m, "Head_dome1")
		if d and d:IsA("BasePart") then burst(d.Position, Color3.fromRGB(200, 230, 255), Color3.fromRGB(110, 184, 255), 12, 20 * k(), 0.5 * k(), 0.35, 180) end
		ev()
	end)
	-- landing (pistons): this client sees the humanoid land
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed then st.landAt = os.clock() end
		end)
	end
end

-- ---------------------------------------------------------------- every frame: pistons, glows, tints, shells
local DOME_RED, DOME_BLUE = Color3.fromRGB(255, 70, 40), Color3.fromRGB(111, 184, 255)
local shells = {}
local function domeTint(m, st, col, a)
	local list = st.domeList or domeParts(m)
	st.domeList = list
	for _, p in ipairs(list) do
		if p.Parent then
			if not st.domeCol[p] then st.domeCol[p] = {p.Color, p.Material} end
			if a > 0 then
				p.Color = st.domeCol[p][1]:Lerp(col, a)
				p.Material = Enum.Material.Neon
			else
				p.Color, p.Material = st.domeCol[p][1], st.domeCol[p][2]
			end
		end
	end
	st.domeTinted = a > 0
end
local function pistonTick(m, st)
	local legs = m:FindFirstChild("Mecha_Legs")
	local onP = legs and on("PachyFXPistonEnabled")
	for _, side in ipairs({"L", "R"}) do
		local orig = legs and legs:FindFirstChild("Piston" .. side)
		local copy = st.pistons[side]
		if onP and orig and orig:IsA("BasePart") then
			if not copy or not copy.Parent then
				copy = part(orig.Size, orig.Color, orig.Material, orig.CFrame, 0)
				copy.Name = "PistonCopy" .. side
				st.pistons[side] = copy
			end
			orig.LocalTransparencyModifier = 1
			local T = now()
			local isOwner = m == me.Character
			local js = num(m, "JumpStartedAt") or -1e9
			local jp = isOwner and num(m, "JumpPredictedAt") or nil
			if jp and jp > js then js = jp end
			local W0 = num(m, "JumpWindup") or 0.12
			local dj = num(m, "JumpDoubleAt") or -1e9
			local djp = isOwner and num(m, "JumpDoublePredictedAt") or nil
			if djp and djp > dj then dj = djp end
			local x = T - js
			local slide = 0 -- + = pushed up into the cover (compressed), - = punched out
			if x >= 0 and x < W0 then slide = x / W0
			elseif x >= W0 and x < W0 + 0.12 then slide = -1 + (x - W0) / 0.12 * 0.5
			end
			local d = T - dj
			if d >= 0 and d < 0.15 then slide = -1 + d / 0.15 end
			if st.landAt and os.clock() - st.landAt < 0.25 then slide = 1 - (os.clock() - st.landAt) / 0.25 end
			copy.Size = orig.Size
			copy.CFrame = orig.CFrame * CFrame.new(0, slide * orig.Size.Y * 0.25, 0)
			local vent = legs:FindFirstChild("Vent" .. side)
			if vent and vent:IsA("BasePart") then
				local hot = (x >= W0 and x < W0 + 0.4) or (d >= 0 and d < 0.35)
				if hot and not st["ventCol" .. side] then st["ventCol" .. side] = {vent.Color, vent.Material}; vent.Color = Color3.fromRGB(255, 138, 42); vent.Material = Enum.Material.Neon
				elseif not hot and st["ventCol" .. side] then vent.Color, vent.Material = st["ventCol" .. side][1], st["ventCol" .. side][2]; st["ventCol" .. side] = nil end
			end
		else
			if copy then copy:Destroy(); st.pistons[side] = nil end
			if orig and orig:IsA("BasePart") then orig.LocalTransparencyModifier = 0 end
		end
	end
end
local reelAcc = 0
RunService.RenderStepped:Connect(function(dt)
	local T = now()
	reelAcc += dt
	local doReel = reelAcc >= 0.08
	if doReel then reelAcc = 0 end
	for m, st in pairs(W) do
		if not m.Parent then
			for _, c in pairs(st.pistons) do c:Destroy() end
			if shells[m] then shells[m]:Destroy(); shells[m] = nil end
			W[m] = nil
		else
			local k = scaleK(m)
			pistonTick(m, st)
			-- charging (for Head Down)
			local hs = num(m, "HeadbuttStartedAt") or -1e9
			st.charging = hs > (num(m, "HeadbuttEndedAt") or -1) and hs > (num(m, "HeadbuttHitAt") or -1) and T - hs < 3.5
				or (m == me.Character and m:GetAttribute("HeadbuttLocalState") == "charge")
			-- dome: Last Stand red (priority) / Head Down steel-blue
			local hum = m:FindFirstChildOfClass("Humanoid")
			local below = num(m, "PachyLastStandBelow") or 0
			local low = on("PachyFXLastStandEnabled") and hum and hum.Health > 0 and below > 0 and hum.Health < below * hum.MaxHealth
			local hd = on("PachyFXHeadDownEnabled") and st.charging and (num(m, "PachyHeadDownMul") or 1) < 1
			if low then domeTint(m, st, DOME_RED, 0.5 + 0.2 * math.sin(os.clock() * 5))
			elseif hd then domeTint(m, st, DOME_BLUE, 0.7)
			elseif st.domeTinted then domeTint(m, st, DOME_RED, 0) end
			-- gold shell (Last Stand star)
			local lsu = num(m, "PachyLastStandUntil")
			local r = m:FindFirstChild("HumanoidRootPart")
			if on("PachyFXLastStandEnabled") and lsu and lsu > T and r then
				local sh = shells[m]
				if not sh or not sh.Parent then
					sh = part(Vector3.one * 26 * k, Color3.fromRGB(255, 192, 64), Enum.Material.ForceField, r.CFrame, 0.3, Enum.PartType.Ball)
					sh.Name = "LastStandShell"
					shells[m] = sh
				end
				sh.CFrame = CFrame.new(r.Position)
			elseif shells[m] then shells[m]:Destroy(); shells[m] = nil end
			-- servo bells glow through the squat
			if on("PachyFXServoEnabled") then
				local s, b = num(m, "ServoDashStartedAt"), num(m, "ServoDashBlastAt")
				local glow = s and b and b > s and T >= s and T < b and (T - s) / (b - s) or 0
				for _, n in ipairs({"Bell_L", "Bell_R"}) do
					local bell = partOf(m, "Mecha_ServoDash", n)
					if bell then
						if glow > 0 then
							if not st["bell" .. n] then st["bell" .. n] = {bell.Color, bell.Material} end
							bell.Color = st["bell" .. n][1]:Lerp(Color3.fromRGB(255, 150, 50), glow)
							bell.Material = Enum.Material.Neon
						elseif st["bell" .. n] then bell.Color, bell.Material = st["bell" .. n][1], st["bell" .. n][2]; st["bell" .. n] = nil end
					end
				end
			end
			-- hook reel sparks
			if doReel and on("PachyFXHookEnabled") and m:GetAttribute("HookBraceEnabled") ~= false then
				local C, S = num(m, "HookContactAt") or 0, num(m, "HookSmashAt") or 0
				if C > 0 and T >= C and T < S then
					local sp = partOf(m, "Mecha_HookArm", "Spool")
					if sp then burst(sp.Position, Color3.fromRGB(255, 244, 200), Color3.fromRGB(255, 170, 60), 3, 12 * k, 0.35 * k, 0.25, 60, Vector3.yAxis, Vector3.new(0, -40, 0)) end
				end
			end
			-- tether tip hidden while the spike is out
			local tip = partOf(m, "Mecha_TetherLauncher", "Tip")
			if tip then
				local hide = on("PachyFXTetherEnabled") and st.tipHideUntil and T < st.tipHideUntil
				tip.LocalTransparencyModifier = hide and 1 or 0
			end
			-- Blood Pact red sparks
			if st.redUntil and os.clock() < st.redUntil and r and math.random() < dt * 30 then
				burst(r.Position + Vector3.new(0, 2 * k, 0), Color3.fromRGB(220, 30, 50), nil, 2, 6 * k, 0.6 * k, 0.3, 60, -r.CFrame.LookVector)
			end
		end
	end
	script:SetAttribute("PachyFXParts", live)
end)

-- ---------------------------------------------------------------- who to watch
local function onModel(m)
	if m:GetAttribute("Species") == "Pachy" then watch(m) end
	m:GetAttributeChangedSignal("Species"):Connect(function() if m:GetAttribute("Species") == "Pachy" then watch(m) end end)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(onModel)
	if pl.Character then onModel(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 30)
	local bots = isl and isl:WaitForChild("Bots", 30)
	if not bots then return end
	bots.ChildAdded:Connect(onModel)
	for _, b in ipairs(bots:GetChildren()) do onModel(b) end
end)
