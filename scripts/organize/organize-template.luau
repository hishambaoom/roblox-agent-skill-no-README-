--!nocheck
-- ORGANIZE template (derived from the ForgeTax organize pass). lune10. env IN, OUT. Idempotent. Run LAST in every chain.
--   IN=<place> OUT=<out> tools/lune10 run scripts/organize/organize-template.luau
-- Never deletes anything. Every move happens inside group(): after the group, refcheck re-resolves every
-- :WaitForChild / :FindFirstChild / dot lookup in every script; if a lookup that resolved before now fails, the
-- whole group is undone and printed as "LEFT IN PLACE". Moved/renamed instances get OrganizedFrom,
-- OrganizedFromParent, OrganizedFromName attributes (reverse.luau uses them to rebuild the old layout for tests).
-- Edit the MAPS section for your game; keep the framework as is.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local RC = require("./refcheck")
local Instance = roblox.Instance

local IN = process.env.IN or error("set IN")
local OUT = process.env.OUT or error("set OUT")
local game = roblox.deserializePlace(fs.readFile(IN))

local WS = game:GetService("Workspace")
local SS = game:GetService("ServerStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")

local before = RC.scan(game)
local done, skipped = {}, {}

local function allScripts()
	local t = {}
	for _, d in game:GetDescendants() do if d:IsA("LuaSourceContainer") then table.insert(t, d) end end
	return t
end
local function countNamed(name)
	local n = 0
	for _, d in game:GetDescendants() do if d.Name == name then n += 1 end end
	return n
