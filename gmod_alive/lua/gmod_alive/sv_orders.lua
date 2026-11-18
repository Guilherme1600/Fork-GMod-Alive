-- ============================================================================
-- GMod Alive (fork) - NPC Orders & Extra Actions (sv_orders.lua)
-- Lets an NPC command other NPCs (follow, guard, protect, patrol, attack...),
-- call for help, heal allies and play gestures.
-- Must load AFTER sv_behaviour.lua (it wraps GA.ExecuteNPCAction and
-- GA.ActionContext).
-- ============================================================================

if CLIENT then return end

local GA = GModAlive

local previousExecute = GA.ExecuteNPCAction
local previousContext = GA.ActionContext
if not previousExecute or not previousContext then
	ErrorNoHalt("[GMod Alive] sv_orders.lua must load after sv_behaviour.lua. Orders disabled.\n")
	return
end

local orders = {}                 -- recipient NPC -> active order
GA.ActiveOrders = orders
local lastReply = setmetatable({}, { __mode = "k" })
local issuerCooldown = setmetatable({}, { __mode = "k" })
local nextProtect = setmetatable({}, { __mode = "k" })

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------
local function alive(ent) return IsValid(ent) and ent:Health() > 0 end

local function visible(a, b)
	return not util.TraceLine({ start = a:WorldSpaceCenter(), endpos = b:WorldSpaceCenter(), filter = { a, b } }).Hit
end

local function actionsEnabled()
	local cv = GetConVar("gmod_alive_actions_enabled")
	return not cv or cv:GetBool()
end

local function ordersEnabled() return actionsEnabled() and GA.RuleEnabled("orders") end

local function maxOrders()
	local cv = GetConVar("gmod_alive_orders_max")
	return cv and cv:GetInt() or 8
end

local function canMove(npc) return npc.SetLastPosition ~= nil and npc.SetSchedule ~= nil end

local function move(npc, pos, run)
	if not canMove(npc) then return false end
	return pcall(function()
		npc:SetLastPosition(pos)
		npc:SetSchedule(run and SCHED_FORCED_GO_RUN or SCHED_FORCED_GO)
	end)
end

local function enemyOf(npc)
	if npc.GetEnemy then
		local ok, enemy = pcall(npc.GetEnemy, npc)
		if ok and IsValid(enemy) then return enemy end
	end
	return nil
end

local function inCombat(npc) return enemyOf(npc) ~= nil or IsValid(npc.GModAlive_HostileTo) end

local function disposition(npc, target)
	if IsValid(npc) and IsValid(target) and npc.Disposition then
		local ok, value = pcall(npc.Disposition, npc, target)
		if ok and isnumber(value) then return value end
	end
	return D_NU
end

local function label(ent, observer)
	if not IsValid(ent) then return "someone" end
	if ent:IsPlayer() then return ent:Nick() end
	local profile = GA.InspectNPC(ent, observer)
	return profile and profile.name or ent:GetClass()
end

local function activeCount()
	local n = 0
	for _ in pairs(orders) do n = n + 1 end
	return n
end

-- ---------------------------------------------------------------------------
-- Rank: decides how likely an NPC is to obey another one
-- ---------------------------------------------------------------------------
local classRank = {
	npc_gman = 9, npc_breen = 8, npc_eli = 6, npc_magnusson = 5, npc_odessa = 5,
	npc_alyx = 5, npc_barney = 5, npc_kleiner = 4, npc_mossman = 4, npc_monk = 4,
	npc_vortigaunt = 4, npc_combine_s = 3, npc_metropolice = 2, npc_citizen = 1
}
local leaderWords = { "captain", "commander", "leader", "sergeant", "lieutenant", "officer", "general", "chief", "boss" }

function GA.GetNPCRank(npc)
	if not IsValid(npc) then return 0 end
	local rank = classRank[npc:GetClass()] or 2
	local model = string.lower(npc:GetModel() or "")
	if string.find(model, "super_soldier", 1, true) then rank = rank + 1 end
	if npc:GetClass() == "npc_citizen" and string.find(model, "group03", 1, true) then rank = rank + 1 end
	local printName = string.lower(tostring(npc.PrintName or ""))
	for _, word in ipairs(leaderWords) do
		if string.find(printName, word, 1, true) then rank = rank + 2 break end
	end
	return rank
end

