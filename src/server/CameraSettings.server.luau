-- CameraSettings v1.0 (Mecha Dino Arena) — remembers each player's CAMERA choice (MDA-368, plan
-- docs/plans/CAMERA_MODES_v1.0.md ticket 1; Kepu 2026-11-08 live mobile test: "The over the shoulder view on mobile sucks. My
-- players want options to have the regular player camera & a shift lock option"; 2026-11-09 picked direction C "Both", phone
-- start Classic). CameraModes 1.0 (StarterPlayerScripts) shows the choice and ShoulderCam 1.9 places the camera.
-- On join: DataStore "MDA_Settings_v1" (MusicServer 1.0's store), key "u<UserId>" -> the same table, fields camTouch /
--   camMouse ("classic" / "shift" / "shoulder"; one per device type because the defaults differ: phones Classic, PC
--   Shoulder) and camButtonOff (true = the on-screen camera button is hidden). Player attributes: CameraModeTouch,
--   CameraModeMouse ("" = nothing saved -> the device default) and CameraButtonOff (false when nothing is saved or the read
--   fails, e.g. in Studio without API access).
-- Client -> server: ReplicatedStorage.CameraSetting:FireServer(key, value): key "touch" / "mouse" with a mode string, or
--   "button" with a boolean (true = button off); anything else is ignored. The attribute is set at once and saved
--   (UpdateAsync, merged into the table so MUSIC stays) at most once per SAVE_GAP (6) s per player; the newest values win;
--   the last change is saved on leave.
-- Roblox camera movement: on join Player.DevTouchCameraMode / DevComputerCameraMode = Classic (Kepu: the regular camera
--   "follows, turns only when dragged; not Follow"). Only Classic uses Roblox's camera (ShoulderCam places it in Shift Lock
--   / Shoulder). Switch: script attribute CameraSettingsClassicMovement (default true, read at each join; false = the
--   player's own Roblox setting).
-- Switch: script attribute CameraSettingsEnabled (default true, read at start; false = no remote, the attributes are never
--   set: every device uses its default and the button shows).
-- Diagnostics: script attributes CameraSettingsVersion, CameraSaveState ("ok" / "readFailed" / "writeFailed" / "noStore"),
--   CameraSettingRequests, CameraSettingRejects; player attribute CameraSettingLast ("<key>=<value>").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local VERSION = "1.0"
local STORE = "MDA_Settings_v1"
local SAVE_GAP = 6
local MODES = {classic = true, shift = true, shoulder = true}
local FIELDS = {touch = {"camTouch", "CameraModeTouch"}, mouse = {"camMouse", "CameraModeMouse"}} -- key -> {store field, attribute}

script:SetAttribute("CameraSettingsVersion", VERSION)
script:SetAttribute("CameraSettingRequests", 0)
script:SetAttribute("CameraSettingRejects", 0)
if script:GetAttribute("CameraSettingsEnabled") == nil then script:SetAttribute("CameraSettingsEnabled", true) end
if script:GetAttribute("CameraSettingsEnabled") == false then return end

local remote = ReplicatedStorage:FindFirstChild("CameraSetting")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "CameraSetting"
	remote.Parent = ReplicatedStorage
end

local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE) end)
	store = ok and s or nil
	if not store then script:SetAttribute("CameraSaveState", "noStore") end
end

local state = {} -- [player] = {value = {camTouch, camMouse, camButtonOff}, saved = {...}, changed = bool, lastSave, queued}
local function save(player)
	local st = state[player]
	if not (st and store and st.changed) then return end
	local v = {camTouch = st.value.camTouch, camMouse = st.value.camMouse, camButtonOff = st.value.camButtonOff}
	st.changed = false
	st.lastSave = os.clock()
	local ok = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			local t = type(old) == "table" and old or {}
			t.camTouch, t.camMouse, t.camButtonOff = v.camTouch, v.camMouse, v.camButtonOff
			return t
		end)
	end)
	if ok then
		script:SetAttribute("CameraSaveState", "ok")
	else
		st.changed = true
		script:SetAttribute("CameraSaveState", "writeFailed")
	end
end

local function publish(player, st)
	player:SetAttribute("CameraModeTouch", st.value.camTouch or "")
	player:SetAttribute("CameraModeMouse", st.value.camMouse or "")
	player:SetAttribute("CameraButtonOff", st.value.camButtonOff == true)
end

if script:GetAttribute("CameraSettingsClassicMovement") == nil then script:SetAttribute("CameraSettingsClassicMovement", true) end
local function onPlayer(player)
	if script:GetAttribute("CameraSettingsClassicMovement") ~= false then
		pcall(function()
			player.DevTouchCameraMode = Enum.DevTouchCameraMovementMode.Classic
			player.DevComputerCameraMode = Enum.DevComputerCameraMovementMode.Classic
		end)
	end
	local st = {value = {}, changed = false, lastSave = 0, touched = false}
	state[player] = st
	publish(player, st)
	if not store then return end
	local ok, data = pcall(function() return store:GetAsync("u" .. player.UserId) end)
	if not ok then
		script:SetAttribute("CameraSaveState", "readFailed")
		return
	end
	if state[player] ~= st or st.touched then return end -- left, or a change came in while reading (the newest wins)
	if type(data) == "table" then
		st.value.camTouch = MODES[data.camTouch] and data.camTouch or nil
		st.value.camMouse = MODES[data.camMouse] and data.camMouse or nil
		st.value.camButtonOff = data.camButtonOff == true
	end
	publish(player, st)
end

remote.OnServerEvent:Connect(function(player, key, value)
	script:SetAttribute("CameraSettingRequests", (script:GetAttribute("CameraSettingRequests") or 0) + 1)
	local st = state[player]
	local okArg = false
	if st and FIELDS[key] and type(value) == "string" and MODES[value] then
		st.value[FIELDS[key][1]] = value
		okArg = true
	elseif st and key == "button" and type(value) == "boolean" then
		st.value.camButtonOff = value
		okArg = true
	end
	if not okArg then
		script:SetAttribute("CameraSettingRejects", (script:GetAttribute("CameraSettingRejects") or 0) + 1)
		return
	end
	st.changed, st.touched = true, true
	publish(player, st)
	player:SetAttribute("CameraSettingLast", tostring(key) .. "=" .. tostring(value))
	local wait = SAVE_GAP - (os.clock() - st.lastSave)
	if wait <= 0 then
		task.spawn(save, player)
	elseif not st.queued then
		st.queued = true
		task.delay(wait, function()
			st.queued = false
			if player.Parent then save(player) end
		end)
	end
end)

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	state[player] = nil
end)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do save(p) end
end)
