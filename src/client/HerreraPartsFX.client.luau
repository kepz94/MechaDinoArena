-- HerreraPartsFX v1.0 (Mecha Dino Arena) — the Herrera mecha parts' effects on this client (LocalScript,
-- StarterPlayerScripts). Plan docs/plans/HERRERA_PARTS_v1.0.md (pass 1: Iron Claw MDA-149, Back Plating MDA-153, Blood
-- Siphon MDA-154); the looks come from HerreraPartsServer 1.0. Runs for every player character (yours and others').
-- Iron Claw (character IronClawEnabled, SkillEffects 1.27):
--   * slash start (yours: SlashLocalState -> "dash" (SlashTest); others: SlashStartedAt (SlashServer)): the blades and their
--     edges flash white for FLASH_TIME (0.25 s); the two "IronClawTrail" trails (HerreraPartsServer) are on for the dash
--     time (SlashDashTime, else SlashTime 0.3) + 0.12 s.
--   * a hit (the attacker's SlashHitAt): at the target (SlashHitTarget: a player's character or a Workspace.DinoIsland.Bots
--     model) an orange + white spark burst (Emit 18 + 6) and a "CLANG!" pop (yellow, rises 3 studs, 0.7 s).
--     No camera shake (Kepu 2026-10-31 "Forget the camera shake"). The hit-stop of the mockup is not in pass 1.
--   * IronClawDust (III): heavier footstep dust (a ParticleEmitter on the root, rate 14) while running (Sprinting true).
-- Back Plating (a character's PlatingHitAt, BoneCrest 1.3): orange-white sparks at the back (Torso_hump), the plates flash
--   white for 0.25 s, and a "-N% PLATED" pop (N from PlatingLastMul).
-- Blood Siphon (character SiphonEnabled): about 8 red beads per second from each bleeding model in range (SlashBleedUntil /
--   SkillBleedUntil in the future, root within SiphonRange x scale; Bots + player characters) fly on an arc into the tank
--   core (HerreraPartsServer piece role "core") in 0.5 s; on SiphonHealAt the core pulses (+25% for 0.2 s) and a green
--   "+N" pop (N = SiphonRate x SiphonBleeding x 0.5) shows at most once per second; SiphonKillAt shows a big "+25%" pop.
-- Switch: script attribute HerreraPartsFXEnabled (default true, read each event; false = no effects).
-- Diagnostics: script HerreraPartsFXVersion, HerreraPartsFXEvents (count).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local FLASH_TIME = 0.25
local HOT = Color3.fromRGB(255, 138, 42)
local WHITE = Color3.new(1, 1, 1)
local me = Players.LocalPlayer
script:SetAttribute("HerreraPartsFXVersion", VERSION)
script:SetAttribute("HerreraPartsFXEvents", 0)
if script:GetAttribute("HerreraPartsFXEnabled") == nil then script:SetAttribute("HerreraPartsFXEnabled", true) end
local function on() return script:GetAttribute("HerreraPartsFXEnabled") ~= false end
local function count() script:SetAttribute("HerreraPartsFXEvents", (script:GetAttribute("HerreraPartsFXEvents") or 0) + 1) end

local fxFolder = Instance.new("Folder")
fxFolder.Name = "HerreraPartsFX"
fxFolder.Parent = workspace

local function animate(dur, step, done)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.min(1, (os.clock() - t0) / dur)
		step(u)
		if u >= 1 then
			conn:Disconnect()
			if done then done() end
		end
	end)
end
local function fxPart(size, color, cf, material)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.CFrame = size, color, cf
	p.Material = material or Enum.Material.Neon
	p.Parent = fxFolder
	return p
end
local function pop(text, color, pos, size)
	local holder = fxPart(Vector3.new(0.2, 0.2, 0.2), Color3.new(), CFrame.new(pos))
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size or 6, (size or 6) / 2)
	gui.AlwaysOnTop, gui.LightInfluence, gui.Adornee = true, 0, holder
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.AnchorPoint, label.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	label.Font, label.TextScaled, label.Text = Enum.Font.FredokaOne, true, text
	label.TextColor3, label.TextStrokeColor3, label.TextStrokeTransparency = color, Color3.fromRGB(40, 20, 6), 0
	label.Parent = gui
	animate(0.7, function(u)
		local sc = u < 0.12 and (0.5 + 0.8 * u / 0.12) or (u < 0.25 and (1.3 - 0.3 * (u - 0.12) / 0.13) or 1)
		label.Size = UDim2.fromScale(sc, sc)
		holder.CFrame = CFrame.new(pos + Vector3.new(0, 3 * (1 - (1 - u) ^ 2), 0))
		local fade = u > 0.65 and (u - 0.65) / 0.35 or 0
		label.TextTransparency, label.TextStrokeTransparency = fade, fade
	end, function() holder:Destroy() end)
