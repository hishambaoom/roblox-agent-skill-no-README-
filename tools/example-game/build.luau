--!nocheck
--[[
	Example reproducible build (portable skeleton). Run from your game repo root:
	    BASE=work/base.rbxl BUILD_OUT=work/x/v1.rbxl tools/lune run tools/example-game/build.luau
	BASE      input place (.rbxl) - your template / last LIVE file (QUEUE.md "BASE next")
	BUILD_OUT output place (default: <GAME_DIR>/build/game.rbxl)
	GAME_DIR  folder holding hooks/ (default: the folder of this file, as seen from the repo root)
	Steps: load base -> cleanup -> ensure scaffolding -> run hooks in a FIXED order -> write place + build log.
	Each hook is `return function(ctx) ... end`, owned by exactly one agent, idempotent, logs one ctx.note line.
]]
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")

local GAME_DIR = process.env.GAME_DIR or "tools/example-game"
local BASE = process.env.BASE or process.env.IN
assert(BASE and fs.isFile(BASE), "set BASE=<input place .rbxl> (got " .. tostring(BASE) .. ")")
local OUT = process.env.BUILD_OUT or (GAME_DIR .. "/build/game.rbxl")

local game = roblox.deserializePlace(fs.readFile(BASE))
local Instance = roblox.Instance

local log = {}
local function note(s) table.insert(log, s); print(s) end
local function find(root, path)
	local node = root
	for _, name in string.split(path, ".") do
		if not node then return nil end
		node = node:FindFirstChild(name)
	end
	return node
end
local function ensure(parent, className, name)
	local inst = parent:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className); inst.Name = name; inst.Parent = parent
		note(("created %s.%s (%s)"):format(parent.Name, name, className))
	end
	return inst
end

local RS = game:GetService("ReplicatedStorage")

------------------------------------------------------------------ 1. cleanup (example: tracer/watermark scripts)
local removed = 0
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") and string.sub(d.Name, 1, 2) == "_!" then d:Destroy(); removed += 1 end
end
note(("cleanup: removed %d tracer script(s)"):format(removed))

------------------------------------------------------------------ 2. scaffolding (Studio-first homes)
local config = ensure(RS, "Folder", "Config")
local gs = config:FindFirstChild("GameSettings") or ensure(config, "Configuration", "GameSettings")
local uiT = ensure(RS, "Folder", "UITemplates")

------------------------------------------------------------------ 3. hooks (FIXED order; organize-style hooks LAST)
local ctx = {
	roblox = roblox, game = game, note = note, find = find, ensure = ensure,
	ReplicatedStorage = RS, StarterGui = game:GetService("StarterGui"), Workspace = game:GetService("Workspace"),
	GameSettings = gs, UITemplates = uiT, shared = {}, GAME_DIR = GAME_DIR, OUT = OUT,
}
local ran = {}
for _, name in { "build_example_ui" } do
	local path = GAME_DIR .. "/hooks/" .. name .. ".luau"
	if fs.isFile(path) then
		local chunk = require("./hooks/" .. name)
		chunk(ctx)
		table.insert(ran, name)
	end
end
note(("hooks: ran %d (%s)"):format(#ran, table.concat(ran, ", ")))

------------------------------------------------------------------ 4. write
local dir = string.match(OUT, "^(.*)/[^/]+$")
if dir and not fs.isDir(dir) then fs.writeDir(dir) end
fs.writeFile(OUT, roblox.serializePlace(game))
fs.writeFile(OUT .. ".log.txt", table.concat(log, "\n"))
print("wrote " .. OUT)
