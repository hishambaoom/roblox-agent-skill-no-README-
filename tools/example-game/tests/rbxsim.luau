--!nocheck
-- Portable copy from the agent skill repo. Origin: the "Don't Wake the Pumpkin King" test rig. Generic Roblox stand-in for Lune; adapt Sim.ServerModules() to your own server layout.
--[[
	rbxsim (v12): a small Roblox runtime stand-in for Lune tests. NOT a test itself.
	Runs the BUILT place's real scripts (ModuleScripts) with:
	  * every Instance wrapped in a proxy that adds what Lune's Instances lack: signals (events, attribute /
	    property changed), WaitForChild, GetPivot / PivotTo / GetBoundingBox, Humanoid / Animator stubs,
	    RemoteEvent / RemoteFunction loopback (FireServer -> OnServerEvent with the sim player, FireClient ->
	    OnClientEvent), runtime-only properties (AbsoluteSize, ViewportSize, AssemblyLinearVelocity, ...)
	  * mock services (RunService with a manual Step(dt), TweenService, ContextActionService, UserInputService,
	    ProximityPromptService, GuiService, CollectionService, Debris, MarketplaceService, TextChatService, HttpService)
	  * a manual clock: Sim.Step(dt) advances os.clock / GetServerTimeNow and fires Heartbeat; task.wait/delay
	    inside sim scripts are driven by the same clock, so a 60 s scenario runs instantly and deterministically.
	Errors inside connected handlers are collected in Sim.Errors (never swallowed silently).

	Usage:
		local Sim = require("./rbxsim")
		local sim = Sim.new(placePath, { side = "server" | "client" })
		local mod = sim:Require(sim.game.ServerScriptService.Systems.MySystem.MyModule)
		sim:Step(0.25)
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RInstance = roblox.Instance
local Vector3, Vector2, CFrame = roblox.Vector3, roblox.Vector2, roblox.CFrame

local Sim = {}
Sim.__index = Sim

local EVENT_NAMES = {
	Touched = true, TouchEnded = true, Triggered = true, TriggerEnded = true, PromptShown = true, PromptHidden = true,
	Activated = true, Deactivated = true, MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true,
	MouseEnter = true, MouseLeave = true, Changed = true, ChildAdded = true, ChildRemoved = true,
	DescendantAdded = true, DescendantRemoving = true, AncestryChanged = true, Destroying = true,
	AttributeChanged = true, CharacterAdded = true, CharacterRemoving = true, CharacterAppearanceLoaded = true,
	Chatted = true, Died = true, StateChanged = true, Running = true, Jumping = true, HealthChanged = true,
	Equipped = true, Unequipped = true, OnServerEvent = true, OnClientEvent = true, Event = true, Ended = true,
	Completed = true, Played = true, Stopped = true, DidLoop = true, FocusLost = true, InputBegan = true,
	InputEnded = true, InputChanged = true, MoveToFinished = true, PromptButtonHoldBegan = true,
	PromptButtonHoldEnded = true, Idled = true, KeyframeReached = true, Seated = true, FreeFalling = true,
	PlatformStanding = true, Climbing = true, GettingUp = true, StateEnabledChanged = true,
	PlayerAdded = true, PlayerRemoving = true, ReturnPressedFromOnScreenKeyboard = true,
}

local RUNTIME_DEFAULTS = {
	AbsoluteSize = function() return Vector2.new(400, 40) end,
	AbsolutePosition = function() return Vector2.new(0, 0) end,
	AbsoluteRotation = function() return 0 end,
	ViewportSize = function() return Vector2.new(1280, 720) end,
	MoveDirection = function() return Vector3.zero end,
	AssemblyLinearVelocity = function() return Vector3.zero end,
	AssemblyAngularVelocity = function() return Vector3.zero end,
	FloorMaterial = function() return roblox.Enum.Material.Plastic end,
	TextBounds = function() return Vector2.new(100, 20) end,
	TimeLength = function() return 1 end,
	IsPlaying = function() return false end,
	IsLoaded = function() return true end,
	PlatformStand = function() return false end,
	Sit = function() return false end,
	Jump = function() return false end,
	AutoRotate = function() return true end,
	UserId = function() return 1 end,
	DisplayName = function(inst) return inst.Name end,
	AccountAge = function() return 100 end,
	MembershipType = function() return roblox.Enum.MembershipType.None end,
	RootPart = function() return nil end,
	TopbarInset = function() return roblox.Rect.new(0, 0, 0, 0) end,
	WorldPosition = function() return Vector3.zero end,
	WorldCFrame = function() return CFrame.new() end,
}

------------------------------------------------------------------------------------------------ signals
local function NewSignal(sim, label)
	local s = { _conns = {}, _waiting = {}, label = label }
	function s:Connect(fn)
		local conn = { Connected = true, _fn = fn }
		function conn:Disconnect() conn.Connected = false end
		conn.Destroy = conn.Disconnect
		table.insert(s._conns, conn)
		return conn
	end
	function s:Once(fn)
		local conn
		conn = s:Connect(function(...) conn:Disconnect() fn(...) end)
		return conn
	end
	s.ConnectParallel = s.Connect
	function s:Wait()
		table.insert(s._waiting, coroutine.running())
		return coroutine.yield()
	end
	function s:Fire(...)
		local list = table.clone(s._conns)
		for _, conn in ipairs(list) do
			if conn.Connected then
				sim:_run(label, conn._fn, ...)
			end
		end
		local waiting = s._waiting
		s._waiting = {}
		for _, th in ipairs(waiting) do
			sim:_resume(th, ...)
		end
	end
	function s:Count()
		local n = 0
		for _, c in ipairs(s._conns) do if c.Connected then n += 1 end end
		return n
	end
	return s
end
Sim.NewSignal = NewSignal

------------------------------------------------------------------------------------------------ construction
function Sim.new(placePath: string, opts)
	opts = opts or {}
	local self = setmetatable({}, Sim)
	self.side = opts.side or "server"
	self.Errors = {}
	self.Log = {}
	self.now = 1000
	self.serverTimeBase = 1.79e9
	self._sleepers = {} -- { at, thread, args }
	self._proxies = {}
	self._byId = {}
	self._nextId = 0
	self._raw = setmetatable({}, { __mode = "k" })
	self._signals = {}
	self._over = {}
	self._modules = {}
	self.fired = {} -- remote traffic log: { dir, remote, args }
	self.place = roblox.deserializePlace(fs.readFile(placePath))
	self.players = {}
	self:_buildServices()
	return self
end

function Sim:_run(label, fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(self.Errors, `{label}: {err}\n{debug.traceback(co)}`)
	end
	return co
end

function Sim:_resume(th, ...)
	if coroutine.status(th) ~= "suspended" then return end
	local ok, err = coroutine.resume(th, ...)
	if not ok then
		table.insert(self.Errors, `resumed thread: {err}\n{debug.traceback(th)}`)
	end
end

-- Lune hands out a new userdata per access (== works, table keys do not): key everything by a stable id
function Sim:Key(inst)
	local okA, id = pcall(function() return inst:GetAttribute("__simid") end)
	if not okA then
		-- destroyed instance: Lune refuses attribute access; give it a throwaway id
		self._nextId += 1
		return self._nextId
	end
	if id and self._byId[id] ~= nil and self._byId[id] == inst then return id end
	self._nextId += 1
	id = self._nextId
	pcall(function() inst:SetAttribute("__simid", id) end)
	self._byId[id] = inst
	return id
end

function Sim:Signal(inst, key)
	local k = self:Key(inst)
	local t = self._signals[k]
	if not t then t = {}; self._signals[k] = t end
	local s = t[key]
	if not s then
		s = NewSignal(self, (pcall(function() return inst:GetFullName() end) and inst:GetFullName() or "?") .. "." .. key)
		t[key] = s
	end
	return s
end

function Sim:Over(inst)
	local k = self:Key(inst)
	local t = self._over[k]
	if not t then t = {}; self._over[k] = t end
	return t
end

function Sim:Unwrap(v)
	if type(v) == "table" then
		local raw = self._raw[v]
		if raw then return raw end
	end
	return v
end

local function isInstance(v)
	return typeof(v) == "Instance"
end

function Sim:Wrap(v)
	if isInstance(v) then
		local k = self:Key(v)
		local p = self._proxies[k]
		if p then return p end
		p = self:_makeProxy(v)
		self._proxies[k] = p
		local ov = self:Over(v)
		ov.__name = v.Name
		ov.__class = v.ClassName
		self._raw[p] = v
		return p
	elseif type(v) == "table" and getmetatable(v) == nil then
		-- arrays from GetChildren / GetDescendants
		local out = {}
		for k, x in pairs(v) do out[k] = self:Wrap(x) end
		return out
	end
	return v
end

function Sim:IsProxy(v)
	return type(v) == "table" and self._raw[v] ~= nil
end

------------------------------------------------------------------------------------------------ pivots
local function partsOf(inst)
	local out = {}
	if inst:IsA("BasePart") then table.insert(out, inst) end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then table.insert(out, d) end
	end
	return out
end

function Sim:_bbox(model)
	local parts = partsOf(model)
	if #parts == 0 then return CFrame.new(), Vector3.zero end
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in parts do
		local cf, h = p.CFrame, p.Size / 2
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			local w = cf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
			mn = Vector3.new(math.min(mn.X, w.X), math.min(mn.Y, w.Y), math.min(mn.Z, w.Z))
			mx = Vector3.new(math.max(mx.X, w.X), math.max(mx.Y, w.Y), math.max(mx.Z, w.Z))
		end end end
	end
	return CFrame.new((mn + mx) / 2), mx - mn
end

function Sim:GetPivot(inst)
	if inst:IsA("BasePart") then return inst.CFrame end
	local over = self:Over(inst)
	if over.__pivot then
		local pp = inst:IsA("Model") and inst.PrimaryPart
		if pp and over.__pivotPart == pp then
			return pp.CFrame * over.__pivotOffset
		end
		return over.__pivot
	end
	local pp = inst:IsA("Model") and inst.PrimaryPart
	if pp then return pp.CFrame end
	local ok, wp = pcall(function() return inst.WorldPivot end)
	if ok and wp then return wp end
	return (self:_bbox(inst))
end

function Sim:PivotTo(inst, cf)
	if inst:IsA("BasePart") then
		inst.CFrame = cf
		return
	end
	local old = self:GetPivot(inst)
	local delta = cf * old:Inverse()
	for _, p in partsOf(inst) do
		p.CFrame = delta * p.CFrame
	end
	local over = self:Over(inst)
	over.__pivot = cf
	local pp = inst:IsA("Model") and inst.PrimaryPart
	if pp then
		over.__pivotPart = pp
		over.__pivotOffset = pp.CFrame:Inverse() * cf
	end
end

------------------------------------------------------------------------------------------------ proxy
local function animTrack(sim)
	local t = { IsPlaying = false, Looped = false, Length = 1, Speed = 1, TimePosition = 0 }
	t.Stopped = NewSignal(sim, "AnimTrack.Stopped")
	t.Ended = NewSignal(sim, "AnimTrack.Ended")
	t.DidLoop = NewSignal(sim, "AnimTrack.DidLoop")
	t.KeyframeReached = NewSignal(sim, "AnimTrack.KeyframeReached")
	function t:Play() t.IsPlaying = true end
	function t:Stop() t.IsPlaying = false end
	function t:AdjustSpeed(s) t.Speed = s end
	function t:AdjustWeight() end
	function t:GetMarkerReachedSignal() return NewSignal(sim, "marker") end
	return t
end

function Sim:_methods()
	local sim = self
	local M = {}
	M.WaitForChild = function(inst, name, timeout)
		local c = inst:FindFirstChild(name)
		if not c then
			table.insert(sim.Log, `WaitForChild({inst:GetFullName()}, {name}, {timeout}) -> nil`)
			if timeout == nil then
				-- a real infinite yield: park the calling thread forever (recorded)
				table.insert(sim.Errors, `infinite yield: {inst:GetFullName()}:WaitForChild("{name}")`)
				coroutine.yield()
			end
		end
		return c
	end
	M.GetAttributeChangedSignal = function(inst, name) return sim:Signal(inst, "attr:" .. name) end
	M.GetPropertyChangedSignal = function(inst, name) return sim:Signal(inst, "prop:" .. name) end
	M.SetAttribute = function(inst, name, value)
		local old = inst:GetAttribute(name)
		inst:SetAttribute(name, value)
		if old ~= value then
			sim:Signal(inst, "attr:" .. name):Fire()
			sim:Signal(inst, "AttributeChanged"):Fire(name)
		end
	end
	M.GetPivot = function(inst) return sim:GetPivot(inst) end
	M.PivotTo = function(inst, cf) sim:PivotTo(inst, cf) end
	M.GetBoundingBox = function(inst) return sim:_bbox(inst) end
	M.GetExtentsSize = function(inst) local _, s = sim:_bbox(inst); return s end
	M.GetScale = function() return 1 end
	M.ScaleTo = function() end
	M.MoveTo = function(inst, pos)
		if inst:IsA("Humanoid") then sim:Over(inst).__moveTarget = pos
		elseif inst:IsA("Model") then sim:PivotTo(inst, CFrame.new(pos)) end
	end
	M.ChangeState = function(inst, st) sim:Over(inst).__state = st end
	M.GetState = function(inst) return sim:Over(inst).__state or roblox.Enum.HumanoidStateType.Running end
	M.SetStateEnabled = function() end
	M.LoadAnimation = function() return animTrack(sim) end
	M.GetPlayingAnimationTracks = function() return {} end
	M.SetExperimentalFeatures = function() end
	M.SetNetworkOwner = function() end
	M.SetNetworkOwnershipAuto = function() end
	M.GetNetworkOwner = function() return nil end
	M.ApplyImpulse = function() end
	M.ApplyAngularImpulse = function() end
	M.BreakJoints = function() end
	M.GetMass = function() return 1 end
	M.TakeDamage = function(inst, n) inst.Health = inst.Health - n end
	M.EquipTool = function(inst, tool) local ch = inst.Parent; if ch then tool.Parent = ch end end
	M.UnequipTools = function() end
	M.Play = function(inst) sim:Over(inst).IsPlaying = true end
	M.Stop = function(inst) sim:Over(inst).IsPlaying = false end
	M.Pause = M.Stop
	M.Resume = M.Play
	M.Emit = function() end
	M.Clear = function() end
	M.InputHoldBegin = function() end
	M.InputHoldEnd = function() end
	M.CaptureFocus = function() end
	M.ReleaseFocus = function() end
	M.TweenSize = function() return true end
	M.TweenPosition = function() return true end
	M.TweenSizeAndPosition = function() return true end
	M.LoadCharacter = function(inst) sim:SpawnCharacter(inst) end
	M.Kick = function(inst, msg) table.insert(sim.Log, `KICK {inst.Name}: {msg}`); sim:RemovePlayer(inst) end
	M.IsFriendsWith = function() return false end
	M.GetRankInGroup = function() return 0 end
	M.IsInGroup = function() return false end
	M.GetNetworkPing = function() return 0.05 end
	M.GetMouse = function() return { Hit = CFrame.new(), Target = nil, X = 0, Y = 0, Move = NewSignal(sim, "mouse"), Button1Down = NewSignal(sim, "mouse") } end
	M.Destroy = function(inst)
		sim:Signal(inst, "Destroying"):Fire()
		local parent = inst.Parent
		local ov = sim:Over(inst)
		ov.__name = inst.Name
		-- mark the whole subtree destroyed (Lune refuses any access afterwards)
		for _, d in inst:GetDescendants() do
			local o = sim:Over(d); o.__name = o.__name or d.Name; o.__class = o.__class or d.ClassName; o.__destroyed = true
		end
		inst:Destroy()
		ov.__destroyed = true
		if parent then sim:Signal(parent, "ChildRemoved"):Fire(sim:Wrap(inst)) end
	end
	M.Raycast = function(inst, origin, dir, params) return sim:Raycast(origin, dir, params) end
	M.GetPartBoundsInBox = function() return {} end
	M.GetPartBoundsInRadius = function() return {} end
	M.GetPartsInPart = function() return {} end
	M.GetServerTimeNow = function() return sim.serverTimeBase + sim.now end
	M.FindFirstAncestor = function(inst, name)
		local p = inst.Parent
		while p do if p.Name == name then return p end p = p.Parent end
		return nil
	end
	M.FindFirstAncestorOfClass = function(inst, cls)
		local p = inst.Parent
		while p do if p.ClassName == cls then return p end p = p.Parent end
		return nil
	end
	M.FindFirstAncestorWhichIsA = function(inst, cls)
		local p = inst.Parent
		while p do if p:IsA(cls) then return p end p = p.Parent end
		return nil
	end
	-- remotes
	M.FireServer = function(inst, ...)
		table.insert(sim.fired, { "c->s", inst:GetFullName(), { ... } })
		sim:Signal(inst, "OnServerEvent"):Fire(sim.LocalPlayer, ...)
	end
	M.FireClient = function(inst, player, ...)
		table.insert(sim.fired, { "s->c", inst:GetFullName(), { ... }, player })
		if sim.side == "client" or sim.loopback then sim:Signal(inst, "OnClientEvent"):Fire(...) end
	end
	M.FireAllClients = function(inst, ...)
		table.insert(sim.fired, { "s->all", inst:GetFullName(), { ... } })
		if sim.side == "client" or sim.loopback then sim:Signal(inst, "OnClientEvent"):Fire(...) end
	end
	M.InvokeServer = function(inst, ...)
		local f = sim:Over(inst).OnServerInvoke
		if not f then return nil end
		return f(sim.LocalPlayer, ...)
	end
	M.Fire = function(inst, ...) -- BindableEvent
		sim:Signal(inst, "Event"):Fire(...)
	end
	M.Invoke = function(inst, ...)
		local f = sim:Over(inst).OnInvoke
		return f and f(...)
	end
	return M
end

function Sim:_makeProxy(inst)
	local sim = self
	local methods = self._methodTable or self:_methods()
	self._methodTable = methods
	local proxy = {}
	local mt = {}
	local myKey = sim:Key(inst)
	local function destroyedFallback(key)
		local over = sim._over[myKey] or {}
		if key == "Parent" then return nil end
		if key == "Name" then return over.__name end
		if key == "ClassName" then return over.__class end
		if key == "IsA" then return function(_, c) return over.__class == c end end
		if key == "GetChildren" or key == "GetDescendants" then return function() return {} end end
		if key == "IsDescendantOf" then return function() return false end end
		if string.find(key, "^FindFirst") or key == "GetAttribute" or key == "WaitForChild" then return function() return nil end end
		if key == "GetFullName" then return function() return over.__name or "?" end end
		if EVENT_NAMES[key] then return sim:Signal(inst, key) end
		if string.match(key, "^%u%l+%u") or methods[key] then return function() end end
		return nil
	end
	mt.__index = function(_, key)
		local over = sim._over[myKey]
		if over and over.__destroyed then return destroyedFallback(key) end
		if over and over[key] ~= nil and key ~= "__name" then return sim:Wrap(over[key]) end
		local m = methods[key]
		if m then
			return function(selfArg, ...)
				local args = table.pack(...)
				for i = 1, args.n do args[i] = sim:Unwrap(args[i]) end
				local r = table.pack(pcall(m, sim:Unwrap(selfArg), table.unpack(args, 1, args.n)))
				if not r[1] then
					if string.find(tostring(r[2]), "destroyed", 1, true) then
						sim:Over(inst).__destroyed = true
						local fb = destroyedFallback(key)
						if type(fb) == "function" then return fb() end
						return nil
					end
					error(r[2], 2)
				end
				return sim:_wrapResults(table.unpack(r, 2, r.n))
			end
		end
		local ok, v = pcall(function() return inst[key] end)
		if not ok and string.find(tostring(v), "destroyed", 1, true) then
			sim:Over(inst).__destroyed = true
			return destroyedFallback(key)
		end
		if ok then
			if type(v) == "function" then
				return function(selfArg, ...)
					local args = table.pack(...)
					for i = 1, args.n do args[i] = sim:Unwrap(args[i]) end
					local r = table.pack(pcall(v, sim:Unwrap(selfArg), table.unpack(args, 1, args.n)))
					if not r[1] then
						if string.find(tostring(r[2]), "destroyed", 1, true) then
							sim:Over(inst).__destroyed = true
							local fb = destroyedFallback(key)
							if type(fb) == "function" then return fb() end
							return nil
						end
						error(r[2], 2)
					end
					return sim:_wrapResults(table.unpack(r, 2, r.n))
				end
			end
			return sim:Wrap(v)
		end
		if key == "Position" and inst:IsA("BasePart") then return inst.CFrame.Position end
		if key == "Orientation" and inst:IsA("BasePart") then
			local x, y, z = inst.CFrame:ToOrientation()
			return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
		end
		if (key == "WorldPosition" or key == "WorldCFrame") and inst:IsA("Attachment") then
			local par = inst.Parent
			local base = if par and par:IsA("BasePart") then par.CFrame
				elseif par and par:IsA("Model") then sim:GetPivot(par) -- 2025 "detached attachments": Model pivot
				else CFrame.new()
			local wcf = base * inst.CFrame
			return if key == "WorldPosition" then wcf.Position else wcf
		end
		if EVENT_NAMES[key] or string.find(key, "Added$") or string.find(key, "Removing$") then return sim:Signal(inst, key) end
		local def = RUNTIME_DEFAULTS[key]
		if def then return def(inst) end
		if key == "Health" or key == "MaxHealth" then return 100 end
		if key == "CurrentCamera" and inst.ClassName == "Workspace" then
			local cam = inst:FindFirstChildOfClass("Camera")
			if not cam then cam = RInstance.new("Camera"); cam.Parent = inst end
			return sim:Wrap(cam)
		end
		if key == "LocalPlayer" then return sim.LocalPlayer end
		if key == "OnServerInvoke" or key == "OnInvoke" or key == "OnClientInvoke" then return nil end
		error(`{key} is not a valid member of {inst.ClassName} "{inst:GetFullName()}"`, 2)
	end
	mt.__newindex = function(_, key, value)
		local raw = sim:Unwrap(value)
		local ov0 = sim._over[myKey]
		if ov0 and ov0.__destroyed then
			if key == "Parent" then error("The Parent property of " .. tostring(ov0.__name) .. " is locked", 2) end
			return
		end
		if key == "Name" then sim:Over(inst).__name = raw end
		local oldParent = if key == "Parent" then inst.Parent else nil
		local ok
		if key == "Position" and inst:IsA("BasePart") then
			ok = pcall(function() inst.CFrame = inst.CFrame.Rotation + raw end)
		elseif key == "Orientation" and inst:IsA("BasePart") then
			ok = pcall(function() inst.CFrame = CFrame.new(inst.CFrame.Position) * CFrame.fromOrientation(math.rad(raw.X), math.rad(raw.Y), math.rad(raw.Z)) end)
		else
			ok = pcall(function() inst[key] = raw end)
		end
		if not ok then
			sim:Over(inst)[key] = raw
		else
			local over = sim._over[sim:Key(inst)]
			if over then over[key] = nil end
		end
		sim:Signal(inst, "prop:" .. key):Fire()
		sim:Signal(inst, "Changed"):Fire(key)
		if key == "Parent" then
			if oldParent then sim:Signal(oldParent, "ChildRemoved"):Fire(proxy) end
			if raw then
				sim:Signal(raw, "ChildAdded"):Fire(proxy)
				local a = raw
				while a do
					sim:Signal(a, "DescendantAdded"):Fire(proxy)
					a = a.Parent
				end
			end
		end
	end
	mt.__tostring = function() return inst.Name end
	mt.__eq = function(a, b) return sim:Unwrap(a) == sim:Unwrap(b) end
	return setmetatable(proxy, mt)
end

function Sim:_wrapResults(...)
	local r = table.pack(...)
	for i = 1, r.n do r[i] = self:Wrap(r[i]) end
	return table.unpack(r, 1, r.n)
end

------------------------------------------------------------------------------------------------ raycast (ground only)
-- A simple ground model: a downward ray hits the top of any CanCollide part whose XZ footprint (axis-aligned)
-- contains the ray origin. Enough for "is the character on the floor" checks.
function Sim:Raycast(origin, dir, params)
	if dir.Y >= 0 then return nil end
	local excluded = {}
	if params and params.FilterDescendantsInstances then
		for _, e in params.FilterDescendantsInstances do excluded[self:Unwrap(e)] = true end
	end
	local function isExcluded(p)
		local a = p
		while a do
			if excluded[a] then return true end
			a = a.Parent
		end
		return false
	end
	local best
	for _, p in self.place:GetService("Workspace"):GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide and not isExcluded(p) then
			local h = p.Size / 2
			local c = p.CFrame.Position
			if math.abs(origin.X - c.X) <= h.X and math.abs(origin.Z - c.Z) <= h.Z then
				local top = c.Y + h.Y
				if top <= origin.Y and top >= origin.Y + dir.Y and (not best or top > best.Position.Y) then
					best = { Instance = self:Wrap(p), Position = Vector3.new(origin.X, top, origin.Z), Normal = Vector3.yAxis, Material = p.Material }
				end
			end
		end
	end
	return best
end

------------------------------------------------------------------------------------------------ services
function Sim:_buildServices()
	local sim = self
	local function mockService(name, fields)
		local s = fields or {}
		s.ClassName = name
		s.Name = name
		for k, v in pairs(s) do
			if v == "signal" then s[k] = NewSignal(sim, name .. "." .. k) end
		end
		return setmetatable(s, { __index = function(_, k)
			if EVENT_NAMES[k] or string.find(k, "Changed$") or string.find(k, "Signal$") then
				local sig = NewSignal(sim, name .. "." .. k)
				rawset(s, k, sig)
				return sig
			end
			return nil
		end })
	end
	self.RunService = mockService("RunService", { Heartbeat = "signal", RenderStepped = "signal", Stepped = "signal",
		PreSimulation = "signal", PostSimulation = "signal", PreRender = "signal" })
	self.RunService.IsServer = function() return sim.side == "server" end
	self.RunService.IsClient = function() return sim.side == "client" end
	self.RunService.IsStudio = function() return sim.studio == true end
	self.RunService.IsRunning = function() return true end
	self.RunService.BindToRenderStep = function(_, _, _, fn) sim.RunService.RenderStepped:Connect(fn) end
	self.RunService.UnbindFromRenderStep = function() end

	self.TweenService = mockService("TweenService", {})
	self.TweenService.Create = function(_, inst, info, goals)
		local tw = { Completed = NewSignal(sim, "Tween.Completed"), PlaybackState = roblox.Enum.PlaybackState.Begin }
		function tw:Play()
			for k, v in pairs(goals) do
				pcall(function() inst[k] = v end)
			end
			tw.Completed:Fire(roblox.Enum.PlaybackState.Completed)
		end
		function tw:Cancel() end
		function tw:Pause() end
		function tw:Destroy() end
		return tw
	end
	self.TweenService.GetValue = function(_, a) return a end

	self.bound = {}
	self.ContextActionService = mockService("ContextActionService", {})
	self.ContextActionService.BindAction = function(_, name, fn, touch, ...) sim.bound[name] = { fn = fn, touch = touch, keys = { ... } } end
	self.ContextActionService.BindActionAtPriority = function(_, name, fn, touch, _p, ...) sim.bound[name] = { fn = fn, touch = touch, keys = { ... } } end
	self.ContextActionService.UnbindAction = function(_, name) sim.bound[name] = nil end
	self.ContextActionService.SetTitle = function() end
	self.ContextActionService.SetImage = function() end
	self.ContextActionService.SetPosition = function() end
	self.ContextActionService.SetDescription = function() end
	self.ContextActionService.GetButton = function() return nil end

	self.touch = true
	self.UserInputService = mockService("UserInputService", { InputBegan = "signal", InputEnded = "signal",
		InputChanged = "signal", LastInputTypeChanged = "signal", JumpRequest = "signal", TouchStarted = "signal" })
	setmetatable(self.UserInputService, { __index = function(t, k)
		if k == "TouchEnabled" then return sim.touch end
		if k == "KeyboardEnabled" then return not sim.touch end
		if k == "MouseEnabled" then return not sim.touch end
		if k == "GamepadEnabled" then return false end
		if string.find(k, "Changed$") or EVENT_NAMES[k] then local s = NewSignal(sim, "UIS." .. k); rawset(t, k, s); return s end
		return nil
	end })
	self.UserInputService.GetLastInputType = function() return if sim.touch then roblox.Enum.UserInputType.Touch else roblox.Enum.UserInputType.Keyboard end
	self.UserInputService.IsKeyDown = function() return false end
	self.UserInputService.GetMouseLocation = function() return Vector2.zero end
	self.UserInputService.GetConnectedGamepads = function() return {} end
	self.UserInputService.GetStringForKeyCode = function(_, k) return k.Name end

	self.ProximityPromptService = mockService("ProximityPromptService", { PromptShown = "signal", PromptHidden = "signal",
		PromptTriggered = "signal", PromptButtonHoldBegan = "signal", PromptButtonHoldEnded = "signal" })
	self.GuiService = mockService("GuiService", {})
	self.GuiService.TopbarInset = roblox.Rect.new(0, 0, 0, 0)
	self.GuiService.GetGuiInset = function() return Vector2.new(0, 36), Vector2.zero end
	self.GuiService.IsTenFootInterface = function() return false end
	self.CollectionService = mockService("CollectionService", {})
	local tags = {}
	self.CollectionService.GetTagged = function(_, tag) return tags[tag] and table.clone(tags[tag]) or {} end
	self.CollectionService.AddTag = function(_, inst, tag) tags[tag] = tags[tag] or {}; table.insert(tags[tag], inst) end
	self.CollectionService.RemoveTag = function() end
	self.CollectionService.HasTag = function(_, inst, tag)
		for _, x in tags[tag] or {} do if x == inst then return true end end
		return false
	end
	self.CollectionService.GetInstanceAddedSignal = function(_, tag) return NewSignal(sim, "tag+" .. tag) end
	self.CollectionService.GetInstanceRemovedSignal = function(_, tag) return NewSignal(sim, "tag-" .. tag) end
	self.Debris = mockService("Debris", {})
	self.Debris.AddItem = function(_, inst, t)
		sim:Delay(t or 10, function() pcall(function() inst:Destroy() end) end)
	end
	self.HttpService = mockService("HttpService", {})
	local guid = 0
	self.HttpService.GenerateGUID = function() guid += 1; return string.format("{%08d-sim}", guid) end
	self.HttpService.JSONEncode = function(_, v) return require("@lune/serde").encode("json", v) end
	self.HttpService.JSONDecode = function(_, v) return require("@lune/serde").decode("json", v) end
	self.MarketplaceService = mockService("MarketplaceService", { PromptProductPurchaseFinished = "signal",
		PromptGamePassPurchaseFinished = "signal", PromptPurchaseFinished = "signal" })
	self.MarketplaceService.UserOwnsGamePassAsync = function() return false end
	self.MarketplaceService.PromptProductPurchase = function() end
	self.MarketplaceService.PromptGamePassPurchase = function() end
	self.MarketplaceService.GetProductInfo = function() return { PriceInRobux = 49, Name = "x" } end
	self.TextChatService = mockService("TextChatService", {})
	self.TextChatService.FindFirstChild = function() return nil end
	self.PhysicsService = mockService("PhysicsService", {})
	self.PhysicsService.RegisterCollisionGroup = function() end
	self.PhysicsService.CollisionGroupSetCollidable = function() end
	self.PhysicsService.IsCollisionGroupRegistered = function() return true end
	self.SocialService = mockService("SocialService", {})
	self.BadgeService = mockService("BadgeService", {})
	self.BadgeService.UserHasBadgeAsync = function() return false end
	self.BadgeService.AwardBadge = function() return true end
	self.TeleportService = mockService("TeleportService", {})
	self.AnalyticsService = mockService("AnalyticsService", {})
	setmetatable(self.AnalyticsService, { __index = function() return function() end end })
	self.PolicyService = mockService("PolicyService", {})
	self.PolicyService.GetPolicyInfoForPlayerAsync = function() return { ArePaidRandomItemsRestricted = false } end
	self.LocalizationService = mockService("LocalizationService", {})
	self.StarterGuiMock = nil
	-- DataStores: "403" makes ProfileStore (with sim.studio = true) fall back to its in-memory mock profiles
	self.DataStoreService = mockService("DataStoreService", {})
	local function noAccess() error("403: Cannot write to DataStore from studio (sim)") end
	self.DataStoreService.GetDataStore = function()
		return setmetatable({}, { __index = function() return noAccess end })
	end
	self.DataStoreService.GetOrderedDataStore = self.DataStoreService.GetDataStore
	self.DataStoreService.GetRequestBudgetForRequestType = function() return 100 end
	self.MessagingService = mockService("MessagingService", {})
	self.MessagingService.SubscribeAsync = function() return { Disconnect = function() end } end
	self.MessagingService.PublishAsync = function() end

	local mocks = {
		RunService = self.RunService, TweenService = self.TweenService, ContextActionService = self.ContextActionService,
		UserInputService = self.UserInputService, ProximityPromptService = self.ProximityPromptService,
		GuiService = self.GuiService, CollectionService = self.CollectionService, Debris = self.Debris,
		HttpService = self.HttpService, MarketplaceService = self.MarketplaceService, TextChatService = self.TextChatService,
		PhysicsService = self.PhysicsService, SocialService = self.SocialService, BadgeService = self.BadgeService,
		TeleportService = self.TeleportService, AnalyticsService = self.AnalyticsService, PolicyService = self.PolicyService,
		LocalizationService = self.LocalizationService, DataStoreService = self.DataStoreService,
		MessagingService = self.MessagingService,
	}
	self.mocks = mocks

	-- the DataModel proxy
	local placeGame = self.place
	local gameProxy = setmetatable({}, {
		__index = function(_, key)
			if key == "GetService" or key == "FindService" then
				return function(_, name)
					if mocks[name] then return mocks[name] end
					local ok, svc = pcall(function() return placeGame:GetService(name) end)
					if ok and svc then return sim:Wrap(svc) end
					return nil
				end
			end
			if key == "PlaceId" then return 1 end
			if key == "GameId" then return 1 end
			if key == "JobId" then return "sim" end
			if key == "CreatorId" then return Sim.OwnerUserId or 1 end -- set Sim.OwnerUserId = <your user id> in a test to act as the owner
			if key == "CreatorType" then return roblox.Enum.CreatorType.User end
			if key == "BindToClose" then return function() end end
			if key == "IsLoaded" then return function() return true end end
			if key == "Loaded" then return NewSignal(sim, "game.Loaded") end
			if key == "Workspace" then return sim:Wrap(placeGame:GetService("Workspace")) end
			if mocks[key] then return mocks[key] end
			local ok, svc = pcall(function() return placeGame:GetService(key) end)
			if ok and svc then return sim:Wrap(svc) end
			return nil
		end,
	})
	self.game = gameProxy
	self.workspace = self:Wrap(placeGame:GetService("Workspace"))
	self.Players = self:Wrap(placeGame:GetService("Players"))
	local playersRaw = placeGame:GetService("Players")
	local over = self:Over(playersRaw)
	over.GetPlayers = function() return table.clone(sim.players) end
	over.GetPlayerByUserId = function(_, id)
		for _, p in sim.players do if p.UserId == id then return p end end
		return nil
	end
	over.GetPlayerFromCharacter = function(_, ch)
		for _, p in sim.players do if p.Character == ch then return p end end
		return nil
	end
	over.GetUserIdFromNameAsync = function() return 1 end
	over.GetNameFromUserIdAsync = function() return "sim" end
	over.GetUserThumbnailAsync = function() return "rbxassetid://0", true end
	over.GetFriendsAsync = function() return { GetCurrentPage = function() return {} end, IsFinished = true } end
	over.CreateHumanoidModelFromUserId = function() return nil end
end

------------------------------------------------------------------------------------------------ clock / task
function Sim:Clock() return self.now end

function Sim:Delay(t, fn, ...)
	local th = if type(fn) == "thread" then fn else coroutine.create(fn)
	table.insert(self._sleepers, { at = self.now + math.max(0, t or 0), thread = th, args = table.pack(...) })
	return th
end

function Sim:_task()
	local sim = self
	local T = {}
	function T.wait(t)
		local th = coroutine.running()
		local start = sim.now
		table.insert(sim._sleepers, { at = sim.now + math.max(1 / 60, t or 0), thread = th, args = { n = 0 }, wait = true })
		coroutine.yield()
		return sim.now - start
	end
	function T.spawn(fn, ...)
		if type(fn) == "thread" then
			sim:_resume(fn, ...)
			return fn
		end
		return sim:_run("task.spawn", fn, ...)
	end
	function T.defer(fn, ...)
		return sim:Delay(0, fn, ...)
	end
	function T.delay(t, fn, ...)
		return sim:Delay(t, fn, ...)
	end
	function T.cancel(th)
		for i = #sim._sleepers, 1, -1 do
			if sim._sleepers[i].thread == th then table.remove(sim._sleepers, i) end
		end
	end
	T.synchronize = function() end
	T.desynchronize = function() end
	return T
end

function Sim:_runSleepers()
	-- run everything that is due (in time order); sleepers created while running and already due also run
	for _ = 1, 10000 do
		local idx, best
		for i, s in ipairs(self._sleepers) do
			if s.at <= self.now and (not best or s.at < best.at) then idx, best = i, s end
		end
		if not idx then return end
		table.remove(self._sleepers, idx)
		local th = best.thread
		if coroutine.status(th) == "suspended" then
			local ok, err
			if best.wait then
				ok, err = coroutine.resume(th, self.now - best.at)
			else
				ok, err = coroutine.resume(th, table.unpack(best.args, 1, best.args.n))
			end
			if not ok then table.insert(self.Errors, `scheduled thread: {err}\n{debug.traceback(th)}`) end
		end
	end
end

-- advance the clock by dt in sub-steps of at most 1/30 s, firing Heartbeat each sub-step
function Sim:Step(dt, sub)
	sub = sub or (1 / 30)
	local left = dt
	while left > 1e-9 do
		local h = math.min(sub, left)
		left -= h
		self.now += h
		self:_runSleepers()
		self.RunService.Stepped:Fire(self.now, h)
		self.RunService.Heartbeat:Fire(h)
		if self.side == "client" then self.RunService.RenderStepped:Fire(h) end
		self:_runSleepers()
	end
end

------------------------------------------------------------------------------------------------ require
function Sim:Env(scriptProxy)
	local sim = self
	local env = {}
	env.script = scriptProxy
	env.game = self.game
	env.Game = self.game
	env.workspace = self.workspace
	env.Workspace = self.workspace
	env.require = function(mod) return sim:Require(mod) end
	env.task = self._taskLib or self:_task()
	self._taskLib = env.task
	env.wait = env.task.wait
	env.delay = env.task.delay
	env.spawn = env.task.spawn
	env.tick = function() return sim.now end
	env.time = function() return sim.now end
	env.elapsedTime = env.time
	env.os = setmetatable({ clock = function() return sim.now end }, { __index = os })
	env.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		table.insert(sim.Log, "[warn] " .. table.concat(parts, " "))
	end
	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		table.insert(sim.Log, table.concat(parts, " "))
	end
	env.typeof = function(v)
		if sim:IsProxy(v) then return "Instance" end
		if type(v) == "table" and v.Connect and v.Fire and v._conns then return "RBXScriptSignal" end
		if type(v) == "table" and v._fn and v.Disconnect then return "RBXScriptConnection" end
		return typeof(v)
	end
	env.Instance = {
		new = function(className, parent)
			local inst = RInstance.new(className)
			local p = sim:Wrap(inst)
			if parent then p.Parent = parent end
			return p
		end,
		fromExisting = function(x) return sim:Wrap(sim:Unwrap(x):Clone()) end,
	}
	for _, k in { "Vector3", "Vector2", "CFrame", "Color3", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence",
		"NumberSequenceKeypoint", "NumberRange", "UDim", "UDim2", "Enum", "BrickColor", "Font", "Rect", "Ray",
		"PhysicalProperties", "Region3", "Faces", "Axes" } do
		env[k] = roblox[k]
	end
	env.TweenInfo = { new = function(...) return { ... } end }
	env.Random = {
		new = function(seed)
			local state = seed or 12345
			local function nextf()
				state = (state * 1103515245 + 12345) % 2147483648
				return state / 2147483648
			end
			return {
				NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + nextf() * (b - a) end,
				NextInteger = function(_, a, b) return a + math.floor(nextf() * (b - a + 1)) end,
				Shuffle = function() end,
			}
		end,
	}
	env.DateTime = { now = function() return { UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000 } end }
	env.RaycastParams = { new = function() return { FilterType = roblox.Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, IgnoreWater = true } end }
	env.OverlapParams = env.RaycastParams
	env.SharedTable = nil
	env.shared = sim._shared or {}
	sim._shared = env.shared
	env._G = env
	return setmetatable(env, { __index = _G })
end

function Sim:Require(mod)
	local raw = self:Unwrap(mod)
	if typeof(raw) ~= "Instance" or not raw:IsA("ModuleScript") then
		error("require: not a ModuleScript: " .. tostring(mod), 2)
	end
	local mk = self:Key(raw)
	local cached = self._modules[mk]
	if cached ~= nil then
		if cached == "__loading" then error("cyclic require " .. raw:GetFullName(), 2) end
		return cached.value
	end
	self._modules[mk] = "__loading"
	local fn = luau.load(raw.Source, { debugName = raw:GetFullName(), environment = self:Env(self:Wrap(raw)) })
	local result = fn()
	self._modules[mk] = { value = result }
	return result
end

-- run a module that may yield at top level (like a real loader): returns ok, result|err
function Sim:RequireAsync(mod)
	local done, value, err = false, nil, nil
	local co = coroutine.create(function()
		local ok, r = pcall(function() return self:Require(mod) end)
		done = true
		if ok then value = r else err = r end
	end)
	local ok, e = coroutine.resume(co)
	if not ok then return false, e end
	return done, value, err, co
end

------------------------------------------------------------------------------------------------ players
function Sim:AddPlayer(name, userId, opts)
	opts = opts or {}
	local raw = RInstance.new("Player")
	raw.Name = name
	local p = self:Wrap(raw)
	local over = self:Over(raw)
	over.UserId = userId or 1
	over.DisplayName = name
	raw.Parent = self.place:GetService("Players")
	local backpack = RInstance.new("Backpack"); backpack.Parent = raw
	local pg = RInstance.new("PlayerGui"); pg.Parent = raw
	local ps = RInstance.new("PlayerScripts"); ps.Parent = raw
	if opts.copyStarterGui then
		for _, g in self.place:GetService("StarterGui"):GetChildren() do
			if g:IsA("ScreenGui") then g:Clone().Parent = pg end
		end
	end
	table.insert(self.players, p)
	if opts["local"] then
		self.LocalPlayer = p
		self:Over(self.place:GetService("Players")).LocalPlayer = raw
	end
	self.Players.PlayerAdded:Fire(p)
	return p
end

function Sim:RemovePlayer(p)
	local idx = table.find(self.players, p)
	if not idx then return end
	self.Players.PlayerRemoving:Fire(p)
	table.remove(self.players, idx)
	pcall(function() self:Unwrap(p).Parent = nil end)
end

function Sim:SpawnCharacter(p, position)
	local rawP = self:Unwrap(p)
	local model = RInstance.new("Model")
	model.Name = rawP.Name
	local root = RInstance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Anchored = false
	root.CanCollide = false
	root.CFrame = CFrame.new(position or Vector3.new(0, 4, 30))
	root.Parent = model
	local hum = RInstance.new("Humanoid")
	hum.HipHeight = 2
	hum.WalkSpeed = 16
	hum.Parent = model
	local animator = RInstance.new("Animator"); animator.Parent = hum
	model.PrimaryPart = root
	model.Parent = self.place:GetService("Workspace")
	local ch = self:Wrap(model)
	self:Over(rawP).Character = model
	p.CharacterAdded:Fire(ch)
	return ch
end

-- move a character: sets the root position and reports a velocity (what the server sees from replication)
function Sim:MoveCharacter(ch, pos, velocity)
	local raw = self:Unwrap(ch)
	local root = raw:FindFirstChild("HumanoidRootPart")
	root.CFrame = CFrame.new(pos) * root.CFrame.Rotation
	self:Over(root).AssemblyLinearVelocity = velocity or Vector3.zero
end

function Sim:ErrorsText()
	return table.concat(self.Errors, "\n---\n")
end

--[=[ RO (2026-10-08): the server modules live in ServerScriptService.Systems.<System> (build_v17_organize).
	Sim.ServerModules(SSS) = the modules ServerLoader starts, in its order (LoadOrder, then full name; skips
	Autoload = false and DISABLED). Sim.ServerModuleTable(SSS) = name -> module for every module in Systems. ]=]
local function systemFolders(sss)
	if sss:FindFirstChild("Systems") then return sss.Systems:GetChildren() end
	-- an older place (before build_v17_organize): the template layout
	local loader = sss.ServerLoader
	return { loader.Handlers, loader.Modules, loader:FindFirstChild("Binding") }
end
function Sim.ServerModules(sss)
	local list = {}
	local legacy = sss:FindFirstChild("Systems") == nil
	if legacy then
		for _, c in { sss.ServerLoader.Handlers, sss.ServerLoader.Modules } do
			for _, m in c:GetChildren() do
				if m:IsA("ModuleScript") and not m:FindFirstChild("DISABLED") then table.insert(list, m) end
			end
		end
		return list
	end
	for _, folder in sss.Systems:GetChildren() do
		for _, m in folder:GetChildren() do
			if m:IsA("ModuleScript") and not m:FindFirstChild("DISABLED") and m:GetAttribute("Autoload") ~= false then
				table.insert(list, m)
			end
		end
	end
	table.sort(list, function(a, b)
		local oa, ob = a:GetAttribute("LoadOrder") or math.huge, b:GetAttribute("LoadOrder") or math.huge
		if oa ~= ob then return oa < ob end
		return a:GetFullName() < b:GetFullName()
	end)
	return list
end
function Sim.ServerModuleTable(sss)
	local t = {}
	for _, folder in systemFolders(sss) do
		for _, m in folder:GetChildren() do t[m.Name] = m end
	end
	return t
end

return Sim
