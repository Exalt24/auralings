# Auralings — progress / handoff

**What it is:** an AI-native creature-summoner demo, built to apply for the **Game Developer role at L7V** (Michia Rohrssen, AI-native mobile game studio, Tokyo). Pitch: every creature is procedurally drawn from a seed, and a Groq LLM authors its identity (name, epithet, lore, ability) live. "Seed draws the body, AI writes the soul." Echoes his creature-collection world without copying his Japanese-learning game.

**Engine:** Godot 4.6 (`E:\Game Editors\Godot_v4.6-stable_win64.exe\`). Verify headless:
`"E:/Game Editors/.../Godot_v4.6-stable_win64_console.exe" --path . --headless --quit` (parse-check).
Render screenshots (real render, not headless): run `res://tools/Capture.tscn` → PNGs in `_shots/`.

## CURRENT STATE (2026-07-05)
- **v0.1 + LLM slice DONE and verified via real render.** Summon screen generates a procedural Auraling (smooth harmonic-blob body, curated per-element palette, eyes/cheeks/spots/horns/feet, idle squash-stretch breathing) + Groq-authored name/title/lore/ability. Compiles clean, renders beautifully, LLM confirmed working (Vyzo/Weru examples).
- **BATTLE LOOP DONE and verified via real render (2026-07-05).** Summon screen has a `BATTLE ►` button → turn-based fight (`scripts/Battle.gd`): your summoned Auraling vs a freshly-generated wild one. ATTACK (1.0x) + element ABILITY (1.8x, 3-turn cooldown), 8-element type chart (super-effective 1.5x / resisted 0.66x, both directions confirmed in logs), tweened HP bars, floating damage numbers, hit flash, screen shake, VICTORY/DEFEATED banner + SUMMON ANOTHER return. Enemy AI uses its ability off cooldown else attacks. The LLM-authored name + ability carry into battle (stored on `current_creature`). Verify render: run `res://tools/CaptureBattle.tscn` → `_shots/battle_*.png`.
- Groq key in `secrets/groq_key.txt` (GITIGNORED). Model `llama-3.3-70b-versatile`, `response_format=json_object`, ~200ms.
- **WEB SHIP DONE and verified live in a browser (2026-07-05).** Playable: **https://auralings.vercel.app** . Repo: **https://github.com/Exalt24/auralings** (public, Exalt24). Vercel project `auralings` is git-connected, so every push to `main` auto-deploys. The Groq key is NOT in the web build (excluded from the `.pck`); the web build calls a same-origin serverless proxy `api/summon.js` that injects `GROQ_API_KEY` (set in Vercel env, production + preview) server-side. Confirmed live: summon renders + AI-authored identity comes back through the proxy (e.g. "Filu, Void Walker") + battle loop runs, all in-browser via Playwright. Godot's HTTPRequest needs an ABSOLUTE url even on web, so `LLM.gd` resolves `window.location.origin` via `JavaScriptBridge` before hitting `/api/summon`.
- **Re-export + redeploy workflow:** edit code → `Godot ... --export-release "Web" public/index.html` → `git add -A && commit && push` (auto-deploys), or `vercel deploy --prod --yes --token "$VERCEL_TOKEN"` for an immediate push. Vercel token at `Other Files/.secrets/vercel_token.txt` (see memory `reference_vercel_token`).

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
2. ~~**Web shipping**~~ — DONE 2026-07-05 (see CURRENT STATE). Live at https://auralings.vercel.app , auto-deploys from the repo. Serverless proxy holds the key; graceful procedural fallback if Groq throttles.
3. ~~**Art polish**~~ — DONE 2026-07-06. Ground contact shadow under every creature; element-tinted summon + knockout spark bursts (`scripts/Fx.gd`, CPUParticles2D, no art assets); ~12% "radiant" rare variant with a glowing aura + stat bump (RARE tag in the info card); horns fattened into blunt nubs. All render-verified desktop (`tools/CapturePolish.tscn` forces a rare) + live in-browser. Optional remaining: 1-2 more silhouette archetypes.
4. (optional) a small "collection" / bestiary of summoned creatures; share-a-seed.

## APPLICATION CONTEXT
- Role is FAIR-to-STRONG fit; Daniel's edge is being genuinely AI-native (Claude Code skills/subagents workflow = exactly what Michia preaches in his videos) + shipped Godot (Loterya) & Unity (MAGSEL). Gap: no shipped commercial game at scale. Demo is meant to close that.
- Firewall: this is a REAL-NAME professional project. Lives in `Portfolio Projects/Actual Projects/`, NOT the pen-name `E:\Projects\GameDev\`.
- After demo ships: apply via L7V's short form, lead with "what I built with AI," drop the playable link.
