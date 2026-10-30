-- MusicServer v1.0 (Mecha Dino Arena) — remembers each player's MUSIC on / off choice (Kepu 2026-10-29: "Yes, in the main
-- menu" — a music on/off button, remembered per player). Music 1.0 (ReplicatedFirst) plays the songs; MainMenu 1.5 has
-- the button.
-- On join: DataStore "MDA_Settings_v1", key "u<UserId>" -> a table {musicOff = true / false}; player attribute
--   MusicMuted = musicOff (false when nothing is saved or the read fails, e.g. in Studio without API access).
-- Client -> server: ReplicatedStorage.MusicSetting:FireServer(muted) (boolean; anything else is ignored) -> MusicMuted =
--   muted, and the value is saved (UpdateAsync) at most once per SAVE_GAP (6) s per player; the newest value wins, the
--   last change is saved on leave.
-- Switch: script attribute MusicServerEnabled (default true, read at start; false = no remote, MusicMuted never set:
--   music always on).
-- Diagnostics: script attributes MusicServerVersion, MusicSaveState ("ok" / "readFailed" / "writeFailed" / "noStore"),
--   MusicSettingRequests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local VERSION = "1.0"
local STORE = "MDA_Settings_v1"
local SAVE_GAP = 6

script:SetAttribute("MusicServerVersion", VERSION)
script:SetAttribute("MusicSettingRequests", 0)
if script:GetAttribute("MusicServerEnabled") == nil then script:SetAttribute("MusicServerEnabled", true) end
if script:GetAttribute("MusicServerEnabled") == false then return end

local remote = ReplicatedStorage:FindFirstChild("MusicSetting")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "MusicSetting"
	remote.Parent = ReplicatedStorage
end

local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(STORE) end)
	store = ok and s or nil
	if not store then script:SetAttribute("MusicSaveState", "noStore") end
end

local pending = {} -- [player] = {value, savedValue, lastSave}
local function save(player)
	local st = pending[player]
	if not (st and store) or st.value == st.savedValue then return end
	local value = st.value
	st.lastSave = os.clock()
	local ok = pcall(function()
		store:UpdateAsync("u" .. player.UserId, function(old)
			local t = type(old) == "table" and old or {}
			t.musicOff = value
			return t
		end)
	end)
	if ok then
		st.savedValue = value
		script:SetAttribute("MusicSaveState", "ok")
	else
		script:SetAttribute("MusicSaveState", "writeFailed")
	end
end

local function onPlayer(player)
	pending[player] = {value = false, savedValue = false, lastSave = 0}
	player:SetAttribute("MusicMuted", false)
	if not store then return end
	local ok, data = pcall(function() return store:GetAsync("u" .. player.UserId) end)
	if not ok then
		script:SetAttribute("MusicSaveState", "readFailed")
		return
	end
	local off = type(data) == "table" and data.musicOff == true
	local st = pending[player]
	if st and st.value == false and st.savedValue == false then -- no change came in while reading
		st.value, st.savedValue = off, off
		player:SetAttribute("MusicMuted", off)
	end
end

remote.OnServerEvent:Connect(function(player, muted)
	script:SetAttribute("MusicSettingRequests", (script:GetAttribute("MusicSettingRequests") or 0) + 1)
	if type(muted) ~= "boolean" then return end
	local st = pending[player]
	if not st then return end
	st.value = muted
	player:SetAttribute("MusicMuted", muted)
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
	pending[player] = nil
end)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do save(p) end
end)
