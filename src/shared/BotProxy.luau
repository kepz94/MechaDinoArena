-- BotProxy v1.0 (Mecha Dino Arena) — a stand-in for `player` so a practice bot can fire the real ability code. MDA-410, plan
-- docs/plans/PRACTICE_MATCH_v1.0.md Task 6, ADR-010 (Kepu 2026-11-10: "Real abilities").
-- Lives in ServerStorage.DinoArcade.BotProxy (server only). Each ability server's BotUse BindableFunction calls its own remote
-- handler with BotProxy.of(model) in place of the Player.
-- What a proxy answers (everything else is nil, so code written for a real Player refuses or skips safely):
--   .Character    the bot model while it is in the game (nil once removed)   .Name  the model's name
--   .DisplayName  the model's DisplayName attribute, else its name           .UserId  0 (no player gets credit)
--   .Parent       the model's parent (truthy while it exists)                 .IsBotProxy  true
--   :GetAttribute / :SetAttribute / :GetAttributeChangedSignal  on the model (InMenu etc. read as nil)
--   :IsA(name)    true only for "BotProxy"                                     :FindFirstChild  nil
-- typeof(proxy) is "table", so checks like typeof(player) == "Instance" are false for a bot.
-- API: of(model) -> proxy (one per model, weak); is(x) -> bool; modelOf(x) -> the model or nil.
local BotProxy = {}
BotProxy.Version = "1.0"

local Proxy = {}
local methods = {}

function methods:GetAttribute(k) return self._model:GetAttribute(k) end
function methods:SetAttribute(k, v) self._model:SetAttribute(k, v) end
function methods:GetAttributeChangedSignal(k) return self._model:GetAttributeChangedSignal(k) end
function methods:IsA(name) return name == "BotProxy" end
function methods:FindFirstChild() return nil end
function methods:FindFirstChildOfClass() return nil end
function methods:GetFullName() return "BotProxy(" .. self._model:GetFullName() .. ")" end

Proxy.__index = function(self, k)
	local m = rawget(self, "_model")
	if k == "Character" then return (m and m.Parent) and m or nil end
	if k == "Name" then return m and m.Name or "" end
	if k == "DisplayName" then return m and (m:GetAttribute("DisplayName") or m.Name) or "" end
	if k == "UserId" then return 0 end
	if k == "Parent" then return m and m.Parent or nil end
	if k == "IsBotProxy" then return true end
	return methods[k]
end
Proxy.__tostring = function(self) return "BotProxy(" .. tostring(rawget(self, "_model")) .. ")" end

local cache = setmetatable({}, {__mode = "k"})

function BotProxy.of(model)
	if typeof(model) ~= "Instance" then return nil end
	local p = cache[model]
	if not p then
		p = setmetatable({_model = model}, Proxy)
		cache[model] = p
	end
	return p
end

function BotProxy.is(x)
	return type(x) == "table" and getmetatable(x) == Proxy
end

function BotProxy.modelOf(x)
	return BotProxy.is(x) and rawget(x, "_model") or nil
end

return BotProxy
