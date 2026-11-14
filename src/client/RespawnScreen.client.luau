-- RespawnScreen v1.0 (Mecha Dino Arena) — the death cam, respawn countdown and CHANGE buttons in a match (LocalScript,
-- StarterPlayerScripts). MDA-540, plan docs/plans/RESPAWN_SWAP_v1.0.md rules 2 and 5, mockup docs/mockups/respawn_change_v0.1.html
-- "C · Death cam + button"; Kepu 2026-11-13 21:18 "a 5 second respawn wait with the option to change Dino in that time and the few
-- seconds after you spawn have the button stay there"; picks "Wait for me", "5 s or until you attack/get hit".
-- Reads RespawnServer 1.0's player attributes: RespawnHold, RespawnAt, RespawnPickOpen, RespawnGraceUntil.
-- While RespawnHold (you died in a match):
--   * death cam (render step "DinoRespawnCam", Camera + 9; character ShoulderCamExternal = true, so ShoulderCam stands aside):
--     the killer from the dead body's KilledByUserId (a player's character) or KilledBy (a player of that name, else a workspace
--     model of that name or "PBot_<name>"); the camera eases (RespawnCamEase 6 /s) to RespawnCamBack (18) studs behind the
--     killer and RespawnCamUp (8) up, looking at it; no killer: 30 up / 20 back over where you died. Mouse free. Hand-back: once
--     the hold ends and the body is off the park (root below RespawnParkY (3000) - 500; at most 2 s), the camera is put
--     RespawnBackDist (12) behind / RespawnBackUp (5) above the body, then CameraType Custom + ShoulderCamExternal false (the
--     default camera starts from that view, not from the death cam's).
--   * ScreenGui "RespawnScreen" (DisplayOrder 30, IgnoreGuiInset): top centre at y RespawnTopY (64; RespawnTopYPhone (80) with
--     the phone HUD, clear of its score strip) "ELIMINATED BY <NAME>" (red rgb(255,154,168),
--     Silkscreen-like FredokaOne 16) and "RESPAWN IN" + a ring (yellow stroke, the seconds left; "WAITING FOR YOU" with the picker
--     open past the time); a tag over the killer "<NAME> · <DINO> · <hp> HP" (its bottom never above the top y + RespawnTagGap (104) px: under the countdown); bottom centre a yellow 260 x 54 button "CHANGE DINO /
--     LOADOUT" (key B on PC; the "OR PRESS B" / "B ·" hints only without touch) -> RespawnRequest("open") (PregameScreen 1.4 then shows the SELECT screen). Hidden while the picker
--     is open, and on the hold after a CHANGE-window swap (player RespawnFromGrace).
-- While RespawnGraceUntil > now (just spawned): a pill under the top strip (AnchorPoint (0.5, 0), (0.5, 0, 0, RespawnPillY 72))
--   "CHANGE <n>" (dark, yellow stroke) + "ENDS IF YOU ATTACK" under it; a tap or B -> RespawnRequest("open"). An attack press in
--   the window -> RespawnRequest("attacked") once (PC: left mouse not on a button, R / C / T / V / E / Q / F / Space; touch: a
--   touch that starts on an ArenaTouch button or a MechaButtons slot).
-- Switch: script attribute RespawnScreenEnabled (default true, read per frame). Diagnostics: RespawnScreenVersion,
--   RespawnScreenState ("off" / "dead" / "picking" / "grace"), RespawnCamTarget (killer name or "spot").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
script:SetAttribute("RespawnScreenVersion", VERSION)
for k, v in pairs({RespawnScreenEnabled = true, RespawnCamBack = 18, RespawnCamUp = 8, RespawnCamEase = 6, RespawnPillY = 72,
	RespawnParkY = 3000, RespawnBackDist = 12, RespawnBackUp = 5, RespawnTagGap = 104, RespawnTopY = 64, RespawnTopYPhone = 80}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function cfg(k) return tonumber(script:GetAttribute(k)) or 0 end
local function setState(s) if script:GetAttribute("RespawnScreenState") ~= s then script:SetAttribute("RespawnScreenState", s) end end
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local YELLOW, RED_T, PANEL = Color3.fromRGB(255, 200, 50), Color3.fromRGB(255, 154, 168), Color3.fromRGB(13, 18, 24)
local FONT = Enum.Font.FredokaOne
local function now() return workspace:GetServerTimeNow() end
local function fire(...)
	local r = ReplicatedStorage:FindFirstChild("RespawnRequest")
	if r then r:FireServer(...) end
end

local function new(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) new("UICorner", {CornerRadius = r or UDim.new(0, 10)}, o) end
local function stroke(o, c, th) new("UIStroke", {Color = c, Thickness = th or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end

local gui = new("ScreenGui", {Name = "RespawnScreen", DisplayOrder = 30, IgnoreGuiInset = true, ResetOnSpawn = false, Enabled = false}, pg)
-- dead view
local dead = new("Frame", {Name = "Dead", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false}, gui)
new("Frame", {Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.72, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0}, dead)
local byL = new("TextLabel", {Name = "By", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64),
	Size = UDim2.fromOffset(420, 22), Font = FONT, TextSize = 18, TextColor3 = RED_T, TextStrokeTransparency = 0.5, Text = ""}, dead)
local inL = new("TextLabel", {Name = "In", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.5, 6, 0, 112),
	Size = UDim2.fromOffset(220, 26), Font = FONT, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.5, Text = "RESPAWN IN"}, dead)
local ring = new("TextLabel", {Name = "Ring", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 16, 0, 112), Size = UDim2.fromOffset(48, 48),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.15, Font = FONT, TextSize = 26, TextColor3 = YELLOW, Text = "5"}, dead)
corner(ring, UDim.new(1, 0))
stroke(ring, YELLOW, 3)
local tag = new("TextLabel", {Name = "KillerTag", BackgroundColor3 = PANEL, BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(230, 26), Font = FONT, TextSize = 15, TextColor3 = RED_T, Text = "", Visible = false}, dead)
corner(tag, UDim.new(0, 6))
stroke(tag, RED_T, 1.5)
local change = new("TextButton", {Name = "Change", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.fromOffset(280, 54),
	BackgroundColor3 = YELLOW, AutoButtonColor = true, Font = FONT, TextSize = 20, TextColor3 = Color3.fromRGB(27, 20, 5),
	Text = "CHANGE DINO / LOADOUT"}, dead)
corner(change, UDim.new(0, 12))
local keyHint = new("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.fromOffset(280, 16), Font = FONT, TextSize = 13, TextColor3 = Color3.fromRGB(200, 208, 220), Text = "",
	TextStrokeTransparency = 0.6}, dead)
