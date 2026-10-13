--!nocheck
-- Test helper: rebuilds the PRE-organize layout from an organized place (IN -> OUT), so the other agents'
-- tests (which use the old paths) can be run unchanged. Puts every instance with OrganizedFrom* attributes
-- back under its old parent/name, reverses the rename rewrites in script sources, and removes what organize
-- created (README modules, empty organize folders). Never use the output as a real place.
local fs=require("@lune/fs"); local roblox=require("@lune/roblox"); local process=require("@lune/process")
local game=roblox.deserializePlace(fs.readFile(process.env.IN))
local function find(pathStr)
	local cur = game
	for seg in string.gmatch(pathStr, "[^%.]+") do
		if not cur then return nil end
		if cur == game then local ok, s = pcall(function() return game:GetService(seg) end); cur = (ok and s) or game:FindFirstChild(seg)
		elseif seg == "StarterPlayerScripts" and cur:IsA("StarterPlayer") then cur = cur:FindFirstChildOfClass("StarterPlayerScripts")
		else cur = cur:FindFirstChild(seg) end
	end
	return cur
end
local renames = {}
local moved = {}
for _, d in game:GetDescendants() do if d:GetAttribute("OrganizedFromParent") then table.insert(moved, d) end end
for _, d in moved do
	local p = find(d:GetAttribute("OrganizedFromParent")) or error("cannot find old parent " .. d:GetAttribute("OrganizedFromParent"))
	local oldName = d:GetAttribute("OrganizedFromName")
	if oldName ~= d.Name then renames[d.Name] = oldName end
	d.Name = oldName; d.Parent = p
	d:SetAttribute("OrganizedFrom", nil); d:SetAttribute("OrganizedFromParent", nil); d:SetAttribute("OrganizedFromName", nil)
	if d:IsA("BaseScript") and d:FindFirstAncestor("_Old_Unused") == nil then end
end
local function esc(s) return (string.gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")) end
for newName, oldName in renames do
	local o, n = esc(newName), oldName
	for _, sc in game:GetDescendants() do if sc:IsA("LuaSourceContainer") then
		local s2 = sc.Source
		s2 = string.gsub(s2, "(:%s*WaitForChild%s*%(%s*[\"'])" .. o .. "([\"'])", "%1" .. n .. "%2")
		s2 = string.gsub(s2, "(:%s*FindFirstChild%s*%(%s*[\"'])" .. o .. "([\"'])", "%1" .. n .. "%2")
		s2 = string.gsub(s2, "(ServerStorage)%." .. o .. "(%f[^%w_])", "%1." .. n .. "%2")
		s2 = string.gsub(s2, "(Workspace)%." .. o .. "(%f[^%w_])", "%1." .. n .. "%2")
		if s2 ~= sc.Source then sc.Source = s2 end
	end end
end
for _, d in game:GetDescendants() do
	if d:GetAttribute("OrganizeCreated") and d:IsA("ModuleScript") and d.Name == "README" then d.Parent = nil end
end
local again = true
while again do
	again = false
	for _, d in game:GetDescendants() do
		if d:GetAttribute("OrganizeCreated") and d:IsA("Folder") and #d:GetChildren() == 0 then d.Parent = nil; again = true end
	end
end
fs.writeFile(process.env.OUT, roblox.serializePlace(game))
print("reverse: restored " .. #moved .. " instances -> " .. process.env.OUT)
