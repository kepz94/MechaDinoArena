-- ShopStandServer v1.1 (Mecha Dino Arena) — the island shop stand by the WORLDWIDE board (Script, ServerScriptService).
-- Kepu 2026-11-25 13:04 "Create a shop stand where the spawn is on the island by the side of the leaderboard"; 13:24 picks on mockup
--   docs/mockups/shop_stand_v0.1.html: look "B" (dino market stall), "open shop" (walking up shows OPEN SHOP and opens the Shop),
--   spot "Right of WORLDWIDE".
-- Builds (ServerKind == "hub" only, once Workspace.PortalIslet.Portal_arena and Workspace.IsletBoards.Board_world exist) the Model
--   Workspace.ShopStand (ModelStreamingMode Persistent): a wooden market stall with an orange / yellow striped gable roof, a striped
--   front valance, a counter with crates and a dark "SHOP" sign. Placed in the gate frame used by LeaderboardServer 1.1: gate pivot
--   g, F = g.LookVector flat, R = (-F):Cross(up); spot = (g.X, ShopStandGroundY, g.Z) + R * ShopStandSide + F * ShopStandFwd
--   (the WORLDWIDE board is at R * 60 + F * 14, so this is its outer side as a player on the spawn arc sees it), turned to face
--   (g.X, y, g.Z) + F * ShopStandAim (the spawn arc, as the boards). Sizes x ShopStandScale.
-- Model attributes for ShopStandClient 1.0: ShopStandFront (Vector3, the ground point ShopStandFrontGap studs in front of the
--   counter) and ShopStandRange (studs from that point that show OPEN SHOP).
-- Switches / numbers (script attributes, read at start): ShopStandEnabled (true; false = nothing built), ShopStandSide (100),
--   ShopStandFwd (34), ShopStandAim (82), ShopStandGroundY (1.3, the plaza top), ShopStandScale (1.35), ShopStandRange (24),
--   ShopStandFrontGap (4). Studio 2026-11-25: at scale 1 the stall read small next to the 65-stud board; 1.35 and the spot moved
--   (Side 92 -> 100, Fwd 26 -> 34) keep it clear of the board and on the plaza (radius 110).
-- Diagnostics: ShopStandServerVersion, ShopStandState ("off" / "notHub" / "waiting" / "built" / "error: ..."), ShopStandParts.
-- v1.1 (Kepu 2026-11-25 22:24 "The shop is placed weird, I want it to be spaced properly and facing the center"; picks on mockup
--   docs/mockups/shop_stand_v0.2: spot "A: WORLDWIDE side", centre = the plaza centre): new switch ShopStandPlace ("centre", the
--   default; "gate" = the v1.0 spot above, unchanged). "centre": c = Workspace.PortalIslet.Plaza (X, Z) at ShopStandGroundY;
--   spot = c + (cos a, 0, sin a) * ShopStandRadius with a = ShopStandAngle degrees from world +X toward +Z (160, 85: the WORLDWIDE
--   side, 21 studs clear of that board, measured in Studio); turned to face c. No Plaza part -> the "gate" spot.
--   Diagnostic ShopStandPlaceUsed ("centre" / "gate").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERSION = "1.1"
script:SetAttribute("ShopStandServerVersion", VERSION)
for k, v in pairs({ShopStandEnabled = true, ShopStandSide = 100, ShopStandFwd = 34, ShopStandAim = 82, ShopStandGroundY = 1.3,
	ShopStandScale = 1.35, ShopStandRange = 24, ShopStandFrontGap = 4,
	ShopStandPlace = "centre", ShopStandAngle = 160, ShopStandRadius = 85}) do -- v1.1: last three
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function A(k, d) return tonumber(script:GetAttribute(k)) or d end
local function state(s) script:SetAttribute("ShopStandState", s) end

if script:GetAttribute("ShopStandEnabled") == false then state("off") return end

