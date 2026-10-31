-- SlashFX v1.0 (Mecha Dino Arena) — the Herrerasaurus' dash-through slash effects on this client (LocalScript,
-- StarterPlayerScripts). MDA-142, plan docs/plans/HERRERA_KIT_v1.0.md Task 10, mockup docs/mockups/herrera_kit_options.html
-- look A "Claw streaks" (Kepu 2026-10-30 "A"). Colours from the plan's layout line: trail FFE066, claw marks FF3B2F, hit
-- number FFD84A, bleed number FF4A4A.
-- Dash (every player character with SlashEnabled = true; own: SlashLocalState "dash" (SlashTest); others: SlashStartedAt
--   .. + SlashDashTime (SlashServer)): yellow trail dots — a small neon cube (0.5 x scale) dropped at the
--   HumanoidRootPart every DOT_EVERY s, fading and shrinking over DOT_TIME s (the mockup's trailDot).
-- Hit (a model's SlashTakenAt, SlashServer, at most STALE s old; players' characters and Workspace.DinoIsland.Bots):
--   three red claw streaks across the target (neon bars 0.35 x 9 x 0.35 x the attacker's scale / 2, 1.6 apart, tilted
--   0.75 rad, across the attacker's SlashDir; they grow in over the first 1/6 and fade over CLAW_TIME s), a red
--   Highlight flash on the target (FLASH_TIME s), and the damage number (SlashTakenDamage) in yellow popping up.
-- Bleed tick (the target's SlashBleedTickAt): the tick damage (SlashBleedTickDamage) in red popping up at a random spot
--   over the target and DROPS blood drops falling from it.
-- Switch: model attribute SlashFXEnabled (default true; false = no effects from / on that model).
-- Diagnostics (client-side model attributes): SlashFXVersion (attackers), SlashFXHits / SlashFXTicks (targets).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local TRAIL_COLOR = Color3.fromHex("FFE066")
local CLAW_COLOR = Color3.fromHex("FF3B2F")
local HIT_COLOR = Color3.fromHex("FFD84A")
local BLEED_COLOR = Color3.fromHex("FF4A4A")
local STALE = 1
local DOT_EVERY = 0.025
local DOT_TIME = 0.35
local CLAW_TIME = 0.55
local FLASH_TIME = 0.25
local NUMBER_TIME = 0.8
local DROPS = 4

local player = Players.LocalPlayer

local fxFolder = workspace:FindFirstChild("DinoFX_Local")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DinoFX_Local"
	fxFolder.Parent = workspace
end

local function fxPart(name, size, color, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Color = color
	p.CFrame = cf
	p.Parent = fxFolder
	return p
end

local function animate(duration, fn, done)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.min(1, (os.clock() - t0) / duration)
		fn(u)
		if u >= 1 then
			conn:Disconnect()
			if done then done() end
		end
	end)
end

local function popNumber(text, color, pos)
	local holder = fxPart("SlashNumber", Vector3.new(0.2, 0.2, 0.2), Color3.new(), CFrame.new(pos))
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 3)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = holder
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(40, 10, 10)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	animate(NUMBER_TIME, function(u)
		local sc = u < 0.12 and (0.5 + 0.8 * u / 0.12) or (u < 0.25 and (1.3 - 0.3 * (u - 0.12) / 0.13) or 1)
		label.Size = UDim2.fromScale(sc, sc)
		holder.CFrame = CFrame.new(pos + Vector3.new(0, 4 * (1 - (1 - u) ^ 2), 0))
		local fade = u > 0.65 and (u - 0.65) / 0.35 or 0
		label.TextTransparency = fade
		label.TextStrokeTransparency = fade
	end, function() holder:Destroy() end)
end

local function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart")
end

local function attackerOf(model)
	local name = model:GetAttribute("SlashHitBy")
	if typeof(name) ~= "string" then return nil end
	local p = Players:FindFirstChild(name)
	return p and p.Character or nil
end

local function flash(model, color)
	local hl = Instance.new("Highlight")
	hl.Name = "SlashFlash"
	hl.FillColor, hl.OutlineColor = color, color
	hl.FillTransparency, hl.OutlineTransparency = 0.45, 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = model
	hl.Parent = model
	animate(FLASH_TIME, function(u)
		hl.FillTransparency = 0.45 + 0.55 * u
		hl.OutlineTransparency = 0.2 + 0.8 * u
	end, function() hl:Destroy() end)
end

local function onHit(model)
	local root = rootOf(model)
	if not root then return end
	local attacker = attackerOf(model)
	local scale = attacker and attacker:GetScale() or 1
	local dir = attacker and attacker:GetAttribute("SlashDir")
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 1e-3 then dir = root.CFrame.LookVector end
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	local at = root.Position + Vector3.new(0, 2 * scale, 0)
	local k = scale / 2 -- the mockup's sizes are at the 2x body
	local base = CFrame.lookAt(at, at + dir) -- -Z along the dash
	for i = 0, 2 do
		local cf = base * CFrame.new((i - 1) * 1.6 * k, 0, 0) * CFrame.Angles(0, 0, 0.75)
		local full = Vector3.new(0.35, 9, 0.35) * k
		local bar = fxPart("SlashClaw", Vector3.new(full.X, 0.05, full.Z), CLAW_COLOR, cf)
		animate(CLAW_TIME, function(u)
			bar.Size = Vector3.new(full.X, full.Y * math.min(1, u * 6), full.Z)
			bar.Transparency = u
		end, function() bar:Destroy() end)
	end
	flash(model, CLAW_COLOR)
	local dmg = model:GetAttribute("SlashTakenDamage")
	if typeof(dmg) == "number" then popNumber("-" .. tostring(dmg), HIT_COLOR, at + Vector3.new(0, 6 * k, 0)) end
	model:SetAttribute("SlashFXHits", (model:GetAttribute("SlashFXHits") or 0) + 1)
end

local function onTick(model)
	local root = rootOf(model)
	if not root then return end
	local d = model:GetAttribute("SlashBleedTickDamage")
	local pos = root.Position + Vector3.new((math.random() - 0.5) * 4, 8, 0)
	if typeof(d) == "number" then
		local txt = (d == math.floor(d)) and tostring(math.floor(d)) or string.format("%.1f", d)
		popNumber("-" .. txt, BLEED_COLOR, pos)
	end
	for _ = 1, DROPS do
		local start = root.Position + Vector3.new((math.random() - 0.5) * 3, 1 + math.random() * 2, (math.random() - 0.5) * 3)
		local drop = fxPart("SlashBlood", Vector3.new(0.35, 0.35, 0.35), BLEED_COLOR, CFrame.new(start))
		local fall = 3 + math.random() * 3
		animate(0.6, function(u)
			drop.CFrame = CFrame.new(start - Vector3.new(0, fall * u * u, 0))
			drop.Transparency = u
		end, function() drop:Destroy() end)
	end
	model:SetAttribute("SlashFXTicks", (model:GetAttribute("SlashFXTicks") or 0) + 1)
end

-- targets
local watchedTargets = {}
local function watchTarget(model)
	if watchedTargets[model] then return end
	watchedTargets[model] = true
	model:GetAttributeChangedSignal("SlashTakenAt"):Connect(function()
		local at = model:GetAttribute("SlashTakenAt")
		if model:GetAttribute("SlashFXEnabled") == false then return end
		if typeof(at) == "number" and math.abs(workspace:GetServerTimeNow() - at) <= STALE then onHit(model) end
	end)
	model:GetAttributeChangedSignal("SlashBleedTickAt"):Connect(function()
		local at = model:GetAttribute("SlashBleedTickAt")
		if model:GetAttribute("SlashFXEnabled") == false then return end
		if typeof(at) == "number" and math.abs(workspace:GetServerTimeNow() - at) <= STALE then onTick(model) end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then watchedTargets[model] = nil end
	end)
end

-- attackers (trail)
local attackers = {} -- [char] = {lastDot}
local function watchAttacker(char)
	if attackers[char] or char:GetAttribute("SlashEnabled") ~= true then return end
	attackers[char] = {lastDot = 0}
	char:SetAttribute("SlashFXVersion", VERSION)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then attackers[char] = nil end
	end)
end

local function dashing(char, own, now)
	if own then return char:GetAttribute("SlashLocalState") == "dash" end
	local start = char:GetAttribute("SlashStartedAt")
	local dur = char:GetAttribute("SlashDashTime")
	if typeof(start) ~= "number" or typeof(dur) ~= "number" then return false end
	return now >= start and now <= start + dur
end

local function onCharacter(char)
	watchTarget(char)
	task.defer(function()
		if char.Parent then watchAttacker(char) end
	end)
	char:GetAttributeChangedSignal("SlashEnabled"):Connect(function() watchAttacker(char) end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 30)
	local bots = isl and isl:WaitForChild("Bots", 30)
	if not bots then return end
	for _, m in ipairs(bots:GetChildren()) do
		if m:IsA("Model") then watchTarget(m) end
	end
	bots.ChildAdded:Connect(function(m)
		if m:IsA("Model") then watchTarget(m) end
	end)
end)

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for char, st in pairs(attackers) do
		if char:GetAttribute("SlashFXEnabled") ~= false and dashing(char, char == player.Character, now)
			and clock - st.lastDot >= DOT_EVERY then
			st.lastDot = clock
			local root = rootOf(char)
			if root then
				local s = 0.5 * char:GetScale()
				local dot = fxPart("SlashTrail", Vector3.new(s, s, s), TRAIL_COLOR, CFrame.new(root.Position))
				animate(DOT_TIME, function(u)
					local k = 1 - 0.6 * u
					dot.Size = Vector3.new(s * k, s * k, s * k)
					dot.Transparency = 0.1 + 0.9 * u
				end, function() dot:Destroy() end)
			end
		end
	end
end)
