-- Music v1.1 (Mecha Dino Arena) — background music by screen (LocalScript in ReplicatedFirst, so it is running from the
-- first loading screen; this client only). Kepu 2026-10-29: "I want [the island music] to start playing during the
-- loading screen ... At the main menu screen up until you load up play gymnopedie on repeat ... In the lab play [its
-- song]"; "From the loading screen to the island the music keeps playing it doesn't restart. It just begins the playlist
-- at loading screen"; "These will just keep being on repeat"; answers: compact Lab keeps the island music, volume 0.4
-- with 1.5 s fades, a MUSIC on/off button in the main menu (remembered per player). Songs (2026-10-29): Sunflower Dance
-- Party, Daily Beetle and Divertissement were refused by Roblox's audio upload, so the island song is "Little Toys" and
-- the Lab song "Crazy Daisy" (album "Afro 8 Bit") from Roblox's licensed APM library; the menu song is Kepu's upload of
-- Gymnopedie No. 2 (Erik Satie, Kevin MacLeod).
-- Tracks (each Looped, one at a time):
--   menu   = Gymnopedie No. 2, rbxassetid://120675586878082
--   island = Little Toys,      rbxassetid://1835450413
--   lab    = Crazy Daisy,      rbxassetid://1845556724
-- Which one plays (checked on every relevant attribute change and every 0.25 s, first match wins):
--   1. player attribute MusicMuted == true (MusicServer 1.0 / MainMenu 1.5 button) -> "off" (silence);
--   2. player attribute LabOpen == "full" (the Lab from the menu; Lab 1.x) -> "lab";
--   3. a loading screen is up: player attribute EggLoaderState is "splash" / "loading" / "hatching" / "hatched" /
--      "fading" / "travel" (EggLoader 1.1) -> "island";
--   4. player attribute MainMenuOpen == true -> "menu";
--   5. otherwise (on the island, compact Lab included) -> "island".
-- Changing track: the old one fades to 0 over FADE (1.5 s) then stops; the new one starts from the beginning and fades
--   up to VOLUME (0.4). Staying in the same state never restarts the song, so the island song runs on from the loading
--   screen onto the island. "off" fades the current song out.
-- Switch: script attribute MusicEnabled (default true, read at start; false = no music at all).
-- Diagnostics (LocalPlayer attributes, this client): MusicVersion, MusicState ("menu" / "island" / "lab" / "off"),
--   MusicTrack (the playing song's name, "" when silent), MusicLoaded (the playing song's TimeLength > 0).
-- v1.1 (Kepu 2026-11-02: "I want these to be the default songs when you load in to these places. Airship Serenity for the
--   main menu. Bitquest starts at the loading screen and continues on to the island. Level up for the lab. All the current
--   songs can stay but they will no longer be the default load in songs. The 8bit dungeon level song will go on to the
--   island as well."; all four by Kevin MacLeod, incompetech.com, CC BY 4.0 -> credit needed):
--   new default tracks, each one's Roblox asset id read from a script attribute (set once Kepu has uploaded the mp3s):
--     menu   = Airship Serenity          (MusicIdAirshipSerenity), looped;
--     island = Bit Quest -> 8bit Dungeon Level -> Bit Quest ... (MusicIdBitQuest, MusicIdDungeonLevel): a playlist that
--              starts with Bit Quest at the loading screen and runs on onto the island without restarting (same state);
--              each song plays once, the next starts when it ends;
--     lab    = Level Up                  (MusicIdLevelUp), looped.
--   A state whose new id is not set yet (attribute "" / missing) keeps its 1.0 song, so nothing goes silent before the
--   upload; on the island a missing Dungeon Level id just loops Bit Quest. The 1.0 songs stay in TRACKS (kept, not
--   default). Switch: script attribute MusicNewDefaults (default true, read at start; false = 1.0 songs everywhere).
--   Diagnostic: MusicPlaylistIndex (island: which playlist song is playing, 1-based; 0 otherwise).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.1"
local VOLUME = 0.4
local FADE = 1.5
local TRACKS = {
	menu = {name = "Gymnopedie No. 2", id = "rbxassetid://120675586878082"},
	island = {name = "Little Toys", id = "rbxassetid://1835450413"},
	lab = {name = "Crazy Daisy", id = "rbxassetid://1845556724"},
}
local LOADING = {splash = true, loading = true, hatching = true, hatched = true, fading = true, travel = true}
-- v1.1: the new default songs (asset ids from script attributes; "" = not uploaded yet)
local NEW = {
	menu = {{name = "Airship Serenity", attr = "MusicIdAirshipSerenity"}},
	island = {{name = "Bit Quest", attr = "MusicIdBitQuest"}, {name = "8bit Dungeon Level", attr = "MusicIdDungeonLevel"}},
	lab = {{name = "Level Up", attr = "MusicIdLevelUp"}},
}
if script:GetAttribute("MusicNewDefaults") == nil then script:SetAttribute("MusicNewDefaults", true) end
for _, list in pairs(NEW) do
	for _, t in ipairs(list) do
		if script:GetAttribute(t.attr) == nil then script:SetAttribute(t.attr, "") end
	end
end
local useNew = script:GetAttribute("MusicNewDefaults") ~= false
local function newId(t)
	local v = script:GetAttribute(t.attr)
	if type(v) == "number" then v = tostring(v) end
	if type(v) ~= "string" or v == "" then return nil end
	return v:match("^rbxassetid://") and v or ("rbxassetid://" .. v)
end

if script:GetAttribute("MusicEnabled") == nil then script:SetAttribute("MusicEnabled", true) end
local player = Players.LocalPlayer
player:SetAttribute("MusicVersion", VERSION)
if script:GetAttribute("MusicEnabled") == false then
	player:SetAttribute("MusicState", "off")
	return
end

local folder = SoundService:FindFirstChild("MDA_Music")
if folder then folder:Destroy() end
folder = Instance.new("Folder")
folder.Name = "MDA_Music"
folder.Parent = SoundService
local sounds = {}
for key, t in pairs(TRACKS) do
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = t.id
	s.Looped = true
	s.Volume = 0
	s.Parent = folder
	sounds[key] = s
end

local current = "off"
-- v1.1: per state, the list of sounds to play in order (1 = looped single song); falls back to the 1.0 sound
local lists = {}
for state, old in pairs(sounds) do
	local list = {}
	if useNew and NEW[state] then
		for i, t in ipairs(NEW[state]) do
			local id = newId(t)
			if id then
				local s = Instance.new("Sound")
				s.Name = state .. "_" .. i
				s.SoundId = id
				s.Volume = 0
				s.Parent = folder
				table.insert(list, {sound = s, name = t.name})
			end
		end
	end
	if #list == 0 then list = {{sound = old, name = TRACKS[state].name}} end
	for _, e in ipairs(list) do e.sound.Looped = #list == 1 end
	lists[state] = list
end
local index = 0 -- playlist position in the current state
player:SetAttribute("MusicPlaylistIndex", 0)
local function playing() local l = lists[current]; return l and l[index] and l[index].sound end

local function wanted()
	if player:GetAttribute("MusicMuted") == true then return "off" end
	if player:GetAttribute("LabOpen") == "full" then return "lab" end
	if LOADING[player:GetAttribute("EggLoaderState")] then return "island" end
	if player:GetAttribute("MainMenuOpen") == true then return "menu" end
	return "island"
end
local function startEntry(i)
	local l = lists[current]
	index = i
	local e = l and l[i]
	player:SetAttribute("MusicPlaylistIndex", (l and #l > 1) and i or 0)
	if not e then
		player:SetAttribute("MusicTrack", "")
		return
	end
	e.sound.TimePosition = 0
	e.sound.Volume = 0
	e.sound:Play()
	TweenService:Create(e.sound, TweenInfo.new(FADE), {Volume = VOLUME}):Play()
	player:SetAttribute("MusicTrack", e.name)
end
local function setState(state)
	if state == current then return end
	local old = playing()
	current = state
	player:SetAttribute("MusicState", state)
	if old then
		TweenService:Create(old, TweenInfo.new(FADE), {Volume = 0}):Play()
		task.delay(FADE, function()
			if playing() ~= old then old:Stop() end -- not if its state came back meanwhile
		end)
	end
	startEntry(1) -- a new state always starts its playlist from the first song
end
-- v1.1: a playlist song that ends (not looped) hands over to the next one, wrapping round
for state, l in pairs(lists) do
	for i, e in ipairs(l) do
		e.sound.Ended:Connect(function()
			if current == state and index == i and #l > 1 then startEntry(i % #l + 1) end
		end)
	end
end
local function check() setState(wanted()) end

for _, name in ipairs({"MusicMuted", "LabOpen", "EggLoaderState", "MainMenuOpen"}) do
	player:GetAttributeChangedSignal(name):Connect(check)
end
check()
task.spawn(function()
	while folder.Parent do
		check()
		local s = playing()
		player:SetAttribute("MusicLoaded", s ~= nil and s.TimeLength > 0)
		task.wait(0.25)
	end
end)
