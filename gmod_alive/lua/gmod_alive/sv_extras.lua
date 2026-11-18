-- ============================================================================
-- GMod Alive (fork) - sv_extras.lua
-- Prop shooting, multi-step task memory, G-Man god powers, extended context.
-- Must load AFTER sv_awareness.lua.
-- ============================================================================
local GA = GModAlive

local function alive(e) return IsValid(e) and (not (e:IsNPC() or e:IsPlayer()) or e:Health() > 0) end
local function isNPC(e) return IsValid(e) and GA.IsValidTalkTarget(e) and e:Health() > 0 end
local function admin(ply)
	return IsValid(ply) and (game.SinglePlayer() or ply:IsAdmin() or ply:IsSuperAdmin() or ply:IsListenServerHost())
end
local function move(npc, pos, run)
	if not npc.SetLastPosition or not npc.SetSchedule then return false end
	npc:SetLastPosition(pos) npc:SetSchedule(run and SCHED_FORCED_GO_RUN or SCHED_FORCED_GO)
	return true
end
local function weaponOf(npc)
	local w = npc.GetActiveWeapon and npc:GetActiveWeapon()
	return IsValid(w) and w or nil
end
local function visibleTo(npc, ent)
	return not util.TraceLine({ start = npc:EyePos(), endpos = ent:WorldSpaceCenter(), filter = { npc, ent } }).Hit
end

-- ---------------------------------------------------------------------------
-- Names: make the server compute every NPC's identity as soon as it exists so
-- clients always receive the authoritative name / seed (NWString / NWInt).
-- ---------------------------------------------------------------------------
hook.Add("OnEntityCreated", "GModAlive_PublishName", function(ent)
	timer.Simple(0.7, function() if IsValid(ent) and GA.IsValidTalkTarget(ent) then GA.InspectNPC(ent) end end)
end)

-- ---------------------------------------------------------------------------
-- Context: all known NPCs (any distance), shootable objects, current tasks
-- ---------------------------------------------------------------------------
local prevContext = GA.ActionContext
local OBJ_CLASSES = { prop_physics = true, prop_physics_multiplayer = true, prop_dynamic = true, func_breakable = true,
	prop_door_rotating = true, func_door = true, func_door_rotating = true, func_physbox = true }
