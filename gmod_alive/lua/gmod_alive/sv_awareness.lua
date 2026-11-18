-- ============================================================================
-- GMod Alive (fork) - Self-awareness (sv_awareness.lua)
-- World event log + periodic / event-driven NPC "thinking".
-- Must load AFTER sv_orders.lua / sv_trade.lua.
-- ============================================================================
local GA = GModAlive
local FL = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)

local cvEnabled   = CreateConVar("gmod_alive_aware_enabled",    "0",    FL, "NPCs think about the world on their own (all NPCs).")
local cvInterval  = CreateConVar("gmod_alive_aware_interval",   "12",   FL, "Seconds between ambient thoughts.")
local cvNpcRadius = CreateConVar("gmod_alive_aware_npc_radius", "1200", FL, "Radius (units) in which an NPC perceives events.")
local cvPlyRadius = CreateConVar("gmod_alive_aware_player_radius", "1800", FL, "An NPC only thinks if a player is within this radius.")
local cvMaxArea   = CreateConVar("gmod_alive_aware_max_per_area", "3",  FL, "Max NPCs that may think at the same time in one area.")
local cvReact     = CreateConVar("gmod_alive_aware_react_delay", "1.2", FL, "Seconds before an NPC reacts to an event it witnessed.")

util.AddNetworkString("GModAlive_ToggleAware")

local function alive(e) return IsValid(e) and (not e:IsNPC() or e:Health() > 0) and (e:IsNPC() or e:IsPlayer() or e:IsNextBot()) end

local function isAdmin(ply)
	return IsValid(ply) and (game.SinglePlayer() or ply:IsAdmin() or ply:IsSuperAdmin() or ply:IsListenServerHost())
end

-- ---------------------------------------------------------------------------
-- World event log
-- ---------------------------------------------------------------------------
GA.WorldEvents = GA.WorldEvents or {}
local MAX_EVENTS = 60

local function nameOf(ent, observer)
	if not IsValid(ent) then return "something" end
	if ent:IsPlayer() then return "the player" end
	local p = GA.InspectNPC and GA.InspectNPC(ent, observer)
	return p and p.name or ent:GetClass()
end
GA.EntityLabel = nameOf

local function idOf(ent)
	if not IsValid(ent) then return nil end
	if ent:IsPlayer() then return "player" end
	return ent:EntIndex()
end

