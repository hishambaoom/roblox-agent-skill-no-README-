--!nocheck
--[[
  StuddedUIClient — reference LocalScript for the studded UI kit (docs/STUDDED_UI_GUIDE.md).
  Lives inside the ScreenGui (StarterGui.StuddedUI_Reference), so script.Parent is the player's copy.

  What a UI script MAY do: clone templates, show/hide (Visible/Enabled), fill Text/Image, tween Scale/Position/
  Transparency/Offset, read attributes. What it must NOT do: Instance.new any visual, or write Size/colours/Font/
  TextSize/stroke/corner on Studio instances — except through attributes the owner can see (PhoneSize, Palette…).
  This is the same logic the shipped game's ForgeUIClient uses, cut down to the parts every studded UI needs.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local gui = script.Parent
local Templates = gui:WaitForChild("Templates")
local Toasts = gui:WaitForChild("Toasts")

local TI_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function tween(o, info, goal) local t = TweenService:Create(o, info, goal); t:Play(); return t end
local function attr(name, default) local v = script:GetAttribute(name); if typeof(v) == typeof(default) then return v end; return default end

---------------------------------------------------------------- 1. device scale + Phone* attributes
-- Phone = touch without keyboard, or a short viewport side < 500 px. Reference sizes: PC 1920x1080, phone 667x375.
local function isPhone()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return (UIS.TouchEnabled and not UIS.KeyboardEnabled) or math.min(vp.X, vp.Y) < 500, vp
end
local function applyScale()
	local phone, vp = isPhone()
	local alpha = math.clamp((vp.Y - 320) / (1080 - 320), 0, 1)
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("UIScale") and d.Name == "DeviceScale" then
			-- Scale = lerp(MinScale, MaxScale, viewport height) * (TouchFactor on phone | PcFactor on PC)
			local mn, mx = d:GetAttribute("MinScale") or 1, d:GetAttribute("MaxScale") or 1
			local f = phone and (d:GetAttribute("TouchFactor") or 0.7) or (d:GetAttribute("PcFactor") or 1)
			d.Scale = (mn + (mx - mn) * alpha) * f
			d:SetAttribute("Base", d.Scale)
		elseif d:IsA("GuiObject") then
			-- PhoneSize / PhonePosition / PhoneAnchorPoint swap in on phones; the PC value is remembered in Pc<Prop>
			for _, p in ipairs({ "Size", "Position", "AnchorPoint" }) do
				local v = d:GetAttribute("Phone" .. p)
				if v ~= nil then
					if d:GetAttribute("Pc" .. p) == nil then d:SetAttribute("Pc" .. p, d[p]) end
					d[p] = phone and v or d:GetAttribute("Pc" .. p)
				end
			end
		end
	end
end
applyScale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale) end

---------------------------------------------------------------- 2. button feel (the Press UIScale)
local function press(btn, fn)
	local s = btn:FindFirstChild("Press")
	if s then
		local hover = false
		btn.MouseEnter:Connect(function() hover = true; tween(s, TI_FAST, { Scale = attr("HoverScale", 1.04) }) end)
		btn.MouseButton1Down:Connect(function() tween(s, TI_FAST, { Scale = 0.88 }) end)
		btn.MouseButton1Up:Connect(function() tween(s, TI_POP, { Scale = hover and attr("HoverScale", 1.04) or 1 }) end)
		btn.MouseLeave:Connect(function() hover = false; tween(s, TI_FAST, { Scale = 1 }) end)
	end
	btn.Activated:Connect(fn)
end
local function setDim(btn, on) local d = btn:FindFirstChild("Dim"); if d then d.Visible = on end end

---------------------------------------------------------------- 3. panels: one open at a time, pop in, slide out
local PANELS = {}
for _, c in ipairs(gui:GetChildren()) do
	if c:IsA("Frame") and c:FindFirstChild("Top") and c:FindFirstChild("Body") then PANELS[c.Name] = c end
end
local basePos = {}
for _, p in pairs(PANELS) do basePos[p] = p.Position end
local function hidePanel(p)
	if not p.Visible then return end
	local ds = p:FindFirstChild("DeviceScale")
	if ds then tween(ds, TI_FAST, { Scale = (ds:GetAttribute("Base") or ds.Scale) * 0.85 }) end
	local t = tween(p, TI_FAST, { Position = p.Position + UDim2.fromOffset(0, 30) })
	t.Completed:Connect(function()
		p.Visible = false; p.Position = basePos[p]
		if ds then ds.Scale = ds:GetAttribute("Base") or ds.Scale end
	end)
end
local function openPanel(name)
	local p = PANELS[name]
	if not p then return end
	if p.Visible then hidePanel(p); return end
	for n, o in pairs(PANELS) do if n ~= name then o.Visible = false end end
	basePos[p] = p.Position -- picks up PhonePosition after applyScale
	p.Visible = true
	p.Position = basePos[p] + UDim2.fromOffset(0, 40)
	tween(p, TI_POP, { Position = basePos[p] })
	local ds = p:FindFirstChild("DeviceScale")
	if ds then local base = ds:GetAttribute("Base") or ds.Scale; ds.Scale = base * 0.85; tween(ds, TI_POP, { Scale = base }) end
end
for _, col in ipairs({ gui:FindFirstChild("RightButtons"), gui:FindFirstChild("LeftButtons") }) do
	for _, b in ipairs(col and col:GetChildren() or {}) do
		if b:IsA("GuiButton") and b:GetAttribute("Panel") then press(b, function() openPanel(b:GetAttribute("Panel")) end) end
	end
end
for _, p in pairs(PANELS) do
	local close = p.Top:FindFirstChild("Close")
	if close then press(close, function() hidePanel(p) end) end
end

---------------------------------------------------------------- 4. tabs: Dim on every tab except the active one
for _, p in pairs(PANELS) do
	local tabs = p.Body:FindFirstChild("Tabs")
	if tabs then
		local function setTab(name)
			p.Body:SetAttribute("Tab", name)
			for _, t in ipairs(tabs:GetChildren()) do if t:IsA("GuiButton") then setDim(t, t:GetAttribute("Tab") ~= name) end end
		end
		for _, t in ipairs(tabs:GetChildren()) do
			if t:IsA("GuiButton") and t:GetAttribute("Tab") then press(t, function() setTab(t:GetAttribute("Tab")) end) end
		end
	end
end

---------------------------------------------------------------- 5. toasts: clone the template, dedupe, cap, pop
local toastN, lastToast = 0, {}
local function toast(msg, colorName)
	msg = tostring(msg)
	local now = os.clock()
	local prev = lastToast[msg]
	if prev and now - prev < (Toasts:GetAttribute("RepeatIgnoreSeconds") or 2) then return end
	lastToast[msg] = now
	local tpl = Templates:FindFirstChild("Toast")
	if not tpl then warn("[StuddedUI] Templates.Toast missing"); return end -- missing template = loud skip, never rebuild in code
	local t = tpl:Clone()
	toastN += 1
	t.Name = "Toast" .. toastN; t.LayoutOrder = toastN
	t.Label.Text = msg
	local c = Toasts:GetAttribute(colorName or "White") or Toasts:GetAttribute("White")
	if typeof(c) == "Color3" then -- colour comes from an attribute the owner can edit
		local s = t:FindFirstChildOfClass("UIStroke"); if s then s.Color = c end
		t.Label.TextColor3 = c
	end
	t.Visible = true
	t.Parent = Toasts
	local pop = t:FindFirstChild("Pop")
	if pop then pop.Scale = 0.6; tween(pop, TI_POP, { Scale = 1 }) end
	local list = {}
	for _, ch in ipairs(Toasts:GetChildren()) do if ch:IsA("GuiObject") then table.insert(list, ch) end end
	table.sort(list, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for k = 1, #list - (Toasts:GetAttribute("MaxToasts") or 2) do list[k]:Destroy() end
	task.delay(Toasts:GetAttribute("Seconds") or 1.5, function()
		if t.Parent and pop then tween(pop, TI_FAST, { Scale = 0 }); task.wait(0.15) end
		t:Destroy()
	end)
end

---------------------------------------------------------------- 6. tooltip: hover on PC, tap on phone, clamped
local tip = gui:FindFirstChild("Tooltip")
local function showTip(near)
	if not tip then return end
	local vp = workspace.CurrentCamera.ViewportSize
	local pos = isPhone() and (near.AbsolutePosition + Vector2.new(near.AbsoluteSize.X + 8, 0)) or (UIS:GetMouseLocation() + Vector2.new(16, -20))
	local size = tip.AbsoluteSize
	pos = Vector2.new(math.clamp(pos.X, 4, vp.X - size.X - 4), math.clamp(pos.Y, 4, vp.Y - size.Y - 4))
	tip.Position = UDim2.fromOffset(pos.X, pos.Y)
	tip.Visible = true
end

---------------------------------------------------------------- 7. shine sweep (ScreenGui@ShineEvery, 0 = off)
task.spawn(function()
	while gui.Parent do
		local every = gui:GetAttribute("ShineEvery") or 2.5
		if every <= 0 then task.wait(1) else
			for _, g in ipairs(gui:GetDescendants()) do
				if g.Name == "ShineGradient" and g:IsA("UIGradient") and g.Parent.Parent.Visible then
					g.Offset = Vector2.new(-1, 0)
					tween(g, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) })
				end
			end
			task.wait(every)
		end
	end
end)

---------------------------------------------------------------- demo wiring for the example panel
local panel = PANELS.ExamplePanel
if panel then
	local card = panel.Body:FindFirstChild("ItemCard")
	if card then
		press(card.Buy, function() toast("Bought Iron Hammer!", "Green") end)
		card.MouseEnter:Connect(function() if not isPhone() then showTip(card) end end)
		card.MouseLeave:Connect(function() if tip then tip.Visible = false end end)
		card.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.Touch then if tip and tip.Visible then tip.Visible = false else showTip(card) end end
		end)
	end
	press(panel.Body.Secondary, function() toast("Sold for $25K", "Gold") end)
	press(panel.Body.Primary, function() toast("Not enough cash", "Red") end)
end
