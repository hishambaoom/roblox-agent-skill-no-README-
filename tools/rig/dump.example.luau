--!nocheck
-- RIG dump (tools/rig/dump.example.luau): ONE layout dump, merged from v17mig/HL + IV screens_dump (shims + layout from text_size_v17x_test).
-- usage: tools/lune run tools/rig/dump.example.luau <place> <outdir> <W> <H> [touch] [lair] [open=<MenuName>]
-- writes <outdir>/<W>x<H>.json : every visible GuiObject of every enabled ScreenGui, rbxsim geometry + baked look. NOT Studio.
local process = require("@lune/process"); local roblox = require("@lune/roblox"); local fs = require("@lune/fs"); local serde = require("@lune/serde")
local Sim = require("../example-game/tests/rbxsim")
local Vector2, Vector3 = roblox.Vector2, roblox.Vector3
local RCS, RCSK, RFont = roblox.ColorSequence, roblox.ColorSequenceKeypoint, roblox.Font
local FixedCS = setmetatable({
	new = function(a, b, ...)
		if typeof(a) == "Color3" and typeof(b) == "Color3" then return RCS.new({ RCSK.new(0, a), RCSK.new(1, b) }) end
		if typeof(a) == "Color3" and b == nil then return RCS.new({ RCSK.new(0, a), RCSK.new(1, a) }) end
		return RCS.new(a, b, ...)
	end,
}, { __index = RCS })
local origEnv = Sim.Env
function Sim:Env(sp)
	local env = origEnv(self, sp)
	rawset(env, "ColorSequence", FixedCS)
	return env
end
local origProxy = Sim._makeProxy
function Sim:_makeProxy(inst)
	local proxy = origProxy(self, inst)
	local mt = getmetatable(proxy)
	if type(mt) == "table" and not mt.__xtxtfont then
		local ni = mt.__newindex
		mt.__newindex = function(p, k, v)
			if k == "Font" and typeof(v) == "EnumItem" then
				local ok, f = pcall(RFont.fromEnum, v)
				if ok then return ni(p, "FontFace", f) end
			end
			return ni(p, k, v)
		end
		mt.__xtxtfont = true
	end
	return proxy
end

---------------------------------------------------------------------------------------------- text model
local function isEmojiCp(cp)
	return (cp >= 0x1F000 and cp <= 0x1FAFF) or (cp >= 0x2600 and cp <= 0x27BF) or (cp >= 0x2300 and cp <= 0x23FF)
		or (cp >= 0x2B00 and cp <= 0x2BFF) or cp == 0xFE0F
end
-- returns glyph count (non-space), has-emoji, emoji-only
local function scanText(t)
	local n, emoji, other = 0, false, 0
	local ok = pcall(function()
		for _, cp in utf8.codes(t) do
			n += 1
			if isEmojiCp(cp) then emoji = true
			elseif cp ~= 32 and cp ~= 0xE002 then other += 1 end
		end
	end)
	if not ok then n = #t; other = #t end
	return n, emoji, other == 0
end

local function fit(n, w, h, wrap)
	if n <= 0 or w <= 0 or h <= 0 then return 0 end
	local best = math.min(h, w / (0.6 * n))
	if wrap then
		for k = 2, 4 do
			best = math.max(best, math.min(h / (1.15 * k), w * k / (0.6 * n)))
		end
	end
	return best
end

---------------------------------------------------------------------------------------------- layout pass
local function padOf(inst, w, h)
	local p = inst:FindFirstChildOfClass("UIPadding")
	if not p then return 0, 0, 0, 0 end
	return p.PaddingLeft.Scale * w + p.PaddingLeft.Offset, p.PaddingRight.Scale * w + p.PaddingRight.Offset,
		p.PaddingTop.Scale * h + p.PaddingTop.Offset, p.PaddingBottom.Scale * h + p.PaddingBottom.Offset
end

