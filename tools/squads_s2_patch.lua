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
	return "-- v" .. v .. " (Arena squads, MDA-159, plan docs/plans/SQUADS_v1.0.md Task S2, ADR-006; Kepu 2026-10-31 \"turning friendly fire off\",\n--   picked \"Everything harmful\"): " .. what .. " Squadmates = SquadRules 1.0 sameChar (same Arena squad; a test target's\n--   SquadTestId counts). Switch: script attribute " .. P .. "SquadEnabled (default true, read at each check; false = " .. old .. ").\n--   Diagnostic: script " .. P .. "SquadSkips (count of squadmate skips / refusals).\n"
end
local function helper(P, v)
	return "-- v" .. v .. ": squadmates are never targets (SquadRules 1.0, loaded on first use)\nlocal squadMod\nlocal function squadmate(a, b)\n\tif script:GetAttribute(\"" .. P .. "SquadEnabled\") == false then return false end\n\tif not squadMod then\n\t\tlocal arc = game:GetService(\"ServerStorage\"):FindFirstChild(\"DinoArcade\")\n\t\tlocal m = arc and arc:FindFirstChild(\"SquadRules\")\n\t\tif not m then return false end\n\t\tlocal ok, mod = pcall(require, m)\n\t\tif not ok then return false end\n\t\tsquadMod = mod\n\tend\n\tif squadMod.sameChar(a, b) then\n\t\tscript:SetAttribute(\"" .. P .. "SquadSkips\", (script:GetAttribute(\"" .. P .. "SquadSkips\") or 0) + 1)\n\t\treturn true\n\tend\n\treturn false\nend\n"
end
local function header(s, name, old, new, what)
	local line = s:match("^[^\n]*")
	assert(line:find("-- " .. name .. " v" .. old .. " ", 1, true), "header " .. name)
	s = first(s, "-- " .. name .. " v" .. old .. " ", "-- " .. name .. " v" .. new .. " ")
	local k = s:find("\nlocal ", 1, true)
	return s:sub(1, k) .. note(name, new, old, what) .. s:sub(k + 1)
end
local RET = "\treturn ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)\nend"
local RET2 = "\t\treturn ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)\n\tend\nend"
local MAYAFF = "mayAffect(source, target) is also false for a squadmate (wraps the ModeRules check), so no squadmate is ever picked, hit or slowed."
local function mayaff(s, name, old, new, anchor)
	s = header(s, name, old, new, MAYAFF)
	return rep(s, anchor, anchor .. "\n" .. helper(name, new) .. "do -- v" .. new .. ": wrap the mode check with the squad check\n\tlocal modeOnly = mayAffect\n\tmayAffect = function(source, target)\n\t\tif squadmate(source, target) then return false end\n\t\treturn modeOnly(source, target)\n\tend\nend")
end
local CREST = "\treturn crestMod or nil\nend\n"
local T = {}
T.InkServer = function(s)
	s = mayaff(s, "InkServer", "1.5", "1.6", RET)
	return rep(s, "local VERSION = \"1.5\"", "local VERSION = \"1.6\"")
end
T.TetherServer = function(s)
	s = mayaff(s, "TetherServer", "1.2", "1.3", RET)
	return rep(s, "local VERSION = \"1.2\"", "local VERSION = \"1.3\"")
end
T.MineServer = function(s)
	s = mayaff(s, "MineServer", "1.7", "1.8", RET2)
	return rep(s, "local VERSION = \"1.7\"", "local VERSION = \"1.8\"")
end
T.ScreechServer = function(s)
	s = mayaff(s, "ScreechServer", "1.10", "1.11", RET2)
	return rep(s, "local VERSION = \"1.10\"", "local VERSION = \"1.11\"")
end
T.HerreraMovesServer = function(s)
	s = mayaff(s, "HerreraMovesServer", "1.0", "1.1", RET)
	s = rep(s, "local VERSION = \"1.0\"", "local VERSION = \"1.1\"")
	return rep(s, "\t\t\tif target.Parent and isTarget(target, char) and not shielded(target, ta) then",
		"\t\t\tif target.Parent and isTarget(target, char) and mayAffect(char, target) and not shielded(target, ta) then -- v1.1: + mayAffect (squad / mode) on arrival")
