-- HookFX v1.0 (Mecha Dino Arena) — the pachy Grappling Hook effects on this client (LocalScript, StarterPlayerScripts).
-- MDA-122, plan docs/plans/PACHY_PARTS_v1.0.md Drop A Task 6, mockup docs/mockups/pachy_parts_options.html "A · Wrist claw".
-- For every player character with HookStartedAt (HookServer 1.0), from its server stamps:
--   launch .. contact: a small steel claw flies from the wrist (Mecha_HookArm Barrel, else the ArmR segment) to
--     HookAimEnd on a thin dark chain; on a hit it then sticks to the grabbed dino (HookTargetName) and the chain reels it
--     in until HookSmashAt; a clamp flash at contact. On a miss / block / shield it flies out and back the same time.
--   HookHitAt (fresh): white flash at the smash point, low thud (built-in collide.wav, pitched down) and the damage number
--     (HookHitDamage, yellow) popping up.
-- Created locally in Workspace.DinoFX_Local. Switch: character attribute HookFXEnabled (default true).
-- Diagnostics (character, this client): HookFXVersion, HookFXState ("none" / "out" / "reel" / "back").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local STALE = 1
local STEEL, CHAIN = Color3.fromRGB(154, 166, 184), Color3.fromRGB(60, 66, 78)
local NUMBER_COLOR = Color3.fromRGB(255, 214, 64)

local fxFolder = workspace:FindFirstChild("DinoFX_Local")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DinoFX_Local"
	fxFolder.Parent = workspace
end

local function fxPart(name, size, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Metal
	if shape then p.Shape = shape end
	p.Parent = fxFolder
	return p
end

local function animate(duration, fn, done)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.min(1, (os.clock() - t0) / duration)
		fn(u)
		if u >= 1 then conn:Disconnect() if done then done() end end
	end)
end

local function wrist(char)
	local m = char:FindFirstChild("Mecha_HookArm")
	local b = m and m:FindFirstChild("Barrel")
	if b then return b.Position end
	local seg = char:FindFirstChild("ArmR")
	local r = seg and (seg:IsA("BasePart") and seg or seg:FindFirstChild("Root"))
	if r and r:IsA("BasePart") then return r.Position end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function flash(pos, size)
	local f = fxPart("HookFlash", Vector3.one, Color3.new(1, 1, 1), Enum.PartType.Ball)
	f.Material = Enum.Material.Neon
	f.CFrame = CFrame.new(pos)
	animate(0.14, function(u)
		local d = size * (0.4 + u)
		f.Size = Vector3.new(d, d, d)
		f.Transparency = 0.15 + 0.85 * u
	end, function() f:Destroy() end)
	return f
end

local function smashFX(char)
	local hb = char:FindFirstChild("Hitboxes")
	local head
	if hb then for _, p in ipairs(hb:GetChildren()) do if p:GetAttribute("HitboxSegment") == "Head" then head = p end end end
	local pos = head and (head.Position + head.CFrame.LookVector * head.Size.Z * 0.4) or (wrist(char) or Vector3.zero)
	local s = char:GetScale()
	local f = flash(pos, 8 * s)
	local snd = Instance.new("Sound")
	snd.SoundId = "rbxasset://sounds/collide.wav"
	snd.PlaybackSpeed, snd.Volume, snd.RollOffMaxDistance = 0.5, 0.9, 200
	snd.Parent = f
	snd:Play()
	local dmg = char:GetAttribute("HookHitDamage")
	if typeof(dmg) ~= "number" then return end
	local holder = fxPart("HookNumber", Vector3.new(0.2, 0.2, 0.2), Color3.new(), nil)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(pos)
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
	label.Text = "-" .. tostring(dmg)
	label.TextColor3 = NUMBER_COLOR
	label.TextStrokeColor3 = Color3.fromRGB(40, 24, 10)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	animate(0.8, function(u)
		local sc = u < 0.12 and (0.5 + 0.8 * u / 0.12) or (u < 0.25 and (1.3 - 0.3 * (u - 0.12) / 0.13) or 1)
		label.Size = UDim2.fromScale(sc, sc)
		holder.CFrame = CFrame.new(pos + Vector3.new(0, 4 * (1 - (1 - u) ^ 2), 0))
		local fade = u > 0.65 and (u - 0.65) / 0.35 or 0
		label.TextTransparency, label.TextStrokeTransparency = fade, fade
	end, function() holder:Destroy() end)
