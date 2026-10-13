--!nocheck
--[[
  build_reference.luau — writes StuddedUI_Reference.rbxmx, a small, self-contained example of the studded UI style
  (ForgeTax / Pumpkin King look) as REAL instances you can insert into Studio and edit by hand.

  Run (Lune 0.10.x):
      tools/lune10 run assets/ui/reference/build_reference.luau
      STUDS_ID=1234567890 tools/lune10 run assets/ui/reference/build_reference.luau     -- bake your own studs texture
      OUT=path/to/file.rbxmx tools/lune10 run assets/ui/reference/build_reference.luau

  Instance.new is fine HERE: this is a build-time generator whose output is saved as a model file. Runtime game scripts
  never create visuals (docs/STUDDED_UI_GUIDE.md §1). Every number below is the value used in the shipped game; the guide
  explains each one. Change the recipe here, re-run, re-insert — or just edit the inserted copy in Studio.
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance, Color3, UDim2, UDim, Vector2 = roblox.Instance, roblox.Color3, roblox.UDim2, roblox.UDim, roblox.Vector2
local Enum = roblox.Enum

local HERE = "assets/ui/reference/"
local OUT = process.env.OUT or (HERE .. "StuddedUI_Reference.rbxmx")
local STUDS_ID = process.env.STUDS_ID or "0" -- upload assets/ui/reference/studs_tile.png (or your own) and pass its id
local STUDS = "rbxassetid://" .. STUDS_ID

local function hex(s) return Color3.fromRGB(tonumber(s:sub(2, 3), 16), tonumber(s:sub(4, 5), 16), tonumber(s:sub(6, 7), 16)) end
local FREDOKA = roblox.Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

---------------------------------------------------------------- palette (exact values from the shipped game)
local THEMES = {
	green  = { top = "#82FF46", bottom = "#28BE1E", stroke = "#0E500A" }, -- buy / confirm / cash / green headers
	blue   = { top = "#50B4FF", bottom = "#1E64E6", stroke = "#0A286E" }, -- tabs / info / blue headers
	orange = { top = "#FFAA3C", bottom = "#EB640A", stroke = "#642800" }, -- main action / upgrades
	purple = { top = "#C86EFF", bottom = "#8228E6", stroke = "#320A64" }, -- rebirth / premium / collect
	gold   = { top = "#FFE150", bottom = "#EBA000", stroke = "#6E3C00" }, -- sell / option buttons
	red    = { top = "#FF4646", bottom = "#BE0F0F", stroke = "#460000" }, -- close X / exit / danger
	brown  = { top = "#AA7846", bottom = "#6E4623", stroke = "#0A286E" }, -- bag / settings side button
}
local DARK = {
	panel = "#2B2D34", panelStroke = "#0E0E12", -- panel body, 4 px stroke
	card = "#3C3F48", cardStroke = "#16161C",   -- cards / tooltip, 2.5–3 px stroke
	slot = "#1C1D22", slotStroke = "#464850",   -- 3D stages, empty slots
	track = "#191A1E",                          -- progress bar track
	textStroke = "#14141A",                     -- outline of white text on dark surfaces
}

---------------------------------------------------------------- helpers (each one = one rule in the guide)
local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props do i[k] = v end
	if parent then i.Parent = parent end
	return i
end
local function corner(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p) end
local function stroke(p, th, col)
	return new("UIStroke", { Thickness = th, Color = hex(col), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, p)
end
local function grad(p, top, bottom, name)
	return new("UIGradient", {
		Name = name or "UIGradient", Rotation = 90,
		Color = roblox.ColorSequence.new({ roblox.ColorSequenceKeypoint.new(0, hex(top)), roblox.ColorSequenceKeypoint.new(1, hex(bottom)) }),
	}, p)
end
local function shade(p) return grad(p, "#FFFFFF", "#9696A0", "Shade") end -- darkens the bottom of every dark surface
local function studs(p, z, transp, small, r)
	-- CanvasGroup clips the tiled texture to the rounded corner; the tile sits ON TOP of the gradient/background.
	local cg = new("CanvasGroup", {
		Name = "Studs", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z, GroupTransparency = 0,
	}, p)
	corner(cg, r)
	local img = new("ImageLabel", {
		Name = "STUDS", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z,
		ScaleType = Enum.ScaleType.Tile, TileSize = small and UDim2.fromOffset(28, 21) or UDim2.fromOffset(42, 32),
		ImageTransparency = transp,
	}, cg)
	local ok = pcall(function() img.ImageContent = roblox.Content.fromUri(STUDS) end) -- Lune 0.10: Content property
	if not ok then img.Image = STUDS end
	return cg
end
local function label(p, name, text, props)
	-- THE text rule: TextScaled + TextWrapped + UITextSizeConstraint(Min 12) + Contextual UIStroke. Never TextStroke.
	local l = new("TextLabel", {
		Name = name, Text = text, BackgroundTransparency = 1, BorderSizePixel = 0, FontFace = FREDOKA,
		TextColor3 = hex(props.color or "#FFFFFF"), TextSize = 8, TextScaled = true, TextWrapped = true,
		Size = props.size, Position = props.pos or UDim2.fromScale(0.5, 0.5), AnchorPoint = props.ap or Vector2.new(0.5, 0.5),
		ZIndex = props.z or 5, TextXAlignment = props.xalign or Enum.TextXAlignment.Center,
	}, p)
	new("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = props.max or 24 }, l)
	stroke(l, props.th or 2.5, props.stroke or DARK.textStroke)
	return l
end
local function button(p, name, theme, text, size, pos, ap, z, opts)
	opts = opts or {}
	local t = THEMES[theme]
	local b = new("ImageButton", {
		Name = name, Size = size, Position = pos, AnchorPoint = ap or Vector2.new(0.5, 0.5), ZIndex = z,
		BackgroundColor3 = hex("#FFFFFF"), BackgroundTransparency = 0, BorderSizePixel = 0, -- white bg = gradient shows true colours
		ImageTransparency = 1, ScaleType = Enum.ScaleType.Stretch, AutoButtonColor = false,
	}, p)
	b:SetAttribute("Theme", theme)
	corner(b)
	grad(b, t.top, t.bottom)
	stroke(b, 3, t.stroke)
	studs(b, z, 0.5, opts.small)
	new("UIScale", { Name = "Press", Scale = 1 }, b) -- client tweens this: hover 1.04, down 0.88, up Back-pop to 1
	local maxText = opts.max or math.max(14, math.floor(size.Y.Offset * 0.6))
	label(b, "Label", text, { size = UDim2.fromScale(0.86, 0.72), z = z + 2, max = maxText, stroke = t.stroke, th = opts.labelTh or 2.5 })
	local dim = new("Frame", {
		Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = hex("#000000"), BackgroundTransparency = 0.5,
		BorderSizePixel = 0, ZIndex = z + 3, Visible = false,
	}, b) -- disabled / not-selected state: client toggles Visible only
	corner(dim)
	if opts.shine then
		local sh = new("Frame", { Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = hex("#FFFFFF"),
			BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = z + 1 }, b)
		corner(sh)
		new("UIGradient", {
			Name = "ShineGradient", Rotation = 20, Offset = Vector2.new(-1, 0),
			Transparency = roblox.NumberSequence.new({
				roblox.NumberSequenceKeypoint.new(0, 1), roblox.NumberSequenceKeypoint.new(0.42, 1),
				roblox.NumberSequenceKeypoint.new(0.5, 0.45), roblox.NumberSequenceKeypoint.new(0.58, 1),
				roblox.NumberSequenceKeypoint.new(1, 1),
			}),
		}, sh) -- client sweeps Offset -1 -> 1 every ScreenGui@ShineEvery seconds
	end
	return b
end
local function deviceScale(p, touch)
	local s = new("UIScale", { Name = "DeviceScale", Scale = 1 }, p)
	s:SetAttribute("MinScale", 1); s:SetAttribute("MaxScale", 1.2); s:SetAttribute("PcFactor", 1); s:SetAttribute("TouchFactor", touch or 0.8)
	return s
end
local function darkFrame(p, name, col, strokeCol, th, size, pos, ap, z, smallStuds)
	local f = new("Frame", { Name = name, Size = size, Position = pos, AnchorPoint = ap or Vector2.new(0, 0),
		BackgroundColor3 = hex(col), BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = z }, p)
	corner(f); stroke(f, th, strokeCol); studs(f, z, 0.6, smallStuds); shade(f)
	return f
end

---------------------------------------------------------------- the ScreenGui
local gui = new("ScreenGui", { Name = "StuddedUI_Reference", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
gui:SetAttribute("ShineEvery", 2.5)
gui:SetAttribute("Note", "Reference kit (docs/STUDDED_UI_GUIDE.md). Insert into StarterGui, press Play, click SHOP. Clone pieces from here; never rebuild them in code.")

-- Palette as editable attributes (scripts that switch colours by state read these, never Lua constants)
local pal = new("Configuration", { Name = "Palette" }, gui)
for name, t in THEMES do
	pal:SetAttribute(name .. "Top", hex(t.top)); pal:SetAttribute(name .. "Bottom", hex(t.bottom)); pal:SetAttribute(name .. "Stroke", hex(t.stroke))
end
for k, v in DARK do pal:SetAttribute(k, hex(v)) end
for k, v in { Common = "#B4B4B4", Uncommon = "#50DC50", Rare = "#3C8CFF", Epic = "#AA46FF", Legendary = "#FFBE1E", Mythic = "#FF3C78" } do
	pal:SetAttribute("Rarity" .. k, hex(v))
end

---------------------------------------------------------------- side button column (60x60 square menu buttons)
local side = new("Frame", { Name = "RightButtons", Size = UDim2.fromOffset(60, 126), Position = UDim2.new(1, -6, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1 }, gui)
side:SetAttribute("PhonePosition", UDim2.new(1, -4, 0.4, 0))
deviceScale(side, 0.8)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = Enum.FillDirection.Vertical }, side)
local function sideButton(name, theme, text, panel, order)
	local b = button(side, name, theme, text, UDim2.fromOffset(60, 60), UDim2.new(), Vector2.new(0, 0), 3, { max = 18 })
	b.LayoutOrder = order
	b:SetAttribute("Panel", panel)
	b.Label.Size = UDim2.fromScale(0.96, 0.3); b.Label.Position = UDim2.fromScale(0.5, 0.8) -- name along the bottom
	local icon = new("ImageLabel", { Name = "Icon", Size = UDim2.fromScale(0.58, 0.5), Position = UDim2.fromScale(0.5, 0.33),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 5 }, b)
	icon:SetAttribute("Note", "Put your icon image here (ScaleType Fit).")
	local badge = new("Frame", { Name = "Badge", Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(-4, -4),
		BackgroundColor3 = hex("#BE0F0F"), BorderSizePixel = 0, ZIndex = 7, Visible = false }, b)
	corner(badge); stroke(badge, 2.5, "#FFFFFF"); studs(badge, 7, 0.6, true); shade(badge)
	label(badge, "Label", "!", { size = UDim2.fromScale(0.8, 0.8), z = 8, max = 16, th = 2 })
	return b
end
sideButton("ShopButton", "orange", "Shop", "ExamplePanel", 1)
sideButton("BagButton", "brown", "Bag", "ExamplePanel", 2)

---------------------------------------------------------------- panel: dark studded body + coloured header + red X
local panel = darkFrame(gui, "ExamplePanel", DARK.panel, DARK.panelStroke, 4, UDim2.fromOffset(520, 340),
	UDim2.fromScale(0.5, 0.52), Vector2.new(0.5, 0.5), 2)
panel.Visible = false
panel:SetAttribute("PhoneSize", UDim2.fromOffset(520, 300))
panel:SetAttribute("PhonePosition", UDim2.new(0.5, 0, 0.5, 12))
panel:SetAttribute("Note", "Panel recipe: dark body #2B2D34 + 4px #0E0E12 stroke + studs t0.6 + Shade; Top header overhangs 3px each side and 6px above.")
deviceScale(panel, 0.8)

local top = new("Frame", { Name = "Top", Size = UDim2.new(1, 6, 0, 44), Position = UDim2.new(0.5, 0, 0, -6), AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = hex("#FFFFFF"), BorderSizePixel = 0, ZIndex = 6 }, panel)
corner(top); grad(top, THEMES.green.top, THEMES.green.bottom); stroke(top, 4, THEMES.green.stroke); studs(top, 6, 0.5)
label(top, "Title", "Shop", { size = UDim2.new(0.5, 0, 0.8, 0), pos = UDim2.new(0, 14, 0.5, 0), ap = Vector2.new(0, 0.5), z = 8, max = 34, th = 3,
	xalign = Enum.TextXAlignment.Left })
button(top, "Close", "red", "X", UDim2.fromOffset(44, 36), UDim2.new(1, -6, 0.5, 0), Vector2.new(1, 0.5), 8, { small = true, max = 28 })

local body = new("Frame", { Name = "Body", Size = UDim2.new(1, -20, 1, -54), Position = UDim2.new(0.5, 0, 0, 44), AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1, ZIndex = 3 }, panel)

-- tabs: blue buttons, the active one has Dim hidden, the others Dim visible
local tabs = new("Frame", { Name = "Tabs", Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, ZIndex = 3 }, body)
new("UIListLayout", { Padding = UDim.new(0, 10), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, tabs)
for i, n in { "Items", "Boosts" } do
	local t = button(tabs, n .. "Tab", "blue", string.upper(n), UDim2.fromOffset(150, 34), UDim2.new(), Vector2.new(0, 0), 5, { max = 26 })
	t.LayoutOrder = i; t:SetAttribute("Tab", n); t.Dim.Visible = i ~= 1
end
body:SetAttribute("Tab", "Items")

-- card: lighter dark surface, coloured head strip, dark stage, buy button pinned to the bottom
local card = darkFrame(body, "ItemCard", DARK.card, DARK.cardStroke, 2.5, UDim2.new(0, 230, 1, -44), UDim2.fromOffset(0, 44), nil, 3)
local head = new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = hex("#FFFFFF"), BorderSizePixel = 0, ZIndex = 4 }, card)
corner(head); grad(head, THEMES.orange.top, THEMES.orange.bottom); stroke(head, 2.5, THEMES.orange.stroke); studs(head, 4, 0.5)
label(head, "Title", "IRON HAMMER", { size = UDim2.new(1, -12, 0.78, 0), z = 6, max = 26, stroke = THEMES.orange.stroke })
local stage = darkFrame(card, "Stage", DARK.slot, DARK.slotStroke, 2.5, UDim2.new(1, -20, 0, 92), UDim2.new(0.5, 0, 0, 46), Vector2.new(0.5, 0), 4)
stage:SetAttribute("Note", "Put a ViewportFrame or ImageLabel here (3D previews: docs/viewport-previews.md).")
label(card, "Line1", "Shatter -5%", { size = UDim2.new(1, -12, 0, 24), pos = UDim2.new(0.5, 0, 0, 144), ap = Vector2.new(0.5, 0), max = 22, th = 2 })
label(card, "Price", "$500", { size = UDim2.new(1, -12, 0, 26), pos = UDim2.new(0.5, 0, 0, 168), ap = Vector2.new(0.5, 0), max = 24, color = "#FFE150" })
button(card, "Buy", "green", "BUY", UDim2.new(1, -20, 0, 44), UDim2.new(0.5, 0, 1, -8), Vector2.new(0.5, 1), 4, { shine = true, max = 28, labelTh = 3 })

-- info column + primary / secondary buttons
label(body, "Info", "Primary = big action (orange/green/purple). Secondary = gold. Danger = red.",
	{ size = UDim2.new(0, 246, 0, 60), pos = UDim2.fromOffset(244, 52), ap = Vector2.new(0, 0), max = 18, th = 2, color = "#C8C8D2" })
button(body, "Secondary", "gold", "SELL", UDim2.fromOffset(246, 44), UDim2.new(0, 244, 1, -64), Vector2.new(0, 1), 4, { max = 26 })
button(body, "Primary", "purple", "UPGRADE", UDim2.fromOffset(246, 54), UDim2.new(0, 244, 1, -6), Vector2.new(0, 1), 4, { shine = true, max = 32, labelTh = 3 })

---------------------------------------------------------------- toasts container + templates
local toasts = new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(270, 64), Position = UDim2.new(0.5, 0, 1, -190), AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1, ZIndex = 20 }, gui)
deviceScale(toasts, 0.8)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }, toasts)
for k, v in { White = "#FFFFFF", Green = "#82FF46", Red = "#FF4646", Gold = "#FFE150", Blue = "#50B4FF", Purple = "#C86EFF", Orange = "#FFAA3C" } do
	toasts:SetAttribute(k, hex(v))
