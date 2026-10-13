--!strict
-- ViewportPreviewClient (LocalScript, StarterPlayerScripts). Example of the working 3D-preview pattern.
-- Why: Camera instances never replicate server -> client, so a Camera saved inside a ViewportFrame in StarterGui is gone
-- once the server copies the UI into PlayerGui. The client must make its own camera (the one allowed Instance.new here).
-- Studio layout this expects (all editable):
--   ReplicatedStorage.Previews.<Category>.<ModelName>              preview models (scripts/emitters/lights stripped)
--   <card>.Preview (ViewportFrame) with attributes Category, Model, Locked (bool)
--   <card>.Preview.WorldModel (optional; created if missing)
--   PlayerGui.<Screen>@SpinSpeed (deg/s), Preview@Fit (1.1), @Tilt (12), @Roll (0), @TintAmount (0.3), @RarityColor (Color3)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local previews = ReplicatedStorage:WaitForChild("Previews", 10)

type Entry = { vp: ViewportFrame, cam: Camera, model: Model?, center: Vector3, dist: number, angle: number }
local entries: { [ViewportFrame]: Entry } = {}

local function findSource(category: string, name: string): Model?
	local folder = previews and previews:FindFirstChild(category)
	local m = folder and folder:FindFirstChild(name)
	return (m and m:IsA("Model")) and m or nil
end

local function frame(e: Entry)
	local model = e.model
	if not model then return end
	local cf, size = model:GetBoundingBox()
	local fit = (e.vp:GetAttribute("Fit") :: number?) or 1.1
	local radius = size.Magnitude / 2 * fit
	e.center = cf.Position
	e.dist = radius / math.tan(math.rad(e.cam.FieldOfView) / 2)
end

local function place(e: Entry)
	local tilt = math.rad((e.vp:GetAttribute("Tilt") :: number?) or 12)
	local roll = math.rad((e.vp:GetAttribute("Roll") :: number?) or 0)
	local dir = (CFrame.Angles(0, e.angle, 0) * CFrame.Angles(-tilt, 0, 0)).LookVector
	-- CFrame.lookAt is fine in the real engine (only Lune's is wrong)
	e.cam.CFrame = CFrame.lookAt(e.center - dir * e.dist, e.center) * CFrame.Angles(0, 0, roll)
end

local function setLocked(e: Entry, locked: boolean)
	local vp = e.vp
	local q = vp.Parent and vp.Parent:FindFirstChild("Unknown")
	if locked then
		vp.Ambient, vp.LightColor, vp.ImageColor3 = Color3.new(), Color3.new(), Color3.new()
	else
		local tint = (vp:GetAttribute("TintAmount") :: number?) or 0.3
		local rc = (vp:GetAttribute("RarityColor") :: Color3?) or Color3.new(1, 1, 1)
		vp.Ambient = Color3.fromRGB(200, 200, 200)
		vp.LightColor = Color3.new(1, 1, 1):Lerp(rc, tint)
		vp.ImageColor3 = Color3.new(1, 1, 1)
	end
	if q and q:IsA("GuiObject") then q.Visible = locked end
end

local function bind(vp: ViewportFrame)
	if entries[vp] then return end
	local cam = vp:FindFirstChild("ClientCam") :: Camera?
	if not cam then
		cam = Instance.new("Camera")
		cam.Name = "ClientCam"
		cam.FieldOfView = 30
		cam.Parent = vp
	end
	vp.CurrentCamera = cam
	local wm = vp:FindFirstChildOfClass("WorldModel")
	if not wm then
		wm = Instance.new("WorldModel")
		wm.Parent = vp
	end
	local e: Entry = { vp = vp, cam = cam :: Camera, model = nil, center = Vector3.zero, dist = 10, angle = 0 }
	entries[vp] = e

	local function refresh()
		if e.model then e.model:Destroy(); e.model = nil end
		local src = findSource(vp:GetAttribute("Category") :: string? or "", vp:GetAttribute("Model") :: string? or "")
		if src then
			local m = src:Clone()
			m.Parent = wm
			e.model = m
			frame(e)
		end
		setLocked(e, vp:GetAttribute("Locked") == true)
		place(e)
	end
	vp:GetAttributeChangedSignal("Model"):Connect(refresh)
	vp:GetAttributeChangedSignal("Locked"):Connect(refresh)
	vp.Destroying:Connect(function() entries[vp] = nil end)
	refresh()
end

for _, d in gui:GetDescendants() do
	if d:IsA("ViewportFrame") and d.Name == "Preview" then bind(d) end
end
gui.DescendantAdded:Connect(function(d)
	if d:IsA("ViewportFrame") and d.Name == "Preview" then task.defer(bind, d) end
end)

RunService.RenderStepped:Connect(function(dt)
	for vp, e in entries do
		if vp.Visible and vp.AbsoluteSize.X > 0 then -- spin only what is on screen
			local screen = vp:FindFirstAncestorOfClass("ScreenGui")
			local speed = (screen and screen:GetAttribute("SpinSpeed") :: number?) or 40
			e.angle += math.rad(speed) * dt
			place(e)
		end
	end
end)
