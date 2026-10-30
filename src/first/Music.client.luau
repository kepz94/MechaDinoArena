-- Music v1.0 (Mecha Dino Arena) — background music by screen (LocalScript in ReplicatedFirst, so it is running from the
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
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.0"
local VOLUME = 0.4
local FADE = 1.5
local TRACKS = {
	menu = {name = "Gymnopedie No. 2", id = "rbxassetid://120675586878082"},
	island = {name = "Little Toys", id = "rbxassetid://1835450413"},
	lab = {name = "Crazy Daisy", id = "rbxassetid://1845556724"},
}
local LOADING = {splash = true, loading = true, hatching = true, hatched = true, fading = true, travel = true}

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
local function wanted()
	if player:GetAttribute("MusicMuted") == true then return "off" end
	if player:GetAttribute("LabOpen") == "full" then return "lab" end
	if LOADING[player:GetAttribute("EggLoaderState")] then return "island" end
	if player:GetAttribute("MainMenuOpen") == true then return "menu" end
	return "island"
end
local function setState(state)
	if state == current then return end
	local old = sounds[current]
	current = state
	player:SetAttribute("MusicState", state)
	if old then
		TweenService:Create(old, TweenInfo.new(FADE), {Volume = 0}):Play()
		task.delay(FADE, function()
			if sounds[current] ~= old then old:Stop() end -- not if its state came back meanwhile
		end)
	end
	local new = sounds[state]
	if new then
		new.TimePosition = 0
		new.Volume = 0
		new:Play()
		TweenService:Create(new, TweenInfo.new(FADE), {Volume = VOLUME}):Play()
		player:SetAttribute("MusicTrack", TRACKS[state].name)
	else
		player:SetAttribute("MusicTrack", "")
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
		local s = sounds[current]
		player:SetAttribute("MusicLoaded", s ~= nil and s.TimeLength > 0)
		task.wait(0.25)
	end
end)