-- wait for the island (HubServer sets ServerKind; LeaderboardServer builds the boards once the gate exists)
state("waiting")
local t0 = os.clock()
local gate, board
while os.clock() - t0 < 120 do
	local kind = ReplicatedStorage:GetAttribute("ServerKind")
	if kind ~= nil and kind ~= "hub" then state("notHub") return end
	local islet = workspace:FindFirstChild("PortalIslet")
	gate = islet and islet:FindFirstChild("Portal_arena")
	local boards = workspace:FindFirstChild("IsletBoards")
	board = boards and boards:FindFirstChild("Board_world")
	if kind == "hub" and gate and board then break end
	task.wait(0.5)
end
if not (gate and board) then state("waiting: no gate / board") return end

local WOOD, WOOD_D, WOOD_L = Color3.fromRGB(154, 106, 60), Color3.fromRGB(122, 82, 48), Color3.fromRGB(185, 133, 79)
local ORANGE, YELLOW = Color3.fromRGB(255, 122, 26), Color3.fromRGB(255, 200, 50)
local CRATE, CYAN, SIGN = Color3.fromRGB(196, 154, 90), Color3.fromRGB(127, 233, 255), Color3.fromRGB(29, 38, 51)

local sc = A("ShopStandScale", 1.35)
local W, D, POST_H, COUNTER_H, RISE = 32 * sc, 14 * sc, 24 * sc, 8 * sc, 8 * sc

local g = gate:GetPivot()
local F = Vector3.new(g.LookVector.X, 0, g.LookVector.Z)
F = F.Magnitude > 1e-3 and F.Unit or Vector3.new(-0.7071, 0, -0.7071)
local R = (-F):Cross(Vector3.yAxis)
local gy = A("ShopStandGroundY", 1.3)
local origin = Vector3.new(g.X, gy, g.Z)
local pos = origin + R * A("ShopStandSide", 100) + F * A("ShopStandFwd", 34)
local aim = origin + F * A("ShopStandAim", 82)
local base = CFrame.lookAt(pos, Vector3.new(aim.X, pos.Y, aim.Z)) -- local -Z = the front (counter side)
-- v1.1: "centre" spot (the v1.0 lines above stay as the "gate" spot)
local placeUsed = "gate"
local plaza = gate.Parent and gate.Parent:FindFirstChild("Plaza")
if script:GetAttribute("ShopStandPlace") ~= "gate" and plaza and plaza:IsA("BasePart") then
	local c = Vector3.new(plaza.Position.X, gy, plaza.Position.Z)
	local a = math.rad(A("ShopStandAngle", 160))
	local cpos = c + Vector3.new(math.cos(a), 0, math.sin(a)) * A("ShopStandRadius", 85)
	base = CFrame.lookAt(cpos, c)
	placeUsed = "centre"
end
script:SetAttribute("ShopStandPlaceUsed", placeUsed)

