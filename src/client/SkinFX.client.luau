-- SkinFX v1.0 (Mecha Dino Arena) — animates the glowing blocks of animated skins (Prism, Void Matter, Spectral, Element X, Opal) on
-- this client. MDA-569, plan docs/plans/UNIVERSAL_SKINS_v0.1.md Task 4 (Kepu 2026-11-24: animated skins kept; phones get an
-- "Animated skins" on/off setting, on by default).
-- Blocks: every BasePart with the CollectionService tag "SkinAnim" (UniversalSkins 1.0 setAnim: SkinServer 1.2 on bodies, Lab 1.8
--   on its stage copy) and attributes SkinAnim ("pulse" / "twinkle" / "hue"), SkinPhase (0-1), SkinAnimBase (hex).
-- Look (mockup numbers): pulse k = 0.55 + 1.25 x (0.5 + 0.5 sin(2.4 t + 2 pi phase)); twinkle k = 0.4 + 1.9 x (0.5 + 0.5 sin(4.2 t +
--   2 pi phase))^6; colour = base hue, value = base value x k (max 1), saturation / (1 + 0.6 x the part of value x k above 1)
--   (keeps the hue; a plain RGB multiply turned purple pink). hue: base hue + 0.08 t + 0.25 phase, saturation >= 0.55,
--   value 1. Colour writes are local only (the server colour stays the base).
-- Budget: TICK (0.05 s, 20 Hz); blocks in the world only within RANGE (120) studs of the camera; blocks inside a ViewportFrame
--   (Lab, menu) always; at most CAP (600) blocks per tick, round robin.
-- Off: player attribute SettingAnimatedSkins == false (the Settings row, MDA-572) or script attribute SkinFXEnabled == false (read
--   per tick) -> every block goes back to its base colour once and nothing more is written.
-- Diagnostics (LocalPlayer): SkinFXVersion, SkinFXBlocks (tagged), SkinFXLive (animated last tick).
-- v1.1 (UniversalSkins 1.1, Kepu 2026-11-24 picks on docs/mockups/animated_skins_v0.6.html): whole-body kinds, same maths as the
--   mockup (t = os.clock(), zf / yf = SkinZF / SkinYF, r = the block's hash from SkinLP, base = SkinAnimBase, glow / hi = SkinGlow /
--   SkinHi; boost(c, k) = value x k, whitened above 1):
--   wave (Void Matter, Element X): w = max(0, cos(2 pi (0.9 zf - 0.45 t)))^3; breathe (Spectral): w = 0.5 + 0.5 sin(2.2 t + 0.8 r);
--     colour = boost(lerp(base, w > 0.93 and hi or glow, min(1, 0.12 + w)), 0.55 + 0.85 w).
--   rainbow (Prism big panels): w = (0.5 + 0.5 cos(2 pi (0.6 zf - 0.3 t) + r))^2; hsl(1.2 zf - 0.22 t + 0.08 r, 0.7 + 0.3 w, 0.62),
--     boost 0.9 + 0.4 w (more saturated than the mockup's 0.45 / 0.74: Roblox Neon showed those as white).
--   glitch: q = hash(floor(9 t + 17 r), floor(lp.X), floor(lp.Z / 1.2), 5): < 0.55 dark 121822 (x0.7), < 0.8 cyan 00F0FF, else
--     magenta FF2BD6. storm: a flash of FFF6B0 every 1.1 s around a random spot along the body, else storm grey / blue veins.
--   beat: double thump (p = frac(0.9 t - 1.1 |zf - 0.45|)), veins (r < 0.35) 3A0610 -> FF2A3A, rest 140A0C -> B0102A.
--   fire: heat = clamp((1.15 - yf) x (0.5 + 0.5 sin(2 pi (1.8 yf - 0.9 t) + 5 r)) x 1.2 - 0.05); 1A1210 -> C8231E -> FF6A1A -> FFD23A.
--   Each block's attributes are read once and re-read when its SkinAnim / SkinAnimBase changes (a repaint). CAP 900 (whole-body
--   skins tag about 3x more blocks).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local VERSION = "1.1" -- v1.1 whole-body kinds
local TAG = "SkinAnim"
local TICK, RANGE, CAP = 0.05, 120, 900 -- v1.1: CAP 600 -> 900

local player = Players.LocalPlayer
player:SetAttribute("SkinFXVersion", VERSION)
if script:GetAttribute("SkinFXEnabled") == nil then script:SetAttribute("SkinFXEnabled", true) end

local blocks = {} -- array of parts
local index = {} -- [part] = true
local function add(p)
	if index[p] or not p:IsA("BasePart") then return end
	index[p] = true
	table.insert(blocks, p)
