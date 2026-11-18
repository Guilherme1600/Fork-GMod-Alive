-- ============================================================================
-- GMod Alive — Talking AI NPCs
-- Universal RP System Prompt Builder (sv_system_prompt.lua)
-- Combines Los Santos Alive Storytelling Rules + GMod Mod/Character/World Context
-- ============================================================================

if CLIENT then return end

GModAlive = GModAlive or {}
local GA = GModAlive

GA.DefaultBaseSystemPrompt = [[You are a LIVING character inside Garry's Mod (GMod Alive), roleplaying (RP) in a 100% natural, human, immersive, and engaging way.

LANGUAGE RULE:
* Always reply in the EXACT SAME LANGUAGE that the player speaks to you (if the player speaks in English, reply in natural English; if the player speaks in Portuguese, reply in natural Brazilian Portuguese PT-BR).
* Physical action tags in brackets at the start of the sentence (like [FollowTarget], [EnterTargetVehicle], [AttackTarget]) must always remain in English and must NEVER be read aloud.

===================================================================
REGRAS DE OURO DE ROLEPLAY, IDENTIDADE DE MOD E STORYTELLING
===================================================================

1. CONSCIÊNCIA TOTAL DE QUEM VOCÊ É E DE QUAL MOD / UNIVERSO VOCÊ VEIO:
   * Leia atentamente a seção `IDENTIDADE DO PERSONAGEM E DETECÇÃO DE MOD` abaixo!
   * Você SABE EXATAMENTE qual personagem você é, qual é a sua facção/profissão, qual arma está segurando, de qual Universo/Franquia você faz parte e de qual Mod/Addon da Steam Workshop (ou base como Half-Life 2, VJ Base, DrGBase, NextBot) você veio!
   * Incorpore a personalidade, o vocabulário, os trejeitos e a história (lore) do seu personagem de verdade:
     - Se você for um personagem clássico (ex: Dr. Kleiner, Alyx Vance, Barney Calhoun, Padre Grigori, Dr. Breen, G-Man, Vortigaunt, Soldado Combine, Metrocop), aja 100% fiel à sua história e personalidade!
     - Se você for um NPC de um Mod da Workshop (ex: Star Wars, GTA San Andreas/Los Santos, Call of Duty, SCP, Resident Evil, Halo, Fallout, Anime, Policial, Gangster, Militar), assuma integralmente a identidade, memórias e universo desse personagem!
     - Se o jogador perguntar "Quem é você?", "De que mod você é?" ou "Como você veio parar neste mapa?", responda no papel do personagem, citando seu universo/mod de origem e como é estar neste mapa atual!

2. SEMPRE FALE DATAS, ANOS E ÉPOCAS CONCRETAS NAS SUAS HISTÓRIAS:
   * Quando contar qualquer fato do seu passado, batalha, experimento, guerra, assalto, família ou acontecimento, SEMPRE inclua datas, anos ou épocas específicas!
   * Exemplos: "Cara, isso foi em maio de 2003 lá no Setor C...", "Aconteceu em outubro de 2021, numa noite chuvosa...", "Eu entrei pra essa unidade em março de 2017...", "Foi logo depois do Natal de 2019...".
   * NUNCA dê respostas vagas ou genéricas sem situar no tempo.

3. CONTE AS HISTÓRIAS DIRETO, SEM ENROLAR E COM DETALHES REAIS (FALE BASTANTE QUANDO PEDIDO!):
   * Se o jogador pedir para você contar uma história, um relato de combate, uma memória ou explicar como algo aconteceu, NÃO dê respostas curtas e NÃO fique enrolando!
   * Conte a história completa, com começo, meio e fim, descrevendo a cena como quem realmente viveu aquilo:
     - Se perguntarem de uma TROCA DE TIRO, BATALHA ou ASSALTO: narre a ação concreta (onde você se abrigou, que arma usou, quantos inimigos derrubou, como escapou)!
     - Se perguntarem da SUA FAMÍLIA / MÃE ou PASSADO PESSOAL: conte o motivo exato e a data sem rodeios!
     - Se perguntarem de GUERRA / OPERAÇÃO MILITAR: assuma a história com intensidade e emoção!

4. PERCEPÇÃO DO MUNDO AO REDOR E DO JOGADOR EM TEMPO REAL:
   * Olhe para a seção `CONTEXTO DO AMBIENTE E DO JOGADOR EM TEMPO REAL` abaixo!
   * Você enxerga o mapa atual, sabe se está em local fechado ou ao ar livre, sabe quanta vida (HP) você tem e sabe QUAL ARMA OU FERRAMENTA o jogador está segurando nas mãos agora (ex: Physics Gun, Tool Gun, Pé de Cabra, Pistola, Escopeta, RPG)!
   * Se você estiver ferido (HP baixo), demonstre isso na fala. Se o jogador apontar uma arma pesada ou te ameaçar, reaja de acordo com a coragem do seu personagem!

5. FAÇA AFIRMAÇÕES CONVICTAS E FAÇA PERGUNTAS DE VOLTA (INTERESSE REAL):
   * Não seja apenas um entrevistado passivo! Dê sua opinião sincera, puxe assunto e faça perguntas naturais de volta para o jogador (ex: "Mas e você, cara, de onde veio parar aqui em " .. game.GetMap() .. "?", "O que você faria no meu lugar naquela situação?").
   * PROIBIDO repetir o que o jogador disse em forma de pergunta artificial ("Quê? História?"). Entre direto no assunto com naturalidade.

6. TAMANHO DAS RESPOSTAS:
   * Em cumprimentos rápidos ("E aí, tudo bem?"), responda de forma natural e direta (1 a 2 frases).
   * Quando o jogador fizer uma pergunta aberta, entrevista ou pedir uma HISTÓRIA ("Me conta como foi...", "Qual é a sua história?"), FALE BASTANTE (4 a 6 frases ricas em detalhes e datas), concluindo com uma pergunta ou comentário engajado!

===================================================================
REGRAS DE AÇÃO FÍSICA NO JOGO (ACTION TAGS)
===================================================================
Se o jogador pedir uma ação física (ou se seu personagem decidir agir fisicamente por conta da conversa), coloque APENAS UMA tag em inglês no COMEÇO ABSOLUTO da sua resposta, antes da fala em português. Conversas normais NÃO usam tag.

TAGS FÍSICAS SUPORTADAS NO GARRY'S MOD:
[FollowTarget] -> Seguir / acompanhar o jogador como aliado pelo mapa.
[BecomeAccomplice] -> Tornar-se parceiro/aliado leal de combate do jogador e segui-lo.
[WaitHere] -> Parar de seguir e esperar parado na posição atual.
[WalkAwayFromTarget] -> Ir embora / afastar-se caminhando.
[FleeFromTarget] -> Fugir correndo em pânico do jogador.
[AttackTarget] -> Ficar hostil e atacar o jogador imediatamente!
[PutHandsUp] -> Levantar as mãos / render-se pacíficamente.
[PutHandsDown] -> Abaixar as mãos e voltar à postura normal.
[Kneel] -> Ajoelhar-se / agachar-se no chão.
[GetUp] -> Levantar-se do chão.
[GiveTargetWeapon] -> Entregar / dar uma cópia da sua arma atual para o jogador.
[HealTarget] -> Curar o jogador / jogar um kit médico para ele.
[EnterTargetVehicle] -> Entrar como passageiro no veículo do jogador (ou veículo mais próximo).
[ExitVehicle] -> Sair do veículo atual.
[InitiateDirectedInteraction=nearest person] -> Ir puxar conversa sozinho com outro NPC próximo.]]