local old = workspace:FindFirstChild("ShopStand")
if old then old:Destroy() end
local m = Instance.new("Model")
m.Name = "ShopStand"
m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
local count = 0
local function part(name, size, cf, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = base * cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
	count += 1
	return p
end

local ok, err = pcall(function()
	local PLANK = Enum.Material.WoodPlanks
	part("Floor", Vector3.new(W + 2, 1, D + 2), CFrame.new(0, 0.5, 0), WOOD_D, PLANK)
	for _, sx in ipairs({-1, 1}) do
		for _, sz in ipairs({-1, 1}) do
			part("Post", Vector3.new(2 * sc, POST_H, 2 * sc), CFrame.new(sx * (W / 2 - sc), 1 + POST_H / 2, sz * (D / 2 - sc)), WOOD_D, PLANK)
		end
	end
	part("BackWall", Vector3.new(W - 2 * sc, POST_H - 2 * sc, 1 * sc), CFrame.new(0, 1 + (POST_H - 2 * sc) / 2, D / 2 - sc), WOOD, PLANK)
	part("Counter", Vector3.new(W - 4 * sc, COUNTER_H, 4 * sc), CFrame.new(0, 1 + COUNTER_H / 2, -D / 2 + 2.5 * sc), WOOD, PLANK)
	part("CounterTop", Vector3.new(W - 3 * sc, 1 * sc, 5 * sc), CFrame.new(0, 1 + COUNTER_H + 0.5 * sc, -D / 2 + 2.5 * sc), WOOD_L, PLANK)
	local topY = 1 + COUNTER_H + sc
	part("Crate", Vector3.new(4, 4, 4) * sc, CFrame.new(-W / 2 + 6 * sc, topY + 2 * sc, -D / 2 + 3 * sc) * CFrame.Angles(0, math.rad(12), 0), CRATE, PLANK)
	part("Crate", Vector3.new(3.5, 3.5, 3.5) * sc, CFrame.new(W / 2 - 6 * sc, topY + 1.75 * sc, -D / 2 + 3 * sc) * CFrame.Angles(0, math.rad(-8), 0), CRATE, PLANK)
	local item = part("Item", Vector3.new(6, 2.5, 3) * sc, CFrame.new(0, topY + 1.25 * sc, -D / 2 + 3 * sc), CYAN, Enum.Material.Neon)
	item.CastShadow = false
	-- gable roof (ridge front to back), 4 stripes a side, orange / yellow left to right
	local half = W / 2 + 2 * sc
	local a = math.atan2(RISE, half)
	local L = math.sqrt(half * half + RISE * RISE)
	local eaveY = 1 + POST_H
	local top = eaveY + RISE
	local idx = 0
	for _, s in ipairs({-1, 1}) do
		local order = s < 0 and {3, 2, 1, 0} or {0, 1, 2, 3} -- left side from the eave in, right side from the ridge out
		for _, i in ipairs(order) do
			local t = (i + 0.5) / 4
			local cf = CFrame.new(s * half * t, top - RISE * t + 0.5 * sc, 0) * CFrame.Angles(0, 0, -s * a)
			part("Roof", Vector3.new(L / 4 + 0.05, 1 * sc, D + 4 * sc), cf, idx % 2 == 0 and ORANGE or YELLOW)
			idx += 1
		end
	end
	part("Ridge", Vector3.new(1.2 * sc, 1.2 * sc, D + 4.2 * sc), CFrame.new(0, top + 0.6 * sc, 0), WOOD_D, PLANK)
	-- striped valance under the front eave
	local n = 8
	local vw = (W + 4 * sc) / n
	for i = 0, n - 1 do
		part("Valance", Vector3.new(vw, 3 * sc, 0.6 * sc), CFrame.new(-(W + 4 * sc) / 2 + vw * (i + 0.5), eaveY - 1.5 * sc, -D / 2 - 2 * sc),
			i % 2 == 0 and ORANGE or YELLOW)
	end
	-- SHOP sign hanging under the valance
	local sign = part("Sign", Vector3.new(16 * sc, 4.5 * sc, 0.6 * sc), CFrame.new(0, eaveY - 5.6 * sc, -D / 2 - 1.6 * sc), SIGN)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "SignGui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = sign
	local tl = Instance.new("TextLabel")
	tl.Name = "Shop"
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold) -- Silkscreen Bold
	tl:SetAttribute("FontSwap", "keep")
	tl.TextScaled = true
	tl.TextColor3 = YELLOW
	tl.Text = "SHOP"
	tl.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
	pad.Parent = tl
	for _, p in ipairs({sign}) do p.CastShadow = false end
end)
if not ok then
	m:Destroy()
	state("error: " .. tostring(err))
	return
end
m.WorldPivot = base
local front = (base * CFrame.new(0, 0, -D / 2 - A("ShopStandFrontGap", 4))).Position
m:SetAttribute("ShopStandFront", front)
m:SetAttribute("ShopStandRange", A("ShopStandRange", 24))
m.Parent = workspace
script:SetAttribute("ShopStandParts", count)
state("built")
