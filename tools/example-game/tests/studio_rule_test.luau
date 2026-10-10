--!nocheck
--[[
	studio_rule_test (generic guard): scripts must not CREATE visuals at runtime (Studio-first rule).
	  tools/lune run tools/example-game/tests/studio_rule_test.luau <place.rbxl>
	  STRICT=1    exit 1 if any script has MORE runtime-creation lines than its baseline (new violations)
	  BASELINE=1  (re)write the baseline from this place (do it once when adopting the rule on an old game)
	Baseline file: $RULE_BASELINE or <test dir>/data/studio_rule_baseline.json. Missing baseline = this run becomes it.
	Opt-outs (need a reason): trailing "-- studio-rule: allow (<reason>)" on a line, or "--!studio-rule: build-only".
	Allowlist (runtime-only by nature): Camera, Weld, WeldConstraint, Motor6D, BindableEvent, BindableFunction,
	GetTextBoundsParams, *Value objects.
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")

local PLACE = process.args[1]
assert(PLACE and fs.isFile(PLACE), "usage: studio_rule_test.luau <place.rbxl>")
local STRICT = process.env.STRICT == "1"
local BASEFILE = process.env.RULE_BASELINE or ((process.env.TESTS or "tools/example-game/tests") .. "/data/studio_rule_baseline.json")
local game = roblox.deserializePlace(fs.readFile(PLACE))

local function set(t) local s = {} for _, v in t do s[v] = true end return s end
local VISUAL = set({
	"ScreenGui", "BillboardGui", "SurfaceGui", "Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton",
	"ScrollingFrame", "ViewportFrame", "CanvasGroup", "UICorner", "UIStroke", "UIGradient", "UIPadding", "UIListLayout",
	"UIGridLayout", "UIScale", "UIAspectRatioConstraint", "UISizeConstraint", "UITextSizeConstraint",
	"Part", "MeshPart", "WedgePart", "TrussPart", "Model", "SpecialMesh", "PointLight", "SpotLight", "SurfaceLight",
	"ParticleEmitter", "Sparkles", "Fire", "Smoke", "Beam", "Trail", "Attachment", "Highlight", "SelectionBox", "Decal",
	"Texture", "Sound", "ColorCorrectionEffect", "BloomEffect", "BlurEffect", "Atmosphere", "Sky", "Tool",
	"Folder", "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent",
})
local PATTERNS = { "Instance%.new%(%s*[\"']([%w_]+)[\"']", "[^%w_.:]new%(%s*[\"']([%w_]+)[\"']" }

local function fullName(inst)
	local parts, cur = {}, inst
	while cur and cur ~= game do table.insert(parts, 1, cur.Name); cur = cur.Parent end
	return table.concat(parts, ".")
end

local counts, examples, total = {}, {}, 0
for _, s in game:GetDescendants() do
	if s:IsA("LuaSourceContainer") then
		local ok, src = pcall(function() return s.Source end)
		if ok and src and not src:find("--!studio-rule: build-only", 1, true) then
			local n, ln = 0, 0
			for line in (src .. "\n"):gmatch("([^\n]*)\n") do
				ln += 1
				local code = line:gsub("%-%-.*$", "")
				if not line:find("studio-rule: allow", 1, true) then
					for _, pat in PATTERNS do
						for cls in code:gmatch(pat) do
							if VISUAL[cls] then
								n += 1
								examples[fullName(s)] = examples[fullName(s)] or (("line %d: %s"):format(ln, line:gsub("^%s+", ""):sub(1, 90)))
							end
						end
					end
				end
			end
			if n > 0 then counts[fullName(s)] = n; total += n end
		end
	end
end

local baseline = nil
if fs.isFile(BASEFILE) and process.env.BASELINE ~= "1" then
	baseline = serde.decode("json", fs.readFile(BASEFILE))
else
	local dir = BASEFILE:match("^(.*)/[^/]+$")
	if dir and not fs.isDir(dir) then fs.writeDir(dir) end
	fs.writeFile(BASEFILE, serde.encode("json", counts, true))
	print("baseline written: " .. BASEFILE)
	baseline = counts
end

local worse = 0
local names = {}
for k in counts do table.insert(names, k) end
table.sort(names)
for _, k in names do
	local b = baseline[k] or 0
	if counts[k] > b then
		worse += 1
		print(("NEW  %s: %d runtime visual creation line(s) (baseline %d)  e.g. %s"):format(k, counts[k], b, examples[k]))
	end
end
print(("studio rule: %d script(s) create visuals at runtime (%d lines total), %d worse than baseline"):format(#names, total, worse))
if STRICT and worse > 0 then print("FAIL (STRICT)"); process.exit(1) end
print("PASS"); process.exit(0)