function GA.ActionContext(npc, ply)
	local data = prevContext(npc, ply)
	local known = {}
	for _, e in ipairs(ents.GetAll()) do
		if e ~= npc and isNPC(e) then known[#known + 1] = e end
	end
	table.sort(known, function(a, b) return a:GetPos():DistToSqr(npc:GetPos()) < b:GetPos():DistToSqr(npc:GetPos()) end)
	data.known_npcs = {}
	for i = 1, math.min(30, #known) do
		local e = known[i]
		data.known_npcs[i] = { id = e:EntIndex(), name = GA.InspectNPC(e, ply).name, class = e:GetClass(),
			distance_units = math.Round(e:GetPos():Distance(npc:GetPos())) }
	end
	if GA.RuleEnabled and GetConVar("gmod_alive_shoot_props"):GetBool() and weaponOf(npc) then
		data.nearby_objects = {}
		for _, e in ipairs(ents.FindInSphere(npc:GetPos(), 700)) do
			if OBJ_CLASSES[e:GetClass()] and #data.nearby_objects < 8 and visibleTo(npc, e) then
				data.nearby_objects[#data.nearby_objects + 1] = { id = e:EntIndex(), class = e:GetClass(), model = e:GetModel() }
			end
		end
	end
	local t = npc.GModAlive_Tasks
	if t and t.steps[t.idx] then
		data.active_tasks = { current_step = t.steps[t.idx].raw, remaining = #t.steps - t.idx + 1 }
	end
	if npc.GModAlive_TaskNote then data.task_note = npc.GModAlive_TaskNote end
	if npc:GetClass() == "npc_gman" then data.you_are_gman_god = admin(ply) and GetConVar("gmod_alive_gman_god"):GetBool() end
	return data
end

-- ---------------------------------------------------------------------------
-- Shooting objects (props, doors)
-- ---------------------------------------------------------------------------
local shooters = setmetatable({}, { __mode = "k" })
local function shootObject(npc, ply, param)
	if not GetConVar("gmod_alive_shoot_props"):GetBool() then return false, "Shooting objects is disabled." end
	local obj = Entity(tonumber(string.Trim(tostring(param or ""))) or 0)
	if not IsValid(obj) or not OBJ_CLASSES[obj:GetClass()] then return false, "Not a valid object." end
	if not weaponOf(npc) then return false, "You have no weapon." end
	if npc:GetPos():DistToSqr(obj:GetPos()) > 1000 ^ 2 then return false, "The object is too far." end
	shooters[npc] = { obj = obj, shots = 0, max = 14, nextShot = CurTime() + 0.3 }
	return true
end

timer.Create("GModAlive_ShootObjects", 0.12, 0, function()
	for npc, st in pairs(shooters) do
		local w = IsValid(npc) and weaponOf(npc)
		if not w or not IsValid(st.obj) or st.shots >= st.max or npc:Health() <= 0 then
			shooters[npc] = nil
		elseif CurTime() >= st.nextShot then
			st.nextShot = CurTime() + 0.18
			local src = npc:EyePos()
			local dir = (st.obj:WorldSpaceCenter() - src):GetNormalized()
			npc:SetAngles(Angle(0, dir:Angle().y, 0))
			st.shots = st.shots + 1
			npc:FireBullets({ Attacker = npc, Inflictor = w, Damage = 12, Force = 6, Num = 1, Src = src, Dir = dir,
				Spread = Vector(0.012, 0.012, 0), Tracer = 1, IgnoreEntity = npc })
			pcall(function() w:EmitSound(w.Primary and w.Primary.Sound or "Weapon_Pistol.Single") end)
			local c = st.obj:GetClass()
			if string.find(c, "door", 1, true) and st.shots == 5 then -- lock shot off, door swings open
				st.obj:Fire("Unlock") st.obj:Fire("Open")
			end
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Multi-step tasks:  Find:id ; Tell:id:Verb:arg ; Say:id:text ; Come:player ; Wait:s
-- ---------------------------------------------------------------------------
local taskNPCs = setmetatable({}, { __mode = "k" })
local VERBS = { follow = "Follow", come = "Come", protect = "Protect", guard = "Guard", wait = "Wait", stay = "Wait",
	patrol = "Patrol", stop = "Stop", attack = "Attack", flee = "Flee", heal = "HealNPC" }

local function startTasks(npc, ply, param)
	local steps = {}
	for raw in string.gmatch(tostring(param or ""), "[^;]+") do
		raw = string.Trim(raw)
		local kind, a, b, c = string.match(raw, "^(%a+):?([^:]*):?([^:]*):?(.*)$")
		if kind then
			steps[#steps + 1] = { raw = raw, kind = string.lower(kind), a = a, b = b, c = c }
		end
		if #steps >= 6 then break end
	end
	if #steps == 0 then return false, "Empty task plan." end
	npc.GModAlive_Tasks = { steps = steps, idx = 1, ply = ply, started = CurTime() }
	npc.GModAlive_TaskNote = nil
	npc.GModAlive_FollowingPlayer = nil
	taskNPCs[npc] = true
	return true
end

local function finishStep(npc, t)
	t.idx = t.idx + 1 t.started = CurTime() t.nextMove = 0
	if not t.steps[t.idx] then npc.GModAlive_Tasks = nil taskNPCs[npc] = nil end
end

local function failTasks(npc, note)
	npc.GModAlive_Tasks = nil taskNPCs[npc] = nil npc.GModAlive_TaskNote = note
end

timer.Create("GModAlive_Tasks", 0.5, 0, function()
	if not GA.IsEnabled() then return end
	for npc in pairs(taskNPCs) do
		local t = IsValid(npc) and npc.GModAlive_Tasks
		if not t or npc:Health() <= 0 then taskNPCs[npc] = nil
		elseif GA.IsNPCConversationPaused and GA.IsNPCConversationPaused(npc) then t.started = t.started + 0.5
		else
			local st = t.steps[t.idx]
			local ply = IsValid(t.ply) and t.ply or player.GetAll()[1]
			if CurTime() - t.started > 120 then failTasks(npc, "task '" .. st.raw .. "' timed out")
			elseif st.kind == "wait" then
				if CurTime() - t.started >= math.Clamp(tonumber(st.a) or 3, 1, 30) then finishStep(npc, t) end
			else
				local dest
				if st.kind == "come" then dest = ply else
					dest = Entity(tonumber(st.a) or 0)
					if not isNPC(dest) then
						failTasks(npc, "the character you had to reach (id " .. tostring(st.a) .. ") no longer exists")
						dest = nil
					end
				end
				if dest then
					local near = st.kind == "tell" and 220 or 170
					if npc:GetPos():DistToSqr(dest:GetPos()) > near ^ 2 then
						if CurTime() >= (t.nextMove or 0) then
							t.nextMove = CurTime() + 1.5
							move(npc, dest:GetPos(), true)
						end
					elseif st.kind == "tell" then
						local verb = VERBS[string.lower(st.b)]
						local arg = string.lower(string.Trim(st.c))
						local target = arg == "player" and ply or (tonumber(arg) and Entity(tonumber(arg))) or nil
						if verb and GA.IssueOrder then
							if (verb == "Follow" or verb == "Come" or verb == "Protect") and not IsValid(target) then target = ply end
							GA.IssueOrder(npc, dest, verb, target, ply, {})
						end
						finishStep(npc, t)
					elseif st.kind == "say" then
						local text = string.Trim(st.b .. (st.c ~= "" and (":" .. st.c) or ""))
						if text ~= "" then
							GA.StartNPCSpeakingState(npc, text)
							GA.BroadcastNPCResponse(npc, ply, text, nil, nil, "")
						end
						finishStep(npc, t)
					else
						finishStep(npc, t) -- find / come: arrived
					end
				end
			end
		end
	end
end)

-- ---------------------------------------------------------------------------
-- G-Man god powers
-- ---------------------------------------------------------------------------
local function godAllowed(npc, ply)
	return IsValid(npc) and npc:GetClass() == "npc_gman" and GetConVar("gmod_alive_gman_god"):GetBool() and admin(ply)
end

local function deletable(e)
	if not IsValid(e) or e:IsPlayer() or e:IsWorld() or e:GetClass() == "npc_gman" then return false end
	local c = e:GetClass()
	return string.StartWith(c, "prop_") or string.StartWith(c, "gmod_") or string.StartWith(c, "item_")
		or string.StartWith(c, "weapon_") or c == "func_physbox" or string.StartWith(c, "sent_") or c == "func_breakable"
end

local function poof(e)
	local fx = EffectData() fx:SetOrigin(e:WorldSpaceCenter()) fx:SetScale(1) fx:SetMagnitude(1)
	util.Effect("cball_explode", fx, true, true)
end

local function godDelete(npc, ply, param)
	local what = string.lower(string.Trim(tostring(param or "")))
	local n = 0
	local function kill(e) if IsValid(e) then poof(e) e:Remove() n = n + 1 end end
	if what == "aim" then
		local e = ply:GetEyeTrace().Entity
		if deletable(e) or isNPC(e) then kill(e) end
	elseif what == "all_props" then
		for _, e in ipairs(ents.GetAll()) do if deletable(e) then kill(e) end end
	elseif what == "all_npcs" then
		for _, e in ipairs(ents.GetAll()) do if isNPC(e) and e ~= npc then kill(e) end end
	elseif string.StartWith(what, "npc:") then
		local e = Entity(tonumber(string.sub(what, 5)) or 0)
		if isNPC(e) and e ~= npc then kill(e) end
	elseif string.StartWith(what, "class:") then
		local c = string.Trim(string.sub(what, 7))
		for _, e in ipairs(ents.GetAll()) do
			if e ~= npc and (deletable(e) or isNPC(e)) and string.find(string.lower(e:GetClass()), c, 1, true) then kill(e) end
		end
	elseif string.StartWith(what, "props:") then
		local c = string.Trim(string.sub(what, 7))
		for _, e in ipairs(ents.GetAll()) do
			if deletable(e) and (string.find(string.lower(e:GetClass()), c, 1, true) or string.find(string.lower(e:GetModel() or ""), c, 1, true)) then kill(e) end
		end
	elseif string.StartWith(what, "near:") then
		local r = math.Clamp(tonumber(string.sub(what, 6)) or 500, 50, 5000)
		for _, e in ipairs(ents.FindInSphere(ply:GetPos(), r)) do
			if e ~= npc and (deletable(e) or isNPC(e)) then kill(e) end
		end
	else return false, "Unknown delete scope." end
	return n > 0, n == 0 and "Nothing matched." or nil
end

local SAFE_PREFIX = { "npc_", "prop_", "item_", "weapon_", "gmod_", "sent_", "vj_", "drg_", "zb_", "combine_", "monster_" }
local function resolveThing(thing)
	thing = string.Trim(tostring(thing or ""))
	local low = string.lower(thing)
	if string.EndsWith(low, ".mdl") then return { kind = "model", model = thing } end
	for _, listName in ipairs({ "NPC", "Vehicles", "SpawnableEntities" }) do
		local l = list.Get(listName)
		if l[thing] then return { kind = listName, entry = l[thing], key = thing } end
	end
	for _, listName in ipairs({ "NPC", "Vehicles", "SpawnableEntities" }) do -- fuzzy by key/name
		for key, entry in pairs(list.Get(listName)) do
			if string.find(string.lower(key), low, 1, true) or (isstring(entry.Name) and string.find(string.lower(entry.Name), low, 1, true)) then
				return { kind = listName, entry = entry, key = key }
			end
		end
	end
	for _, p in ipairs(SAFE_PREFIX) do
		if string.StartWith(low, p) then return { kind = "class", class = low } end
	end
end

local function spawnPositions(ply, where, count)
	local base, up = nil, Vector(0, 0, 0)
	if where == "aim" then
		local tr = ply:GetEyeTrace() base = tr.HitPos + tr.HitNormal * 12
	elseif where == "above" then
		base = ply:GetPos() + Vector(0, 0, ply:OBBMaxs().z + 90)
	else
		base = ply:GetPos() + ply:GetForward() * 70 + Vector(0, 0, 8)
	end
	local list = {}
	for i = 1, count do
		local ring = (i - 1) % 5 local row = math.floor((i - 1) / 5)
		list[i] = base + Vector(ring * 55 - 110, row * 55, row * 0)
		if where == "above" then list[i] = list[i] + Vector(0, 0, row * 60) end
	end
	return list
end

local function spawnOne(info, pos, ply)
	local ent
	if info.kind == "model" then
		ent = ents.Create("prop_physics") ent:SetModel(info.model)
	elseif info.kind == "class" then
		ent = ents.Create(info.class)
	elseif info.kind == "NPC" then
		local t = info.entry
		ent = ents.Create(t.Class or info.key)
		if not IsValid(ent) then return end
		if t.Model then ent:SetModel(t.Model) end
		for k, v in pairs(t.KeyValues or {}) do ent:SetKeyValue(k, v) end
		if t.SpawnFlags then ent:SetKeyValue("spawnflags", t.SpawnFlags) end
		if t.Weapons and #t.Weapons > 0 then ent:SetKeyValue("additionalequipment", table.Random(t.Weapons)) end
		ent:SetPos(pos) ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0)) ent:Spawn() ent:Activate()
		return ent
	elseif info.kind == "Vehicles" then
		local t = info.entry
		ent = ents.Create(t.Class)
		if not IsValid(ent) then return end
		if t.Model then ent:SetModel(t.Model) end
		for k, v in pairs(t.KeyValues or {}) do ent:SetKeyValue(k, v) end
		ent:SetPos(pos + Vector(0, 0, 25)) ent:SetAngles(Angle(0, ply:EyeAngles().y, 0)) ent:Spawn() ent:Activate()
		return ent
	else
		ent = ents.Create(info.entry.ClassName or info.key)
	end
	if not IsValid(ent) then return end
	ent:SetPos(pos) ent:SetAngles(Angle(0, ply:EyeAngles().y, 0)) ent:Spawn() ent:Activate()
	return ent
end

local function godSpawn(npc, ply, param)
	local thing, where, count = string.match(tostring(param or ""), "^([^:]+):?([^:]*):?(.*)$")
	where = string.lower(string.Trim(where or "")) if where == "" then where = "aim" end
	count = math.Clamp(tonumber(count) or 1, 1, 10)
	local info = resolveThing(thing)
	if not info then return false, "Unknown thing to spawn." end
	local made = 0
	for _, pos in ipairs(spawnPositions(ply, where, count)) do
		local e = IsValid(ply) and spawnOne(info, pos, ply)
		if IsValid(e) then made = made + 1 poof(e) end
	end
	return made > 0, made == 0 and "Spawn failed." or nil
end

local function godScope(scope, npc)
	scope = string.lower(string.Trim(tostring(scope or "")))
	local out = {}
	local function add(e) if isNPC(e) and e ~= npc then out[#out + 1] = e end end
	if scope == "all" then for _, e in ipairs(ents.GetAll()) do add(e) end
	elseif string.StartWith(scope, "id:") then add(Entity(tonumber(string.sub(scope, 4)) or 0))
	elseif string.StartWith(scope, "class:") then
		local c = string.Trim(string.sub(scope, 7))
		for _, e in ipairs(ents.GetAll()) do if isNPC(e) and string.find(string.lower(e:GetClass()), c, 1, true) then add(e) end end
	elseif string.StartWith(scope, "type:") then
		local c = string.Trim(string.sub(scope, 6))
		local words = ({ combine = { "combine", "metropolice", "overwatch" }, citizen = { "citizen", "eli", "alyx", "barney", "kleiner", "mossman", "monk", "breen" },
			rebel = { "citizen", "alyx", "barney", "monk" } })[c] or { c }
		for _, e in ipairs(ents.GetAll()) do
			if isNPC(e) then
				local cl = string.lower(e:GetClass())
				for _, w in ipairs(words) do if string.find(cl, w, 1, true) then add(e) break end end
			end
		end
	elseif string.StartWith(scope, "near:") then
		-- relative to the first player; radius clamped
		local ply = player.GetAll()[1]
		local r = math.Clamp(tonumber(string.sub(scope, 6)) or 600, 50, 6000)
		if IsValid(ply) then for _, e in ipairs(ents.FindInSphere(ply:GetPos(), r)) do add(e) end end
	end
	return out
end

local peaceful = setmetatable({}, { __mode = "k" })
local function release(e, ply)
	if e.GModAlive_Frozen then e:RemoveEFlags(EFL_NO_THINK_FUNCTION) e.GModAlive_Frozen = nil end
	peaceful[e] = nil
	e.GModAlive_Tasks = nil taskNPCs[e] = nil
	if GA.IssueOrder then GA.IssueOrder(e, e, "Stop", nil, ply, { noReply = true }) end
end

local function godOrder(npc, ply, param)
	local scope, cmd = string.match(tostring(param or ""), "^([^:]+:?[^:]*):(%a+)$")
	if not scope then scope, cmd = string.match(tostring(param or ""), "^(all):(%a+)$") end
	if not scope then return false, "Bad god order." end
	cmd = string.lower(cmd)
	local list = godScope(scope, npc)
	if #list == 0 then return false, "Nobody matched." end
	for _, e in ipairs(list) do
		if cmd == "dropweapons" then
			local w = weaponOf(e)
			if w then if not pcall(e.DropWeapon, e, w) then w:Remove() end end
		elseif cmd == "freeze" then
			e.GModAlive_Frozen = true e.GModAlive_FollowingPlayer = nil
			if e.SetSchedule then e:SetSchedule(SCHED_IDLE_STAND) end
			if e.SetEnemy then e:SetEnemy(NULL) end
			e:AddEFlags(EFL_NO_THINK_FUNCTION)
		elseif cmd == "unfreeze" then
			e:RemoveEFlags(EFL_NO_THINK_FUNCTION) e.GModAlive_Frozen = nil
		elseif cmd == "peaceful" then
			peaceful[e] = true
		elseif cmd == "hostile" then
			peaceful[e] = nil
		elseif cmd == "flee" then
			GA.ExecuteNPCAction(e, ply, "FleeFromTarget")
		elseif cmd == "follow" then
			if GA.IssueOrder then GA.IssueOrder(e, e, "Follow", ply, ply, { noReply = true }) end
		elseif cmd == "release" then
			release(e, ply)
		end
	end
	return true
end

timer.Create("GModAlive_Peaceful", 0.8, 0, function()
	for e in pairs(peaceful) do
		if not IsValid(e) then peaceful[e] = nil else
			e.GModAlive_HostileTo = nil e.GModAlive_CombatUntil = 0
			if e.SetEnemy then local en = e:GetEnemy() if IsValid(en) then
				pcall(e.AddEntityRelationship, e, en, D_NU, 99)
				e:SetEnemy(NULL) if e.ClearEnemyMemory then e:ClearEnemyMemory() end
				if e.SetSchedule then e:SetSchedule(SCHED_IDLE_STAND) end
			end end
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Action dispatch
-- ---------------------------------------------------------------------------
local previousExecute = GA.ExecuteNPCAction
function GA.ExecuteNPCAction(npc, ply, tag, param)
	if tag == "ShootObject" then return shootObject(npc, ply, param)
	elseif tag == "TaskPlan" then return startTasks(npc, ply, param)
	elseif tag == "GodDelete" or tag == "GodSpawn" or tag == "GodOrder" then
		if not godAllowed(npc, ply) then return false, "Only the G-Man may do this, with an admin player." end
		if tag == "GodDelete" then return godDelete(npc, ply, param)
		elseif tag == "GodSpawn" then return godSpawn(npc, ply, param) end
		return godOrder(npc, ply, param)
	end
	return previousExecute(npc, ply, tag, param)
end
