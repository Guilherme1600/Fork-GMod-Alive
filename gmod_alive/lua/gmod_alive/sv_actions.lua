-- ============================================================================
-- GMod Alive — Talking AI NPCs
-- Physical RP Actions, Follow Loop, Lip-Sync Flexes & NPC-to-NPC (sv_actions.lua)
-- ============================================================================

if CLIENT then return end

GModAlive = GModAlive or {}
local GA = GModAlive

local FLEX_NAMES = {
	"jaw_drop",
	"right_part",
	"left_part",
	"right_mouth_drop",
	"left_mouth_drop",
	"lower_lip",
	"chin_raiser",
	"smile"
}

-- Smoothly turn NPC toward the speaker
function GA.MakeNPCFaceTarget(npc, targetEnt)
	if not IsValid(npc) or not IsValid(targetEnt) then return end
	if npc.GModAlive_HostileTo == targetEnt then return end

	local dir = (targetEnt:GetPos() - npc:GetPos())
	dir.z = 0
	if dir:LengthSqr() < 1 then return end
	local ang = dir:Angle()

	if npc:IsNPC() then
		pcall(function()
			npc:SetTarget(targetEnt)
			if npc.SetIdealYawAndUpdate then
				npc:SetIdealYawAndUpdate(ang.y, 120)
			else
				npc:SetAngles(Angle(0, ang.y, 0))
			end
		end)
	else
		npc:SetAngles(Angle(0, ang.y, 0))
	end
end

-- Mark NPC as actively speaking for a given duration & animate facial flexes
function GA.StartNPCSpeakingState(npc, spokenText)
	if not IsValid(npc) then return 3.0 end
	local charCount = string.len(spokenText or "")
	local estDuration = math.Clamp(charCount * 0.068, 2.0, 26.0)

	npc:SetNWBool("GModAlive_Speaking", true)
	npc:SetNWFloat("GModAlive_SpeakUntil", CurTime() + estDuration)
	return estDuration
end