end
local function sparks(pos, color, n)
	local a = fxPart(Vector3.new(0.2, 0.2, 0.2), Color3.new(), CFrame.new(pos))
	a.Transparency = 1
	local att = Instance.new("Attachment")
	att.Parent = a
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = ColorSequence.new(color)
	e.LightEmission, e.Lifetime, e.Speed = 1, NumberRange.new(0.25, 0.45), NumberRange.new(14, 26)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.45, 0)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Parent = att
	e:Emit(n)
	task.delay(0.8, function() a:Destroy() end)
end
local function rootOf(m)
	local r = m and m:FindFirstChild("HumanoidRootPart")
	return r
end
local function findTarget(name)
	if typeof(name) ~= "string" then return nil end
	local p = Players:FindFirstChild(name)
	if p and p.Character then return p.Character end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or workspace:FindFirstChild(name)
end
local function pieces(char, id, roles)
	local m = char:FindFirstChild("HPart_" .. id)
	local out = {}
	if not m then return out end
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and (not roles or roles[p:GetAttribute("HPartRole") or ""]) then table.insert(out, p) end
	end
	return out
end
local function flashPieces(list)
	for _, p in ipairs(list) do
		local base = p:GetAttribute("HPartBaseColor") or p.Color
		p.Color = WHITE
		task.delay(FLASH_TIME, function() if p.Parent then p.Color = base end end)
	end
end

-- ---------- Iron Claw ----------
local function ironStart(char)
	if not on() or char:GetAttribute("IronClawEnabled") ~= true then return end
	count()
	flashPieces(pieces(char, "ironclaw", {blade = true, edge = true}))
	local m = char:FindFirstChild("HPart_ironclaw")
	if not m then return end
	local dur = (tonumber(char:GetAttribute("SlashDashTime")) or tonumber(char:GetAttribute("SlashTime")) or 0.3) + 0.12
	for _, tr in ipairs(m:GetChildren()) do
		if tr:IsA("Trail") then
			tr.Enabled = true
			task.delay(dur, function() if tr.Parent then tr.Enabled = false end end)
		end
	end
end
local function ironHit(char)
	if not on() or char:GetAttribute("IronClawEnabled") ~= true then return end
	local tgt = findTarget(char:GetAttribute("SlashHitTarget"))
	local r = rootOf(tgt) or (tgt and tgt:IsA("Model") and tgt.PrimaryPart)
	local pos = r and r.Position or (tgt and tgt:IsA("Model") and tgt:GetPivot().Position)
	if not pos then return end
	count()
	sparks(pos + Vector3.new(0, 1, 0), HOT, 18)
	sparks(pos + Vector3.new(0, 1, 0), WHITE, 6)
	pop("CLANG!", Color3.fromRGB(255, 200, 50), pos + Vector3.new(0, 5 * char:GetScale(), 0), 5)
end
local function ironDust(char)
	local hrp = rootOf(char)
	if not hrp then return end
	local e = hrp:FindFirstChild("IronClawDust")
	local want = on() and char:GetAttribute("IronClawEnabled") == true and char:GetAttribute("IronClawDust") == true
		and char:GetAttribute("Sprinting") == true
	if want and not e then
		e = Instance.new("ParticleEmitter")
		e.Name = "IronClawDust"
		e.Color = ColorSequence.new(Color3.fromRGB(216, 207, 180))
		e.Lifetime, e.Speed = NumberRange.new(0.4, 0.6), NumberRange.new(2, 4)
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6)})
		e.Transparency = NumberSequence.new(0.3, 1)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(40, 40)
		e.Rate = 14
		e.Parent = hrp
	elseif not want and e then
		e:Destroy()
	end
end

-- ---------- Back Plating ----------
local function platingHit(char)
	if not on() then return end
	local hump = char:FindFirstChild("Torso_hump", true)
	local pos = hump and hump.Position or (rootOf(char) and rootOf(char).Position)
	if not pos then return end
	count()
	sparks(pos, Color3.fromRGB(255, 210, 122), 16)
	flashPieces(pieces(char, "plating", {plate = true}))
	local mul = tonumber(char:GetAttribute("PlatingLastMul")) or 1
	pop(("-%d%% PLATED"):format(math.floor((1 - mul) * 100 + 0.5)), WHITE, pos + Vector3.new(0, 3 * char:GetScale(), 0), 6)
end