end
toasts:SetAttribute("MaxToasts", 2); toasts:SetAttribute("Seconds", 1.5); toasts:SetAttribute("RepeatIgnoreSeconds", 2)
toasts:SetAttribute("PhonePosition", UDim2.new(0.5, 0, 1, -128))

local templates = new("Folder", { Name = "Templates" }, gui)
local toast = darkFrame(templates, "Toast", DARK.panel, THEMES.green.bottom, 3, UDim2.fromOffset(270, 30), UDim2.new(), nil, 20, true)
toast.Visible = false
new("UIScale", { Name = "Pop", Scale = 1 }, toast)
label(toast, "Label", "Message", { size = UDim2.new(1, -14, 0.84, 0), z = 22, max = 16 })

local tip = darkFrame(gui, "Tooltip", DARK.card, DARK.cardStroke, 3, UDim2.fromOffset(184, 74), UDim2.new(), nil, 40)
tip.Visible = false
tip:SetAttribute("Note", "Tooltip: PC follows the mouse on hover, phone shows next to the tapped card; clamp inside the screen.")
deviceScale(tip, 0.8)
label(tip, "NameLabel", "Galaxy", { size = UDim2.new(1, -10, 0, 20), pos = UDim2.new(0.5, 0, 0, 6), ap = Vector2.new(0.5, 0), z = 43, max = 18 })
label(tip, "RarityLabel", "+12 Epic", { size = UDim2.new(1, -10, 0, 16), pos = UDim2.new(0.5, 0, 0, 28), ap = Vector2.new(0.5, 0), z = 43, max = 14, th = 2, color = "#AA46FF" })
label(tip, "ValueLabel", "Sell $25K", { size = UDim2.new(1, -10, 0, 18), pos = UDim2.new(0.5, 0, 0, 48), ap = Vector2.new(0.5, 0), z = 43, max = 16, th = 2, color = "#FFD646" })

---------------------------------------------------------------- reference client (no Instance.new; only tween/show/fill)
local clientSrc = fs.readFile(HERE .. "StuddedUIClient.luau")
local ls = new("LocalScript", { Name = "StuddedUIClient" }, gui)
ls.Source = clientSrc
ls:SetAttribute("HoverScale", 1.04)

fs.writeFile(OUT, roblox.serializeModel({ gui }, true))
print("wrote " .. OUT .. " (studs " .. STUDS .. ")")