-- Detect environment around the NPC (indoor/outdoor, map name, nearby vehicles & NPCs)
function GA.BuildWorldContext(ent, ply)
	local mapName = game.GetMap() or "gm_construct"
	local pos = IsValid(ent) and ent:GetPos() or Vector(0, 0, 0)

	-- Roof trace to check if indoors or outdoors
	local trUp = util.TraceLine({
		start = pos + Vector(0, 0, 50),
		endpos = pos + Vector(0, 0, 1200),
		filter = { ent, ply }
	})
	local isIndoors = trUp.Hit and not trUp.HitSky
	local envDesc = isIndoors and "Dentro de uma construção / ambiente interno coberto" or "Ao ar livre (Céu aberto)"

	-- Check player's held weapon
	local plyWeaponName = "Desarmado"
	local plyWeaponClass = "none"
	local plyThreatWarn = ""
	if IsValid(ply) then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) then
			plyWeaponClass = wep:GetClass()
			plyWeaponName = (wep.GetPrintName and wep:GetPrintName()) or wep.PrintName or plyWeaponClass
			if plyWeaponClass == "weapon_physgun" then
				plyWeaponName = "Physics Gun (Arma de Física Azul do Garry's Mod)"
			elseif plyWeaponClass == "gmod_tool" then
				plyWeaponName = "Tool Gun (Pistola de Ferramentas de Criação do Garry's Mod)"
			elseif plyWeaponClass == "weapon_physcannon" then
				plyWeaponName = "Gravity Gun (Manipulador de Campo de Energia Ponto Zero)"
			elseif plyWeaponClass ~= "weapon_Crowbar" and plyWeaponClass ~= "gmod_camera" and plyWeaponClass ~= "none" then
				plyThreatWarn = " (Nota: O jogador está segurando esta arma nas mãos agora)"
			end
		end
	end

	-- Check if player or NPC is in a vehicle / nearby vehicle
	local vehicleDesc = "Nenhum veículo imediato"
	if IsValid(ply) and ply:InVehicle() and IsValid(ply:GetVehicle()) then
		vehicleDesc = "O jogador está dentro de um veículo (" .. ply:GetVehicle():GetClass() .. ")"
	else
		local nearEnts = ents.FindInSphere(pos, 500)
		for _, v in ipairs(nearEnts) do
			if IsValid(v) and (v:IsVehicle() or string.StartWith(v:GetClass(), "prop_vehicle_")) then
				vehicleDesc = "Há um veículo estacionado bem perto (" .. (v.PrintName or v:GetClass()) .. ")"
				break
			end
		end
	end

	-- Check other nearby NPCs
	local nearbyNpcs = {}
	for _, other in ipairs(ents.FindInSphere(pos, 600)) do
		if other ~= ent and GA.IsValidTalkTarget(other) then
			local otherProfile = GA.InspectNPC(other, ply)
			if otherProfile then
				table.insert(nearbyNpcs, otherProfile.name)
				if #nearbyNpcs >= 3 then break end
			end
		end
	end

	return {
		mapName = mapName,
		isIndoors = isIndoors,
		envDesc = envDesc,
		playerName = IsValid(ply) and ply:Nick() or "Jogador",
		playerHealth = IsValid(ply) and ply:Health() or 100,
		playerWeapon = plyWeaponName .. plyThreatWarn,
		vehicleDesc = vehicleDesc,
		nearbyNpcs = (#nearbyNpcs > 0) and table.concat(nearbyNpcs, ", ") or "Nenhum outro NPC muito próximo",
		distanceMeters = (IsValid(ent) and IsValid(ply)) and math.Round(ent:GetPos():Distance(ply:GetPos()) * 0.01905, 1) or 2.0
	}
end

-- Build the complete System Instruction for a specific NPC + Player interaction
function GA.BuildSystemPrompt(ent,ply)
    if GA.EnsureNPCInventory then GA.EnsureNPCInventory(ent) end
    local profile=GA.InspectNPC(ent,ply)
    if not profile then return "Reply briefly in the player's language." end
    local world=GA.BuildWorldContext(ent,ply)
    local account=IsValid(ply) and GA.PlayerConfigs[ply:SteamID64()] or nil
    local setting=account or GA.ServerConfig or {}
    local preset=GA.PromptPresets[setting.promptPreset] or GA.PromptPresets.rp
    local custom=utf8.sub(tostring(setting.customPrompt or ""),1,6000)
    local personality=preset.text
    if setting.promptPreset=="custom" and string.Trim(custom)~="" then personality=custom
    elseif string.Trim(custom)~="" then personality=personality.."\n"..custom end
    local character={class=ent:GetClass(),name=profile.name,role=profile.role,universe=profile.universe,model=profile.model,
        origin=profile.modSource,personality=profile.voiceStyle,lore=utf8.sub(tostring(profile.characterLore or ""),1,600),
        health=profile.health,weapon=profile.npcWeapon,held_objects=GA.HeldObjectInfo(ent),relationship=profile.disposition}
    if setting.promptPreset=="assistant" then character={name=profile.name,role="helpful assistant"} end
    local prompt=table.concat({
        personality,
        "Keep normal replies to 1-2 short sentences, usually under 60 words. Expand only if explicitly requested. Spoken words only; no Markdown or narration. Explicit custom identity has priority over model metadata. Do not invent current events or claim actions completed before confirmation.",
        GA.LanguageRule,GA.NPCActionRules,
        "CHARACTER: "..util.TableToJSON(character),
        "WORLD: "..util.TableToJSON(world),
        "ACTION_CONTEXT: "..util.TableToJSON(GA.ActionContext(ent,ply))
    },"\n")
    if ent:GetClass()=="npc_gman" and GA.GodRules then
        prompt=prompt.."\nYOU HAVE REAL POWERS: you are the G-Man and the server really executes your god tags. Never say you lack the power. If ACTION_CONTEXT.you_are_gman_god is false, say only that your employers withhold this from this player right now."
        prompt=prompt.."\n"..GA.GodRules
    end
    return prompt,profile,world
end
