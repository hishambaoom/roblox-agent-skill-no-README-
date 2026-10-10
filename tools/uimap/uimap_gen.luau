-- Generates compact style lines for ui-map.md. usage: lune run uimap_gen.luau <place> <path> [childDepth]
local roblox = require("@lune/roblox"); local fs = require("@lune/fs"); local process = require("@lune/process")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local Enum = roblox.Enum
local function find(path) local cur=game for seg in string.gmatch(path,"[^%.]+") do cur = cur:FindFirstChild(seg) or game:GetService(seg) end return cur end
local function hex(c) return string.format("#%02X%02X%02X", math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)) end
local function num(n) local s=string.format("%.2f",n) s=s:gsub("0+$",""):gsub("%.$","") return s end
local function id(img) return (tostring(img):match("(%d+)") or tostring(img)) end
local function cs(seq) local t={} local last for _,k in seq.Keypoints do local h=hex(k.Value) if h~=last then table.insert(t,h) last=h end end return table.concat(t,"→") end
local function ns(seq) local t={} local last for _,k in seq.Keypoints do local v=num(k.Value) if v~=last then table.insert(t,v) last=v end end return table.concat(t,"→") end
local function ud2(u) return num(u.X.Scale)..","..num(u.X.Offset)..","..num(u.Y.Scale)..","..num(u.Y.Offset) end
local function fmtv(v) local ty=typeof(v)
  if ty=="Color3" then return hex(v) elseif ty=="number" then return num(v) elseif ty=="UDim2" then return ud2(v) elseif ty=="UDim" then return num(v.Scale)..","..num(v.Offset) end
  return tostring(v) end
local function attrs(i) local t={} for k,v in i:GetAttributes() do table.insert(t,k.."="..fmtv(v)) end table.sort(t) return table.concat(t," ") end
local function short(f) local fam=tostring(f.Family):match("families/([%w_]+)") or tostring(f.Family) return fam.."/"..tostring(f.Weight):gsub("Enum.FontWeight.","") end
local function deco(i) -- direct style children
  local t={}
  for _,c in i:GetChildren() do
    if c:IsA("UIGradient") then table.insert(t,"grad"..(c.Name~="UIGradient" and "["..c.Name..(c.Enabled and "" or ",off").."]" or "").." "..cs(c.Color)..(c.Rotation~=0 and " r"..num(c.Rotation) or "")..(ns(c.Transparency)~="0" and " T"..ns(c.Transparency) or ""))
    elseif c:IsA("UICorner") then table.insert(t,"corner "..num(c.CornerRadius.Scale)..","..num(c.CornerRadius.Offset))
    elseif c:IsA("UIStroke") then local a=attrs(c) table.insert(t,"stroke"..((c.Name~="UIStroke" and c.Name~="Stroke") and "["..c.Name..(c.Enabled and "" or ",off").."]" or "").." "..num(c.Thickness).." "..hex(c.Color)..(c.Transparency>0 and " t"..num(c.Transparency) or "")..(c.ApplyStrokeMode==Enum.ApplyStrokeMode.Border and " border" or "")..(a~="" and " {"..a.."}" or ""))
    end
  end
  return t
end
local function isText(i) return i:IsA("TextLabel") or i:IsA("TextButton") or i:IsA("TextBox") end
local function textdesc(l,self)
  local s=short(l.FontFace).." "..hex(l.TextColor3)..(self and l.Text~="" and ' "'..string.sub(l.Text,1,18)..'"' or "")
  if l.TextStrokeTransparency<1 then s=s.." TS "..hex(l.TextStrokeColor3).." t"..num(l.TextStrokeTransparency) end
  if not self then for _,c in l:GetChildren() do if c:IsA("UIStroke") then s=s.." +stroke"..((c.Name~="UIStroke") and "["..c.Name..(c.Enabled and "" or ",off").."]" or "").." "..num(c.Thickness).." "..hex(c.Color) end if c:IsA("UIGradient") then s=s.." +grad "..cs(c.Color) end end end
  local a=l:GetAttributes() if a.Shadow~=nil then s=s.." @Shadow" end
  return s