function GA.LogWorldEvent(kind, actor, victim, extra)
	local ev = {
		time = CurTime(), kind = kind,
		actor = idOf(actor), actorName = IsValid(actor) and nameOf(actor) or nil,
		victim = idOf(victim), victimName = IsValid(victim) and nameOf(victim) or nil,
		pos = IsValid(victim) and victim:GetPos() or IsValid(actor) and actor:GetPos() or vector_origin,
		actorEnt = actor, victimEnt = victim, extra = extra
	}
	GA.WorldEvents[#GA.WorldEvents + 1] = ev
	if #GA.WorldEvents > MAX_EVENTS then table.remove(GA.WorldEvents, 1) end
	GA.OnWorldEvent(ev)
	return ev
end

local function relevantEnt(e) return IsValid(e) and (e:IsPlayer() or (GA.IsValidTalkTarget and GA.IsValidTalkTarget(e))) end

local lastHit = {}
hook.Add("EntityTakeDamage", "GModAlive_AwareHits", function(victim, dmg)
	if dmg:GetDamage() <= 0 then return end
	local attacker = dmg:GetAttacker()
	if not relevantEnt(victim) or not relevantEnt(attacker) or attacker == victim then return end
	local key = victim:EntIndex() .. ":" .. attacker:EntIndex()
	if (lastHit[key] or 0) > CurTime() then return end
	lastHit[key] = CurTime() + 4
	GA.LogWorldEvent("attacked", attacker, victim)
end)

hook.Add("OnNPCKilled", "GModAlive_AwareKills", function(npc, attacker)
	if not relevantEnt(npc) and not (IsValid(npc) and npc:IsNPC()) then return end
	-- LogWorldEvent computes the name before the entity is removed.
	GA.LogWorldEvent("killed", attacker, npc)
	npc:SetNWBool("GModAlive_Dead", true)
end)

hook.Add("PlayerDeath", "GModAlive_AwarePlayerDeath", function(victim, _, attacker)
	GA.LogWorldEvent("killed", attacker, victim)
end)

-- ---------------------------------------------------------------------------
-- Who may think?
-- ---------------------------------------------------------------------------
local function nearestPlayer(npc, radius)
	local best, bestD = nil, (radius or 1e9) ^ 2
	for _, p in ipairs(player.GetAll()) do
		if p:Alive() then
			local d = p:GetPos():DistToSqr(npc:GetPos())
			if d < bestD then best, bestD = p, d end
		end
	end
	return best
end

local function awareEnabledFor(npc)
	if npc:GetNWBool("GModAlive_AwareOff", false) then return false end
	return cvEnabled:GetBool() or npc:GetNWBool("GModAlive_Aware", false)
end

local function canThink(npc)
	if not GA.IsEnabled() or not alive(npc) or not GA.IsValidTalkTarget(npc) then return false end
	if not awareEnabledFor(npc) then return false end
	if GA.IsNPCConversationPaused and GA.IsNPCConversationPaused(npc) then return false end
	if npc.GModAlive_Thinking then return false end
	return nearestPlayer(npc, cvPlyRadius:GetFloat()) ~= nil
end

-- Area cap: count NPCs currently thinking inside the NPC radius.
local function areaFull(npc)
	local cap, n = math.max(1, cvMaxArea:GetInt()), 0
	local r2 = cvNpcRadius:GetFloat() ^ 2
	for other in pairs(GA.AwareThinking or {}) do
		if IsValid(other) and other ~= npc and other:GetPos():DistToSqr(npc:GetPos()) < r2 then n = n + 1 end
	end
	return n >= cap
end
GA.AwareThinking = GA.AwareThinking or setmetatable({}, { __mode = "k" })

-- ---------------------------------------------------------------------------
-- Context: events an NPC can know about
-- ---------------------------------------------------------------------------
local function witnessed(npc, ev, window)
	if CurTime() - ev.time > (window or 120) then return false end
	return ev.pos:DistToSqr(npc:GetPos()) <= cvNpcRadius:GetFloat() ^ 2
end

function GA.EventText(ev, npc)
	local a = ev.actorName or "something"
	local v = ev.victimName or "something"
	if ev.actor == npc:EntIndex() then a = "you" end
	if ev.victim == npc:EntIndex() then v = "you" end
	if ev.kind == "killed" then return string.format("%s killed %s", a, v) end
	return string.format("%s attacked %s", a, v)
end

local previousContext = GA.ActionContext
function GA.ActionContext(npc, ply)
	local data = previousContext(npc, ply)
	local out = {}
	for i = #GA.WorldEvents, 1, -1 do
		local ev = GA.WorldEvents[i]
		if witnessed(npc, ev) then
			out[#out + 1] = {
				what = GA.EventText(ev, npc), seconds_ago = math.Round(CurTime() - ev.time),
				actor_id = ev.actor, victim_id = ev.victim,
				victim_still_exists = ev.kind ~= "killed"
			}
			if #out >= 8 then break end
		end
	end
	if #out > 0 then
		data.witnessed_events = out
		data.event_note = "witnessed_events are facts the server saw. Use actor_id/victim_id to know WHO attacked WHOM. If an NPC (not the player) is the aggressor, retaliate against that NPC with [AttackNPC=id], never with [AttackTarget] (which hits the player)."
	end
	return data
end

-- ---------------------------------------------------------------------------
-- Thinking
-- ---------------------------------------------------------------------------
local function languageHint(ply)
	return IsValid(ply) and ply.GModAlive_LastUtterance or "Hello"
end

function GA.AwareThink(npc, reason, eventText)
	if not canThink(npc) or areaFull(npc) then return false end
	local ply = nearestPlayer(npc, cvPlyRadius:GetFloat())
	if not ply then return false end
	npc.GModAlive_Thinking = true
	GA.AwareThinking[npc] = true
	local function release()
		npc.GModAlive_Thinking = nil
		GA.AwareThinking[npc] = nil
	end
	timer.Simple(40, release)
	local prompt
	if eventText then
		prompt = "[AWARENESS] You just witnessed: " .. eventText .. ". React in character right now. Decide with ONE short spoken line (under 20 words) and, if it fits, ONE action tag (flee, take cover, attack the real aggressor with [AttackNPC=id], mourn, call for help...). If your friend or ally no longer exists, show it. Use the language of this earlier player utterance: " .. tostring(languageHint(ply))
	else
		prompt = "[AWARENESS] Nothing in particular is happening. Look at ACTION_CONTEXT and, only if something is worth reacting to, do it; otherwise answer with exactly [NOREACT]. Keep any spoken line under 15 words, in the language of this earlier player utterance: " .. tostring(languageHint(ply))
	end
	GA.SetNPCStatus(npc, "thinking")
	local ok = pcall(GA.GenerateNPCResponse, { ply = ply, npc = npc, userText = prompt }, function(success, result, profile)
		release()
		if IsValid(npc) then GA.SetNPCStatus(npc, "") end
		if not success or not istable(result) or not alive(npc) then return end
		if result.actionTag then GA.ExecuteNPCAction(npc, ply, result.actionTag, result.actionParam) end
		local text = result.spokenText
		if text and text ~= "" and not string.find(text, "NOREACT", 1, true) then
			GA.StartNPCSpeakingState(npc, text)
			GA.BroadcastNPCResponse(npc, ply, text, result.actionTag, profile, "")
		end
	end)
	if not ok then release() end
	return true
end

-- Fast reaction: NPCs that witness a new event think right away (staggered).
function GA.OnWorldEvent(ev)
	if not GA.IsEnabled() then return end
	local r2 = cvNpcRadius:GetFloat() ^ 2
	local delay = cvReact:GetFloat()
	local n = 0
	for _, npc in ipairs(ents.GetAll()) do
		if IsValid(npc) and npc ~= ev.victimEnt and npc:IsNPC() and npc:GetPos():DistToSqr(ev.pos) <= r2
			and (CurTime() - (npc.GModAlive_LastAware or 0)) > 3 and awareEnabledFor(npc) then
			n = n + 1
			local text = GA.EventText(ev, npc)
			-- the victim may be the NPC's own friend: tell the model about it explicitly
			if IsValid(ev.victimEnt) and ev.victimEnt:IsNPC() and npc:Disposition(ev.victimEnt) == D_LI then
				text = text .. " (" .. (ev.victimName or "that character") .. " was your friend/ally)"
			end
			timer.Simple(delay + n * 0.6, function()
				if IsValid(npc) then
					npc.GModAlive_LastAware = CurTime()
					GA.AwareThink(npc, "event", text)
				end
			end)
			if n >= math.max(1, cvMaxArea:GetInt()) then break end
		end
	end
end

-- Ambient loop: every X seconds pick NPCs that may think.
local nextAmbient = 0
timer.Create("GModAlive_AwareLoop", 1, 0, function()
	if not GA.IsEnabled() then return end
	if CurTime() < nextAmbient then return end
	nextAmbient = CurTime() + math.max(2, cvInterval:GetFloat())
	local list = {}
	for _, npc in ipairs(ents.GetAll()) do
		if IsValid(npc) and npc:IsNPC() and awareEnabledFor(npc) and (CurTime() - (npc.GModAlive_LastAware or 0)) > cvInterval:GetFloat() then
			list[#list + 1] = npc
		end
	end
	table.Shuffle(list)
	local started = 0
	for _, npc in ipairs(list) do
		if started >= math.max(1, cvMaxArea:GetInt()) then break end
		npc.GModAlive_LastAware = CurTime()
		if GA.AwareThink(npc, "ambient", nil) then started = started + 1 end
	end
end)

-- ---------------------------------------------------------------------------
-- Per-NPC toggle (admin / single-player)
-- ---------------------------------------------------------------------------
net.Receive("GModAlive_ToggleAware", function(_, ply)
	if not isAdmin(ply) then return end
	local npc = Entity(net.ReadUInt(16))
	if not IsValid(npc) or not npc:IsNPC() then return end
	local on = net.ReadBool()
	npc:SetNWBool("GModAlive_Aware", on)
	npc:SetNWBool("GModAlive_AwareOff", not on and cvEnabled:GetBool())
end)
