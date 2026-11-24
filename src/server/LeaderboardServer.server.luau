-- LeaderboardServer v1.0 (Mecha Dino Arena) — worldwide Arena wins, the top 100 ranks and the two leaderboard models by the
-- ARENA gate (Script, ServerScriptService). Kepu 2026-11-24: 15:39 "how about a leaderboard" (rank by Arena wins); 15:44 "an
-- actual leaderboard that will stand by the portals. One for the lobby and one for worldwide ... a special number badge by
-- your name" (picks: top 100, boards framing the gate); 15:50 "a real look ... Dino themed"; 16:02 board style "B Mecha
-- monitor" (mockup docs/mockups/leaderboard_looks_v0.4.html); 16:08 "scroll the screen". Client side: LeaderboardBoards 1.0
-- (screens), RankBadge 1.0 (badges).
-- Wins store: OrderedDataStore LbStoreName ("MDA_ArenaWins_v1"), key "u" .. UserId, value = that player's Arena wins. Written
--   (SetAsync) whenever a player's ArenaW attribute (ArenaRecordServer: on load and after each saved write) becomes a number > 0
--   that differs from the last value written for that player on this server. Every server kind.
-- Top list: every LbRefresh (60) s (first at start): GetSortedAsync(descending, LbTopN (100)) page 1 -> ranks 1..n in that
--   order. Names: UserService:GetUserInfosByUserIdsAsync (DisplayName, cached per UserId for this server; a player on this
--   server uses their DisplayName; unknown -> "PLAYER"). Published as ReplicatedStorage attributes LbWorldTop (JSON array of
--   [userId, NAME upper case, wins]) and LbWorldAt (os.time() of the fetch). A failed fetch keeps the last list.
-- Ranks: every player on this server gets attribute WorldRank = their place in the list (1..n), nil when not in it; set after
--   each fetch and on join.
-- Boards (ServerKind == "hub" only, once Workspace.PortalIslet.Portal_arena exists): Folder Workspace.IsletBoards with two
--   style-B models (mecha monitor on a rock, from tools/build/LeaderboardLooks.preview.luau v0.4): "Board_lobby" left and
--   "Board_world" right of the gate as a player facing it sees it. Gate pivot g, forward F = g.LookVector flat, right
--   R = (-F):Cross(up). Base spot = (g.X, LbGroundY, g.Z) + R * side * LbBoardSide (60) + F * LbBoardFwd (14), side -1 lobby /
--   +1 world; each turned to face the point (g.X, LbGroundY, g.Z) + F * LbBoardAim (82) (the spawn arc). Models are
--   ModelStreamingMode Persistent. Each screen part is named "Screen" with attribute LbBoard "lobby" / "world"; the client
--   draws on it (nothing is drawn by the server).
-- Switches (script attributes, read at start unless noted): LbEnabled (true; false = nothing at all), LbWorldEnabled (true;
--   false = no store reads / writes, no WorldRank), LbBoardsEnabled (true; false = no boards), LbSaveEnabled (true; false = no
--   DataStore calls, for Studio). Numbers: LbRefresh, LbTopN, LbBoardSide, LbBoardFwd, LbBoardAim, LbGroundY (1.8).
-- Studio test hook (RunService:IsStudio() only, read per fetch): LbTestRows (0) > 0 -> the list is LbTestRows made-up rows
--   instead of the store (wins falling from 300); LbTestMyRank (0) > 0 -> every player on this server is put in the list at
--   that rank (their own name, the wins of that row).
-- Diagnostics: LeaderboardServerVersion, LbState ("off" / "noStore" / "saveOff" / "on"), LbFetches, LbFetchFails, LbWrites,
--   LbWriteFails, LbLast (last fetch / write / error), LbBoards (models built).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local VERSION = "1.0"
local DEFAULTS = {LbEnabled = true, LbWorldEnabled = true, LbBoardsEnabled = true, LbSaveEnabled = true,
	LbStoreName = "MDA_ArenaWins_v1", LbRefresh = 60, LbTopN = 100, LbBoardSide = 60, LbBoardFwd = 14, LbBoardAim = 82,
	LbGroundY = 1.8, LbTestRows = 0, LbTestMyRank = 0}
