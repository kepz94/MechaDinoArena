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
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local VERSION = "1.0"
local TAG = "SkinAnim"
local TICK, RANGE, CAP = 0.05, 120, 600

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
							p.Color = colorOf(p:GetAttribute("SkinAnim"), c[2], tonumber(p:GetAttribute("SkinPhase")) or 0, t)
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
