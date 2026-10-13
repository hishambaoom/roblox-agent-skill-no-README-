-- Static reference checker CLI. IN=<place> [BEFORE=<place>] lune10 run check.luau
-- Prints every lookup that does not resolve. With BEFORE, matches scripts by OrganizedFrom/full path and
-- lists only refs that resolved in BEFORE but not in IN (exit 1 if any).
local fs=require("@lune/fs"); local roblox=require("@lune/roblox"); local process=require("@lune/process")
local RC=require("./refcheck")
local game=roblox.deserializePlace(fs.readFile(process.env.IN))
local res=RC.scan(game)
local total, miss = #res.refs, 0
local hard = 0
for _,r in res.refs do if not r.ok then miss+=1; if r.kind~="find" then hard+=1 end; if process.env.VERBOSE or not process.env.BEFORE then print((r.kind=="find" and "soft " or "HARD ")..RC.fmt(r)) end end end
print(string.format("refs=%d unresolved=%d (hard wait/dot=%d, soft FindFirstChild=%d)", total, miss, hard, miss-hard))
if process.env.BEFORE then
  local g0=roblox.deserializePlace(fs.readFile(process.env.BEFORE)); local r0=RC.scan(g0)
  local function key(sc) return sc:GetAttribute("OrganizedFrom") or sc:GetFullName() end
  local base={}
  for _,r in r0.refs do base[key(r.script).."|"..r.line.."|"..r.ord.."|"..r.step]=r.ok end
  local bad=0
  for _,r in res.refs do if not r.ok then local b=base[key(r.script).."|"..r.line.."|"..r.ord.."|"..r.step]; if b==true then bad+=1; print("REGRESSION "..RC.fmt(r)) end end end
  print("regressions vs BEFORE: "..bad)
  if bad>0 then process.exit(1) end
end
