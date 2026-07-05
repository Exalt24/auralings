# Auralings — progress / handoff

**What it is:** an AI-native creature-summoner demo, built to apply for the **Game Developer role at L7V** (Michia Rohrssen, AI-native mobile game studio, Tokyo). Pitch: every creature is procedurally drawn from a seed, and a Groq LLM authors its identity (name, epithet, lore, ability) live. "Seed draws the body, AI writes the soul." Echoes his creature-collection world without copying his Japanese-learning game.

**Engine:** Godot 4.6 (`E:\Game Editors\Godot_v4.6-stable_win64.exe\`). Verify headless:
`"E:/Game Editors/.../Godot_v4.6-stable_win64_console.exe" --path . --headless --quit` (parse-check).
Render screenshots (real render, not headless): run `res://tools/Capture.tscn` → PNGs in `_shots/`.

## CURRENT STATE (2026-07-05)
- **v0.1 + LLM slice DONE and verified via real render.** Summon screen generates a procedural Auraling (smooth harmonic-blob body, curated per-element palette, eyes/cheeks/spots/horns/feet, idle squash-stretch breathing) + Groq-authored name/title/lore/ability. Compiles clean, renders beautifully, LLM confirmed working (Vyzo/Weru examples).
- **BATTLE LOOP DONE and verified via real render (2026-07-05).** Summon screen has a `BATTLE ►` button → turn-based fight (`scripts/Battle.gd`): your summoned Auraling vs a freshly-generated wild one. ATTACK (1.0x) + element ABILITY (1.8x, 3-turn cooldown), 8-element type chart (super-effective 1.5x / resisted 0.66x, both directions confirmed in logs), tweened HP bars, floating damage numbers, hit flash, screen shake, VICTORY/DEFEATED banner + SUMMON ANOTHER return. Enemy AI uses its ability off cooldown else attacks. The LLM-authored name + ability carry into battle (stored on `current_creature`). Verify render: run `res://tools/CaptureBattle.tscn` → `_shots/battle_*.png`.
- Groq key in `secrets/groq_key.txt` (GITIGNORED). Model `llama-3.3-70b-versatile`, `response_format=json_object`, ~200ms.

## FILES
- `scripts/Palettes.gd` — 8 curated element palettes (body/shade/belly/accent/cheek).
- `scripts/CreatureGen.gd` — deterministic trait generator from a seed (harmonics silhouette, eyes, horns, pattern, stats, fallback name/ability).
- `scripts/CreatureView.gd` — draws the creature in code (`_draw`) + idle animation + `flash_hit()`.
- `scripts/LLM.gd` — Groq client, `request_identity(creature)` → `identity_ready(seed, dict)` signal.
- `scripts/Main.gd` — summon screen. All summon UI lives under a toggleable `summon_layer` so the battle can hide it; holds `current_creature`; `SUMMON` + `BATTLE ►` buttons; `_enter_battle()` / `_on_battle_over()` swap to/from the fight.
- `scripts/Battle.gd` — turn-based battle screen (self-contained, code-built). Type chart, ability cooldown, damage + juice, win/lose banner. Emits `battle_over`. `debug_attack()` hook lets the capture tool drive a turn.
- `tools/CaptureBattle.tscn` + `tools/capture_battle.gd` — dev battle screenshot tool (drives real turns to a KO, saves `_shots/battle_*.png`). Not shipped.
- `scenes/Main.tscn` — trivial (script-only). `tools/Capture.tscn` + `tools/capture.gd` — dev screenshot tool (not shipped).

## OPEN TODOs (next slices, in order)
1. ~~**Battle loop**~~ — DONE 2026-07-05 (see CURRENT STATE). Optional future juice: summon/KO particle bursts, a "wild appears" intro slide-in, a victory reward (add the beaten creature to a collection).
2. **Web shipping** — HTML5 export + host on Vercel for a clickable link. The current LLM path ONLY works on desktop (Godot reads the key from the gitignored `secrets/` file). It will NOT work as-is on web because (a) that file is excluded from the export so the browser has no key, (b) bundling the key would expose it publicly (view-source/network tab) = abuse/ban risk, and (c) browsers block calling Groq directly (CORS). FIX = a **Vercel serverless proxy** `/api/summon`:
   - Groq key lives in a **Vercel env var** (server-side, never shipped to client).
   - Godot web build calls same-origin `/api/summon` (no CORS) with creature traits; the function calls Groq and returns the identity JSON.
   - Point `LLM.gd` ENDPOINT at `/api/summon` for the web build; desktop keeps direct Groq + local secret. Make the endpoint build-configurable so both work.
   - Cost ₱0 (Groq free tier + Vercel free tier). CAVEAT: Groq free tier has rate limits, so under heavy traffic it can throttle — the existing **procedural fallback** in `LLM.gd`/`Main.gd` covers this (creature still gets its code-generated name/ability if the call fails), so it degrades gracefully. Fine for a demo handed to Michia.
3. **Art polish** — horns read a bit thin/pointy; add 1-2 rarer body archetypes; maybe a subtle summon particle burst + ground shadow.
4. (optional) a small "collection" / bestiary of summoned creatures; share-a-seed.

## APPLICATION CONTEXT
- Role is FAIR-to-STRONG fit; Daniel's edge is being genuinely AI-native (Claude Code skills/subagents workflow = exactly what Michia preaches in his videos) + shipped Godot (Loterya) & Unity (MAGSEL). Gap: no shipped commercial game at scale. Demo is meant to close that.
- Firewall: this is a REAL-NAME professional project. Lives in `Portfolio Projects/Actual Projects/`, NOT the pen-name `E:\Projects\GameDev\`.
- After demo ships: apply via L7V's short form, lead with "what I built with AI," drop the playable link.
