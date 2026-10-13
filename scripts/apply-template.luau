--!nocheck
-- Idempotent place patch template (Lune 0.10). One agent = one apply.luau = one scope.
--   IN=<place.rbxl> OUT=<out.rbxl> tools/lune10 run games/<game>/work/<agent>/apply.luau
-- Contract:
--   * Works on BASE and on BASE + every earlier agent in the chain (touch only your scope).
--   * FindFirstChild before create; never overwrite an existing instance the owner may have edited (FORCE=1 to redo).
--   * Attribute defaults only when nil, so Studio edits survive re-runs.
--   * Script text edits are anchor patches with a marker: anchor must exist exactly once; a 2nd run reports 0 edits.
--   * Fail loudly instead of half-applying. Print one summary line per area.
--   * Never put "--" comments inside a single-line table literal you insert (it comments out the rest of the line).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

local MARK = "[myagent]" -- change per agent
local IN = process.env.IN or error("set IN")
local OUT = process.env.OUT or error("set OUT")
local FORCE = process.env.FORCE == "1"
local HERE = process.env.SRC_DIR or "./" -- folder with the .luau sources this patch installs (end with /)

local game = roblox.deserializePlace(fs.readFile(IN))
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SP = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChildOfClass("StarterPlayerScripts")

local log = {}
local function note(s) table.insert(log, s) end

local function findScript(name, root)
	for _, d in (root or game):GetDescendants() do
		if d:IsA("LuaSourceContainer") and d.Name == name and not d:FindFirstAncestor("_Old_Unused") then return d end
	end
	return nil
end

-- get-or-create; replaces a wrong-class instance only when FORCE=1
local function ensure(parent, name, className)
	local i = parent:FindFirstChild(name)
	if i and i.ClassName ~= className then
		if not FORCE then error(parent:GetFullName() .. "." .. name .. " is a " .. i.ClassName .. ", expected " .. className) end
		i.Parent = nil; i = nil
	end
	if not i then
		i = Instance.new(className); i.Name = name; i.Parent = parent
		note("created " .. i:GetFullName())
	end
	return i
end

local function setDefault(inst, name, value)
	if inst:GetAttribute(name) == nil then inst:SetAttribute(name, value) end
end

-- big IDs (badges, assets) > 2^31: store as strings, tonumber() at runtime
local function setIdDefault(inst, name, id)
	if type(inst:GetAttribute(name)) ~= "string" then inst:SetAttribute(name, tostring(id)) end
end

-- text patch: edits = { { marker, oldText, newText }, ... }; marker present => already applied
local function patch(sc, label, edits)
	if not sc then error("missing script for " .. label) end
	local s, n = sc.Source, 0
	for _, e in edits do
		local marker, old, new = e[1], e[2], e[3]
		if not string.find(s, marker, 1, true) then
			local a, b = string.find(s, old, 1, true)
			if not a then error(label .. ": anchor not found for " .. marker) end
			if string.find(s, old, b + 1, true) then error(label .. ": anchor not unique for " .. marker) end
			s = string.sub(s, 1, a - 1) .. new .. string.sub(s, b + 1)
			n += 1
		end
	end
	sc.Source = s
	note(string.format("%s: %d new edit(s)", label, n))
end

-- sounds in Lune 0.10: SoundId writes are lost; set AudioContent and read it back
local function setSound(sound, uri)
	sound.AudioContent = roblox.Content.fromUri(uri)
end

---------------------------------------------------------------- 1. tunables (owner edits these in Studio)
local cfgFolder = RS:FindFirstChild("Config") or ensure(RS, "Config", "Folder")
local cfg = ensure(cfgFolder, "MyFeature", "Configuration")
setDefault(cfg, "Enabled", true)
setDefault(cfg, "Cooldown", 2)
-- setIdDefault(cfg, "BadgeId", "<BADGE_ID>")

---------------------------------------------------------------- 2. a server script whose Source we own (refreshed every run)
local sys = SSS:FindFirstChild("Systems") or ensure(SSS, "Systems", "Folder")
local sv = ensure(sys, "MyFeatureServer", "Script")
local srcPath = HERE .. "MyFeatureServer.server.luau"
if fs.isFile(srcPath) then sv.Source = fs.readFile(srcPath) end

---------------------------------------------------------------- 3. anchor patch into someone else's script (example, off by default)
if process.env.EXAMPLE_PATCH == "1" then
	patch(findScript("CoreServer", SSS), "CoreServer", {
		{ "-- " .. MARK, 'Fx:FireAllClients("Sell", data)',
			'-- ' .. MARK .. ' fire after the object exists (Deferred signals)\n\ttask.defer(function() Fx:FireAllClients("Sell", data) end)' },
	})
end

---------------------------------------------------------------- write
fs.writeFile(OUT, roblox.serializePlace(game))
for _, l in log do print(l) end
print(MARK .. " applied: " .. #log .. " change(s) -> " .. OUT)