end
local function esc(s) return (string.gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")) end

---------------------------------------------------------------- transactional groups
local function group(title, fn)
	local undo = {}
	local ctx = {}
	function ctx.folder(parent, name)
		local f = parent:FindFirstChild(name)
		if f then return f:IsA("Folder") and f or nil end
		f = Instance.new("Folder")
		f.Name = name
		f:SetAttribute("OrganizeCreated", true)
		f.Parent = parent
		table.insert(undo, { kind = "create", inst = f })
		return f
	end
	function ctx.move(inst, newParent, newName)
		if inst.Parent == newParent and (newName == nil or inst.Name == newName) then return false end
		table.insert(undo, { kind = "move", inst = inst, parent = inst.Parent, name = inst.Name,
			a1 = inst:GetAttribute("OrganizedFrom"), a2 = inst:GetAttribute("OrganizedFromParent"), a3 = inst:GetAttribute("OrganizedFromName") })
		if inst:GetAttribute("OrganizedFrom") == nil then
			inst:SetAttribute("OrganizedFrom", inst:GetFullName())
			inst:SetAttribute("OrganizedFromParent", inst.Parent:GetFullName())
			inst:SetAttribute("OrganizedFromName", inst.Name)
		end
		if newName then inst.Name = newName end
		inst.Parent = newParent
		return true
	end
	function ctx.setSource(sc, src)
		if sc.Source == src then return end
		table.insert(undo, { kind = "src", inst = sc, src = sc.Source })
		sc.Source = src
	end
	function ctx.setProp(inst, prop, value)
		table.insert(undo, { kind = "prop", inst = inst, prop = prop, value = inst[prop] })
		inst[prop] = value
	end
	local ok, err = pcall(fn, ctx)
	local bad = {}
	if ok then bad = RC.diff(before, RC.scan(game)) end
	if (not ok) or #bad > 0 or (type(err) == "string" and err ~= "") then
		for i = #undo, 1, -1 do
			local u = undo[i]
			if u.kind == "move" then
				u.inst.Name = u.name; u.inst.Parent = u.parent
				u.inst:SetAttribute("OrganizedFrom", u.a1); u.inst:SetAttribute("OrganizedFromParent", u.a2); u.inst:SetAttribute("OrganizedFromName", u.a3)
			elseif u.kind == "src" then u.inst.Source = u.src
			elseif u.kind == "prop" then u.inst[u.prop] = u.value
			elseif u.kind == "create" then if #u.inst:GetChildren() == 0 then u.inst.Parent = nil end end
		end
		local why = (not ok) and tostring(err) or (type(err) == "string" and err ~= "" and err) or ""
		for k = 1, math.min(#bad, 3) do why ..= " | " .. RC.fmt(bad[k]) end
		table.insert(skipped, title .. " -- " .. why)
		print("LEFT IN PLACE: " .. title .. " -- " .. why)
		return false
	end
	local moved = 0
	for _, u in undo do if u.kind == "move" then moved += 1 end end
	table.insert(done, string.format("%s (%d moved/renamed)", title, moved))
	return true
end

-- Rewrites lookups of a renamed instance in every script. Returns error text if the old name is still used
-- some other way (then the caller's group is undone).
local function rewriteRename(ctx, oldName, newName)
	local o, n = esc(oldName), newName
	for _, sc in allScripts() do
		local src = sc.Source
		local s2 = src
		s2 = string.gsub(s2, "(:%s*WaitForChild%s*%(%s*[\"'])" .. o .. "([\"'])", "%1" .. n .. "%2")
		s2 = string.gsub(s2, "(:%s*FindFirstChild%s*%(%s*[\"'])" .. o .. "([\"'])", "%1" .. n .. "%2")
		s2 = string.gsub(s2, "([%w_%)])%." .. o .. "(%f[^%w_])", "%1." .. n .. "%2")
		ctx.setSource(sc, s2)
		local code = RC.stripComments(s2)
		if string.find(code, "%f[%w_]" .. o .. "%f[^%w_]") then
			return sc:GetFullName() .. " still uses '" .. oldName .. "' in a way this pass cannot rewrite safely"
		end
	end
	return ""
end

---------------------------------------------------------------- MAPS (edit for your game)
-- 1. Client scripts at the StarterPlayerScripts root -> category folders
local CLIENT_FOLDERS = {
	-- ExampleUIClient = "UI", ExampleCamClient = "Camera", ExampleFxClient = "VFX",
}
if SPS then
	group("StarterPlayerScripts: client scripts into category folders", function(ctx)
		for _, sc in SPS:GetChildren() do
			local cat = sc:IsA("LocalScript") and CLIENT_FOLDERS[sc.Name]
			if cat then
				local f = ctx.folder(SPS, cat) or error("StarterPlayerScripts." .. cat .. " exists and is not a Folder")
				ctx.move(sc, f)
			end
		end
		return ""
	end)
end

-- 2. Loose Workspace models -> Workspace.Map
group("Workspace.Map: terrain props, baseplate, spawn", function(ctx)
	local map = ctx.folder(WS, "Map") or error("Workspace.Map exists and is not a Folder")
	for _, nm in { "Baseplate", "SpawnLocation" } do
		local c = WS:FindFirstChild(nm)
		if c then ctx.move(c, map) end
	end
	return ""
end)

-- 3. Renames (script lookups rewritten; refused if the old name is used some other way)
for _, pair in { -- { "Old_Folder_Name", "NewName" },
} do
	local oldName, newName = pair[1], pair[2]
	group("ServerStorage." .. oldName .. " -> ServerStorage." .. newName, function(ctx)
		local f = SS:FindFirstChild(oldName)
		if not f then return "" end
		if SS:FindFirstChild(newName) then return "ServerStorage." .. newName .. " already exists" end
		if countNamed(oldName) ~= 1 then return "more than one instance named " .. oldName end
		ctx.move(f, SS, newName)
		return rewriteRename(ctx, oldName, newName)
	end)
end

---------------------------------------------------------------- final check + write
local after = RC.scan(game)
local bad = RC.diff(before, after)
print("organize: " .. #done .. " groups applied, " .. #skipped .. " left in place, refs=" .. #after.refs .. ", regressions=" .. #bad)
for _, d in done do print("  done: " .. d) end
if #bad > 0 then
	for _, r in bad do print("REGRESSION " .. RC.fmt(r)) end
	error("organize produced broken references; OUT not written")
end
fs.writeFile(OUT, roblox.serializePlace(game))
print("wrote " .. OUT)