-- grace pill
local pill = new("TextButton", {Name = "GracePill", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(150, 38), BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1, AutoButtonColor = false, Font = FONT, TextSize = 18, TextColor3 = YELLOW, Text = "CHANGE", Visible = false}, gui)
corner(pill, UDim.new(1, 0))
stroke(pill, YELLOW, 2.5)
local pillSub = new("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 3),
	Size = UDim2.fromOffset(200, 14), Font = FONT, TextSize = 12, TextColor3 = Color3.fromRGB(207, 214, 224), TextStrokeTransparency = 0.4,
	Text = "ENDS IF YOU ATTACK"}, pill)

local function open() fire("open") end
change.Activated:Connect(open)
pill.Activated:Connect(open)

-- killer + death spot, taken from the body as it dies
local killerId, killerName, deathPos = nil, nil, nil
local function watchChar(c)
	local hum = c:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.Died:Connect(function()
		killerId = tonumber(c:GetAttribute("KilledByUserId"))
		killerName = c:GetAttribute("KilledBy")
		local hrp = c:FindFirstChild("HumanoidRootPart")
		deathPos = hrp and hrp.Position or nil
		task.delay(0.3, function() -- the attributes may land just after the death
			killerId = killerId or tonumber(c:GetAttribute("KilledByUserId"))
			killerName = killerName or c:GetAttribute("KilledBy")
		end)
	end)
end
player.CharacterAdded:Connect(watchChar)
if player.Character then task.spawn(watchChar, player.Character) end