end
T.BiteServer = function(s)
	s = header(s, "BiteServer", "1.9", "1.10", "a squadmate is skipped by the server sweep, dropped as the aimed target (request and fallback), refused as a\n--   client claim (BiteClaimResult \"squad\"), and applyHit does nothing to one (backstop).")
	s = rep(s, "script:SetAttribute(\"BiteServerVersion\", \"1.8\")", "script:SetAttribute(\"BiteServerVersion\", \"1.10\") -- v1.10 (1.9 left this at \"1.8\")")
	s = rep(s, CREST, CREST .. helper("BiteServer", "1.10"))
	s = rep(s, "\t\tlocal model = targetOf(part)\n\t\tif model then\n\t\t\tlocal d, cp = segmentHit(part, a, b)", "\t\tlocal model = targetOf(part)\n\t\tif model and not squadmate(char, model) then -- v1.10\n\t\t\tlocal d, cp = segmentHit(part, a, b)")
	s = rep(s, "\tif aim and aim.Parent and aim:IsDescendantOf(workspace) then", "\tif aim and aim.Parent and aim:IsDescendantOf(workspace) and not squadmate(char, aim) then -- v1.10")
	s = rep(s, "\t\treturn reject(\"badTarget\")\n\tend\n\tlocal onTarget = math.huge", "\t\treturn reject(\"badTarget\")\n\tend\n\tif squadmate(char, model) then return reject(\"squad\") end -- v1.10\n\tlocal onTarget = math.huge")
	s = rep(s, "aimTarget ~= char and aimTarget:IsDescendantOf(workspace)\n", "aimTarget ~= char and aimTarget:IsDescendantOf(workspace) and not squadmate(char, aimTarget) -- v1.10\n")
	return rep(s, "local function applyHit(char, model, point, source, part)\n", "local function applyHit(char, model, point, source, part)\n\tif squadmate(char, model) then return end -- v1.10: backstop\n")
end
T.PounceServer = function(s)
	s = header(s, "PounceServer", "1.12", "1.13", "a claim on a squadmate is refused (PounceClaimResult \"squad\") right after \"busy\", before the\n--   Dome Visor check, so nothing pins, latches, hurts or knocks back anyone.")
	s = rep(s, "script:SetAttribute(\"PounceServerVersion\", \"1.11\")", "script:SetAttribute(\"PounceServerVersion\", \"1.13\") -- v1.13 (1.12 left this at \"1.11\")")
	s = rep(s, CREST, CREST .. helper("PounceServer", "1.13"))
	return rep(s, "\t\telseif model:GetAttribute(\"PinnedAt\") ~= nil then -- v1.1: already pinned\n\t\t\tresult = \"busy\"\n", "\t\telseif model:GetAttribute(\"PinnedAt\") ~= nil then -- v1.1: already pinned\n\t\t\tresult = \"busy\"\n\t\telseif squadmate(char, model) then -- v1.13\n\t\t\tresult = \"squad\"\n")
end
T.SlashServer = function(s)
	s = header(s, "SlashServer", "1.5", "1.6", "a hit claim on a squadmate is refused (SlashHitResult \"squad\"), a dive target that is a\n--   squadmate counts as no target (SlashDiveCheck \"squad\"), and the glide-dive bleed burst skips squadmates.")
	s = rep(s, "local VERSION = \"1.5\"", "local VERSION = \"1.6\"")
	local TOK = "\tif model:GetAttribute(\"Species\") == nil and model:GetAttribute(\"IsBot\") ~= true then return false end\n\treturn true, hb\nend\n"
	s = rep(s, TOK, TOK .. helper("SlashServer", "1.6"))
	s = rep(s, "\t\telseif target == char then\n\t\t\tcheck = \"self\"\n", "\t\telseif target == char then\n\t\t\tcheck = \"self\"\n\t\telseif squadmate(char, target) then -- v1.6\n\t\t\tcheck = \"squad\"\n")
	s = rep(s, "\telseif model == char then\n\t\tresult = \"self\"\n\telseif st.active.hit[model] then", "\telseif model == char then\n\t\tresult = \"self\"\n\telseif squadmate(char, model) then -- v1.6\n\t\tresult = \"squad\"\n\telseif st.active.hit[model] then")
	return rep(s, "\t\t\t\tif m ~= char and m ~= model and targetOk(m) and m:GetAttribute(\"DummyState\") ~= \"ko\"\n", "\t\t\t\tif m ~= char and m ~= model and targetOk(m) and not squadmate(char, m) and m:GetAttribute(\"DummyState\") ~= \"ko\" -- v1.6: squad\n")