local function childBox(inst, pw, ph, parent)
	local grid = parent and parent:FindFirstChildOfClass("UIGridLayout")
	local s = inst.Size
	if grid then s = grid.CellSize end
	local w = s.X.Scale * pw + s.X.Offset
	local h = s.Y.Scale * ph + s.Y.Offset
	local okc, sc = pcall(function() return inst.SizeConstraint end)
	if okc and sc then
		local name = tostring(sc)
		if name:find("RelativeXX") then h = s.Y.Scale * pw + s.Y.Offset
		elseif name:find("RelativeYY") then w = s.X.Scale * ph + s.X.Offset end
	end
	local ar = inst:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ar and ar.AspectRatio > 0 then
		local r = ar.AspectRatio
		if w / math.max(h, 1e-6) > r then w = h * r else h = w / r end
	end
	local szc = inst:FindFirstChildOfClass("UISizeConstraint")
	if szc then
		w = math.clamp(w, szc.MinSize.X, math.max(szc.MinSize.X, szc.MaxSize.X))
		h = math.clamp(h, szc.MinSize.Y, math.max(szc.MinSize.Y, szc.MaxSize.Y))
	end
	return math.max(w, 0), math.max(h, 0)
end

local function strokeOf(inst)
	local best = nil
	for _, c in inst:GetChildren() do
		if c:IsA("UIStroke") and tostring(c.ApplyStrokeMode):find("Contextual") and c.Enabled and c.Transparency < 0.9 then
			if not best or c.Thickness > best then best = c.Thickness end
		end
	end
	return best
end


---------------------------------------------------------------------------------------------- args
local PLACE, OUTDIR = process.args[1], process.args[2]
local W, H = tonumber(process.args[3]), tonumber(process.args[4])
assert(PLACE and OUTDIR and W and H, "usage: dump.luau <place> <outdir> <W> <H> [touch] [lair] [open=<MenuName>]")
local TOUCH, LAIR, OPEN = false, false, nil
for i = 5, #process.args do
	local a = process.args[i]
	if a == "touch" then TOUCH = true elseif a == "lair" then LAIR = true
	elseif a:sub(1, 5) == "open=" then OPEN = a:sub(6) elseif a ~= "" then error("dump.luau: unknown arg " .. a) end
end
local INSET = 58

local function scaleOf(inst) local s = inst:FindFirstChildOfClass("UIScale"); return s and s.Scale or 1 end
local function sortKids(kids, layout)
	local byName = layout and tostring(layout.SortOrder):find("Name")
	table.sort(kids, function(a, b)
		if not byName and a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
		return a.Name < b.Name
	end)
	return kids
end
local function alignOff(al, free) local n = tostring(al)
	if n:find("Center") then return free / 2 elseif n:find("Right") or n:find("Bottom") then return free end return 0 end
local function cornerPx(inst, w, h, S)
	local c = inst:FindFirstChildOfClass("UICorner"); if not c then return nil end
	return math.min(c.CornerRadius.Scale * math.min(w, h) + c.CornerRadius.Offset * S, math.min(w, h) / 2)
end