local cache, cacheAt = nil, 0
local function killerModel()
	if os.clock() - cacheAt < 0.5 and cache and cache.Parent then return cache end
	cacheAt = os.clock()
	cache = nil
	if killerId and killerId > 0 then
		local p = Players:GetPlayerByUserId(killerId)
		cache = p and p.Character
	end
	if not cache and type(killerName) == "string" and killerName ~= "" then
		local p = Players:FindFirstChild(killerName)
		cache = (p and p:IsA("Player") and p.Character) or workspace:FindFirstChild(killerName, true) or workspace:FindFirstChild("PBot_" .. killerName, true)
		if cache and not cache:IsA("Model") then cache = nil end
	end
	return cache
end
local function displayName()
	if killerId and killerId > 0 then
		local p = Players:GetPlayerByUserId(killerId)
		if p then return string.upper(p.DisplayName) end
	end
	local n = tostring(killerName or "")
	n = n:gsub("^PBot_", "")
	return n ~= "" and string.upper(n) or nil
end

-- the camera
local camOwned, camCF, restoreWait = false, nil, 0
local tagMinY = 168
local BIND = "DinoRespawnCam"
pcall(function() RunService:UnbindFromRenderStep(BIND) end)
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 9, function(dt)
	local held = script:GetAttribute("RespawnScreenEnabled") ~= false and player:GetAttribute("RespawnHold") == true
	local c = player.Character
	local cam = workspace.CurrentCamera
	if not held then
		if camOwned and cam then -- hand back once the body is placed (off the park), the camera put behind it first
			local hrp = c and c:FindFirstChild("HumanoidRootPart")
			local placed = hrp and hrp.Position.Y < cfg("RespawnParkY") - 500
			restoreWait += dt
			if placed or restoreWait > 2 then
				camOwned = false
				restoreWait = 0
				camCF = nil
				if placed then
					local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
					if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
					cam.CFrame = CFrame.lookAt(hrp.Position - look.Unit * cfg("RespawnBackDist") + Vector3.new(0, cfg("RespawnBackUp"), 0), hrp.Position)
				end
				if c then c:SetAttribute("ShoulderCamExternal", false) end
				cam.CameraType = Enum.CameraType.Custom
			end
		end
		return
	end
	restoreWait = 0
	if not cam then return end
	camOwned = true
	if c and c:GetAttribute("ShoulderCamExternal") ~= true then c:SetAttribute("ShoulderCamExternal", true) end
	cam.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	local k = killerModel()
	local root = k and (k:FindFirstChild("HumanoidRootPart") or k.PrimaryPart or k:FindFirstChildWhichIsA("BasePart"))
	local goal
	if root then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
		local pos = root.Position - look.Unit * cfg("RespawnCamBack") + Vector3.new(0, cfg("RespawnCamUp"), 0)
		goal = CFrame.lookAt(pos, root.Position + Vector3.new(0, 2, 0))
		script:SetAttribute("RespawnCamTarget", k.Name)
	elseif deathPos then
		goal = CFrame.lookAt(deathPos + Vector3.new(0, 30, 20), deathPos)
		script:SetAttribute("RespawnCamTarget", "spot")
	end
	if goal then
		camCF = camCF and camCF:Lerp(goal, math.clamp(dt * cfg("RespawnCamEase"), 0, 1)) or goal
		cam.CFrame = camCF
	end
	-- the killer's tag
	if root and dead.Visible then
		local sp, onScreen = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 7, 0))
		tag.Visible = onScreen
		if onScreen then
			tag.Position = UDim2.fromOffset(sp.X, math.max(sp.Y, tagMinY)) -- kept under the countdown
			local hum = k:FindFirstChildOfClass("Humanoid")
			local hp = tonumber(k:GetAttribute("DummyHealth")) or (hum and hum.Health) or 0
			local dino = tostring(k:GetAttribute("Species") or k:GetAttribute("BotSpecies") or "")
			tag.Text = ("%s · %s · %d HP"):format(displayName() or "", string.upper(dino == "TRex" and "T-Rex" or dino), math.max(0, math.floor(hp + 0.5)))
		end
	else
		tag.Visible = false
	end