local function obedienceChance(issuer, recipient, verb, target)
	if GA.RuleEnabled("orders_always_obey") then return 1 end
	local attitude = disposition(recipient, issuer)
	if attitude == D_HT then return 0, "you are hostile toward the one giving the order" end
	local chance = 0.55 + (GA.GetNPCRank(issuer) - GA.GetNPCRank(recipient)) * 0.18
	if attitude == D_LI then chance = chance + 0.2 elseif attitude == D_FR then chance = chance + 0.1 end
	if verb == "Attack" then
		if IsValid(target) and disposition(recipient, target) == D_LI then chance = chance - 0.35 end
		if recipient:GetMaxHealth() > 0 and recipient:Health() < recipient:GetMaxHealth() * 0.3 then chance = chance - 0.25 end
	end
	if (verb == "Follow" or verb == "Come" or verb == "Protect") and IsValid(target) and target ~= recipient
		and disposition(recipient, target) == D_HT then
		return 0, "you are hostile toward the one you were told to follow"
	end
	local followed = recipient.GModAlive_FollowingPlayer
	if IsValid(followed) and followed:IsPlayer() and followed ~= issuer then chance = chance - 0.15 end
	return math.Clamp(chance, 0.05, 0.95)
end

-- ---------------------------------------------------------------------------
-- Order bookkeeping
-- ---------------------------------------------------------------------------
local function clearOrder(npc)
	local o = orders[npc]
	if not o then return end
	orders[npc] = nil
	if IsValid(npc) then
		if o.followed and npc.GModAlive_FollowingPlayer == o.followed then npc.GModAlive_FollowingPlayer = nil end
		if o.state and npc:GetNWString("GModAlive_ActionState", "") == o.state then npc:SetNWString("GModAlive_ActionState", "") end
	end
end

local function setState(npc, o, text)
	o.state = text
	npc:SetNWString("GModAlive_ActionState", text)
end

local function followEntity(npc, target, o)
	npc.GModAlive_FollowingPlayer = target
	npc.GModAlive_WaitHere = false
	npc.GModAlive_HostileTo = nil
	o.followed = target
	if npc.AddEntityRelationship and target ~= npc and disposition(npc, target) ~= D_HT then
		pcall(npc.AddEntityRelationship, npc, target, D_LI, 99)
	end
end

local function engage(npc, target, seconds)
	if not alive(target) or target == npc or not npc.SetEnemy or not npc.AddEntityRelationship then return false end
	npc.GModAlive_FollowingPlayer = nil
	npc.GModAlive_HostileTo = target
	npc.GModAlive_CombatUntil = CurTime() + (seconds or 45)
	npc:SetNWBool("GModAlive_Surrendered", false)
	return pcall(function()
		npc:AddEntityRelationship(target, D_HT, 99)
		npc:SetEnemy(target)
		if npc.UpdateEnemyMemory then npc:UpdateEnemyMemory(target, target:GetPos()) end
		if npc.SetSchedule then npc:SetSchedule(SCHED_CHASE_ENEMY) end
	end)
end

-- ---------------------------------------------------------------------------
-- Verbs: what each order does when it is accepted
-- ---------------------------------------------------------------------------
local appliers = {}
local steppers = {}

appliers.Follow = function(npc, issuer, o)
	local who = o.target or issuer
	if who == npc or not alive(who) then return false, "there is nobody to follow" end
	o.target = who
	followEntity(npc, who, o)
	setState(npc, o, "Following " .. label(who))
	return true
end

appliers.Come = function(npc, issuer, o)
	local who = o.target or issuer
	if who == npc or not alive(who) then return false, "there is nobody to walk to" end
	o.target = who
	npc.GModAlive_FollowingPlayer = nil
	move(npc, who:GetPos(), true)
	setState(npc, o, "Coming to " .. label(who))
	return true
end

appliers.Guard = function(npc, issuer, o)
	o.pos = npc:GetPos()
	local away = npc:GetPos() - (IsValid(issuer) and issuer:GetPos() or npc:GetPos())
	away.z = 0
	o.yaw = away:LengthSqr() > 1 and away:Angle().y or npc:GetAngles().y
	o.arrived = false
	npc.GModAlive_FollowingPlayer = nil
	setState(npc, o, "Guarding position")
	return true
end

appliers.Protect = function(npc, issuer, o)
	local protectee = o.target or issuer
	if not alive(protectee) or protectee == npc then return false, "there is nobody to protect" end
	o.protectee = protectee
	followEntity(npc, protectee, o)
	setState(npc, o, "Protecting " .. label(protectee))
	return true
