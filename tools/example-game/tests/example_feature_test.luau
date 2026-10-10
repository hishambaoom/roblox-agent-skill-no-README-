--!nocheck
--[[
	example_feature_test: proves build_example_ui did its job. It must FAIL on the base place and PASS on the build.
	  tools/lune run tools/example-game/tests/example_feature_test.luau <place.rbxl>
	Checks the three things every feature test checks:
	  0. baked into the place (template exists, attributes seeded)       -> Studio-first
	  1. behaviour (here: a runtime-style clone + fill works without creating instances)
	  2. the tunable is live (changing the attribute changes the result)
]]
local process = require("@lune/process")
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local PLACE = process.args[1]
assert(PLACE and fs.isFile(PLACE), "usage: example_feature_test.luau <place.rbxl>")
local game = roblox.deserializePlace(fs.readFile(PLACE))
local failures = 0
local function check(cond, msg) if cond then print("  ok   " .. msg) else failures += 1; print("  FAIL " .. msg) end; return cond end

local RS = game:GetService("ReplicatedStorage")
print("== 0. baked into the place")
local cfg = RS:FindFirstChild("Config")
local gs = cfg and cfg:FindFirstChild("GameSettings")
check(gs ~= nil and gs.ClassName == "Configuration", "ReplicatedStorage.Config.GameSettings is a Configuration")
check(gs and gs:GetAttribute("ExampleToastEnabled") == true, "GameSettings@ExampleToastEnabled = true")
local uiT = RS:FindFirstChild("UITemplates")
local tpl = uiT and uiT:FindFirstChild("ExampleToast")
if not check(tpl ~= nil, "UITemplates.ExampleToast exists") then
	print(("FAIL %d"):format(failures)); process.exit(1)
end
check(tpl.Visible == false, "template is hidden (only clones show)")
check(typeof(tpl:GetAttribute("Duration")) == "number", "@Duration is a number (seconds)")
check(typeof(tpl:GetAttribute("MaxChars")) == "number", "@MaxChars is a number")

print("== 1. behaviour: clone + fill, like runtime code would")
local function show(text)
	local c = tpl:Clone()
	local label = c:FindFirstChildWhichIsA("TextLabel", true)
	local max = tpl:GetAttribute("MaxChars")
	if #text > max then text = string.sub(text, 1, max - 3) .. "..." end
	if label then label.Text = text end
	c.Visible = true
	return c, label
end
local c, label = show("Bag full (10/10)")
check(c.Visible and c ~= tpl, "clone is visible, template untouched")
check(label == nil or label.Text == "Bag full (10/10)", "text filled")
for _, d in tpl:GetDescendants() do
	if d:IsA("TextLabel") and d.TextScaled then
		check(d.TextWrapped, "TextScaled label " .. d.Name .. " has TextWrapped (else live engine draws it at TextSize)")
	end
end

print("== 2. tunable is live")
tpl:SetAttribute("MaxChars", 10)
local _, l2 = show("A very long announcement text")
check(l2 == nil or #l2.Text <= 10, "MaxChars=10 cuts the text (" .. tostring(l2 and l2.Text) .. ")")

print(failures == 0 and "PASS" or ("FAIL " .. failures))
process.exit(failures == 0 and 0 or 1)
