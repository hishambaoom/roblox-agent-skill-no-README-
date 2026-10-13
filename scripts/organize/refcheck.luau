--!nocheck
-- Static reference checker (from the ForgeTax organize agent). Pure function module, lune10.
-- scan(game) -> { refs = {ref...}, byKey = {[key]=ref} }
--   ref = { script=Instance, line=n, ord=n, step=n, kind="wait"|"find"|"dot", name=str, ok=bool, text=str }
-- Resolves chains that start at a known Instance: game, workspace/Workspace, script, game:GetService("X"),
-- or a local variable assigned from such a chain. Player containers map to their Starter* templates
-- (PlayerGui->StarterGui, PlayerScripts->StarterPlayerScripts, Backpack->StarterPack).
-- Every step that looks up a child (".Name", ":WaitForChild("Name")", ":FindFirstChild("Name"[, true])")
-- is recorded with ok=true/false. A failed step stops the chain.
local M = {}

-- Replace comments with spaces (keeps line numbers, keeps string contents).
local function stripComments(src)
	local out = table.create(#src)
	local i, n = 1, #src
	while i <= n do
		local c = string.sub(src, i, i)
		if c == "-" and string.sub(src, i, i + 1) == "--" then
			local eq = string.match(src, "^%[(=*)%[", i + 2)
			local j
			if eq then
				local close = "]" .. eq .. "]"
				local s, e = string.find(src, close, i + 2, true)
				j = e or n
			else
				j = (string.find(src, "\n", i, true) or (n + 1)) - 1
			end
			local chunk = string.sub(src, i, j)
			table.insert(out, (string.gsub(chunk, "[^\n]", " ")))
			i = j + 1
		elseif c == '"' or c == "'" then
			local j = i + 1
			while j <= n do
				local d = string.sub(src, j, j)
				if d == "\\" then j += 2
				elseif d == c or d == "\n" then break
				else j += 1 end
			end
			table.insert(out, string.sub(src, i, j))
			i = j + 1
		elseif c == "[" and string.match(src, "^%[=*%[", i) then
			local eq = string.match(src, "^%[(=*)%[", i)
			local close = "]" .. eq .. "]"
			local s, e = string.find(src, close, i + 2 + #eq, true)
			local j = e or n
			table.insert(out, string.sub(src, i, j))
			i = j + 1
		else
			table.insert(out, c)
			i += 1
		end
	end
	return table.concat(out)
end
M.stripComments = stripComments

local PLAYER_MAP = { PlayerGui = "StarterGui", PlayerScripts = "StarterPlayerScripts", Backpack = "StarterPack" }

local function svc(game, name)
	if name == "StarterPlayerScripts" then
		local sp = game:GetService("StarterPlayer")
		return sp and sp:FindFirstChildOfClass("StarterPlayerScripts")
	end
	-- never GetService here: it would add missing services (RunService...) to the saved place
	local s = game:FindFirstChildOfClass(name)
	if s == nil and name == "Workspace" then s = game:FindFirstChildOfClass("Workspace") end
	return s
end

-- is `name` a property/method of inst (not a child)?
local function isMember(inst, name)
	local ok, err = pcall(function() return inst[name] end)
	if ok then return true end
	err = tostring(err)
	if string.find(err, "missing default", 1, true) or string.find(err, "not implemented", 1, true) then return true end
	return false
end

-- x.Event:Connect(...) / x.Callback = fn / x.Method(...) -> a member, not a child lookup
local function looksLikeMember(line, after)
	local rest = string.sub(line, after or 1)
	if string.match(rest, "^%s*:%s*Connect") or string.match(rest, "^%s*:%s*Once") or string.match(rest, "^%s*:%s*Wait%s*%(")
		or string.match(rest, "^%s*:%s*ConnectParallel") then return true end
	if string.match(rest, "^%s*=[^=]") then return true end
	if string.match(rest, "^%s*%(") then return true end
	if string.match(rest, "^%s*[,%)]") or string.match(rest, "^%s*[=~]=") then return true end
	return false
end

local function findDesc(inst, name)
	return inst:FindFirstChild(name, true)
end

-- parse chain suffixes starting at position p in line; returns list of steps and end pos
local function parseSteps(line, p)
	local steps = {}
	while true do
		local m = string.match(line, "^%s*%.%s*([%a_][%w_]*)", p)
		if m then
			local s, e = string.find(line, "^%s*%.%s*[%a_][%w_]*", p)
			-- a following "(" means method-like call on a field -> stop before it
			table.insert(steps, { kind = "dot", name = m, after = e + 1 })
			p = e + 1
		else
			local meth, s1, e1
			s1, e1, meth = string.find(line, "^%s*:%s*([%a_][%w_]*)%s*%(", p)
			if not meth then break end
			if meth == "WaitForChild" or meth == "FindFirstChild" then
				local s2, e2, q, nm, rest = string.find(line, "^%s*([\"'])([^\"']*)%1%s*([,%)])", e1 + 1)
				if not s2 then break end
				local recursive = false
				local after = e2 + 1
				if rest == "," then
					local s3, e3, arg = string.find(line, "^%s*([%w_%.]+)%s*%)", after)
					if not s3 then break end
					if meth == "FindFirstChild" and arg == "true" then recursive = true end
					after = e3 + 1
				end
				table.insert(steps, { kind = meth == "WaitForChild" and "wait" or "find", name = nm, recursive = recursive })
				p = after
			elseif meth == "GetService" then
				local s2, e2, q, nm = string.find(line, "^%s*([\"'])([%w_]+)%1%s*%)", e1 + 1)
				if not s2 then break end
				table.insert(steps, { kind = "service", name = nm })
				p = e2 + 1
			else
				break
			end
		end
	end
	return steps, p
end

function M.scan(game)
	local refs, byKey = {}, {}
	local scripts = {}
	for _, d in game:GetDescendants() do
		if d:IsA("LuaSourceContainer") then table.insert(scripts, d) end
	end
	local ws = game:GetService("Workspace")
	for _, sc in scripts do
		local src = stripComments(sc.Source)
		local env = {}
		local ln = 0
		for line in string.gmatch(src .. "\n", "([^\n]*)\n") do
			ln += 1
			local ord = 0
			local p = 1
			-- function parameters / for-loop variables shadow tracked locals
			for params in string.gmatch(line, "function%s*[%w_%.:]*%s*%(([^%)]*)%)") do
				for nm in string.gmatch(params, "[%a_][%w_]*") do env[nm] = nil end
			end
			local forVars = string.match(line, "^%s*for%s+(.-)%s+in%s") or string.match(line, "^%s*for%s+([%a_][%w_]*)%s*=")
			if forVars then for nm in string.gmatch(forVars, "[%a_][%w_]*") do env[nm] = nil end end
			local localName = string.match(line, "^%s*local%s+([%a_][%w_]*)%s*=%s*")
			local localValueSet = false
			while p <= #line do
				local s, e, ident = string.find(line, "([%a_][%w_]*)", p)
				if not s then break end
				local prev = s > 1 and string.sub(line, s - 1, s - 1) or ""
				local prevNonSpace = string.match(string.sub(line, 1, s - 1), "(%S)%s*$") or ""
				-- skip when part of another chain (x.ident / x:ident) or inside a string
				local _, quotes = string.gsub(string.sub(line, 1, s - 1), "[\"']", "")
				if prevNonSpace == "." or prevNonSpace == ":" or (quotes % 2 == 1) then
					p = e + 1
				else
					local base, mapped = nil, nil
					if ident == "game" then base = game
					elseif ident == "workspace" or ident == "Workspace" then base = ws
					elseif ident == "script" then base = sc
					elseif env[ident] ~= nil then base = env[ident] end
					local steps, np = parseSteps(line, e + 1)
					if base ~= nil and #steps > 0 then
						ord += 1
						local cur = base
						local stepIdx = 0
						for _, st in steps do
							if cur == false then break end
							if st.kind == "service" then
								if cur == game then cur = svc(game, st.name) or false else cur = false end
							else
								local nm = st.name
								local child
								if st.kind == "dot" then
									if nm == "Parent" then child = cur.Parent
									elseif cur == game and svc(game, nm) and not cur:FindFirstChild(nm) then child = svc(game, nm)
									elseif PLAYER_MAP[nm] == nil and cur:FindFirstChild(nm) then child = cur:FindFirstChild(nm)
									elseif PLAYER_MAP[nm] then child = svc(game, PLAYER_MAP[nm])
									elseif isMember(cur, nm) or looksLikeMember(line, st.after) then child = nil; cur = false
									else child = nil end
									if cur ~= false and nm ~= "Parent" then
										stepIdx += 1
										local r = { script = sc, line = ln, ord = ord, step = stepIdx, kind = "dot", name = nm, ok = child ~= nil, text = line }
										table.insert(refs, r); byKey[sc] = byKey[sc] or {}; byKey[sc][ln .. ":" .. ord .. ":" .. stepIdx] = r
									end
									if cur ~= false then cur = child or false end
								else
									if PLAYER_MAP[nm] and not cur:FindFirstChild(nm) then
										child = svc(game, PLAYER_MAP[nm])
									elseif st.recursive then child = findDesc(cur, nm)
									else child = cur:FindFirstChild(nm) end
									stepIdx += 1
									local r = { script = sc, line = ln, ord = ord, step = stepIdx, kind = st.kind, name = nm, ok = child ~= nil, text = line }
									table.insert(refs, r); byKey[sc] = byKey[sc] or {}; byKey[sc][ln .. ":" .. ord .. ":" .. stepIdx] = r
									cur = child or false
								end
							end
						end
						if localName and not localValueSet and ord == 1 and string.match(string.sub(line, 1, s - 1), "^%s*local%s+[%a_][%w_]*%s*=%s*$") then
							-- local X = <this chain> [or ...]: keep the first resolved value
							env[localName] = cur ~= false and cur or nil
							localValueSet = true
						end
						p = np
					else
						-- player containers on unknown receivers (lp:WaitForChild("PlayerGui"))
						if base == nil and #steps > 0 and (steps[1].kind == "wait" or steps[1].kind == "find" or steps[1].kind == "dot") and PLAYER_MAP[steps[1].name] then
							local cur = svc(game, PLAYER_MAP[steps[1].name])
							ord += 1
							local stepIdx = 0
							for k = 2, #steps do
								local st = steps[k]
								if not cur or st.kind == "service" then break end
								local child
								if st.kind == "dot" then
									if st.name == "Parent" then child = cur.Parent
									elseif cur:FindFirstChild(st.name) then child = cur:FindFirstChild(st.name)
									elseif isMember(cur, st.name) or looksLikeMember(line, st.after) then break end
								elseif st.recursive then child = findDesc(cur, st.name)
								else child = cur:FindFirstChild(st.name) end
								stepIdx += 1
								local r = { script = sc, line = ln, ord = ord, step = stepIdx, kind = st.kind, name = st.name, ok = child ~= nil, text = line }
								table.insert(refs, r); byKey[sc] = byKey[sc] or {}; byKey[sc][ln .. ":" .. ord .. ":" .. stepIdx] = r
								cur = child
							end
							if localName and not localValueSet and ord == 1 and string.match(string.sub(line, 1, s - 1), "^%s*local%s+[%a_][%w_]*%s*=%s*$") then env[localName] = cur; localValueSet = true end
							p = np
						else
							p = e + 1
						end
					end
				end
			end
			-- a plain re-assignment of a local we track to something unknown -> forget it
			local reName = string.match(line, "^%s*local%s+([%a_][%w_]*)%s*=")
			if reName and not localValueSet then env[reName] = nil end
		end
	end
	return { refs = refs, byKey = byKey }
end

-- refs that resolved in `before` but fail in `after` (same script instances, same line/ord/step)
function M.diff(before, after)
	local bad = {}
	for _, r in after.refs do
		if not r.ok then
			local b = before.byKey[r.script] and before.byKey[r.script][r.line .. ":" .. r.ord .. ":" .. r.step]
			if b == nil or b.ok then table.insert(bad, r) end
		end
	end
	return bad
end

function M.fmt(r)
	return string.format("%s:%d %s(%q) -> %s | %s", r.script:GetFullName(), r.line, r.kind, r.name, r.ok and "ok" or "MISSING",
		(string.gsub(r.text, "^%s+", "")):sub(1, 140))
end

return M