end
local function studsOf(i)
  local out={}
  local function scan(x,depth)
    for _,c in x:GetChildren() do
      if (c:IsA("ImageLabel") or c:IsA("ImageButton")) and c.ScaleType==Enum.ScaleType.Tile and tostring(c.Image)~="" then
        local n=string.lower(c.Name)
        if string.find(n,"stud") or depth==1 or x:IsA("CanvasGroup") then
          local s="studs "..id(c.Image).." ts "..num(c.TileSize.X.Scale)..","..num(c.TileSize.X.Offset)..","..num(c.TileSize.Y.Scale)..","..num(c.TileSize.Y.Offset).." t"..num(c.ImageTransparency)
          if hex(c.ImageColor3)~="#FFFFFF" then s=s.." col "..hex(c.ImageColor3) end
          if x:IsA("CanvasGroup") and x.GroupTransparency>0 then s=s.." gT"..num(x.GroupTransparency) end
          local g=deco(c) if #g>0 then s=s.." ("..table.concat(g,"; ")..")" end
          table.insert(out,(depth>1 and (x.Name..">") or "")..c.Name..": "..s)
          if #out>=1 then return true end
        end
      end
      if (c:IsA("CanvasGroup") or c:IsA("Frame")) and depth<2 then if scan(c,depth+1) then return true end end
    end
  end
  if (i:IsA("ImageLabel") or i:IsA("ImageButton")) and i.ScaleType==Enum.ScaleType.Tile and string.find(string.lower(i.Name),"stud") then
    table.insert(out,"self: studs "..id(i.Image).." ts "..ud2(i.TileSize).." t"..num(i.ImageTransparency)) return out end
  scan(i,1)
  return out
end
local function line(i)
  local p={}
  local ok=pcall(function() return i.BackgroundColor3 end)
  if ok and i:IsA("GuiObject") then
    if i.BackgroundTransparency<1 then table.insert(p,"bg "..hex(i.BackgroundColor3)..(i.BackgroundTransparency>0 and "/t"..num(i.BackgroundTransparency) or "")) end
  end
  if (i:IsA("ImageLabel") or i:IsA("ImageButton")) and tostring(i.Image)~="" then
    table.insert(p,"img "..id(i.Image)..(i.ScaleType~=Enum.ScaleType.Stretch and " "..tostring(i.ScaleType):gsub("Enum.ScaleType.","") or "")..(i.ImageTransparency>0 and " t"..num(i.ImageTransparency) or "")..(hex(i.ImageColor3)~="#FFFFFF" and " col "..hex(i.ImageColor3) or ""))
  end
  if i:IsA("CanvasGroup") and i.GroupTransparency>0 then table.insert(p,"gT"..num(i.GroupTransparency)) end
  for _,d in deco(i) do table.insert(p,d) end
  for _,s in studsOf(i) do table.insert(p,s) end
  if isText(i) then table.insert(p,"text "..textdesc(i,true)) else
    -- main label: first text descendant (BFS depth<=2)
    local best
    for _,c in i:GetChildren() do if isText(c) then best=c break end end
    if not best then for _,c in i:GetChildren() do for _,g in c:GetChildren() do if isText(g) then best=g break end end if best then break end end end
    if best then table.insert(p,"label["..best.Name.."] "..textdesc(best)) end
  end
  local a=attrs(i) if a~="" then table.insert(p,"@{"..a.."}") end
  return table.concat(p," · ")
end
local root=find(process.args[2])
local depth=tonumber(process.args[3]) or 0
local skip={UICorner=1,UIStroke=1,UIGradient=1,UIAspectRatioConstraint=1,UITextSizeConstraint=1,UIPadding=1,UIListLayout=1,UISizeConstraint=1,UIFlexItem=1,UIGridLayout=1}
local function emit(i,rel,d)
  local l=line(i) if l=="" and (i:IsA("UIScale") or i:IsA("Camera") or i:IsA("WorldModel")) then return end
  print("`"..rel.."` ["..i.ClassName.."] "..line(i))
  if d<depth then for _,c in i:GetChildren() do if not skip[c.ClassName] then emit(c,rel.."."..c.Name,d+1) end end end
end
emit(root,process.args[4] or root.Name,0)