script:SetAttribute("LeaderboardServerVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function A(k) local v = script:GetAttribute(k) if v == nil then return DEFAULTS[k] end return v end
local function bump(name) script:SetAttribute(name, (script:GetAttribute(name) or 0) + 1) end

if A("LbEnabled") == false then
	script:SetAttribute("LbState", "off")
	return
end

-- ---------- worldwide wins ----------
local store
if A("LbWorldEnabled") ~= false and A("LbSaveEnabled") ~= false then
	local ok, s = pcall(function() return DataStoreService:GetOrderedDataStore(A("LbStoreName")) end)
	store = ok and s or nil
end
script:SetAttribute("LbState", A("LbWorldEnabled") == false and "off" or A("LbSaveEnabled") == false and "saveOff" or (store and "on" or "noStore"))

local written = {} -- [userId] = wins last written from this server
local function writeWins(p)
	if not store or p.Parent ~= Players then return end
	local w = p:GetAttribute("ArenaW")
	if type(w) ~= "number" or w <= 0 or written[p.UserId] == w then return end
	written[p.UserId] = w
	local ok, err = pcall(function() store:SetAsync("u" .. p.UserId, math.floor(w)) end)
	if ok then
		bump("LbWrites")
		script:SetAttribute("LbLast", ("write %s %d"):format(p.Name, w))
	else
		written[p.UserId] = nil
		bump("LbWriteFails")
		script:SetAttribute("LbLast", "write " .. p.Name .. ": " .. tostring(err))
	end
end

local names = {} -- [userId] = NAME
local list = {} -- {{id, name, wins}}
local function rankFor(p)
	for i, r in ipairs(list) do
		if r[1] == p.UserId then return i end
	end
	return nil
end
local function applyRanks()
	if A("LbWorldEnabled") == false then return end
	for _, p in ipairs(Players:GetPlayers()) do
		local r = rankFor(p)
		if p:GetAttribute("WorldRank") ~= r then p:SetAttribute("WorldRank", r) end
	end
end

local function fillNames(ids)
	local need = {}
	for _, id in ipairs(ids) do
		local p = Players:GetPlayerByUserId(id)
		if p then names[id] = string.upper(p.DisplayName) elseif not names[id] then table.insert(need, id) end
	end
	if #need > 0 then
		local ok, infos = pcall(function() return UserService:GetUserInfosByUserIdsAsync(need) end)
		if ok and type(infos) == "table" then
			for _, info in ipairs(infos) do
				if info.Id then names[info.Id] = string.upper(tostring(info.DisplayName or info.Username or "PLAYER")) end
			end
		end
	end
end

local function testList()
	local n = math.floor(tonumber(A("LbTestRows")) or 0)
	local out = {}
	local words = {"DINO", "SKY", "ROCK", "QUILL", "VENOM", "SPIKE", "MEGA", "T3NO", "PACHY", "GLOW"}
	local ends = {"SLAYER", "CLAW", "JAW", "STORM", "QUEEN", "DOG", "BYTE", "TANK", "POWER", "STICK"}
	for i = 1, n do
		table.insert(out, {-i, words[(i - 1) % 10 + 1] .. ends[(i * 7 - 1) % 10 + 1] .. (i > 10 and tostring(i) or ""), math.max(1, 300 - i * 3)})
	end
	local my = math.floor(tonumber(A("LbTestMyRank")) or 0)
	if my > 0 then
		for _, p in ipairs(Players:GetPlayers()) do
			local at = math.clamp(my, 1, #out + 1)
			table.insert(out, at, {p.UserId, string.upper(p.DisplayName), out[at] and out[at][3] or 1})
			my += 1
		end
		while #out > math.max(n, 1) and #out > (tonumber(A("LbTopN")) or 100) do table.remove(out) end
	end
	return out
end

local function publish()
	local ok, json = pcall(function() return HttpService:JSONEncode(list) end)
	if ok then
		ReplicatedStorage:SetAttribute("LbWorldTop", json)
		ReplicatedStorage:SetAttribute("LbWorldAt", os.time())
	end
	applyRanks()
end

local function fetch()
	if A("LbWorldEnabled") == false then return end
	if RunService:IsStudio() and (tonumber(A("LbTestRows")) or 0) > 0 then
		list = testList()
		bump("LbFetches")
		script:SetAttribute("LbLast", ("test %d rows"):format(#list))
		publish()
		return
	end
	if not store then return end
	local ok, err = pcall(function()
		local pages = store:GetSortedAsync(false, math.clamp(math.floor(tonumber(A("LbTopN")) or 100), 1, 100))
		local page = pages:GetCurrentPage()
		local ids, rows = {}, {}
		for _, e in ipairs(page) do
			local id = tonumber(string.match(tostring(e.key), "^u(%d+)$"))
			if id and type(e.value) == "number" and e.value > 0 then
				table.insert(ids, id)
				table.insert(rows, {id, e.value})
			end
		end
		fillNames(ids)
		local out = {}
		for _, r in ipairs(rows) do table.insert(out, {r[1], names[r[1]] or "PLAYER", math.floor(r[2])}) end
		list = out
	end)
	if ok then
		bump("LbFetches")
		script:SetAttribute("LbLast", ("fetch %d rows"):format(#list))
		publish()
	else
		bump("LbFetchFails")
		script:SetAttribute("LbLast", "fetch: " .. tostring(err))
	end
end

local function watch(p)
	p:GetAttributeChangedSignal("ArenaW"):Connect(function() task.spawn(writeWins, p) end)
	task.spawn(writeWins, p)
	if A("LbWorldEnabled") ~= false then
		local r = rankFor(p)
		p:SetAttribute("WorldRank", r)
	end
end
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watch, p) end
Players.PlayerRemoving:Connect(function(p) written[p.UserId] = nil end)

task.spawn(function()
	while true do
		fetch()
		task.wait(math.max(10, tonumber(A("LbRefresh")) or 60))
	end
end)

-- ---------- the boards (hub only) ----------
if A("LbBoardsEnabled") == false then return end
local kind
for _ = 1, 60 do
	kind = ReplicatedStorage:GetAttribute("ServerKind")
	if kind ~= nil then break end
	task.wait(0.5)
end
if kind ~= "hub" then return end
local isl = workspace:WaitForChild("PortalIslet", 60)
local gate = isl and isl:WaitForChild("Portal_arena", 30)
if not (gate and gate:IsA("Model")) then
	script:SetAttribute("LbLast", "boards: no Portal_arena")
	return
end

local C = {
	slateD = Color3.fromRGB(60, 70, 86), slate = Color3.fromRGB(74, 84, 102), steel = Color3.fromRGB(154, 166, 184),
	neon = Color3.fromRGB(255, 100, 18), bone = Color3.fromRGB(236, 224, 196), boneD = Color3.fromRGB(205, 190, 160),
	rock = Color3.fromRGB(96, 88, 80), rockD = Color3.fromRGB(70, 64, 58), stone = Color3.fromRGB(120, 110, 98),
	screen = Color3.fromRGB(12, 16, 24),
}
local function P(parent, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end -- after Size, as the preview builder (the picked look)
	p.Parent = parent
	return p
end
local function W(parent, size, cf, color, mat)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = mat or Enum.Material.SmoothPlastic
	w.Parent = parent
	return w
end
local function skull(parent, cf, s, color, eye)
	local c = color or C.bone
	P(parent, Vector3.new(6, 4.6, 6) * s, cf * CFrame.new(0, 0.6 * s, 1.2 * s), c)
	P(parent, Vector3.new(4.4, 3, 5) * s, cf * CFrame.new(0, 0.1 * s, -3.6 * s), c)
	P(parent, Vector3.new(4.2, 1.4, 6.6) * s, cf * CFrame.new(0, -2.2 * s, -1.6 * s), C.boneD)
	P(parent, Vector3.new(1.4, 1.3, 0.3) * s, cf * CFrame.new(-1.7, 1.2 * s, -1.8 * s), eye or Color3.fromRGB(30, 26, 22), eye and Enum.Material.Neon or nil)
	P(parent, Vector3.new(1.4, 1.3, 0.3) * s, cf * CFrame.new(1.7, 1.2 * s, -1.8 * s), eye or Color3.fromRGB(30, 26, 22), eye and Enum.Material.Neon or nil)
	P(parent, Vector3.new(0.9, 0.7, 0.3) * s, cf * CFrame.new(-0.8 * s, 0.6 * s, -6.15 * s), Color3.fromRGB(30, 26, 22))
	P(parent, Vector3.new(0.9, 0.7, 0.3) * s, cf * CFrame.new(0.8 * s, 0.6 * s, -6.15 * s), Color3.fromRGB(30, 26, 22))
	for i = -3, 3 do
		W(parent, Vector3.new(0.45, 1.1, 0.6) * s, cf * CFrame.new(i * 0.6 * s, -1.6 * s, -5.6 * s) * CFrame.Angles(math.rad(180), 0, 0), Color3.new(1, 1, 1))
	end
	W(parent, Vector3.new(0.8, 2.4, 2) * s, cf * CFrame.new(-2.6 * s, 3.4 * s, 2.4 * s), c)
	W(parent, Vector3.new(0.8, 2.4, 2) * s, cf * CFrame.new(2.6 * s, 3.4 * s, 2.4 * s), c)
end
local function rockLump(parent, cf, size)
	P(parent, size, cf, C.rock, Enum.Material.Slate)
	P(parent, size * Vector3.new(0.7, 0.8, 0.8), cf * CFrame.new(size.X * 0.25, size.Y * 0.15, size.Z * 0.1) * CFrame.Angles(0.15, 0.4, 0.1), C.rockD, Enum.Material.Slate)
	P(parent, size * Vector3.new(0.6, 0.7, 0.7), cf * CFrame.new(-size.X * 0.3, size.Y * 0.05, -size.Z * 0.1) * CFrame.Angles(-0.1, -0.5, 0.12), C.stone, Enum.Material.Slate)
end
-- style B: mecha monitor on a rock (as the v0.4 preview)
local function styleB(m, base, kind)
	rockLump(m, base * CFrame.new(0, 3, 0), Vector3.new(22, 6, 14))
	P(m, Vector3.new(10, 3, 8), base * CFrame.new(0, 7, 0), C.slateD, Enum.Material.Metal)
	P(m, Vector3.new(4, 10, 4), base * CFrame.new(-3, 13, 0) * CFrame.Angles(0, 0, math.rad(90)), C.steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	P(m, Vector3.new(4, 10, 4), base * CFrame.new(3, 13, 0) * CFrame.Angles(0, 0, math.rad(90)), C.steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	P(m, Vector3.new(10, 10, 2.4), base * CFrame.new(0, 13, 0) * CFrame.Angles(0, 0, math.rad(90)), C.slate, Enum.Material.Metal, Enum.PartType.Cylinder)
	local mon = base * CFrame.new(0, 18 + 19, 0) * CFrame.Angles(math.rad(-6), 0, 0)
	P(m, Vector3.new(32, 38, 4), mon, C.slateD, Enum.Material.Metal)
	P(m, Vector3.new(34, 3, 5), mon * CFrame.new(0, 19.5, 0), C.slate, Enum.Material.DiamondPlate)
	P(m, Vector3.new(34, 3, 5), mon * CFrame.new(0, -19.5, 0), C.slate, Enum.Material.DiamondPlate)
	local scr = P(m, Vector3.new(27, 31, 0.3), mon * CFrame.new(0, -0.5, -2.1), C.screen)
	scr.Name = "Screen"
	scr:SetAttribute("LbBoard", kind)
	for _, x in ipairs({-15.2, 15.2}) do
		P(m, Vector3.new(0.6, 30, 0.6), mon * CFrame.new(x, 0, -2.2), C.neon, Enum.Material.Neon)
	end
	P(m, Vector3.new(26, 0.6, 0.6), mon * CFrame.new(0, 17.4, -2.2), C.neon, Enum.Material.Neon)
	for _, v in ipairs({{-15.5, 19.5}, {15.5, 19.5}, {-15.5, -19.5}, {15.5, -19.5}}) do
		P(m, Vector3.new(1.6, 1.6, 1.6), mon * CFrame.new(v[1], v[2], -2.6), C.steel, Enum.Material.Metal, Enum.PartType.Ball)
	end
	skull(m, mon * CFrame.new(0, 25, 0), 1.1, C.steel, C.neon)
	for i = 0, 2 do
		P(m, Vector3.new(0.5, 8, 0.3), mon * CFrame.new(11 + i * 1.3, -12, -2.3) * CFrame.Angles(0, 0, math.rad(25)), C.neon, Enum.Material.Neon)
	end
	for i = 0, 3 do
		W(m, Vector3.new(1, 5 - i, 4), mon * CFrame.new(-17.5, 10 - i * 6, 0) * CFrame.Angles(0, math.rad(-90), 0), C.slate, Enum.Material.Metal)
		W(m, Vector3.new(1, 5 - i, 4), mon * CFrame.new(17.5, 10 - i * 6, 0) * CFrame.Angles(0, math.rad(90), 0), C.slate, Enum.Material.Metal)
	end
end

local old = workspace:FindFirstChild("IsletBoards")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "IsletBoards"
local g = gate:GetPivot()
local F = Vector3.new(g.LookVector.X, 0, g.LookVector.Z)
F = F.Magnitude > 1e-3 and F.Unit or Vector3.new(-0.7071, 0, -0.7071)
local R = (-F):Cross(Vector3.yAxis)
local gy = tonumber(A("LbGroundY")) or 1.8
local origin = Vector3.new(g.X, gy, g.Z)
local target = origin + F * (tonumber(A("LbBoardAim")) or 82)
local built = 0
for _, side in ipairs({-1, 1}) do
	local kindB = side < 0 and "lobby" or "world"
	local pos = origin + R * side * (tonumber(A("LbBoardSide")) or 60) + F * (tonumber(A("LbBoardFwd")) or 14)
	local base = CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z))
	local m = Instance.new("Model")
	m.Name = "Board_" .. kindB
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local ok, err = pcall(styleB, m, base, kindB)
	if ok then
		m.Parent = folder
		built += 1
	else
		script:SetAttribute("LbLast", "board " .. kindB .. ": " .. tostring(err))
	end
end
folder.Parent = workspace
script:SetAttribute("LbBoards", built)