end

local tracked = {} -- [char] = {claw, chain, clamped}

local function watch(char)
	if tracked[char] then return end
	tracked[char] = {}
	char:SetAttribute("HookFXVersion", VERSION)
	char:GetAttributeChangedSignal("HookHitAt"):Connect(function()
		local at = char:GetAttribute("HookHitAt")
		if char:GetAttribute("HookFXEnabled") == false then return end
		if typeof(at) == "number" and math.abs(workspace:GetServerTimeNow() - at) <= STALE then smashFX(char) end
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			local st = tracked[char]
			if st then
				if st.claw then st.claw:Destroy() end
				if st.chain then st.chain:Destroy() end
			end
			tracked[char] = nil
		end
	end)
end

local function onCharacter(char)
	char:GetAttributeChangedSignal("HookStartedAt"):Connect(function() watch(char) end)
	if char:GetAttribute("HookStartedAt") ~= nil then watch(char) end
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

local function show(char, k, v) if char:GetAttribute(k) ~= v then char:SetAttribute(k, v) end end

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for char, st in pairs(tracked) do
		local start = tonumber(char:GetAttribute("HookStartedAt")) or 0
		local launch = tonumber(char:GetAttribute("HookLaunchAt")) or start
		local contact = tonumber(char:GetAttribute("HookContactAt")) or 0
		local smash = tonumber(char:GetAttribute("HookSmashAt")) or 0
		local busy = tonumber(char:GetAttribute("HookBusyUntil")) or 0
		local aimEnd = char:GetAttribute("HookAimEnd")
		local from = wrist(char)
		local clawPos, state = nil, "none"
		if char:GetAttribute("HookFXEnabled") ~= false and from and typeof(aimEnd) == "Vector3" and t >= launch then
			if contact > 0 then
				if t < contact then
					clawPos, state = from:Lerp(aimEnd, (t - launch) / math.max(0.01, contact - launch)), "out"
				elseif t < smash then
					local target = workspace:FindFirstChild(char:GetAttribute("HookTargetName") or "", true)
					local root = target and target:IsA("Model") and target:FindFirstChild("HumanoidRootPart")
					clawPos, state = root and root.Position or aimEnd, "reel"
					if not st.clamped then st.clamped = true flash(clawPos, 3 * char:GetScale()) end
				end
			elseif t < busy then
				local half = math.max(0.01, (busy - 0.1 - launch) / 2)
				local u = (t - launch) / half
				clawPos = u <= 1 and from:Lerp(aimEnd, u) or aimEnd:Lerp(from, math.clamp(u - 1, 0, 1))
				state = u <= 1 and "out" or "back"
			end
		end
		if t < launch or state == "none" then st.clamped = false end
		if clawPos then
			local s = char:GetScale()
			st.claw = st.claw or fxPart("HookClaw", Vector3.new(0.5, 0.5, 0.7) * s, STEEL, nil)
			st.chain = st.chain or fxPart("HookChain", Vector3.new(0.12, 0.12, 1) * s, CHAIN, nil)
			local dir = clawPos - from
			local len = math.max(0.1, dir.Magnitude)
			st.claw.CFrame = CFrame.lookAt(clawPos, clawPos + (dir.Magnitude > 1e-3 and dir.Unit or Vector3.zAxis))
			st.chain.Size = Vector3.new(0.12 * s, 0.12 * s, len)
			st.chain.CFrame = CFrame.lookAt(from + dir / 2, clawPos)
			st.claw.Transparency, st.chain.Transparency = 0, 0
		else
			if st.claw then st.claw.Transparency = 1 end
			if st.chain then st.chain.Transparency = 1 end
		end
		show(char, "HookFXState", state)
	end
end)