-- full layout: visit(inst, path, x, y, w, h, S, clip, scroll, key)
--   clip = {x0,y0,x1,y1[,r]} of ClipsDescendants / CanvasGroup ancestors (r = rounded clip of the innermost one)
--   scroll = rect of the enclosing ScrollingFrame; key = draw-order key (DisplayOrder, then ZIndex/child index per level; all ScreenGuis are Sibling)
local function layoutAll(root, rx, ry, rw, rh, prefix, visit)
	local function rec(inst, path, x, y, w, h, S, clip, scroll, key)
		visit(inst, path, x, y, w, h, S, clip, scroll, key)
		local l, r, t, b = padOf(inst, w / S, h / S)
		l, r, t, b = l * S, r * S, t * S, b * S
		local cx, cy, cw, ch = x + l, y + t, w - l - r, h - t - b
		local nclip, nscroll = clip, scroll
		if inst:IsA("ScrollingFrame") then
			local cs = inst.CanvasSize
			local canvasH = cs.Y.Scale * h + cs.Y.Offset * S
			if canvasH > h then ch = canvasH - t - b end
			nscroll = { x, y, x + w, y + h }
		elseif inst:IsA("GuiObject") and (inst.ClipsDescendants or inst:IsA("CanvasGroup")) then
			nclip = { math.max(clip[1], x), math.max(clip[2], y), math.min(clip[3], x + w), math.min(clip[4], y + h), cornerPx(inst, w, h, S) }
		end
		local list = inst:FindFirstChildOfClass("UIListLayout")
		local grid = inst:FindFirstChildOfClass("UIGridLayout")
		local allKids = inst:GetChildren()
		local kids = {}
		for _, c in allKids do if c:IsA("GuiObject") and c.Visible then table.insert(kids, c) end end
		local placed = {}
		if list or grid then sortKids(kids, list or grid) end
		if grid then
			local cs, cp = grid.CellSize, grid.CellPadding
			local gw, gh = cs.X.Scale * cw + cs.X.Offset * S, cs.Y.Scale * ch + cs.Y.Offset * S
			local px, py = cp.X.Scale * cw + cp.X.Offset * S, cp.Y.Scale * ch + cp.Y.Offset * S
			local ar = grid:FindFirstChildOfClass("UIAspectRatioConstraint")
			if ar and ar.AspectRatio > 0 then gh = gw / ar.AspectRatio end
			local perRow = math.max(1, math.floor((cw + px) / math.max(gw + px, 1)))
			local rows = math.ceil(#kids / perRow)
			local usedW = math.min(#kids, perRow) * (gw + px) - px
			local ox = alignOff(grid.HorizontalAlignment, cw - usedW)
			local oy = alignOff(grid.VerticalAlignment, ch - (rows * (gh + py) - py))
			for i, c in kids do
				local col, row = (i - 1) % perRow, (i - 1) // perRow
				placed[c] = { cx + ox + col * (gw + px), cy + oy + row * (gh + py), gw, gh }
			end
		elseif list then
			local horiz = tostring(list.FillDirection):find("Horizontal") ~= nil
			local pad = list.Padding; local p = (if horiz then pad.Scale * cw else pad.Scale * ch) + pad.Offset * S
			local sizes, total = {}, 0
			for _, c in kids do
				local s = c.Size -- Scale parts of Size are relative to px, not scaled by S
				local bw, bh = (s.X.Scale * cw + s.X.Offset * S), (s.Y.Scale * ch + s.Y.Offset * S)
				local arc = c:FindFirstChildOfClass("UIAspectRatioConstraint")
				if arc and arc.AspectRatio > 0 then local rr = arc.AspectRatio; if bw / math.max(bh, 1e-6) > rr then bw = bh * rr else bh = bw / rr end end
				bw *= scaleOf(c); bh *= scaleOf(c)
				sizes[c] = { bw, bh }; total += (if horiz then bw else bh)
			end
			total += math.max(0, #kids - 1) * p
			local start = if horiz then alignOff(list.HorizontalAlignment, cw - total) else alignOff(list.VerticalAlignment, ch - total)
			local pos = start
			for _, c in kids do
				local bw, bh = sizes[c][1], sizes[c][2]
				if horiz then placed[c] = { cx + pos, cy + alignOff(list.VerticalAlignment, ch - bh), bw, bh }; pos += bw + p
				else placed[c] = { cx + alignOff(list.HorizontalAlignment, cw - bw), cy + pos, bw, bh }; pos += bh + p end
			end
		end
		local seen = {}
		for idx, c in allKids do
			local n = c.Name; seen[n] = (seen[n] or 0) + 1
			local cpath = path .. "/" .. n .. (if seen[n] > 1 then "#" .. seen[n] else "")
			if c:IsA("GuiObject") then
				if not c.Visible then continue end
				local k = scaleOf(c)
				local px, py, pw, ph
				if placed[c] then px, py, pw, ph = table.unpack(placed[c])
				else
					local s = c.Size
					pw = s.X.Scale * cw + s.X.Offset * S; ph = s.Y.Scale * ch + s.Y.Offset * S
					local okc, sc = pcall(function() return c.SizeConstraint end)
					if okc and sc then local nm = tostring(sc)
						if nm:find("RelativeXX") then ph = s.Y.Scale * cw + s.Y.Offset * S elseif nm:find("RelativeYY") then pw = s.X.Scale * ch + s.X.Offset * S end end
					local arc = c:FindFirstChildOfClass("UIAspectRatioConstraint")
					if arc and arc.AspectRatio > 0 then local rr = arc.AspectRatio; if pw / math.max(ph, 1e-6) > rr then pw = ph * rr else ph = pw / rr end end
					local szc = c:FindFirstChildOfClass("UISizeConstraint")
					if szc then pw = math.clamp(pw, szc.MinSize.X * S, math.max(szc.MinSize.X, szc.MaxSize.X) * S); ph = math.clamp(ph, szc.MinSize.Y * S, math.max(szc.MinSize.Y, szc.MaxSize.Y) * S) end
					local P, A = c.Position, c.AnchorPoint
					local ax = cx + P.X.Scale * cw + P.X.Offset * S
					local ay = cy + P.Y.Scale * ch + P.Y.Offset * S
					pw *= k; ph *= k
					px, py = ax - A.X * pw, ay - A.Y * ph
				end
				local ck = table.clone(key); table.insert(ck, c.ZIndex); table.insert(ck, idx)
				rec(c, cpath, px, py, pw, ph, S * k, nclip, nscroll, ck)
			elseif c:IsA("Folder") then
				local ck = table.clone(key); table.insert(ck, 0); table.insert(ck, idx)
				rec(c, cpath, cx, cy, cw, ch, S, nclip, nscroll, ck)
			end
		end
	end
	local dord = 0; pcall(function() dord = root.DisplayOrder end)
	rec(root, prefix, rx, ry, rw, rh, scaleOf(root), { -1e9, -1e9, 1e9, 1e9 }, nil, { dord })
end

---------------------------------------------------------------------------------------------- boot (IV boot = text_size_v17x_test + touch, tools, HeistClient, Alerts, seeded bag/Index; HL lair zone)
local c = Sim.new(PLACE, { side = "client" })
c.studio = true
if TOUCH then
	c.UserInputService.TouchEnabled = true; c.UserInputService.KeyboardEnabled = false
	c.UserInputService.GetLastInputType = function() return roblox.Enum.UserInputType.Touch end
else
	c.UserInputService.TouchEnabled = false; c.UserInputService.KeyboardEnabled = true
	c.UserInputService.GetLastInputType = function() return roblox.Enum.UserInputType.Keyboard end
end
local lp = c:AddPlayer("Owner", 1, { ["local"] = true, copyStarterGui = true })
c:SpawnCharacter(lp, Vector3.new(0, 4, 30))
local RS = c.game:GetService("ReplicatedStorage")
local SP = c.game:GetService("StarterPlayer")
local CL = SP.StarterPlayerScripts.ClientLoader
local handlers = CL.Handlers
local GC = handlers.UIController.GeneralControllers
local MC = handlers.UIController.MenuControllers
local fake = {
	Data = { Upgrades = {}, Cash = 1234, OwnedProducts = {}, Gears = {}, Inventory = {}, Rebirths = 0, Index = {} },
	OnChange = function() end, ListenToChange = function() return { Disconnect = function() end } end,
}
do -- seed one bag item + a few discovered Index entries so the previews mount
	local okR, Registry = pcall(function() return c:Require((RS:FindFirstChild("Config") and RS.Config:FindFirstChild("Registry")) or RS.Shared.Registry) end)
	local npcs, idx = {}, {}
	if okR and Registry and Registry.NPCOrdered then
		for i = 1, 10 do
			local info = Registry.NPCOrdered[i]
			if info then
				if i == 7 then npcs["g07"] = { Type = info.Id, Mutation = "Normal", Level = 1, Location = "TOOLBAR" } end
				if i <= 6 then idx[info.Id] = true end
			end
		end
	end
	fake.Data.NPCs = npcs; fake.Data.Index = { Normal = idx }; fake.Data.Slots = { { Occupied = false } }
	lp:SetAttribute("InventoryUsed", 1); lp:SetAttribute("InventoryMax", 10)
end
local DA = CL:FindFirstChild("Modules") and CL.Modules:FindFirstChild("DataAggregation")
if DA then c._modules[c:Key(c:Unwrap(DA))] = { value = { WaitForReplica = function() return fake end } } end
local RCm = CL:FindFirstChild("Modules") and CL.Modules:FindFirstChild("ReplicaClient")
if RCm then c._modules[c:Key(c:Unwrap(RCm))] = { value = {} } end
local MI = c:Require(RS.Shared.MonetizationInfo)
local hs = {}
MI.BoundSignal = { Event = { Connect = function(_, f) table.insert(hs, f) end }, Fire = function(_, l, k) for _, f in hs do f(c:Wrap(c:Unwrap(l)), k) end end }
local ui = lp.PlayerGui.MainUI
local UW, UH = W, H - INSET
local function setSizes() ui.AbsoluteSize = Vector2.new(UW, UH); pcall(function() c.game.Workspace.CurrentCamera.ViewportSize = Vector2.new(W, H) end) end
setSizes()
local errs = {}
local function try(name, f) local ok, e = pcall(f); if not ok then table.insert(errs, name .. ": " .. tostring(e)) end end
local raw = c:Unwrap(lp)
local bp = raw:FindFirstChildOfClass("Backpack")
local gearF = c:Unwrap(RS.Assets.Gear)
for _, n in { "PumpkinBonk", "SpringyCoil" } do local g = gearF:FindFirstChild(n); if g and bp then g:Clone().Parent = bp end end
local UIC = {}
function UIC.OpenGui(name) local m = ui.Menus:FindFirstChild(name); if m then m.Visible = true end end
function UIC.CloseGui(name) local m = ui.Menus:FindFirstChild(name); if m then m.Visible = false end end
local function co(name, f) try(name, function() local th = coroutine.create(f); local ok, e = coroutine.resume(th); if not ok then error(e) end end) end
try("SaleFx", function() c:Require(GC.SaleFx).Init(ui, nil) end)
try("PassStore", function() c:Require(GC.PassStore).Init(ui, nil) end)
try("RightSideCards", function() c:Require(GC.RightSideCards).Init(ui, nil) end)
try("Wheel", function() c:Require(GC.RightSideMonetizationWheel).Init(ui, nil) end)
try("ScreenFit", function() local m = c:Require(GC.ScreenFit); if m.Init then m.Init(ui, nil) end end)
c:Step(0.5, 0.1)
local tc = handlers:FindFirstChild("ThemeClient"); if tc then try("Theme", function() return c:RequireAsync(tc) end) end
try("HeistClient", function() return c:RequireAsync(handlers.HeistClient) end)
c:Step(0.5, 0.1)
try("MenuLayout", function() c:Require(GC.MenuLayout).Init(ui, nil) end)
for _, name in { "UpgradesFrame", "ShopFrame", "DailyFrame", "RebirthFrame", "IndexFrame", "SellFrame" } do
	local m = MC:FindFirstChild(name); local f = ui.Menus:FindFirstChild(name)
	if m and f then try(name, function() c:Require(m).Init(f, UIC) end) end
end
pcall(function() ui.Menus.InventoryFrame.ScrollingFrame.AbsoluteSize = Vector2.new(926, 488) end) -- as viewport_render_v17x_test
try("InventoryFrame", function() c:Require(GC.InventoryFrame).Init(ui, nil) end)
for _, name in { "WelcomeBack", "Alerts" } do
	local m = GC:FindFirstChild(name); if m then co(name, function() c:Require(m).Init(ui, UIC) end) end
end
co("Hotbar", function() c:Require(GC.Hotbar).Init(ui, UIC) end)
for _ = 1, 10 do c:Step(0.1) end

local pg = c:Unwrap(lp.PlayerGui)
local mainRaw = c:Unwrap(ui)
local function deviceScales()
	local mobile = TOUCH or math.min(W, H) < 500
	local alpha = math.clamp((H - 320) / (1080 - 320), 0, 1)
	for _, d in pg:GetDescendants() do
		if d:IsA("UIScale") and d.Name == "DeviceScale" then
			local minS, maxS = d:GetAttribute("MinScale") or 1, d:GetAttribute("MaxScale") or 1
			local f = if mobile then (d:GetAttribute("TouchFactor") or 0.7) else (d:GetAttribute("PcFactor") or 0.85)
			d.Scale = (minS + (maxS - minS) * alpha) * f
		end
	end
end
local function relayout()
	deviceScales()
	for _ = 1, 2 do
		for _, g in pg:GetChildren() do
			if not g:IsA("ScreenGui") then continue end
			layoutAll(g, 0, INSET, UW, UH, g.Name, function(inst, _, x, y, w, h)
				if inst:IsA("GuiObject") then pcall(function() local wi = c:Wrap(inst); wi.AbsoluteSize = Vector2.new(w, h); wi.AbsolutePosition = Vector2.new(x, y) end) end
			end)
		end
		setSizes()
		for _ = 1, 8 do c:Step(0.1) end
	end
end

---------------------------------------------------------------------------------------------- baked look
local function rgb(c3) return { c3.R, c3.G, c3.B } end
local function lookOf(inst, it, w, h, S, isText)
	it.z = inst.ZIndex
	local okR, rot = pcall(function() return inst.Rotation end); if okR and rot and rot ~= 0 then it.rot = rot end
	it.corner = cornerPx(inst, w, h, S)
	local strokes = {}
	for _, ch in inst:GetChildren() do
		if ch:IsA("UIGradient") and ch.Enabled then
			local kc, kt = {}, {}
			for _, kp in ch.Color.Keypoints do table.insert(kc, { kp.Time, kp.Value.R, kp.Value.G, kp.Value.B }) end
			for _, kp in ch.Transparency.Keypoints do table.insert(kt, { kp.Time, kp.Value }) end
			it.grad = { c = kc, t = kt, rot = ch.Rotation, off = { ch.Offset.X, ch.Offset.Y } }
		elseif ch:IsA("UIStroke") and ch.Enabled and ch.Transparency < 0.99 then
			local ctx = tostring(ch.ApplyStrokeMode):find("Contextual") ~= nil
			local s = { c = rgb(ch.Color), th = ch.Thickness * S, tr = ch.Transparency }
			if isText and ctx then it.tstroke = s else table.insert(strokes, s) end
		end
	end
	if #strokes > 0 then it.strokes = strokes end
	if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		it.img = inst.Image; it.imgT = inst.ImageTransparency; it.imgC = rgb(inst.ImageColor3)
		it.tile = tostring(inst.ScaleType):find("Tile") ~= nil
		if it.tile then local ts = inst.TileSize; it.tileSize = { ts.X.Scale * w + ts.X.Offset * S, ts.Y.Scale * h + ts.Y.Offset * S } end
	end
	if inst:IsA("CanvasGroup") then it.groupT = inst.GroupTransparency end
	if inst:IsA("ViewportFrame") then it.vp = true end
end

local function dumpScreen(screen)
	relayout()
	local items = {}
	for _, g in pg:GetChildren() do
		if not g:IsA("ScreenGui") then continue end
		local en = true; pcall(function() en = g.Enabled end); if not en then continue end
		layoutAll(g, 0, INSET, UW, UH, g.Name, function(inst, path, x, y, w, h, S, clip, scroll, key)
			if not inst:IsA("GuiObject") then return end
			local it = { path = path, cls = inst.ClassName, x = x, y = y, w = w, h = h, S = S, clip = clip, scroll = scroll, k = key,
				btn = inst:IsA("GuiButton"), bgT = inst.BackgroundTransparency }
			local isText = inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")
			if isText then
				local text = inst.Text or ""
				if text ~= "" then
					local n, emoji, iconOnly = scanText(text)
					local l, r, t, b = padOf(inst, w, h)
					local tsc = inst:FindFirstChildOfClass("UITextSizeConstraint")
					local lo, hi = 1, 100; if tsc then lo, hi = tsc.MinTextSize, tsc.MaxTextSize end
					local live
					if inst.TextScaled then
						if inst.TextWrapped and not emoji then live = math.clamp(fit(n, w - l - r, h - t - b, true), lo * S, hi * S) else live = math.clamp(inst.TextSize, lo, hi) * S end
					else live = inst.TextSize * S end
					it.text = text; it.th = live; it.iconOnly = iconOnly; it.tc = rgb(inst.TextColor3); it.tT = inst.TextTransparency
					it.stroke = strokeOf(inst)
					it.xa = tostring(inst.TextXAlignment):match("%.(%a+)$"); it.ya = tostring(inst.TextYAlignment):match("%.(%a+)$")
					it.wrap = inst.TextWrapped
					it.pad = { l, r, t, b }
				end
			end
			local ok, bc = pcall(function() return inst.BackgroundColor3 end); if ok and bc then it.bg = rgb(bc) end
			lookOf(inst, it, w, h, S, isText)
			table.insert(items, it)
		end)
	end
	local f = OUTDIR .. "/" .. W .. "x" .. H .. ".json"
	fs.writeFile(f, serde.encode("json", { W = W, H = H, inset = INSET, touch = TOUCH, lair = LAIR, open = OPEN, screen = screen, items = items, errs = errs }))
	print("wrote", f, #items, "items")
end

---------------------------------------------------------------------------------------------- screen setup
local menus = mainRaw.Menus
local function closeAll() for _, f in menus:GetChildren() do if f:IsA("GuiObject") then f.Visible = false end end
	local sc = pg:FindFirstChild("SellConfirmGui"); if sc then for _, d in sc:GetChildren() do if d:IsA("GuiObject") then d.Visible = false end end end end
closeAll()
lp:SetAttribute("Zone", if LAIR then "Field" else "Safe")
for _ = 1, 5 do c:Step(0.1) end

-- Inventory: the controller's Rebuild does not run in rbxsim, so mount exactly what it mounts (1 loot tile, 9 empty, +1 SLOT), FitGrid sizes
local function fillInventory(inv)
	local Instance, UDim2, Color3 = roblox.Instance, roblox.UDim2, roblox.Color3
	local RSr = c:Unwrap(RS)
	local list = inv.ScrollingFrame
	for _, ch in list:GetChildren() do if ch:IsA("GuiObject") then return "already filled" end end
	local grid = list:FindFirstChildOfClass("UIGridLayout")
	local k = 1; local node = list; while node do for _, ch in node:GetChildren() do if ch:IsA("UIScale") and ch.Scale > 0.01 then k *= ch.Scale end end; node = node.Parent end
	local w, h = list.AbsoluteSize.X / k, list.AbsoluteSize.Y / k
	local pd = list:FindFirstChildOfClass("UIPadding")
	local pl, pr, pt, pb = pd.PaddingLeft.Offset, pd.PaddingRight.Offset, pd.PaddingTop.Offset, pd.PaddingBottom.Offset
	local pc = w >= 560; local cols = if pc then 5 else 3; local rows = if pc then 2.25 else 2.15
	local pad = math.clamp(math.floor(w * 0.014), 6, 14)
	local cw = math.floor((w - pl - pr - list.ScrollBarThickness - 2 - pad * (cols - 1)) / cols)
	local ch = math.floor((h - pt - pb - pad * math.floor(rows)) / rows)
	grid.CellPadding = UDim2.fromOffset(pad, pad); grid.CellSize = UDim2.fromOffset(math.max(cw, 40), math.max(ch, 48))
	local T = RSr.UITemplates.InventoryFrame
	local rc = RSr.UITemplates.RarityStyles:GetAttribute("Rare")
	local function cell(i) local c0 = T.Cell:Clone(); c0.Name = "C" .. string.format("%02d", i); c0.LayoutOrder = i; return c0 end
	local t = T.Tile:Clone(); local g = t:FindFirstChildOfClass("UIGradient")
	g.Color = RCS.new({ RCSK.new(0, rc:Lerp(Color3.new(0, 0, 0), g:GetAttribute("DarkenTop"))), RCSK.new(1, rc:Lerp(Color3.new(0, 0, 0), g:GetAttribute("DarkenBottom"))) })
	t.GearName.Text = "Caramel Apple"; t.Rarity.Text = "Rare"; t.Rarity.TextColor3 = rc; t.Income.Text = "$30/s"; t.Visible = true
	local c1 = cell(1); t.Parent = c1; c1.Parent = list
	for i = 2, 10 do local e = T.EmptySlot:Clone(); e.Number.Text = tostring(i); e.Visible = true; local ci = cell(i); e.Parent = ci; ci.Parent = list end
	local l = T.LockedSlot:Clone(); l.Visible = true; local cl = cell(11); l.Parent = cl; cl.Parent = list
	return ("grid %dx%d k=%.3f cols=%d cell=%dx%d pad=%d"):format(w, h, k, cols, cw, ch, pad)
end

local screen = if LAIR then "HUD_lair" else "HUD"
if OPEN then
	local f = menus:FindFirstChild(OPEN) or menus:FindFirstChild(OPEN .. "Frame")
	if f then
		f.Visible = true; setSizes(); for _ = 1, 6 do c:Step(0.1) end
		if f.Name == "InventoryFrame" then relayout(); print("inventory", fillInventory(f)) end
	else -- a separate ScreenGui (e.g. SellConfirmGui): enable it and show its top-level frames
		local g = pg:FindFirstChild(OPEN) or pg:FindFirstChild(OPEN .. "Gui")
		assert(g, "open=" .. OPEN .. ": no Menus." .. OPEN .. "[Frame] and no ScreenGui " .. OPEN .. "[Gui]")
		pcall(function() g.Enabled = true end)
		for _, d in g:GetChildren() do if d:IsA("GuiObject") then d.Visible = true end end
		for _ = 1, 6 do c:Step(0.1) end
	end
	screen = OPEN .. (if LAIR then "_lair" else "")
end
dumpScreen(screen)
print("done", W, H, screen, "boot errors:", #errs, "sim errors:", #c.Errors)
for _, e in errs do print("  boot: " .. e:sub(1, 300)) end
for i, e in c.Errors do if i <= 4 then print("  sim: " .. tostring(e):sub(1, 300)) end end
