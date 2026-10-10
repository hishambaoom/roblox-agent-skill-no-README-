--!nocheck
--[[
	text_size_test (generic, static): text the live engine will draw too small.
	  tools/lune run tools/example-game/tests/text_size_test.luau <place.rbxl>
	  MIN_PX=12 (default)  STRICT=1 -> exit 1 if MORE problems than the baseline
	Rules checked on every TextLabel/TextButton/TextBox under StarterGui and ReplicatedStorage.UITemplates:
	  A. TextScaled = true but TextWrapped = false  -> live engine draws it at TextSize (real bug: 8-14 px store text)
	  B. TextScaled = false and TextSize < MIN_PX
	  C. UITextSizeConstraint.MaxTextSize < MIN_PX
	This is a cheap static net; the reference project also had a layout-aware version (box fit per viewport).
	Baseline: $TEXT_BASELINE or tools/example-game/tests/data/text_size_baseline.json (first run writes it).
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")

local PLACE = process.args[1]
assert(PLACE and fs.isFile(PLACE), "usage: text_size_test.luau <place.rbxl>")
local MIN = tonumber(process.env.MIN_PX or "12")
local STRICT = process.env.STRICT == "1"
local BASEFILE = process.env.TEXT_BASELINE or ((process.env.TESTS or "tools/example-game/tests") .. "/data/text_size_baseline.json")
local game = roblox.deserializePlace(fs.readFile(PLACE))

local function fullName(inst)
	local parts, cur = {}, inst
	while cur and cur ~= game do table.insert(parts, 1, cur.Name); cur = cur.Parent end
	return table.concat(parts, ".")
end

local problems = {}
local roots = { game:GetService("StarterGui") }
local uiT = game:GetService("ReplicatedStorage"):FindFirstChild("UITemplates")
if uiT then table.insert(roots, uiT) end
for _, root in roots do
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" then
			local key = fullName(d)
			if d.TextScaled and not d.TextWrapped then
				problems[key] = "A TextScaled without TextWrapped (draws at TextSize " .. d.TextSize .. ")"
			elseif not d.TextScaled and d.TextSize < MIN then
				problems[key] = ("B TextSize %d < %d"):format(d.TextSize, MIN)
			end
			local c = d:FindFirstChildWhichIsA("UITextSizeConstraint")
			if c and c.MaxTextSize < MIN then problems[key] = ("C MaxTextSize %d < %d"):format(c.MaxTextSize, MIN) end
		end
	end
end

local n = 0
for _ in problems do n += 1 end
local baseline
if fs.isFile(BASEFILE) and process.env.BASELINE ~= "1" then
	baseline = serde.decode("json", fs.readFile(BASEFILE))
else
	local dir = BASEFILE:match("^(.*)/[^/]+$")
	if dir and not fs.isDir(dir) then fs.writeDir(dir) end
	fs.writeFile(BASEFILE, serde.encode("json", problems, true))
	print("baseline written: " .. BASEFILE)
	baseline = problems
end
local new = 0
local keys = {}
for k in problems do table.insert(keys, k) end
table.sort(keys)
for _, k in keys do
	if baseline[k] == nil then new += 1; print("NEW  " .. k .. ": " .. problems[k]) end
end
print(("text size: %d label(s) at risk (min %d px), %d new vs baseline"):format(n, MIN, new))
if STRICT and new > 0 then print("FAIL (STRICT)"); process.exit(1) end
print("PASS"); process.exit(0)