-- Execute a parsed [ActionTag] on an NPC
function GA.ExecuteNPCAction(npc, ply, actionTag, actionParam)
	if not IsValid(npc) or not actionTag or actionTag == "" then return end

	local cvActions = GetConVar("gmod_alive_actions_enabled")
	if cvActions and not cvActions:GetBool() then return end

	local tag = tostring(actionTag)

	if tag == "FollowTarget" or tag == "BecomeAccomplice" then
		if not IsValid(ply) then return end
		npc.GModAlive_FollowingPlayer = ply
		npc.GModAlive_WaitHere = false
		npc.GModAlive_HostileTo = nil
		npc:SetNWBool("GModAlive_Surrendered", false)
		npc:SetNWString("GModAlive_ActionState", "Seguindo " .. ply:Nick())

		if npc.AddEntityRelationship then
			pcall(npc.AddEntityRelationship, npc, ply, D_LI, 99)
		end
		if npc.IsVJBaseSNPC then
			npc.FollowingPlayer = true
			npc.FollowPlayer_Entity = ply
		end

	elseif tag == "WaitHere" then
		npc.GModAlive_FollowingPlayer = nil
		npc.GModAlive_WaitHere = true
		npc:SetNWString("GModAlive_ActionState", "Aguardando no local")
		if npc.IsVJBaseSNPC then
			npc.FollowingPlayer = false
			npc.FollowPlayer_Entity = nil
		end
		if npc.SetSchedule then
			pcall(npc.SetSchedule, npc, SCHED_IDLE_STAND)
		end

	elseif tag == "WalkAwayFromTarget" then
		npc.GModAlive_FollowingPlayer = nil
		npc:SetNWString("GModAlive_ActionState", "Afastando-se")
		if IsValid(ply) and npc.SetLastPosition and npc.SetSchedule then
			local dir = (npc:GetPos() - ply:GetPos()):GetNormalized()
			if dir:LengthSqr() < 0.1 then dir = npc:GetForward() end
			local dest = npc:GetPos() + dir * 450
			pcall(function()
				npc:SetLastPosition(dest)
				npc:SetSchedule(SCHED_FORCED_GO)
			end)
		end

	elseif tag == "FleeFromTarget" then
		npc.GModAlive_FollowingPlayer = nil
		npc:SetNWString("GModAlive_ActionState", "Em fuga!")
		if IsValid(ply) then
			if npc.AddEntityRelationship then
				pcall(npc.AddEntityRelationship, npc, ply, D_FR, 99)
			end
			if npc.SetLastPosition and npc.SetSchedule then
				local dir = (npc:GetPos() - ply:GetPos()):GetNormalized()
				if dir:LengthSqr() < 0.1 then dir = -npc:GetForward() end
				local dest = npc:GetPos() + dir * 800
				pcall(function()
					npc:SetLastPosition(dest)
					npc:SetSchedule(SCHED_FORCED_GO_RUN)
				end)
			end
		end

	elseif tag == "AttackTarget" then
		npc.GModAlive_FollowingPlayer = nil
		npc.GModAlive_HostileTo = ply
		npc:SetNWBool("GModAlive_Surrendered", false)
		npc:SetNWString("GModAlive_ActionState", "Hostil / Atacando!")
		if IsValid(ply) then
			if npc.AddEntityRelationship then
				pcall(npc.AddEntityRelationship, npc, ply, D_HT, 99)
			end
			if npc.SetEnemy then
				pcall(npc.SetEnemy, npc, ply)
			end
			if npc.UpdateEnemyMemory then
				pcall(npc.UpdateEnemyMemory, npc, ply, ply:GetPos())
			end
			if npc.SetSchedule then
				pcall(npc.SetSchedule, npc, SCHED_COMBAT_FACE)
			end
		end

	elseif tag == "PutHandsUp" or tag == "Kneel" then
		npc.GModAlive_FollowingPlayer = nil
		npc.GModAlive_HostileTo = nil
		npc:SetNWBool("GModAlive_Surrendered", true)
		npc:SetNWString("GModAlive_ActionState", (tag == "Kneel") and "Ajoelhado / Rendido" or "Mãos ao alto (Rendido)")
		if IsValid(ply) and npc.AddEntityRelationship then
			pcall(npc.AddEntityRelationship, npc, ply, D_NU, 99)
		end
		if npc.SetEnemy then
			pcall(npc.SetEnemy, npc, NULL)
		end
		if npc.SetSchedule then
			pcall(npc.SetSchedule, npc, SCHED_COWER)
		end

	elseif tag == "PutHandsDown" or tag == "GetUp" then
		npc:SetNWBool("GModAlive_Surrendered", false)
		npc:SetNWString("GModAlive_ActionState", "")
		if npc.SetSchedule then
			pcall(npc.SetSchedule, npc, SCHED_IDLE_STAND)
		end

	elseif tag == "GiveTargetWeapon" then
		if IsValid(ply) then
			local wepClass = "weapon_pistol"
			if npc.GetActiveWeapon and IsValid(npc:GetActiveWeapon()) then
				wepClass = npc:GetActiveWeapon():GetClass()
			end
			ply:Give(wepClass)
			ply:EmitSound("items/ammo_pickup.wav", 70, 100)
			npc:SetNWString("GModAlive_ActionState", "Entregou arma")
		end

	elseif tag == "HealTarget" then
		if IsValid(ply) then
			local newHp = math.min(ply:GetMaxHealth(), ply:Health() + 35)
			ply:SetHealth(newHp)
			ply:EmitSound("items/smallmedkit1.wav", 75, 100)
			npc:SetNWString("GModAlive_ActionState", "Curou o jogador")
		end

	elseif tag == "EnterTargetVehicle" then
		if IsValid(ply) then
			local veh = ply:GetVehicle()
			if not IsValid(veh) then
				for _, v in ipairs(ents.FindInSphere(npc:GetPos(), 550)) do
					if IsValid(v) and v:IsVehicle() then
						veh = v
						break
					end
				end
			end
			if IsValid(veh) then
				npc.GModAlive_RidingVehicle = veh
				npc:SetNWString("GModAlive_ActionState", "No veículo")
				npc:SetParent(veh)
				npc:SetLocalPos(Vector(22, -18, 12))
				npc:SetLocalAngles(Angle(0, 90, 0))
			end
		end

	elseif tag == "ExitVehicle" then
		if IsValid(npc.GModAlive_RidingVehicle) or IsValid(npc:GetParent()) then
			local veh = npc.GModAlive_RidingVehicle or npc:GetParent()
			npc:SetParent(NULL)
			npc.GModAlive_RidingVehicle = nil
			npc:SetNWString("GModAlive_ActionState", "")
			if IsValid(veh) then
				npc:SetPos(veh:GetPos() + veh:GetRight() * 75 + Vector(0, 0, 15))
			end
		end

	elseif tag == "InitiateDirectedInteraction" then
		local cvNpcToNpc = GetConVar("gmod_alive_npc_to_npc")
		if not cvNpcToNpc or cvNpcToNpc:GetBool() then
			GA.StartNpcToNpcConversation(npc, ply)
		end
	end
end