end
local function remove(p)
	if not index[p] then return end
	index[p] = nil
	local i = table.find(blocks, p)
	if i then table.remove(blocks, i) end
	-- a copy in a ViewportFrame is ours: put its base colour back. A world block's new colour comes from the server's repaint.
	local base = p:GetAttribute("SkinAnimBase")
	if type(base) == "string" and p:FindFirstAncestorWhichIsA("ViewportFrame") then
		pcall(function() p.Color = Color3.fromHex(base) end)
	end
end
for _, p in ipairs(CollectionService:GetTagged(TAG)) do add(p) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)

local function colorOf(kind, base, phase, t)
	if kind == "hue" then
		local h, s = base:ToHSV()
		return Color3.fromHSV((h + t * 0.08 + phase * 0.25) % 1, math.max(0.55, s), 1)
	end
	local k
	if kind == "twinkle" then
		k = 0.4 + 1.9 * (0.5 + 0.5 * math.sin(t * 4.2 + phase * 6.283)) ^ 6
	else
		k = 0.55 + 1.25 * (0.5 + 0.5 * math.sin(t * 2.4 + phase * 6.283))
	end
	-- keep the hue: brightness scales with k, and above full brightness the colour whitens a little (a capped RGB multiply
	-- turned purple pink in the Studio test)
	local h, s, v = base:ToHSV()
	local over = math.max(0, v * k - 1)
	return Color3.fromHSV(h, s / (1 + over * 0.6), math.min(1, v * k))
end

-- v1.1: whole-body kinds
local function frac(x) return x - math.floor(x) end
local function hsh(a, b, c, s) return frac(math.sin(a * 12.9898 + b * 78.233 + c * 37.719 + s * 4.123) * 43758.5453) end
local function boost(c, k)
	local h, s, v = c:ToHSV()
	local over = math.max(0, v * k - 1)
	return Color3.fromHSV(h, s / (1 + over * 0.6), math.min(1, v * k))
end
local function hsl(h, s, l)
	local q = l < 0.5 and l * (1 + s) or l + s - l * s
	local p = 2 * l - q
	local function f(x)
		x = x % 1
		if x < 1 / 6 then return p + (q - p) * 6 * x elseif x < 0.5 then return q elseif x < 2 / 3 then return p + (q - p) * (2 / 3 - x) * 6 end
		return p
	end
	return Color3.new(f(h + 1 / 3), f(h), f(h - 1 / 3))
end
local function hex(h) return Color3.fromHex(h) end
local K = {dark = hex("121822"), cyan = hex("00F0FF"), mag = hex("FF2BD6"), flash = hex("FFF6B0"), sg1 = hex("2A3140"), sg2 = hex("3A4458"),
	blue = hex("4A7CFF"), vLo = hex("3A0610"), vHi = hex("FF2A3A"), bLo = hex("140A0C"), bHi = hex("B0102A"), f0 = hex("1A1210"),
	f1 = hex("C8231E"), f2 = hex("FF6A1A"), f3 = hex("FFD23A")}
local NEW = {wave = true, breathe = true, rainbow = true, glitch = true, storm = true, beat = true, fire = true}
local infos = setmetatable({}, {__mode = "k"}) -- [part] = cached look inputs
local function infoOf(p, kind, baseHex)
	local i = infos[p]
	if i and i.kind == kind and i.baseHex == baseHex then return i end
	local lp = p:GetAttribute("SkinLP")
	lp = typeof(lp) == "Vector3" and lp or Vector3.zero
	local function c3(name, fb)
		local v = p:GetAttribute(name)
		local ok, col = pcall(Color3.fromHex, type(v) == "string" and v or "")
		return ok and col or fb
	end
	local base = c3("SkinAnimBase", p.Color)
	i = {kind = kind, baseHex = baseHex, base = base, glow = c3("SkinGlow", base), hi = c3("SkinHi", base),
		zf = tonumber(p:GetAttribute("SkinZF")) or 0.5, yf = tonumber(p:GetAttribute("SkinYF")) or 0.5, lp = lp,
		r = hsh(math.floor(lp.X / 0.6), math.floor(lp.Y / 0.6), math.floor(lp.Z / 0.6), 9)}
	infos[p] = i
	return i
