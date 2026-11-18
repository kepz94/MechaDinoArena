-- VictoryTitlesAudio v1.0 (Mecha Dino Arena) — music and sound effects for the end-of-match title show (ModuleScript,
-- StarterPlayerScripts, next to VictoryTitles). MDA-552, docs/plans/SOUND_PASS_v1.0.md round 16. Kepu 2026-11-17 15:05
-- "it would be better to have better music and sound effects during these", 15:10 "Clown music for the crappy title cards
-- and hero music for the good ones" / "With the appropriate sound effects", 16:48 kept all 16 music tracks.
-- Driven by VictoryTitles 1.3; every setting is an attribute on the VictoryTitles LocalScript (cfg):
--   Music: each title starts a track picked at random (never the last two picked) from its list: good titles (apex, king,
--     unkill, medic, masher) VictoryMusicHero1..8, roasts (extinct, carried, pacifist) VictoryMusicClown1..8 (APM tracks from
--     the Roblox Creator Store, free in Roblox games). It fades out over VictoryMusicFade (0.35) s when the next title
--     starts, a title is skipped or the show stops. Volume VictoryMusicVolume (0.4).
--   Title sound effects: the card hit as the lower third slams in (gslam_hero / gslam_roast, played with the title: the hit
--     is 0.42 s in, the card lands 0.3-0.55 s), then one sound per beat of the animation (BEATS: the times are the
--     animation's own beats in VictoryTitlesAnim, read from the runner's clock, so they stay on the picture when Studio runs
--     slow; + VictorySfxShift (0) s). Cue ids VictorySfxId_<cue> (blank = that cue is silent), volumes VictorySfxVol_<cue>.
--   Crowd: res_cheer + res_fireworks (0.25 s later) when the results start, board_cheer + board_fireworks (0.2 s later)
--     when the show ends by itself (HardpointHUD's board comes up).
--   Switches (read per play): VictoryAudioEnabled (all), VictoryTitleMusicEnabled, VictoryTitleSfxEnabled,
--     VictoryCrowdEnabled. VictoryAudioVolume (1) scales everything (the VictoryTitlesAudio SoundGroup).
--   Diagnostics: VictoryAudioVersion, VictoryAudioLast ("<cue> @<t>"), VictoryAudioCount, VictoryMusicLast ("<id> <title>").
-- v1.1 (Kepu 2026-11-17 17:52 "You do it"): the 47 cues imported through Asset Manager (fee 0), every id checked with
--   GetProductInfo (name MDA_SFX_vt_<cue>, Audio, creator 8595585713); they are M.IDS and the VictorySfxId_<cue> defaults.
--   An attribute already set to "" (a 1.0 test session) is filled in with the id once; any other value is kept.
-- The sound files are made by docs/sfx/gen_titles_sfx.py v1.1 from Sonniss GDC 2026 recordings (cue sheet
-- docs/sfx/TITLES_SFX_v1.1.md).
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local M = {}
M.VERSION = "1.0"
M.VERSION = "1.1" -- v1.1 the 47 sound effect ids

M.HERO = {"1839895012", "9042409054", "1848016523", "95493370982599", "1835295052", "94745027512855", "1848014986", "1839432165"}
-- All Action Hero (f), Day Of The Election Sting 2, Global Success StingA, Herald of Freedom (Sting 1), Forging The Army
-- StingA, Wings of Destiny (Sting 2), The Ultimate Challenge StingA, Triumph
M.CLOWN = {"9046171154", "9046171148", "9046172786", "9046171151", "9046173035", "9046174316", "9042030749", "1846070982"}
-- Clown Parade Sting 1, Clown Parade Sting 2, Circus And Clowns Link, Clown Parade Link, Circus And Clowns Sting 2,
-- Round Up Round Up Link 2, Cheerful Tuba, Funny Cut D3

-- cue -> default volume (from each render's loudness: beds lower, the big moments higher)
M.VOL = {apex_cheer = 0.68, apex_land = 1, apex_pounce = 0.99, apex_roar = 0.95, board_cheer = 0.7, board_fireworks = 1,
	car_bag = 1, car_bite = 1, car_dizzy = 0.48, car_fling = 0.68, car_mmph = 0.57, car_poof = 0.74, car_swish = 0.52,
	car_thump = 0.57, car_zip = 0.87, ext_fall = 0.53, ext_ghost = 0.88, ext_gulp = 0.72, ext_happy = 1, ext_impact = 1,
	ext_sign = 1, gslam_hero = 0.64, gslam_roast = 1, king_bonk = 0.8, king_coin = 1, king_ding = 0.85, king_land = 1,
	king_rattle = 0.2, mash_click = 1, mash_fly = 0.69, mash_pop = 0.88, mash_sad = 0.35, mash_sizzle = 1, mash_wahwah = 0.89,
	med_heal = 1, med_open = 1, med_slap = 1, pac_ah = 0.63, pac_bloom = 1, pac_choo = 1, res_cheer = 0.65,
	res_fireworks = 0.98, unk_chew = 0.45, unk_glint = 0.67, unk_hit = 1, unk_pebble = 1, unk_rocks = 1}
-- cue -> asset id (filled in once uploaded; blank = silent)
M.IDS = {}
for k in pairs(M.VOL) do M.IDS[k] = "" end
M.IDS = {apex_cheer = "96532423673781", apex_land = "120142008364103", apex_pounce = "79357121984462",
	apex_roar = "126390021485224", board_cheer = "119169568384031", board_fireworks = "78310813954178",
	car_bag = "133903708278743", car_bite = "92893335324184", car_dizzy = "124934836451935", car_fling = "131894356692490",
	car_mmph = "86725128850846", car_poof = "91083711005300", car_swish = "122593312847624", car_thump = "135100156451298",
	car_zip = "113427946537625", ext_fall = "85514274487711", ext_ghost = "123651615430889", ext_gulp = "125146048141793",
	ext_happy = "138251625769000", ext_impact = "114799108479742", ext_sign = "127566499028104",
	gslam_hero = "71645155737742", gslam_roast = "97146079917175", king_bonk = "122024100932730",
	king_coin = "132501650153339", king_ding = "102411658719885", king_land = "129374689512340",
	king_rattle = "95408227468048", mash_click = "91717834960493", mash_fly = "111914653658294", mash_pop = "87134119392635",
	mash_sad = "73997108531714", mash_sizzle = "104130928400385", mash_wahwah = "93576786331257", med_heal = "92719690524933",
	med_open = "98848745455926", med_slap = "79119560274390", pac_ah = "134864139208586", pac_bloom = "134793104449345",
	pac_choo = "98190956382459", res_cheer = "135699636484419", res_fireworks = "125602112619715",
	unk_chew = "91499801194642", unk_glint = "72694165515052", unk_hit = "91429251701520", unk_pebble = "131758907774696",
	unk_rocks = "85635194393101"} -- v1.1

-- title -> {{cue, seconds into the title (the animation's clock), playback speed}}
local BEATS = {
	apex = {{"apex_pounce", 1.05}, {"apex_land", 1.48}, {"apex_roar", 2.22}, {"apex_cheer", 3.45}},
	king = {{"king_bonk", 0.10}, {"king_coin", 1.1}, {"king_land", 1.55}, {"king_rattle", 1.9}, {"king_ding", 2.49}, {"apex_cheer", 3.2}},
	unkill = {{"unk_chew", 0.0}, {"unk_glint", 0.45}, {"ext_fall", 0.9}, {"unk_hit", 1.68}, {"unk_rocks", 2.35}, {"unk_chew", 4.3},
		{"unk_pebble", 4.75}},
	medic = {{"car_swish", 0.12, 0.8}, {"car_thump", 0.55}, {"med_open", 0.98}, {"car_zip", 1.45}, {"car_swish", 1.75, 1.15},
		{"car_swish", 1.95, 1.3}, {"med_slap", 2.42}, {"med_heal", 3.0}},
	masher = {{"mash_click", 0.78}},
	extinct = {{"ext_happy", 0.05}, {"ext_happy", 0.5, 1.12}, {"ext_gulp", 1.0}, {"ext_fall", 1.5}, {"ext_impact", 2.22},
		{"ext_sign", 3.22}, {"ext_ghost", 3.45}},
	carried = {{"car_bite", 0.7}, {"car_swish", 1.0, 0.9}, {"car_swish", 1.32, 1.0}, {"car_fling", 1.58}, {"car_swish", 1.6, 1.1},
		{"car_swish", 1.84, 1.2}, {"car_swish", 2.05, 1.3}, {"car_dizzy", 2.4}, {"car_poof", 2.6}, {"car_bag", 2.95},
		{"car_zip", 3.85}, {"car_mmph", 4.25}, {"car_thump", 4.85}, {"car_mmph", 5.3, 0.92}},
	pacifist = {{"pac_bloom", 0.1}, {"pac_ah", 1.5, 1.1}, {"pac_ah", 1.83, 1.25}, {"pac_ah", 2.15, 1.4}, {"pac_choo", 2.38},
		{"car_thump", 2.9}, {"car_dizzy", 2.95}, {"unk_glint", 4.4, 1.2}},
}
for k = 0, 14 do table.insert(BEATS.masher, {"mash_click", 0.85 + (k + 0.45) / 7.2, 1 + 0.03 * k}) end -- the pecks speed up
for _, b in ipairs({{"mash_sizzle", 2.1}, {"mash_pop", 2.72}, {"mash_fly", 3.1}, {"mash_sad", 4.36}, {"mash_wahwah", 4.6}}) do
	table.insert(BEATS.masher, b)
end
for _, list in pairs(BEATS) do table.sort(list, function(a, b) return a[2] < b[2] end) end
M.BEATS = BEATS

local cfg -- the VictoryTitles LocalScript (attributes)
local group
local live = {} -- sfx sounds of the current title
local music -- the current track
local recent = {} -- last two music ids
local cur = {title = nil, i = 1, lastT = 0}
local rng = Random.new()

local function on(a) return cfg and cfg:GetAttribute(a) ~= false end
local function num(a, d) return cfg and tonumber(cfg:GetAttribute(a)) or d end
local function enabled(layer) return on("VictoryAudioEnabled") and on(layer) end

function M.init(script)
	cfg = script
	local defaults = {VictoryAudioEnabled = true, VictoryTitleMusicEnabled = true, VictoryTitleSfxEnabled = true, VictoryCrowdEnabled = true,
		VictoryAudioVolume = 1, VictoryMusicVolume = 0.4, VictoryMusicFade = 0.35, VictorySfxShift = 0}
	for i, id in ipairs(M.HERO) do defaults["VictoryMusicHero" .. i] = id end
	for i, id in ipairs(M.CLOWN) do defaults["VictoryMusicClown" .. i] = id end
	for k, v in pairs(M.VOL) do defaults["VictorySfxVol_" .. k] = v defaults["VictorySfxId_" .. k] = M.IDS[k] end
	for k, v in pairs(defaults) do if cfg:GetAttribute(k) == nil then cfg:SetAttribute(k, v) end end
	for k, id in pairs(M.IDS) do -- v1.1: a blank id left by 1.0 gets the uploaded one
		if id ~= "" and cfg:GetAttribute("VictorySfxId_" .. k) == "" then cfg:SetAttribute("VictorySfxId_" .. k, id) end
	end
	cfg:SetAttribute("VictoryAudioVersion", M.VERSION)
	group = SoundService:FindFirstChild("VictoryTitlesAudio") or Instance.new("SoundGroup")
	group.Name = "VictoryTitlesAudio"
	group.Parent = SoundService
end

local function sfxId(cue)
	local id = cfg:GetAttribute("VictorySfxId_" .. cue)
	id = id and tostring(id) or ""
	return id ~= "" and id or nil
end
local function musicIds(roast)
	local list = {}
	for i = 1, 8 do
		local id = cfg:GetAttribute((roast and "VictoryMusicClown" or "VictoryMusicHero") .. i)
		if id and tostring(id) ~= "" then table.insert(list, tostring(id)) end
	end
	return list
end

function M.preload()
	if not cfg then return end
	task.spawn(function()
		local list = {}
		for _, roast in ipairs({false, true}) do
			for _, id in ipairs(musicIds(roast)) do
				local s = Instance.new("Sound") s.SoundId = "rbxassetid://" .. id table.insert(list, s)
			end
		end
		for k in pairs(M.VOL) do
			local id = sfxId(k)
			if id then local s = Instance.new("Sound") s.SoundId = "rbxassetid://" .. id table.insert(list, s) end
		end
		pcall(function() ContentProvider:PreloadAsync(list) end)
		for _, s in ipairs(list) do s:Destroy() end
	end)
end

-- one-shot sound effect
function M.sfx(cue, rate, keep)
	if not cfg or not group then return end
	local id = sfxId(cue)
	if not id then return end
	group.Volume = num("VictoryAudioVolume", 1)
	local s = Instance.new("Sound")
	s.Name = "VT_" .. cue
	s.SoundId = "rbxassetid://" .. id
	s.Volume = num("VictorySfxVol_" .. cue, M.VOL[cue] or 0.7)
	s.PlaybackSpeed = rate or 1
	s.SoundGroup = group
	s.Parent = SoundService
	s:Play()
	if not keep then table.insert(live, s) end
	s.Ended:Once(function() s:Destroy() end)
	task.delay(20, function() if s.Parent then s:Destroy() end end)
	cfg:SetAttribute("VictoryAudioLast", ("%s @%.2f"):format(cue, cur.lastT))
	cfg:SetAttribute("VictoryAudioCount", (cfg:GetAttribute("VictoryAudioCount") or 0) + 1)
end

local function fadeOut(s, sec)
	if not s or not s.Parent then return end
	if sec <= 0 then s:Destroy() return end
	TweenService:Create(s, TweenInfo.new(sec, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Volume = 0}):Play()
	task.delay(sec + 0.05, function() if s.Parent then s:Destroy() end end)
end

local function stopTitle(sec)
	fadeOut(music, sec)
	music = nil
	for _, s in ipairs(live) do fadeOut(s, math.min(sec, 0.15)) end
	table.clear(live)
	cur.title = nil
end

-- a title starts (wall clock: the lower third slams in 0.3 s from now)
function M.title(titleId, roast)
	if not cfg or not group then return end
	stopTitle(num("VictoryMusicFade", 0.35))
	cur.title, cur.i, cur.lastT = titleId, 1, 0
	if not on("VictoryAudioEnabled") then return end
	if on("VictoryTitleSfxEnabled") then M.sfx(roast and "gslam_roast" or "gslam_hero") end
	if on("VictoryTitleMusicEnabled") then
		local list = musicIds(roast)
		local pick = {}
		for _, id in ipairs(list) do if id ~= recent[1] and id ~= recent[2] then table.insert(pick, id) end end
		if #pick == 0 then pick = list end
		if #pick > 0 then
			local id = pick[rng:NextInteger(1, #pick)]
			recent[2], recent[1] = recent[1], id
			group.Volume = num("VictoryAudioVolume", 1)
			local s = Instance.new("Sound")
			s.Name = "VT_music"
			s.SoundId = "rbxassetid://" .. id
			s.Volume = num("VictoryMusicVolume", 0.4)
			s.SoundGroup = group
			s.Parent = SoundService
			s:Play()
			s.Ended:Once(function() s:Destroy() end)
			music = s
			cfg:SetAttribute("VictoryMusicLast", id .. " " .. titleId)
		end
	end
end

-- per frame: t = the runner's clock (seconds into the title's animation)
function M.step(t)
	if not cur.title or type(t) ~= "number" then return end
	local list = BEATS[cur.title]
	if not list then return end
	local shift = num("VictorySfxShift", 0)
	if t - cur.lastT > 0.5 then -- a jump (joined late, caught up): don't fire the beats it skipped
		while list[cur.i] and list[cur.i][2] + shift <= t do cur.i += 1 end
		cur.lastT = t
		return
	end
	cur.lastT = t
	while list[cur.i] and list[cur.i][2] + shift <= t do
		local b = list[cur.i]
		cur.i += 1
		if enabled("VictoryTitleSfxEnabled") then M.sfx(b[1], b[3]) end
	end
end

-- the show stopped (skip to end, ended, done)
function M.stop()
	stopTitle(num("VictoryMusicFade", 0.35))
end

-- crowd: "res" when the results start, "board" when the show ends by itself
function M.crowd(kind)
	if not cfg or not enabled("VictoryCrowdEnabled") then return end
	if kind == "res" then
		M.sfx("res_cheer", 1, true)
		task.delay(0.25, function() M.sfx("res_fireworks", 1, true) end)
	elseif kind == "board" then
		M.sfx("board_cheer", 1, true)
		task.delay(0.2, function() M.sfx("board_fireworks", 1, true) end)
	end
end

return M
