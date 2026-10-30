-- PounceFX v1.1 (Dino Arcade) — pounce bite effects on every player's client (RunContext = Client).
-- Triggered by this character's server attribute PounceBiteAt (set by PounceServer 1.0 on every latch hit):
--   * chomp sound on the head: BiteSoundId (the bite chomp; empty = silent) at PounceSoundPitch (default 1.35, a
--     smaller, higher chomp) and PounceSoundVolume (default 0.7), replayed from the start on every hit;
--   * a small flash at the jaws (front of Head_mouth as this client animates it);
--   * a popping damage number (PounceHitDamage) at the jaws: the landing hit (PounceBiteAt == PounceLatchedAt) is a
--     big yellow number like a bite's, each later bite while latched a smaller, quicker orange one.
-- No chunks, wobble or camera punch (two hits a second would be too busy).
-- v1.1: claw slash effects (Kepu 2026-10-29: "visible slashing with the arm claws" ... "be accurate to the damage
--   taken"; mockup docs/mockups/hud_target_slash_options.html "Claw slashes only"). While the character attribute
--   PounceSlashEnabled ~= false and the server sends PounceHitCount (PounceServer 1.7), each hit instead gives, for the
--   arm of that hit (count odd -> ArmL, even -> ArmR; the same rule as PounceSlash 1.0 in IdleAnimation 1.28):
--   * at once: a slash swish on the hand (SLASH_SOUND, the built-in sword slash, PounceSlashSoundPitch 1.15 /
--     PounceSlashSoundVolume 0.6; no chomp);
--   * PounceSlashStrike (0.07 s, the strike time of PouncePose 1.1) later, when the claws reach the end of the rake as
--     this client animates them: a small flash at the claws, three red neon streaks (the claw marks) along the path the
--     claws travelled during the strike, drawn out over 0.06 s and fading over 0.35 s, and the damage number
--     (PounceHitDamage of this hit, landing = big yellow, later hits = orange, as 1.0) at the claws.
--   One hit = one swish, one set of streaks and one number. When off: the 1.0 jaw effects.
--   Diagnostics: PounceFXLast adds "slashL" / "slashR"; PounceFXSlashes (slash effects shown).
-- Diagnostics (client-side character attributes): PounceFXHits (hit effects shown), PounceFXLast ("land" /
--   "bite"), PounceSoundLoaded.
local RunService = game:GetService("RunService")
local char = script.Parent

local DEFAULTS = {BiteSoundId = "", PounceSoundPitch = 1.35, PounceSoundVolume = 0.7}
local FLASH_TIME = 0.1
local LAND = {time = 0.8, scale = 1, rise = 4, color = Color3.fromRGB(255, 214, 64)}   -- same look as a bite number
local TICK = {time = 0.55, scale = 0.65, rise = 2.5, color = Color3.fromRGB(255, 160, 60)}
local STALE = 1 -- seconds after which a hit stamp is too old to show (e.g. joined late)
-- v1.1: claw slashes
local SLASH_SOUND = "rbxasset://sounds/swordslash.wav"
local SLASH_DEFAULTS = {PounceSlashStrike = 0.07, PounceSlashSoundPitch = 1.15, PounceSlashSoundVolume = 0.6}
local STREAK_COLOR = Color3.fromRGB(255, 70, 55)
local STREAK_GROW, STREAK_FADE = 0.06, 0.35

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

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
	p.Size = size
	p.Color = color
	p.CFrame = cf
	p.Parent = fxFolder
	return p
end

-- runs fn(u) every frame for `duration` seconds (u = 0..1), then done()
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

-- front of the jaws as this client shows them
local function jawPoint()
	local head = char:FindFirstChild("Head")
	local mouth = head and head:FindFirstChild("Head_mouth")
	if mouth and mouth:IsA("BasePart") then
		return mouth.CFrame * Vector3.new(mouth.Size.X / 2, 0, 0)
	end
	local root = head and head:FindFirstChild("Root")
	return root and root.Position or nil
end

local function flash(pos)
	local p = fxPart("PounceFlash", Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(255, 235, 225), CFrame.new(pos))
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	animate(FLASH_TIME, function(u)
		local d = 0.6 + 2 * u
		p.Size = Vector3.new(d, d, d)
		p.Transparency = 0.2 + 0.8 * u
	end, function() p:Destroy() end)
end

local function damageNumber(pos, dmg, style)
	local holder = fxPart("PounceNumber", Vector3.new(0.2, 0.2, 0.2), Color3.new(), CFrame.new(pos))
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6 * style.scale, 3 * style.scale)
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
	label.TextColor3 = style.color
	label.TextStrokeColor3 = Color3.fromRGB(40, 24, 10)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local side = (math.random() - 0.5) * 1.5 -- small sideways scatter so quick numbers don't stack
	animate(style.time, function(u)
		-- pop: 0.5 -> 1.3 -> 1.0 in the first 25%, then rise and fade
		local scale = u < 0.12 and (0.5 + 0.8 * u / 0.12) or (u < 0.25 and (1.3 - 0.3 * (u - 0.12) / 0.13) or 1)
		label.Size = UDim2.fromScale(scale, scale)
		holder.CFrame = CFrame.new(pos + Vector3.new(side * u, style.rise * (1 - (1 - u) ^ 2), 0))
		local fade = u > 0.65 and (u - 0.65) / 0.35 or 0
		label.TextTransparency = fade
		label.TextStrokeTransparency = fade
	end, function() holder:Destroy() end)