-- Autonomous NPC-to-NPC Conversation (Los Santos Alive Style)
function GA.StartNpcToNpcConversation(speakerNpc, observerPly)
	if not IsValid(speakerNpc) then return end

	local bestTarget = nil
	local bestDist = 700
	for _, other in ipairs(ents.FindInSphere(speakerNpc:GetPos(), 700)) do
		if other ~= speakerNpc and GA.IsValidTalkTarget(other) then
			local d = speakerNpc:GetPos():Distance(other:GetPos())
			if d < bestDist then
				bestDist = d
				bestTarget = other
			end
		end
	end

	if not IsValid(bestTarget) then return end

	-- Move closer to the other NPC
	if speakerNpc.SetLastPosition and speakerNpc.SetSchedule and bestDist > 130 then
		local approachPos = bestTarget:GetPos() + (speakerNpc:GetPos() - bestTarget:GetPos()):GetNormalized() * 95
		pcall(function()
			speakerNpc:SetLastPosition(approachPos)
			speakerNpc:SetSchedule(SCHED_FORCED_GO_RUN)
		end)
	end

	local speakerProfile = GA.InspectNPC(speakerNpc, observerPly)
	local targetProfile = GA.InspectNPC(bestTarget, observerPly)
	if not speakerProfile or not targetProfile then return end

	local promptMsg = string.format(
		"[INTERAÇÃO NPC-PARA-NPC]\nVocê acabou de se aproximar de outro personagem que está perto de você: %s (%s, do mod %s).\nPuxe assunto diretamente com ele(a) em Português do Brasil em 1 a 3 frases naturais, comentando algo sobre este lugar ou sobre a situação atual!",
		targetProfile.name, targetProfile.role, targetProfile.modSource
	)

	timer.Simple(1.2, function()
		if not IsValid(speakerNpc) or not IsValid(bestTarget) then return end
		GA.MakeNPCFaceTarget(speakerNpc, bestTarget)
		GA.MakeNPCFaceTarget(bestTarget, speakerNpc)

		GA.GenerateNPCResponse({
			ply = observerPly,
			npc = speakerNpc,
			userText = promptMsg
		}, function(ok, parsed, profile)
			if not ok or not IstableOrValid(parsed) or parsed.spokenText == "" then return end
			if not IsValid(speakerNpc) or not IsValid(bestTarget) then return end

			local dur = GA.StartNPCSpeakingState(speakerNpc, parsed.spokenText)
			GA.BroadcastNPCResponse(speakerNpc, observerPly, parsed.spokenText, parsed.actionTag, profile, "[Para " .. targetProfile.name .. "]")

			-- Second NPC replies after speaker finishes
			timer.Simple(math.Clamp(dur + 0.8, 3.0, 12.0), function()
				if not IsValid(speakerNpc) or not IsValid(bestTarget) then return end
				GA.MakeNPCFaceTarget(bestTarget, speakerNpc)

				local replyInstruction = string.format(
					"[INTERAÇÃO NPC-PARA-NPC]\nO personagem %s (%s) acabou de vir até você e disse: \"%s\".\nResponda diretamente para ele(a) em Português do Brasil atuando como seu personagem (1 a 3 frases naturais)!",
					speakerProfile.name, speakerProfile.role, parsed.spokenText
				)

				GA.GenerateNPCResponse({
					ply = observerPly,
					npc = bestTarget,
					userText = replyInstruction
				}, function(ok2, parsed2, profile2)
					if not ok2 or not istable(parsed2) or parsed2.spokenText == "" then return end
					if not IsValid(bestTarget) then return end

					GA.StartNPCSpeakingState(bestTarget, parsed2.spokenText)
					GA.BroadcastNPCResponse(bestTarget, observerPly, parsed2.spokenText, parsed2.actionTag, profile2, "[Respondendo a " .. speakerProfile.name .. "]")
				end)
			end)
		end)
	end)
end

function IstableOrValid(v)
	return istable(v)
end

-- Periodic Follow & Lip-Sync Flex Timer
timer.Create("GModAlive_FollowAndFlexLoop", 0.25, 0, function()
	if not GA.IsEnabled() then return end
	local now = CurTime()

	for _, ent in ipairs(ents.GetAll()) do
		if IsValid(ent) and (ent:IsNPC() or (ent.IsNextBot and ent:IsNextBot())) then
            if ent:GetNWBool("GModAlive_Speaking",false) and now>ent:GetNWFloat("GModAlive_SpeakUntil",0) then
                ent:SetNWBool("GModAlive_Speaking",false)
            end

			-- 2. Check Follow Player Behavior
			local followPly = ent.GModAlive_FollowingPlayer
			if IsValid(followPly) and not IsValid(ent.GModAlive_RidingVehicle) and not (GA.IsNPCConversationPaused and GA.IsNPCConversationPaused(ent)) then
				local dist = ent:GetPos():Distance(followPly:GetPos())
				if dist > 165 and (not ent.GModAlive_NextFollowMove or now >= ent.GModAlive_NextFollowMove) then
					ent.GModAlive_NextFollowMove = now + 1.0
					local targetPos = followPly:GetPos() - followPly:GetForward() * 85
					if ent.SetLastPosition and ent.SetSchedule then
						pcall(function()
							ent:SetLastPosition(targetPos)
							ent:SetSchedule(dist > 320 and SCHED_FORCED_GO_RUN or SCHED_FORCED_GO)
						end)
					end
				end
			end
		end
	end
end)