end
local function lookOf(i, x)
	local kind, r, zf = i.kind, i.r, i.zf
	if kind == "wave" or kind == "breathe" then
		local w
		if kind == "wave" then w = math.max(0, math.cos(6.283 * (zf * 0.9 - x * 0.45))) ^ 3 else w = 0.5 + 0.5 * math.sin(x * 2.2 + r * 0.8) end
		return boost(i.base:Lerp(w > 0.93 and i.hi or i.glow, math.min(1, 0.12 + w)), 0.55 + 0.85 * w)
	elseif kind == "rainbow" then
		local w = (0.5 + 0.5 * math.cos(6.283 * (zf * 0.6 - x * 0.3) + r)) ^ 2
		-- Roblox Neon draws pale colours near white (Studio test: s 0.35 read as white), so the rainbow is more saturated than the mockup
		return boost(hsl(frac(zf * 1.2 - x * 0.22 + r * 0.08), 0.7 + 0.3 * w, 0.62), 0.9 + 0.4 * w)
	elseif kind == "glitch" then
		local q = hsh(math.floor(x * 9 + r * 17), math.floor(i.lp.X), math.floor(i.lp.Z / 1.2), 5)
		if q < 0.55 then return boost(K.dark, 0.7) elseif q < 0.8 then return K.cyan end
		return K.mag
	elseif kind == "storm" then
		local s = math.floor(x / 1.1)
		local f = x / 1.1 - s
		local zc = hsh(s, 1, 2, 3)
		local near = math.abs(zf - zc) < 0.09 + 0.05 * hsh(s, 4, 5, 6) and hsh(math.floor(i.lp.Y / 0.8), s, 0, 7) < 0.85
		if near and (f < 0.07 or (f > 0.12 and f < 0.18)) then return K.flash end
		if r < 0.2 then return boost(K.sg1:Lerp(K.blue, 0.35 + 0.25 * math.sin(x * 1.5 + r * 9)), 1.1) end
		return boost(r < 0.6 and K.sg1 or K.sg2, 0.75)
	elseif kind == "beat" then
		local p = frac(x * 0.9 - math.abs(zf - 0.45) * 1.1)
		local b = math.exp(-(p - 0.05) ^ 2 / 0.0025) + 0.65 * math.exp(-(p - 0.22) ^ 2 / 0.0025)
		if r < 0.35 then return boost(K.vLo:Lerp(K.vHi, math.clamp(0.2 + b, 0, 1)), 0.8 + 0.9 * b) end
		return boost(K.bLo:Lerp(K.bHi, math.clamp(b * 0.8, 0, 1)), 0.6 + 0.7 * b)
	elseif kind == "fire" then
		local f = 0.5 + 0.5 * math.sin(6.283 * (i.yf * 1.8 - x * 0.9) + r * 5)
		local heat = math.clamp((1.15 - i.yf) * f * 1.2 - 0.05, 0, 1)
		local c
		if heat < 0.35 then c = K.f0:Lerp(K.f1, heat / 0.35)
		elseif heat < 0.7 then c = K.f1:Lerp(K.f2, (heat - 0.35) / 0.35)
		else c = K.f2:Lerp(K.f3, (heat - 0.7) / 0.3) end
		return boost(c, 0.65 + heat)
	end
	return i.base
end

local wasOn = true
local cursor = 0
local baseCache = setmetatable({}, {__mode = "k"}) -- [part] = {hex, Color3}
task.spawn(function()
	while true do
		task.wait(TICK)
		local on = script:GetAttribute("SkinFXEnabled") ~= false and player:GetAttribute("SettingAnimatedSkins") ~= false
		if not on then
			if wasOn then
				for _, p in ipairs(blocks) do
					local base = p:GetAttribute("SkinAnimBase")
					if type(base) == "string" then pcall(function() p.Color = Color3.fromHex(base) end) end
				end
				wasOn = false
			end
			player:SetAttribute("SkinFXLive", 0)
		else
			wasOn = true
			local t = os.clock()
			local cam = workspace.CurrentCamera
			local camPos = cam and cam.CFrame.Position or Vector3.zero
			local n = #blocks
			local live = 0
			local steps = math.min(n, CAP)
			for _ = 1, steps do
				cursor = cursor % n + 1
				local p = blocks[cursor]
				if p and p.Parent then
					local inView = p:FindFirstAncestorWhichIsA("ViewportFrame") ~= nil
					if inView or (p.Position - camPos).Magnitude <= RANGE then
						local hex = p:GetAttribute("SkinAnimBase")
						if type(hex) == "string" then
							local c = baseCache[p]
							if not c or c[1] ~= hex then
								local ok, col = pcall(Color3.fromHex, hex)
								c = {hex, ok and col or p.Color}
								baseCache[p] = c
							end
							local kind = p:GetAttribute("SkinAnim")
							if NEW[kind] then -- v1.1
								p.Color = lookOf(infoOf(p, kind, hex), t)
							else
								p.Color = colorOf(kind, c[2], tonumber(p:GetAttribute("SkinPhase")) or 0, t)
							end
							live += 1
						end
					end
				end
			end
			player:SetAttribute("SkinFXLive", live)
		end
		player:SetAttribute("SkinFXBlocks", #blocks)
	end
end)