end

-- chomp sound on the head
local sound
local function ensureSound()
	local id = get("BiteSoundId")
	if id == "" then return nil end
	local head = char:FindFirstChild("Head")
	local anchor = head and head:FindFirstChild("Root")
	if not anchor then return nil end
	if not sound or sound.Parent ~= anchor then
		sound = Instance.new("Sound")
		sound.Name = "PounceSound"
		sound.RollOffMaxDistance = 200
		sound.Parent = anchor
	end
	if sound.SoundId ~= id then sound.SoundId = id end
	sound.PlaybackSpeed = get("PounceSoundPitch")
	sound.Volume = get("PounceSoundVolume")
	return sound
end

-- v1.1: claw slash effects
local function sget(k)
	local v = char:GetAttribute(k)
	if v == nil then v = SLASH_DEFAULTS[k] end
	return v
end
-- the claws of one arm as this client animates them (long Blade Claw first, then the dino's own claw, then the hand)
local function clawPoint(side)
	local seg = char:FindFirstChild("Arm" .. side)
	if not seg then return nil end
	local p = seg:FindFirstChild("Claw_Arm" .. side .. "_2", true) or char:FindFirstChild("Claw_Arm" .. side .. "_2", true)
		or seg:FindFirstChild("Arm" .. side .. "_claw2") or seg:FindFirstChild("Arm" .. side .. "_hand")
	return p and p:IsA("BasePart") and p.Position or nil
end
local slashSounds = {}
local function slashSound(side)
	local seg = char:FindFirstChild("Arm" .. side)
	local hand = seg and (seg:FindFirstChild("Arm" .. side .. "_hand") or seg:FindFirstChild("Root"))
	if not hand then return end
	local snd = slashSounds[side]
	if not snd or snd.Parent ~= hand then
		snd = Instance.new("Sound")
		snd.Name = "PounceSlashSound"
		snd.SoundId = SLASH_SOUND
		snd.RollOffMaxDistance = 200
		snd.Parent = hand
		slashSounds[side] = snd
	end
	snd.PlaybackSpeed = sget("PounceSlashSoundPitch")
	snd.Volume = sget("PounceSlashSoundVolume")
	snd.TimePosition = 0
	snd:Play()
	char:SetAttribute("PounceSlashSoundLoaded", snd.IsLoaded)
end
local function streaks(from, to)
	local dir = to - from
	local root = char:FindFirstChild("HumanoidRootPart")
	if dir.Magnitude < 0.3 then dir = root and -root.CFrame.UpVector or Vector3.new(0, -1, 0) end
	local scale = math.max(0.5, char:GetScale())
	local len = math.clamp(dir.Magnitude * 1.2, 1.5 * scale, 2.6 * scale)
	local unit = dir.Unit
	local side = root and root.CFrame.RightVector or Vector3.new(1, 0, 0)
	side = (side - unit * side:Dot(unit))
	side = side.Magnitude > 0.01 and side.Unit or Vector3.new(1, 0, 0)
	local w = 0.09 * scale
	local parts = {}
	for i = -1, 1 do
		local p = fxPart("PounceSlashStreak", Vector3.new(w, w, 0.05), STREAK_COLOR, CFrame.new(to))
		p.Material = Enum.Material.Neon
		parts[#parts + 1] = {p = p, off = side * (i * 0.32 * scale) - unit * (math.abs(i) * 0.15 * scale)}
	end
	animate(STREAK_GROW + STREAK_FADE, function(u)
		local t = u * (STREAK_GROW + STREAK_FADE)
		local g = math.min(1, t / STREAK_GROW)
		local l = math.max(0.05, len * g)
		local fade = t > STREAK_GROW and (t - STREAK_GROW) / STREAK_FADE or 0
		for _, e in ipairs(parts) do
			local tip = to + e.off
			local c = tip - unit * (l / 2)
			e.p.Size = Vector3.new(w * (1 - 0.6 * fade), w * (1 - 0.6 * fade), l)
			e.p.CFrame = CFrame.lookAt(c, c + unit)
			e.p.Transparency = 0.05 + 0.95 * fade
		end
	end, function()
		for _, e in ipairs(parts) do e.p:Destroy() end
	end)
end
local slashes = 0
local function slashHit(count, landing)
	local side = (count % 2 == 1) and "L" or "R"
	local dmg = char:GetAttribute("PounceHitDamage") or 0
	slashSound(side)
	local from = clawPoint(side)
	task.delay(sget("PounceSlashStrike"), function()
		local pos = clawPoint(side)
		if not pos then return end
		flash(pos)
		streaks(from or pos, pos)
		damageNumber(pos + Vector3.new(0, 1, 0), dmg, landing and LAND or TICK)
	end)
	slashes += 1
	char:SetAttribute("PounceFXSlashes", slashes)
	char:SetAttribute("PounceFXLast", "slash" .. side)
end

local hits = 0
char:GetAttributeChangedSignal("PounceBiteAt"):Connect(function()
	local at = char:GetAttribute("PounceBiteAt")
	if not at or workspace:GetServerTimeNow() - at > STALE then return end
	local count = char:GetAttribute("PounceHitCount") -- v1.1
	if char:GetAttribute("PounceSlashEnabled") ~= false and type(count) == "number" and count > 0 then
		slashHit(count, math.abs(at - (char:GetAttribute("PounceLatchedAt") or -1)) < 0.01)
		hits += 1
		char:SetAttribute("PounceFXHits", hits)
		return
	end
	local landing = math.abs(at - (char:GetAttribute("PounceLatchedAt") or -1)) < 0.01
	local s = ensureSound()
	if s then
		s.TimePosition = 0
		s:Play()
		char:SetAttribute("PounceSoundLoaded", s.IsLoaded)
	end
	local pos = jawPoint()
	if pos then
		flash(pos)
		damageNumber(pos + Vector3.new(0, 1, 0), char:GetAttribute("PounceHitDamage") or 0, landing and LAND or TICK)
	end
	hits += 1
	char:SetAttribute("PounceFXHits", hits)
	char:SetAttribute("PounceFXLast", landing and "land" or "bite")
end)
ensureSound()
