--!nocheck
--[[
	build_example_ui - example hook (one owner, idempotent).
	Bakes a toast template the owner can edit in Studio and seeds its tunables as attributes.
	Runtime code must only Clone() this template, set .Text, and tween it (Studio-first rule).

	  ReplicatedStorage.UITemplates.ExampleToast (Frame)      the template; edit look in Studio
	    @Duration      2.5   seconds on screen
	    @FadeOut       0.3   seconds
	    @MaxChars      70    longer text is cut with "..."
	  ReplicatedStorage.Config.GameSettings
	    @ExampleToastEnabled  true   master switch (owner can untick)

	If the base place already has a styled toast (UITemplates.Toast), the example CLONES it (same studs, strokes, fonts)
	instead of inventing a new look - that is the rule for all new UI.
]]
return function(ctx)
	local roblox = ctx.roblox
	local Instance, UDim2, Color3 = roblox.Instance, roblox.UDim2, roblox.Color3
	local uiT, gs = ctx.UITemplates, ctx.GameSettings

	local function seed(inst, name, value)
		if inst:GetAttribute(name) == nil then inst:SetAttribute(name, value) end -- keep the owner's edited value
	end

	local tpl = uiT:FindFirstChild("ExampleToast")
	local source = "existing"
	if not tpl then
		local styled = uiT:FindFirstChild("Toast")
		if styled then
			tpl = styled:Clone()          -- clone the game's own styled template: same look
			source = "clone of UITemplates.Toast"
		else
			tpl = Instance.new("Frame")   -- build-time only (Lune), never at runtime
			tpl.Size = UDim2.new(0.5, 0, 0, 30)
			tpl.AnchorPoint = roblox.Vector2.new(0.5, 0)
			tpl.Position = UDim2.new(0.5, 0, 0, 8)
			tpl.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
			local label = Instance.new("TextLabel")
			label.Name = "Text"; label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1
			label.TextScaled = true; label.TextWrapped = true   -- TextScaled ALWAYS with TextWrapped
			label.TextColor3 = Color3.new(1, 1, 1); label.Parent = tpl
			source = "plain fallback"
		end
		tpl.Name = "ExampleToast"
		tpl.Visible = false
		tpl.Parent = uiT
	end
	seed(tpl, "Duration", 2.5)
	seed(tpl, "FadeOut", 0.3)
	seed(tpl, "MaxChars", 70)
	seed(gs, "ExampleToastEnabled", true)

	ctx.note(("example ui: UITemplates.ExampleToast (%s) @Duration=%s s @FadeOut=%s s @MaxChars=%s; GameSettings@ExampleToastEnabled=%s")
		:format(source, tostring(tpl:GetAttribute("Duration")), tostring(tpl:GetAttribute("FadeOut")),
			tostring(tpl:GetAttribute("MaxChars")), tostring(gs:GetAttribute("ExampleToastEnabled"))))
end