end
T.HeadbuttServer = function(s)
	s = header(s, "HeadbuttServer", "1.12", "1.13", "a hit claim on a squadmate is refused (HeadbuttHitResult \"squad\") before the Dome Visor\n--   check, so no damage, slow, shove or visor knockback between squadmates.")
	s = rep(s, "local VERSION = \"1.12\"", "local VERSION = \"1.13\"")
	s = rep(s, "-- target checks\nlocal function targetOk(model)", helper("HeadbuttServer", "1.13") .. "-- target checks\nlocal function targetOk(model)")
	return rep(s, "\telseif model == char then\n\t\tresult = \"self\"\n\telseif model:GetAttribute(\"DummyState\") == \"ko\" then\n\t\tresult = \"ko\"\n\telse\n\t\tlocal hp = headPos(char)", "\telseif model == char then\n\t\tresult = \"self\"\n\telseif squadmate(char, model) then -- v1.13\n\t\tresult = \"squad\"\n\telseif model:GetAttribute(\"DummyState\") == \"ko\" then\n\t\tresult = \"ko\"\n\telse\n\t\tlocal hp = headPos(char)")
end
T.HookServer = function(s)
	s = header(s, "HookServer", "1.7", "1.8", "candidates(self) leaves out squadmates (the hook flies past them to an enemy behind) and the\n--   smash re-check drops a squadmate (\"gone\").")
	s = rep(s, "local VERSION = \"1.7\"", "local VERSION = \"1.8\"")
	s = rep(s, "local function isTarget(m, self)", helper("HookServer", "1.8") .. "local function isTarget(m, self)")
	s = rep(s, "\t\tif c then local hb = isTarget(c, self) if hb then table.insert(list, {m = c, hb = hb}) end end", "\t\tif c and not squadmate(self, c) then local hb = isTarget(c, self) if hb then table.insert(list, {m = c, hb = hb}) end end -- v1.8: squad")
	return rep(s, "\tif not char.Parent or not target.Parent or not isTarget(target, char) then\n\t\tresult = \"gone\"", "\tif not char.Parent or not target.Parent or not isTarget(target, char) or squadmate(char, target) then -- v1.8: squad\n\t\tresult = \"gone\"")
end
T.RoarServer = function(s)
	s = header(s, "RoarServer", "1.1", "1.2", "the roar sweep skips a squadmate (no debuff). Nothing else in the sweep changes (its\n--   missing mode / menu gate stays as it is, plan do-not-touch). Diagnostic: script RoarServerVersion.")
	s = rep(s, "local function dinoOf(part)", helper("RoarServer", "1.2") .. "script:SetAttribute(\"RoarServerVersion\", \"1.2\") -- v1.2\nlocal function dinoOf(part)")
	return rep(s, "\t\t\t\tif model and model ~= char and not seen[model] and not hit[model] then", "\t\t\t\tif model and model ~= char and not seen[model] and not hit[model] and not squadmate(char, model) then -- v1.2: squad")
end
T.SkillEffects = function(s)
	s = header(s, "SkillEffects", "1.28", "1.29", "findBridgedPlayer never returns the attacker's squadmate, so skill bleeds / lifesteal\n--   follow-ups never land on one (backstop; the hit servers already refuse squadmates).")
	s = rep(s, "local VERSION = \"1.28\" -- v1.28 (1.27 left this at \"1.26\")", "local VERSION = \"1.29\" -- v1.28 (1.27 left this at \"1.26\"); v1.29 squads")
	s = rep(s, "local function findBridgedPlayer(name, attacker)", helper("SkillEffects", "1.29") .. "local function findBridgedPlayer(name, attacker)")
	return rep(s, "\t\tand m:GetAttribute(\"ArenaPvPBridged\") == true and m:GetAttribute(\"Bitable\") == true then\n\t\treturn m", "\t\tand m:GetAttribute(\"ArenaPvPBridged\") == true and m:GetAttribute(\"Bitable\") == true\n\t\tand not (attacker and squadmate(attacker, m)) then -- v1.29: squad\n\t\treturn m")
end
