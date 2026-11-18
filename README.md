FORK GMod Alive: Talking AI NPCs
A New Era of Artificial Intelligence in Garry's Mod



Bring Your Garry's Mod World to Life.

What if NPCs could think, talk, remember, develop relationships and independently interact with the world around them?

GMod Alive transforms traditional Garry's Mod NPCs into dynamic AI-powered characters with unique personalities, contextual awareness, emotional states and autonomous behaviours.



✦ ARTIFICIAL INTELLIGENCE — YOUR OWN API

Connect your own API key and choose your preferred AI provider:

Google Gemini
Groq
DeepSeek
OpenRouter
OpenAI

No additional external programs required. AI processing connects directly through the configured provider.

GET YOUR GEMINI API KEY[aistudio.google.com]



✦ PERSONALITIES & EMOTIONAL INTELLIGENCE

Every NPC can have an individual identity, personality, background, communication style and behavioural preferences.

Characters can develop emotional states such as:

Fear and anger
Happiness and gratitude
Trust and suspicion
Loyalty and curiosity
Confidence and sadness

Their reactions depend on their experiences and interactions.



✦ AUTONOMOUS NPC BEHAVIOUR

NPCs can take initiative and perform contextual actions instead of simply waiting for player commands.

NEW AI ACTIONS:

[CallForHelp] — Call nearby allies for assistance.
[HealNPC=id] — Provide medical assistance to another NPC.
[GuardPosition] — Guard a designated position.
[PatrolArea] — Independently patrol an area.
[ProtectTarget] — Protect an assigned character.
[Gesture=wave] — Perform supported character gestures.
[FollowTarget] — Follow an assigned character.
[TakeCover] — Seek an appropriate safe position.
[TalkToNPC=id] — Interact with other NPCs.
[ReturnToRoutine] — Resume autonomous routines.

Gesture availability depends on the animations supported by each model.



✦ SOCIAL INTERACTIONS & RELATIONSHIPS

Talk to NPCs, develop relationships, negotiate, establish trust and influence their decisions.

Characters can interact with each other, remember important events and respond differently depending on their relationship with the player.



✦ INVENTORY & TRADING SYSTEM

An integrated interaction system designed around actual Garry's Mod entities and inventory mechanics.

NPCs can participate in item exchanges, equipment transfers and interactions with existing world objects, subject to addon support.



✦ CONTROLS

G — Talk to the NPC in front of you.

I — Open your inventory and trading interface.

F6 — Open the main GMod Alive configuration menu.

The menu key can be changed through the available configuration options.



✦ A LIVING WORLD. A DIFFERENT EXPERIENCE.

GMod Alive aims to transform Garry's Mod into a dynamic simulation where characters have personalities, memories, relationships and independent behaviours.

Every conversation matters. Every interaction can change a relationship. Every character has the potential to tell a different story.

Your world. Your characters. Your stories.



IMPORTANT INFORMATION

An API key is required for AI functionality. API costs, token limits and availability depend on your selected provider.

This project is an expanded fork of GMod Alive. Please respect the original project's licence and attribution requirements.

Bug fixes

“Follow me” (e.g., Kleiner following Barney): The “Follow,” “Come,” and “Protect” commands now default to targeting the player. The AI ​​is instructed to execute “Follow:player.” An NPC will no longer obey an order to follow someone to whom they are hostile.
Kleiner attacking you instead of Barney: The prompt now specifies that [AttackTarget] applies only to the player. To target NPCs, the AI ​​must use [AttackNPC=id]. NPCs now also receive data on events they have witnessed (who attacked whom), allowing them to identify the aggressor.
Incorrect names (e.g., cp-4090, Daniel): Previously, the client and server generated names using different seeds. Now, the server determines the name, and the client displays that exact name.
Name display above NPCs: Names appear in white, with the NPC’s class (Citizen, Combine Police, etc.) shown underneath. This can be disabled via an option in the menu.

New features

Self-awareness: NPCs react to events (such as the death of an ally or an attack on someone) and also perform periodic “thinking” processes at set intervals. In the new “Awareness & G-Man” tab (accessible via F6), you can configure the thinking interval, the awareness radius for NPCs and the player, and the maximum number of NPCs allowed per area. If the global awareness setting is disabled, you can use the “Awareness” button in the conversation window to enable it only for specific NPCs of your choosing.
Collective reasoning: Commands can be directed toward a specific ID, multiple IDs, all NPCs, a specific type (e.g., “type:combine”), a class, or an area defined by a radius. While only the NPC you addressed will “think” and speak, the server propagates the command to all targeted NPCs (up to a maximum of 15). If you specify only one NPC, the command applies exclusively to that individual.
Tasks with memory: A command such as “go find Barney and tell him to follow me” is now broken down into a multi-step plan (up to 6 steps, such as: Find, Tell, Say, Come, Wait). NPCs are aware of all other NPCs on the map; if a target ceases to exist, they cancel their current task and become aware of the target's disappearance.
Shooting at objects: Using a weapon, an NPC can fire at a prop or door you specify, provided it is within 700 units and in their line of sight. Doors will open upon the fifth shot.
G-Man as a god: This feature applies only to `npc_gman` and is available exclusively to admins or in single-player mode (it can also be disabled via the menu). It allows for the deletion of props and NPCs (by targeting, selecting all, filtering by class, text, or radius). You can spawn any NPC, vehicle, entity, weapon, or prop—either at your crosshair, on top of you, or at your current location—and issue commands from any distance (e.g., drop weapons, stand still, do not attack, flee, follow, or release). These commands are always obeyed.