end)

-- the screen
local function keysShown() -- key hints on PC only (not on a touch device / the phone HUD)
	return UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled and player:GetAttribute("PhoneHudV2") ~= true
end
local reported = false
RunService.RenderStepped:Connect(function()
	local enabled = script:GetAttribute("RespawnScreenEnabled") ~= false
	local held = enabled and player:GetAttribute("RespawnHold") == true
	local picking = player:GetAttribute("RespawnPickOpen") == true
	local graceLeft = (tonumber(player:GetAttribute("RespawnGraceUntil")) or 0) - now()
	local grace = enabled and not held and graceLeft > 0
	gui.Enabled = held or grace
	dead.Visible = held and not picking and player:GetAttribute("RespawnFromGrace") ~= true -- a CHANGE-window swap: no death screen
	pill.Visible = grace and not picking
	if held then
		local left = (tonumber(player:GetAttribute("RespawnAt")) or 0) - now()
		local who = displayName()
		byL.Text = who and ("ELIMINATED BY " .. who) or "ELIMINATED"
		ring.Text = left > 0 and tostring(math.ceil(left)) or "…"
		inL.Text = "RESPAWN IN"
		local top = player:GetAttribute("PhoneHudV2") == true and cfg("RespawnTopYPhone") or cfg("RespawnTopY") -- clear of the score strip
		byL.Position = UDim2.new(0.5, 0, 0, top)
		inL.Position = UDim2.new(0.5, 6, 0, top + 48)
		ring.Position = UDim2.new(0.5, 16, 0, top + 48)
		tagMinY = top + cfg("RespawnTagGap")
		keyHint.Text = keysShown() and "OR PRESS B" or ""
		setState(picking and "picking" or "dead")
		reported = false
	elseif grace then
		pill.Position = UDim2.new(0.5, 0, 0, cfg("RespawnPillY"))
		pill.Text = ("CHANGE  %d"):format(math.ceil(graceLeft))
		pillSub.Text = keysShown() and "B · ENDS IF YOU ATTACK" or "ENDS IF YOU ATTACK"
		setState(picking and "picking" or "grace")
	else
		camCF = nil
		setState("off")
	end
end)

-- B opens the picker; an attack press ends the after-spawn window
local ATTACK_KEYS = {[Enum.KeyCode.R] = true, [Enum.KeyCode.C] = true, [Enum.KeyCode.T] = true, [Enum.KeyCode.V] = true,
	[Enum.KeyCode.E] = true, [Enum.KeyCode.Q] = true, [Enum.KeyCode.F] = true, [Enum.KeyCode.Space] = true}
local function inGui(gname, pos, filter)
	local g = pg:FindFirstChild(gname)
	if not (g and g:IsA("ScreenGui") and g.Enabled) then return false end
	for _, o in ipairs(g:GetChildren()) do
		if o:IsA("GuiObject") and o.Visible and (not filter or filter(o)) then
			local p, s = o.AbsolutePosition, o.AbsoluteSize
			if pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y then return true end
		end
	end
	return false
end
UserInputService.InputBegan:Connect(function(input, processed)
	if UserInputService:GetFocusedTextBox() then return end
	local held = player:GetAttribute("RespawnHold") == true
	local graceOn = (tonumber(player:GetAttribute("RespawnGraceUntil")) or 0) > now()
	if input.KeyCode == Enum.KeyCode.B and (held or graceOn) and player:GetAttribute("RespawnPickOpen") ~= true then
		open()
		return
	end
	if not graceOn or held or reported or player:GetAttribute("RespawnPickOpen") == true then return end
	local attack = false
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then attack = true end
	if ATTACK_KEYS[input.KeyCode] and not processed then attack = true end
	if input.UserInputType == Enum.UserInputType.Touch then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		attack = inGui("ArenaTouch", pos, function(o) return o:FindFirstChildOfClass("UIScale") ~= nil end)
			or inGui("MechaButtons", pos, function(o) return o.Name:match("^Slot_") ~= nil end)
	end
	if attack then
		reported = true
		fire("attacked")
	end
end)