end

appliers.Wait = function(npc, issuer, o)
	npc.GModAlive_FollowingPlayer = nil
	npc.GModAlive_WaitHere = true
	if npc.SetSchedule then pcall(npc.SetSchedule, npc, SCHED_IDLE_STAND) end
	setState(npc, o, "Waiting")
	return true
end

appliers.Patrol = function(npc, issuer, o)
	local center = npc:GetPos()
	local start = math.random() * 360
	o.points = {}
	for i = 0, 3 do
		local rad = math.rad(start + i * 90)
		local dir = Vector(math.cos(rad), math.sin(rad), 0)
		local dist = 240
		local from = center + Vector(0, 0, 40)
		local wall = util.TraceLine({ start = from, endpos = from + dir * dist, filter = npc })
		if wall.Hit then dist = math.max(60, wall.Fraction * dist - 40) end
		local point = center + dir * dist
		local floor = util.TraceLine({ start = point + Vector(0, 0, 40), endpos = point - Vector(0, 0, 120), mask = MASK_SOLID_BRUSHONLY })
		o.points[#o.points + 1] = floor.Hit and (floor.HitPos + Vector(0, 0, 4)) or point
	end
	o.index = 1
	o.pointDeadline = CurTime() + 10
	npc.GModAlive_FollowingPlayer = nil
	move(npc, o.points[1], false)
	setState(npc, o, "Patrolling")
	return true
end

appliers.Attack = function(npc, issuer, o)
	local target = o.target
	if not GA.RuleEnabled("aggression") then return false, "fighting is disabled" end
	if not alive(target) or target == npc or target == issuer then return false, "that target is not valid" end
	if not target:IsPlayer() and not GA.RuleEnabled("interactions") then return false, "fighting other NPCs is disabled" end
	if not engage(npc, target, 45) then return false, "you cannot fight" end
	setState(npc, o, "Attacking " .. label(target))
	return true
end

appliers.Flee = function(npc, issuer, o)
	local threat = o.target
	if not GA.RuleEnabled("flee") then return false, "fleeing is disabled" end
	if not IsValid(threat) or threat == npc then return false, "there is no threat to run from" end
	npc.GModAlive_FollowingPlayer = nil
	npc.GModAlive_HostileTo = nil
	pcall(function()
		if npc.SetEnemy then npc:SetEnemy(NULL) end
		if npc.AddEntityRelationship then npc:AddEntityRelationship(threat, D_FR, 99) end
	end)
	local dir = npc:GetPos() - threat:GetPos()
	dir.z = 0
	if dir:LengthSqr() < 1 then dir = npc:GetForward() end
	if not move(npc, npc:GetPos() + dir:GetNormalized() * 800, true) then return false, "you cannot run" end
	setState(npc, o, "Fleeing")
	return true
end

appliers.HealNPC = function(npc, issuer, o)
	local target = o.target or issuer
	o.target = target
	if not GA.RuleEnabled("inventory") then return false, "items are disabled" end
	if not alive(target) or target == npc then return false, "there is nobody to heal" end
	local inv = GA.EnsureNPCInventory(npc)
	if not inv.item_healthkit and not inv.item_healthvial then return false, "you have no health item" end
	npc.GModAlive_FollowingPlayer = nil
	setState(npc, o, "Going to heal " .. label(target))
	return true
end

-- Steppers run every 0.4 s for the active order. Returning false ends it.
steppers.Follow = function(npc, o)
	if not alive(o.followed) or npc.GModAlive_FollowingPlayer ~= o.followed then return false end
end

steppers.Come = function(npc, o, now)
	local dest = o.target or o.issuer
	if not IsValid(dest) then return false end
	local d2 = npc:GetPos():DistToSqr(dest:GetPos())
	if d2 < 140 ^ 2 then return false end
	if now >= o.nextMove then
		o.nextMove = now + 1
		move(npc, dest:GetPos(), d2 > 400 ^ 2)
	end
end

steppers.Guard = function(npc, o, now)
	if inCombat(npc) then return end
	local d2 = npc:GetPos():DistToSqr(o.pos)
	if d2 > 120 ^ 2 then
		o.arrived = false
		if now >= o.nextMove then
			o.nextMove = now + 1.5
			move(npc, o.pos, d2 > 500 ^ 2)
		end
	elseif not o.arrived then
		o.arrived = true
		if npc.SetSchedule then pcall(npc.SetSchedule, npc, SCHED_IDLE_STAND) end
		pcall(npc.SetAngles, npc, Angle(0, o.yaw or 0, 0))
	end
end

steppers.Patrol = function(npc, o, now)
	if inCombat(npc) then return end
	local point = o.points[o.index]
	local d2 = npc:GetPos():DistToSqr(point)
	if d2 < 90 ^ 2 or now > o.pointDeadline then
		if not o.holdUntil then o.holdUntil = now + 2 return end
		if now < o.holdUntil then return end
		o.holdUntil = nil
		o.index = o.index % #o.points + 1
		o.pointDeadline = now + 10
		move(npc, o.points[o.index], false)
	elseif now >= o.nextMove then
		o.nextMove = now + 2
		move(npc, point, false)
	end
end

steppers.Attack = function(npc, o)
	if not alive(o.target) then return false end
end

steppers.Protect = function(npc, o)
	if not alive(o.protectee) then return false end
	if not inCombat(npc) and npc.GModAlive_FollowingPlayer ~= o.protectee then npc.GModAlive_FollowingPlayer = o.protectee end
end

steppers.HealNPC = function(npc, o, now)
	local target = o.target
	if not alive(target) then return false end
	local d2 = npc:GetPos():DistToSqr(target:GetPos())
	if d2 < 130 ^ 2 then
		local inv = GA.EnsureNPCInventory(npc)
		local key = inv.item_healthkit and "item_healthkit" or inv.item_healthvial and "item_healthvial"
		if not key then return false end
		local maxHealth = math.max(target:GetMaxHealth(), target:Health())
		target:SetHealth(math.min(maxHealth, target:Health() + (key == "item_healthkit" and 25 or 10)))
		inv[key].count = inv[key].count - 1
		if inv[key].count <= 0 then inv[key] = nil end
		npc:EmitSound("items/smallmedkit1.wav", 70, 100)
		return false
	elseif now >= o.nextMove then
		o.nextMove = now + 1
		local offset = npc:GetPos() - target:GetPos()
		offset.z = 0
		if offset:LengthSqr() < 1 then offset = Vector(1, 0, 0) end
		move(npc, target:GetPos() + offset:GetNormalized() * 60, d2 > 400 ^ 2)
	end
end

local ttl = { Follow = 600, Come = 25, Guard = 200, Protect = 200, Wait = 150, Attack = 45, Flee = 10, Patrol = 200, HealNPC = 20 }
local recorded = {}
for verb in pairs(ttl) do recorded[verb] = true end
local movementVerbs = { Follow = true, Come = true, Guard = true, Protect = true, Patrol = true, Flee = true, HealNPC = true }

local verbAliases = {
	follow = "Follow", come = "Come", comehere = "Come", guard = "Guard", hold = "Guard",
	protect = "Protect", defend = "Protect", bodyguard = "Protect", wait = "Wait", stay = "Wait",
	attack = "Attack", kill = "Attack", flee = "Flee", run = "Flee", retreat = "Flee",
	patrol = "Patrol", fetch = "Fetch", pickup = "Fetch", stop = "Stop", standdown = "Stop", cancel = "Stop",
	heal = "HealNPC", healnpc = "HealNPC"
}

local function describeOrder(verb, target, observer)
	local who = target and label(target, observer) or "someone"
	local text = {
		Follow = "follow " .. who, Come = "walk to " .. who, Guard = "guard the spot where you are standing",
		Protect = "protect " .. who .. " like a bodyguard", Wait = "stay where you are", Patrol = "patrol this area",
		Attack = "attack " .. who, Flee = "run away from " .. who, Fetch = "go and pick up a nearby item",
		HealNPC = "heal " .. who, Stop = "stand down and drop your current orders"
	}
	return text[verb] or verb
end

-- ---------------------------------------------------------------------------
-- Spoken reply of the ordered NPC (one extra AI request)
-- ---------------------------------------------------------------------------
local function replyToOrder(issuer, recipient, observer, verb, target, accepted, reason)
	if not GA.RuleEnabled("orders_spoken_reply") or not GA.GenerateNPCResponse then return end
	if (lastReply[recipient] or 0) > CurTime() then return end
	lastReply[recipient] = CurTime() + 10
	local language = IsValid(observer) and observer.GModAlive_LastUtterance or "Hello"
	local text = string.format(
		"[ORDER] %s just gave you this order: %s. Game decision: you %s%s. React with ONE short spoken in-character line (under 20 words), with no action tags, in the language of this earlier player utterance: %s",
		label(issuer, observer), describeOrder(verb, target, observer),
		accepted and "ACCEPT it and start carrying it out" or "REFUSE it",
		(not accepted and reason) and (" (" .. reason .. ")") or "",
		tostring(language))
	timer.Simple(2.5 + math.random() * 1.5, function()
		if not alive(recipient) then return end
		GA.SetNPCStatus(recipient, "thinking")
		GA.GenerateNPCResponse({ ply = observer, npc = recipient, userText = text }, function(ok, response, profile)
			if IsValid(recipient) then GA.SetNPCStatus(recipient, "") end
			if not ok or not istable(response) or response.spokenText == "" or not alive(recipient) then return end
			GA.StartNPCSpeakingState(recipient, response.spokenText)
			GA.BroadcastNPCResponse(recipient, observer, response.spokenText, nil, profile, "")
		end)
	end)
end

local function record(issuer, recipient, verb, accepted, reason, observer)
	local list = issuer.GModAlive_RecentOrders or {}
	issuer.GModAlive_RecentOrders = list
	list[#list + 1] = { to = label(recipient, observer), verb = verb, obeyed = accepted, reason = (not accepted) and reason or nil, time = CurTime() }
	while #list > 3 do table.remove(list, 1) end
end

-- ---------------------------------------------------------------------------
-- Public API: issue one order to one NPC
-- Returns accepted(bool), reason(string|nil)
-- ---------------------------------------------------------------------------
function GA.IssueOrder(issuer, recipient, verb, target, observer, opts)
	opts = opts or {}
	if not ordersEnabled() then return false, "NPC orders are disabled." end
	if not alive(issuer) or not alive(recipient) then return false, "Invalid NPC." end
	local selfOrder = issuer == recipient
	if not GA.IsValidTalkTarget(recipient) then return false, "That character cannot take orders." end
	if movementVerbs[verb] and not canMove(recipient) then return false, "This NPC framework does not support movement orders." end
	if not selfOrder and GA.IsNPCConversationPaused and GA.IsNPCConversationPaused(recipient) then return false, "The NPC is busy talking." end
	if not orders[recipient] and activeCount() >= maxOrders() then return false, "Too many orders are active." end

	local accepted, reason = true, nil
	if not selfOrder then
		local chance, why = obedienceChance(issuer, recipient, verb, target)
		if math.random() >= chance then
			accepted = false
			reason = why or "you do not feel like taking orders from them"
		end
	end

	if accepted then
		clearOrder(recipient)
		local order = { issuer = issuer, verb = verb, target = target, expires = CurTime() + (ttl[verb] or 60), nextMove = 0 }
		local ok, why = true, nil
		if verb == "Fetch" then
			ok, why = previousExecute(recipient, issuer, "PickupItem", opts.argText)
		elseif verb ~= "Stop" then
			ok, why = appliers[verb](recipient, issuer, order)
		end
		if ok == false then
			accepted = false
			reason = why or "you are unable to do that"
		elseif recorded[verb] then
			orders[recipient] = order
		end
	end

	if not selfOrder then
		record(issuer, recipient, verb, accepted, reason, observer)
		if not opts.noReply then replyToOrder(issuer, recipient, observer, verb, target, accepted, reason) end
	end
	return accepted, reason
end

-- ---------------------------------------------------------------------------
-- Tag handling
-- ---------------------------------------------------------------------------
local function lookup(issuer, text, ply)
	text = string.lower(string.Trim(tostring(text or "")))
	if text == "" then return nil end
	if text == "player" then return IsValid(ply) and ply or nil end
	if text == "me" or text == "self" then return issuer end
	local id = tonumber(text)
	local ent = id and Entity(id)
	if not IsValid(ent) then return nil end
	if ent ~= issuer and (issuer:GetPos():DistToSqr(ent:GetPos()) > 900 ^ 2 or not visible(issuer, ent)) then return nil end
	return ent
end

local function sortedByDistance(list, origin)
	table.sort(list, function(a, b) return a:GetPos():DistToSqr(origin) < b:GetPos():DistToSqr(origin) end)
	while #list > 4 do table.remove(list) end
	return list
end

local function squadCandidates(issuer)
	local list = {}
	for _, ent in ipairs(ents.FindInSphere(issuer:GetPos(), 700)) do
		if ent ~= issuer and GA.IsValidTalkTarget(ent) and alive(ent) and disposition(ent, issuer) ~= D_HT and visible(issuer, ent) then
			list[#list + 1] = ent
		end
	end
	return sortedByDistance(list, issuer:GetPos())
end

local function parseOrder(param)
	local parts = {}
	for piece in string.gmatch(tostring(param or ""), "[^:]+") do parts[#parts + 1] = string.Trim(piece) end
	return parts[1], parts[2], parts[3]
end

-- Collective ordering: one NPC thinks (the issuer), the server delivers the order
-- to every recipient. recipient text: id | id,id,id | all | type:x | class:x | area:radius
local TYPE_WORDS = {
	combine = { "combine", "metropolice", "overwatch", "stalker" },
	citizen = { "citizen", "eli", "alyx", "barney", "kleiner", "mossman", "monk", "breen" },
	rebel = { "citizen", "alyx", "barney", "monk", "vortigaunt" },
	zombie = { "zombie", "headcrab" }, antlion = { "antlion" }
}
local function anyNPC(ent) return IsValid(ent) and GA.IsValidTalkTarget(ent) and alive(ent) end
function GA.ResolveOrderRecipients(issuer, text, ply, squadFn)
	text = string.lower(string.Trim(tostring(text or "")))
	local out, seen = {}, { [issuer] = true }
	local function add(e) if anyNPC(e) and not seen[e] and #out < 15 then seen[e] = true out[#out + 1] = e end end
	if text == "all" then
		for _, e in ipairs(ents.FindInSphere(issuer:GetPos(), 1500)) do
			if disposition(e, issuer) ~= D_HT then add(e) end
		end
	elseif string.StartWith(text, "type:") or string.StartWith(text, "class:") then
		local kind, word = string.match(text, "^(%a+):(.+)$")
		word = string.Trim(word or "")
		local words = kind == "type" and TYPE_WORDS[word] or { word }
		for _, e in ipairs(ents.GetAll()) do
			if anyNPC(e) then
				local hay = string.lower(e:GetClass() .. " " .. (e:GetModel() or ""))
				for _, w in ipairs(words or { word }) do
					if string.find(hay, w, 1, true) then add(e) break end
				end
			end
		end
	elseif string.StartWith(text, "area:") then
		local r = math.Clamp(tonumber(string.sub(text, 6)) or 600, 100, 2500)
		for _, e in ipairs(ents.FindInSphere(issuer:GetPos(), r)) do add(e) end
	else
		for piece in string.gmatch(text, "[^,]+") do
			local e = lookup(issuer, piece, ply)
			if not IsValid(e) then
				local id = tonumber(string.Trim(piece))
				local far = id and Entity(id)
				if IsValid(far) and issuer:GetPos():DistToSqr(far:GetPos()) <= 2500 ^ 2 then e = far end
			end
			add(e)
		end
	end
	table.sort(out, function(a, b) return a:GetPos():DistToSqr(issuer:GetPos()) < b:GetPos():DistToSqr(issuer:GetPos()) end)
	return out
end

local function handleOrderTag(npc, ply, param)
	local recipientText, verbText, argText = parseOrder(param)
	local verb = verbAliases[string.lower(string.gsub(verbText or "", "[%s_%-]", ""))]
	if not verb then return false, "Unknown order." end
	if (issuerCooldown[npc] or 0) > CurTime() then return false, "The NPC just gave an order." end

	local recipients = GA.ResolveOrderRecipients(npc, recipientText, ply, squadCandidates)
	if #recipients == 0 then return false, "No valid nearby NPC to order." end

	local target
	if verb == "Attack" or verb == "Flee" then
		target = lookup(npc, argText, ply)
		if not IsValid(target) then return false, "The order has no valid target." end
	elseif verb == "Follow" or verb == "Come" or verb == "Protect" then
		-- Default is the PLAYER; "me"/"self" in the tag means the issuing NPC.
		target = lookup(npc, argText, ply)
		if not IsValid(target) then target = ply end
	elseif verb == "HealNPC" then
		target = lookup(npc, argText, ply) or npc
	end

	issuerCooldown[npc] = CurTime() + 6
	local accepted, lastReason = 0, nil
	for index, recipient in ipairs(recipients) do
		local ok, reason = GA.IssueOrder(npc, recipient, verb, target, ply, { noReply = index > 1, argText = argText })
		if ok then accepted = accepted + 1 else lastReason = reason end
	end
	if accepted == 0 then return false, lastReason or "Nobody obeyed." end
	return true
end

local function callForHelp(npc, ply)
	local enemy = enemyOf(npc)
	local threat = npc.GModAlive_RecentThreat
	if not alive(enemy) and threat and CurTime() - threat.time < 20 then
		local candidate = Entity(threat.entity)
		if alive(candidate) then enemy = candidate end
	end
	if not alive(enemy) then enemy = nil end

	local helpers = {}
	for _, ent in ipairs(ents.FindInSphere(npc:GetPos(), 1200)) do
		if ent ~= npc and ent ~= enemy and GA.IsValidTalkTarget(ent) and alive(ent) and disposition(ent, npc) ~= D_HT
			and not (GA.IsNPCConversationPaused and GA.IsNPCConversationPaused(ent)) then
			helpers[#helpers + 1] = ent
		end
	end
	if #helpers == 0 then return false, "Nobody is close enough to hear." end
	sortedByDistance(helpers, npc:GetPos())

	local answered = 0
	for index, helper in ipairs(helpers) do
		local ok
		if enemy then ok = GA.IssueOrder(npc, helper, "Attack", enemy, ply, { noReply = index > 1 })
		else ok = GA.IssueOrder(npc, helper, "Come", nil, ply, { noReply = index > 1 }) end
		if ok then answered = answered + 1 end
	end
	if answered == 0 then return false, "Nobody answered the call." end
	return true
end

local gestures = {
	wave = { "ACT_GMOD_GESTURE_WAVE", "ACT_WAVE" },
	salute = { "ACT_GMOD_GESTURE_SALUTE", "ACT_SALUTE" },
	halt = { "ACT_SIGNAL_HALT", "ACT_GMOD_GESTURE_BECON" },
	forward = { "ACT_SIGNAL_FORWARD", "ACT_SIGNAL_GROUP" },
	bow = { "ACT_GMOD_GESTURE_BOW" },
	agree = { "ACT_GMOD_GESTURE_AGREE" },
	disagree = { "ACT_GMOD_GESTURE_DISAGREE" },
	cheer = { "ACT_GMOD_TAUNT_CHEER" }
}

local function playGesture(npc, name)
	local list = gestures[string.lower(string.Trim(tostring(name or "")))] or gestures.wave
	for _, actName in ipairs(list) do
		local act = _G[actName]
		if isnumber(act) and npc:SelectWeightedSequence(act) >= 0 then
			pcall(npc.RestartGesture, npc, act, true, true)
			return true
		end
	end
	return false, "This model has no animation for that gesture."
end

local handled = { OrderNPC = true, CallForHelp = true, HealNPC = true, Gesture = true, GuardPosition = true, PatrolArea = true, ProtectTarget = true }

function GA.ExecuteNPCAction(npc, ply, tag, param)
	if not handled[tag] then
		-- Any other action (flee, follow the player, wait...) overrides an active order.
		if tag and tag ~= "" and orders[npc] then clearOrder(npc) end
		return previousExecute(npc, ply, tag, param)
	end
	if not IsValid(npc) or not actionsEnabled() then return false, "NPC actions are disabled." end
	if GA.EndNPCConversation then GA.EndNPCConversation(npc) end

	if tag == "Gesture" then return playGesture(npc, param) end
	if not ordersEnabled() then return false, "NPC orders are disabled." end

	if tag == "OrderNPC" then return handleOrderTag(npc, ply, param)
	elseif tag == "CallForHelp" then return callForHelp(npc, ply)
	elseif tag == "GuardPosition" then return GA.IssueOrder(npc, npc, "Guard", nil, ply, { noReply = true })
	elseif tag == "PatrolArea" then return GA.IssueOrder(npc, npc, "Patrol", nil, ply, { noReply = true })
	elseif tag == "ProtectTarget" then
		local target = (param and param ~= "") and lookup(npc, param, ply) or ply
		if not IsValid(target) then return false, "Nobody valid to protect." end
		return GA.IssueOrder(npc, npc, "Protect", target, ply, { noReply = true })
	elseif tag == "HealNPC" then
		local target = lookup(npc, param, ply)
		if not IsValid(target) then return false, "Nobody valid to heal." end
		return GA.IssueOrder(npc, npc, "HealNPC", target, ply, { noReply = true })
	end
	return false, "Unsupported action."
end

-- ---------------------------------------------------------------------------
-- Context shown to the AI (ranks, attitudes, active and recent orders)
-- ---------------------------------------------------------------------------
function GA.ActionContext(npc, ply)
	local data = previousContext(npc, ply)
	if not ordersEnabled() then return data end
	data.your_rank = GA.GetNPCRank(npc)
	for _, entry in ipairs(data.nearby_npcs or {}) do
		local other = Entity(entry.id)
		if IsValid(other) then
			entry.rank = GA.GetNPCRank(other)
			local attitude = disposition(npc, other)
			entry.attitude_towards_them = attitude == D_LI and "friendly" or attitude == D_HT and "hostile" or attitude == D_FR and "afraid" or "neutral"
			if orders[other] then entry.under_order = orders[other].verb end
		end
	end
	if orders[npc] then data.current_order = orders[npc].verb end
	local recent = {}
	for _, item in ipairs(npc.GModAlive_RecentOrders or {}) do
		local age = CurTime() - item.time
		if age < 180 then
			recent[#recent + 1] = { to = item.to, verb = item.verb, obeyed = item.obeyed, reason = item.reason, seconds_ago = math.Round(age) }
		end
	end
	if #recent > 0 then data.recent_orders = recent end
	return data
end

-- ---------------------------------------------------------------------------
-- Update loop
-- ---------------------------------------------------------------------------
timer.Create("GModAlive_Orders", 0.4, 0, function()
	if not GA.IsEnabled() then return end
	local now = CurTime()
	local enabled = ordersEnabled()
	for npc, o in pairs(orders) do
		if not alive(npc) or now > o.expires or not enabled then
			clearOrder(npc)
		elseif GA.IsNPCConversationPaused and GA.IsNPCConversationPaused(npc) then
			o.expires = o.expires + 0.4
		else
			local step = steppers[o.verb]
			if step and step(npc, o, now) == false then clearOrder(npc) end
		end
	end
end)

hook.Add("EntityRemoved", "GModAlive_OrdersCleanup", function(ent) orders[ent] = nil end)

-- Bodyguards retaliate against whoever hurts their protectee.
hook.Add("EntityTakeDamage", "GModAlive_ProtectOrders", function(victim, damage)
	if not next(orders) or damage:GetDamage() <= 0 then return end
	local attacker = damage:GetAttacker()
	if not alive(attacker) or attacker == victim then return end
	if not attacker:IsPlayer() and not GA.IsValidTalkTarget(attacker) then return end
	for npc, o in pairs(orders) do
		if o.verb == "Protect" and o.protectee == victim and npc ~= attacker and alive(npc)
			and (nextProtect[npc] or 0) < CurTime() and GA.RuleEnabled("aggression") and disposition(npc, attacker) ~= D_LI then
			nextProtect[npc] = CurTime() + 3
			local protector = npc
			timer.Simple(0, function()
				if alive(protector) and alive(attacker) then engage(protector, attacker, 45) end
			end)
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Console helpers (admin / single-player) to test orders without the AI
-- ---------------------------------------------------------------------------
local function isAdmin(ply) return not IsValid(ply) or game.SinglePlayer() or ply:IsSuperAdmin() end

concommand.Add("gmod_alive_npc_ids", function(ply)
	if not isAdmin(ply) or not IsValid(ply) then return end
	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 1200)) do
		if GA.IsValidTalkTarget(ent) then
			ply:PrintMessage(HUD_PRINTCONSOLE, string.format("[GMod Alive] id=%d  %s  (%s)  rank=%d\n", ent:EntIndex(), label(ent, ply), ent:GetClass(), GA.GetNPCRank(ent)))
		end
	end
end)

-- gmod_alive_test_order <issuerId> <recipientId|all> <verb> [arg]
concommand.Add("gmod_alive_test_order", function(ply, _, args)
	if not isAdmin(ply) then return end
	local issuer = Entity(tonumber(args[1]) or 0)
	local reply = function(text) if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, "[GMod Alive] " .. text .. "\n") else print("[GMod Alive] " .. text) end end
	if not IsValid(issuer) or not GA.IsValidTalkTarget(issuer) then reply("Usage: gmod_alive_test_order <issuerId> <recipientId|all> <verb> [arg]  (see gmod_alive_npc_ids)") return end
	local param = table.concat({ args[2] or "", args[3] or "", args[4] or "" }, ":")
	issuerCooldown[issuer] = nil
	local ok, reason = GA.ExecuteNPCAction(issuer, ply, "OrderNPC", param)
	reply(ok == false and ("Not completed: " .. tostring(reason)) or "Order sent.")
end)
