local function rep(s, old, new)
	local i, j = string.find(s, old, 1, true)
	assert(i, "anchor missing: " .. old:sub(1, 60))
	assert(not string.find(s, old, j + 1, true), "anchor twice: " .. old:sub(1, 60))
	return s:sub(1, i - 1) .. new .. s:sub(j + 1)
end
local function first(s, old, new)
	local i, j = string.find(s, old, 1, true)
	assert(i, "first missing: " .. old)
	return s:sub(1, i - 1) .. new .. s:sub(j + 1)
end
local function note(P, v, old, what)
	return "-- v" .. v .. " (Arena squads, MDA-160, plan docs/plans/SQUADS_v1.0.md Task S3, ADR-006; Kepu 2026-10-31 \"turning friendly fire off\"): " .. what .. "\n--   Squadmates = ReplicatedStorage.SquadShared.SquadRules (SquadServer 1.0's copy) sameChar. Switch: script attribute\n--   " .. P .. "SquadEnabled (default true, read at each check; false = " .. old .. ").\n"
end
local function helper(P, v)
	return "-- v" .. v .. ": squadmates are never targets (ReplicatedStorage.SquadShared.SquadRules, loaded on first use)\nlocal squadMod\nlocal function squadmate(a, b)\n\tif script:GetAttribute(\"" .. P .. "SquadEnabled\") == false then return false end\n\tif not squadMod then\n\t\tlocal sh = game:GetService(\"ReplicatedStorage\"):FindFirstChild(\"SquadShared\")\n\t\tlocal m = sh and sh:FindFirstChild(\"SquadRules\")\n\t\tif not m then return false end\n\t\tlocal ok, mod = pcall(require, m)\n\t\tif not ok then return false end\n\t\tsquadMod = mod\n\tend\n\treturn squadMod.sameChar(a, b)\nend\n"
end
local function header(s, name, old, new, what)
	local line = s:match("^[^\n]*")
	assert(line:find("-- " .. name .. " v" .. old .. " ", 1, true), "header " .. name)
	s = first(s, "-- " .. name .. " v" .. old .. " ", "-- " .. name .. " v" .. new .. " ")
	local k = s:find("\nlocal ", 1, true)
	return s:sub(1, k) .. note(name, new, old, what) .. s:sub(k + 1)
end
local T = {}
T.BiteTest = function(s)
	s = header(s, "BiteTest", "1.6", "1.7", "a squadmate's hitboxes are not a bite target (targetOf) and\n--   not an aim-assist candidate (aimCandidates), so the bite never steers onto or claims a squadmate.")
	s = rep(s, "char:SetAttribute(\"BiteTestVersion\", \"1.6\")", "char:SetAttribute(\"BiteTestVersion\", \"1.7\")")
	s = rep(s, "local function targetOf(part)\n", helper("BiteTest", "1.7") .. "local function targetOf(part)\n")
	s = rep(s, "\t\t\tif folder and folder.Name == \"Hitboxes\" and folder.Parent == model then return model end\n", "\t\t\tif folder and folder.Name == \"Hitboxes\" and folder.Parent == model then\n\t\t\t\tif squadmate(char, model) then return nil end -- v1.7\n\t\t\t\treturn model\n\t\t\tend\n")
	return rep(s, "\t\tif not m:IsA(\"Model\") or m == char or m:GetAttribute(\"DummyState\") == \"ko\" then return end\n", "\t\tif not m:IsA(\"Model\") or m == char or m:GetAttribute(\"DummyState\") == \"ko\" then return end\n\t\tif squadmate(char, m) then return end -- v1.7\n")
end
T.PounceTest = function(s)
	s = header(s, "PounceTest", "1.6", "1.7", "a squadmate is not a latch / pin target (findTargets), so the\n--   raptor never latches onto a squadmate locally.")
	s = rep(s, "char:SetAttribute(\"PounceTestVersion\", \"1.6\")", "char:SetAttribute(\"PounceTestVersion\", \"1.7\")")
	s = rep(s, "-- hitbox parts of every latchable / pinnable dino right now", helper("PounceTest", "1.7") .. "-- hitbox parts of every latchable / pinnable dino right now")
	return rep(s, "\t\t\t\tand m:GetAttribute(\"DummyState\") ~= \"ko\" and m:GetAttribute(\"PinnedAt\") == nil then\n", "\t\t\t\tand m:GetAttribute(\"DummyState\") ~= \"ko\" and m:GetAttribute(\"PinnedAt\") == nil and not squadmate(char, m) then -- v1.7: squad\n")
end
T.SlashTest = function(s)
	s = header(s, "SlashTest", "1.4", "1.5", "a squadmate is not a slash target (isTarget feeds findTargets,\n--   the dive pick and the contact loop), so no claim or dive is ever sent for a squadmate.")
	s = rep(s, "local VERSION = \"1.4\"", "local VERSION = \"1.5\"")
	return rep(s, "local function isTarget(m)\n\treturn m and m:IsA(\"Model\") and m ~= char and m:GetAttribute(\"Bitable\") == true\n\t\tand (m:GetAttribute(\"Species\") ~= nil or m:GetAttribute(\"IsBot\") == true) and m:GetAttribute(\"DummyState\") ~= \"ko\"\nend", helper("SlashTest", "1.5") .. "local function isTarget(m)\n\treturn m and m:IsA(\"Model\") and m ~= char and m:GetAttribute(\"Bitable\") == true\n\t\tand (m:GetAttribute(\"Species\") ~= nil or m:GetAttribute(\"IsBot\") == true) and m:GetAttribute(\"DummyState\") ~= \"ko\"\n\t\tand not squadmate(char, m) -- v1.5\nend")
end
T.HeadbuttTest = function(s)
	s = header(s, "HeadbuttTest", "1.1", "1.2", "a squadmate is not a headbutt target (findTargets), so the charge\n--   passes through a squadmate instead of ending on contact.")
	s = rep(s, "local VERSION = \"1.1\"", "local VERSION = \"1.2\"")
	s = rep(s, "local function findTargets()\n", helper("HeadbuttTest", "1.2") .. "local function findTargets()\n")
	return rep(s, "\t\t\t\tand (m:GetAttribute(\"Species\") ~= nil or m:GetAttribute(\"IsBot\") == true) and m:GetAttribute(\"DummyState\") ~= \"ko\" then\n\t\t\t\ttable.insert(folders, d)", "\t\t\t\tand (m:GetAttribute(\"Species\") ~= nil or m:GetAttribute(\"IsBot\") == true) and m:GetAttribute(\"DummyState\") ~= \"ko\"\n\t\t\t\tand not squadmate(char, m) then -- v1.2: squad\n\t\t\t\ttable.insert(folders, d)")
end
T.TreeTopHide = function(s)
	s = header(s, "TreeTopHide", "1.1", "1.2", "a squadmate's name / health bar is never hidden from you (tree\n--   top or smoke): wantsHide is false for your squadmates.")
	s = rep(s, "local VERSION = \"1.1\"", "local VERSION = \"1.2\"")
	s = rep(s, "local function wantsHide(char)\n", helper("TreeTopHide", "1.2") .. "local function wantsHide(char)\n\tif me.Character and squadmate(me.Character, char) then return false end -- v1.2\n")
	return s
end
