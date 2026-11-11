-- FontSwapRules v1.0 (Mecha Dino Arena) — which text turns Silkscreen (ModuleScript, StarterPlayerScripts, next to FontSwap;
-- plan docs/plans/FONT_SILKSCREEN_v1.0.md Task 1, MDA-449; Kepu 2026-11-11 "Let's use SilkScreen font" -> "B · Titles,
-- buttons, numbers", "Shrink to fit"; mockup docs/mockups/font_silkscreen_v0.1.html). Pure: no instances, no services.
--   plainLength(text)  visible characters (rich-text tags removed, the 5 escapes counted as one character)
--   classify(info)     "silk" / "keep". info = {font (Enum.Font name), text, wrapped, scaled, isBox, override}
--                      keep: a TextBox; override "keep"; a font not in LOUD; wrapped; more than MAX_CHARS characters.
--                      silk: override "silk"; a LOUD font that is TextScaled; a LOUD font, one line, <= MAX_CHARS.
--   fitSize(size, factor)  round(size x factor), factor clamped FIT_MIN..1 (nil -> FIT_DEFAULT); never below MIN_SIZE unless
--                      the size already was.
local R = {}
R.VERSION = "1.0"
R.MAX_CHARS = 24
R.MIN_SIZE = 8
R.FIT_MIN = 0.7
R.FIT_DEFAULT = 0.88
R.LOUD = {FredokaOne = true, GothamBlack = true, GothamBold = true, SourceSansBold = true}

function R.plainLength(text)
	local s = tostring(text or "")
	s = s:gsub("<[^>]->", "")
	s = s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", "\""):gsub("&apos;", "'"):gsub("&amp;", "&")
	return utf8.len(s) or #s
end

function R.classify(info)
	if type(info) ~= "table" then return "keep" end
	if info.isBox then return "keep" end
	if info.override == "keep" then return "keep" end
	if info.override == "silk" then return "silk" end
	if not R.LOUD[tostring(info.font or "")] then return "keep" end
	if info.scaled then return "silk" end
	if info.wrapped then return "keep" end
	if R.plainLength(info.text) > R.MAX_CHARS then return "keep" end
	return "silk"
end

function R.fitSize(size, factor)
	size = tonumber(size) or 14
	local f = tonumber(factor) or R.FIT_DEFAULT
	f = math.clamp(f, R.FIT_MIN, 1)
	return math.max(math.min(size, R.MIN_SIZE), math.floor(size * f + 0.5))
end

return R
