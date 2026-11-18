-- ============================================================================
-- GMod Alive — Talking AI NPCs
-- Shared Configuration & ConVars (sh_config.lua)
-- ============================================================================

GModAlive = GModAlive or {}
local GA = GModAlive

GA.DataDir = "gmod_alive"
GA.ConfigFile = "gmod_alive/config.json"

-- Priority order of Gemini models (fastest & most stable first, with automatic failover)
GA.CustomPromptFile = "gmod_alive/custom_prompt.txt"
GA.GeminiCandidateModels = { "gemini-flash-lite-latest" }
GA.DefaultModel = "gemini-flash-lite-latest"

-- Supported Physical Action Tags (Los Santos Alive Compatible + GMod Extensions)
GA.SupportedActions = {
	"FollowTarget",
	"WaitHere",
	"WalkAwayFromTarget",
	"FleeFromTarget",
	"AttackTarget",
	"PutHandsUp",
	"PutHandsDown",
	"Kneel",
	"GetUp",
	"GiveTargetWeapon",
	"HealTarget",
	"EnterTargetVehicle",
	"ExitVehicle",
	"BecomeAccomplice",
	"InitiateDirectedInteraction"
}

-- Shared ConVars (Server & Client)
CreateConVar("gmod_alive_enabled", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Enable or disable GMod Alive — Talking AI NPCs")
CreateConVar("gmod_alive_distance", "320", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Maximum distance (in Source units) for an NPC to hear and respond to the player", 60, 2000)
CreateConVar("gmod_alive_chat_listen", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Allow nearby NPCs within distance X to hear regular text chat messages")
CreateConVar("gmod_alive_actions_enabled", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Allow AI NPCs to execute physical RP action tags")
CreateConVar("gmod_alive_npc_to_npc", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Allow AI NPCs to initiate conversations with other nearby NPCs")

if CLIENT then
    CreateClientConVar("gmod_alive_inventory_key",tostring(KEY_I or 19),true,false,"Open your personal inventory")
	CreateClientConVar("gmod_alive_voice_tone", "0.94", true, false, "Voice tone and playback rate: lower is deeper", 0.8, 1.1)
	CreateClientConVar("gmod_alive_status_visible", "1", true, false, "Show listening/thinking status")
	CreateClientConVar("gmod_alive_quiet", "1", true, false, "No voice popups, recording cards, bubbles or chat output")
	CreateClientConVar("gmod_alive_talk_key", tostring(KEY_G or 17), true, false, "Key code to open the quick text dialog with the nearest NPC")
	CreateClientConVar("gmod_alive_tts_enabled", "0", true, false, "Enable 3D positional voice synthesis (TTS) and lip-sync for NPCs")
	CreateClientConVar("gmod_alive_tts_volume", "1.0", true, false, "Volume multiplier for NPC 3D TTS voice", 0.0, 2.0)
	CreateClientConVar("gmod_alive_subtitles", "1", true, false, "Show cinematic subtitles and 3D overhead speech bubbles")
	CreateClientConVar("gmod_alive_hud_prompt", "1", true, false, "Show proximity HUD card when within distance X of an NPC")
end

function GA.GetMaxDistance()
	local cv = GetConVar("gmod_alive_distance")
	return cv and cv:GetFloat() or 320
end

function GA.IsEnabled()
	local cv = GetConVar("gmod_alive_enabled")
	return not cv or cv:GetBool()
end