-- ---------- Blood Siphon ----------
local lastHealPop = setmetatable({}, {__mode = "k"})
local function siphonHeal(char)
	if not on() or char:GetAttribute("SiphonEnabled") ~= true then return end
	local core = pieces(char, "siphon", {core = true})[1]
	if core then
		local s0 = core.Size
		core.Size = s0 * 1.25
		task.delay(0.2, function() if core.Parent then core.Size = s0 end end)
	end
	local t = os.clock()
	if t - (lastHealPop[char] or 0) >= 1 then
		lastHealPop[char] = t
		local n = (tonumber(char:GetAttribute("SiphonRate")) or 0) * (tonumber(char:GetAttribute("SiphonBleeding")) or 0)
		local head = char:FindFirstChild("Head_cranium", true)
		local pos = head and head.Position or (rootOf(char) and rootOf(char).Position)
		if pos and n > 0 then pop("+" .. (math.floor(n * 10 + 0.5) / 10), Color3.fromRGB(95, 209, 106), pos + Vector3.new(0, 2 * char:GetScale(), 0), 4) end
	end
end
local function siphonKill(char)
	if not on() then return end
	local head = char:FindFirstChild("Head_cranium", true)
	local pos = head and head.Position or (rootOf(char) and rootOf(char).Position)
	if pos then pop("+25% BLEED KILL", Color3.fromRGB(95, 209, 106), pos + Vector3.new(0, 3 * char:GetScale(), 0), 9) end
end
local function bead(from, core)
	local p = fxPart(Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(255, 48, 64), CFrame.new(from))
	local side = (math.random() - 0.5) * 2
	local arc = 1 + math.random() * 1.5
	animate(0.5, function(u)
		if not core.Parent then return end
		local to = core.Position
		local pos = from:Lerp(to, u) + Vector3.new(0, math.sin(math.pi * u) * arc, 0) + core.CFrame.RightVector * math.sin(math.pi * u) * side
		p.CFrame = CFrame.new(pos)
		p.Size = Vector3.new(0.3, 0.3, 0.3) * (1 - 0.5 * u)
	end, function() p:Destroy() end)
end
local function others()
	local list = {}
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	if bots then for _, m in ipairs(bots:GetChildren()) do if m:IsA("Model") then table.insert(list, m) end end end
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
	return list
end

-- ---------- wiring ----------
local watched = setmetatable({}, {__mode = "k"})
local function watch(char)
	if watched[char] then return end
	watched[char] = true
	local isMe = Players:GetPlayerFromCharacter(char) == me
	if isMe then
		char:GetAttributeChangedSignal("SlashLocalState"):Connect(function()
			if char:GetAttribute("SlashLocalState") == "dash" then ironStart(char) end
		end)
	else
		char:GetAttributeChangedSignal("SlashStartedAt"):Connect(function() ironStart(char) end)
	end
	char:GetAttributeChangedSignal("SlashHitAt"):Connect(function() ironHit(char) end)
	for _, a in ipairs({"Sprinting", "IronClawEnabled", "IronClawDust"}) do
		char:GetAttributeChangedSignal(a):Connect(function() ironDust(char) end)
	end
	char:GetAttributeChangedSignal("PlatingHitAt"):Connect(function() platingHit(char) end)
	char:GetAttributeChangedSignal("SiphonHealAt"):Connect(function() siphonHeal(char) end)
	char:GetAttributeChangedSignal("SiphonKillAt"):Connect(function() siphonKill(char) end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- siphon beads (every 0.12 s)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.12 then return end
	acc = 0
	if not on() then return end
	local pool
	local t = workspace:GetServerTimeNow()
	for _, pl in ipairs(Players:GetPlayers()) do
		local char = pl.Character
		local hrp = rootOf(char)
		if char and hrp and char:GetAttribute("SiphonEnabled") == true then
			local core = pieces(char, "siphon", {core = true})[1]
			if core then
				pool = pool or others()
				local range = (tonumber(char:GetAttribute("SiphonRange")) or 0) * char:GetScale()
				for _, m in ipairs(pool) do
					if m ~= char and m.Parent and m:GetAttribute("DummyState") ~= "ko" then
						local bleeding = (tonumber(m:GetAttribute("SlashBleedUntil")) or 0) > t or (tonumber(m:GetAttribute("SkillBleedUntil")) or 0) > t
						local r = rootOf(m)
						local pos = r and r.Position or m:GetPivot().Position
						if bleeding and (pos - hrp.Position).Magnitude <= range then bead(pos + Vector3.new(0, 1.5, 0), core) end
					end
				end
			end
		end
	end
end)
