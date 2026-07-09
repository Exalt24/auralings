# Auralings

An AI-native roguelite creature collector built in Godot 4.6 and playable in the browser. Every creature is generated twice: a deterministic seed draws its body (shape, palette, element, rarity), and a Groq-hosted LLM writes its soul (name, epithet, lore). Same seed, same creature, every time, so the world is procedural but stable.

**Play it live: https://auralings.vercel.app**

## The Game

The core loop is a run called **The Gauntlet**:

1. **Summon** a champion. The seed builds a unique procedural creature; the LLM names it and writes its lore.
2. **Climb** escalating battle rounds. HP carries between fights, so every hit has weight.
3. **Draft** one of several boons after each win to shape your run.
4. **Chase a streak.** Push as far as you can before a loss ends the run.

Between runs, progress persists: your best streak is saved, run-earned **Essence** feeds a bounded upgrade shop (Vigor, Might, Insight), 8 achievements unlock with toasts, and every creature you summon is discovered into a paged, sortable bestiary.

## Features

- **Two-layer generation** — deterministic seed for the body, Groq LLM for the name and lore, so creatures are both reproducible and characterful.
- **Four battle roles** — Warden (Bulwark, -15% damage taken), Berserker (Frenzy, +30% damage under 40% HP), Skirmisher (Evasion, 18% dodge), and Adept (Focus, faster ability cooldowns). Each has a distinct stat spread and signature trait.
- **Rarity ladder** — common through legendary, with an underdog Essence bonus that rewards winning with lower-rarity creatures.
- **Persistent collection** — tap any discovered creature to make it your champion; creatures level up from wins (capped, with per-level stat gains that persist across re-summons).
- **Roguelite meta** — best-streak persistence, per-run Essence, a bounded upgrade shop, and an achievement system.
- **Sim-tuned balance** — enemy scaling was tuned with a Monte Carlo balance simulator (`tools/BalanceSim.tscn`) rather than by guesswork.
- **Native sharing** — Web Share API with a clipboard fallback for run results.

## Tech Stack

- **Engine:** Godot 4.6 (GDScript), exported to HTML5/WebAssembly
- **LLM:** Groq API, reached through a hardened serverless proxy (`api/summon.js`) with timeout, caching, and rate-limiting so the API key never ships to the client
- **Hosting:** Vercel (the `public/` web export plus the serverless function), auto-deploying from this repo

## Project Structure

```
scripts/        GDScript game logic (Battle, BoonChoice, Collection, CreatureGen,
                LLM, RunOver, ShopView, Achievements, Settings, UI, ...)
scenes/         Main scene
api/summon.js   Serverless Groq proxy (timeout / cache / rate-limit)
public/         Godot HTML5/WASM web export served by Vercel
tools/          Balance simulator and capture scenes (excluded from the web build)
vercel.json     Deploy + routing config
```

## Running Locally

1. Open the project in **Godot 4.6**.
2. To play with live LLM naming, the summon path expects the serverless proxy; run `vercel dev` (or deploy) so `/api/summon` is reachable, and set the Groq API key as an environment variable on the serverless side (never in the client).
3. Press play, or export to HTML5 and serve `public/`.

## Notes

Auralings started as a technical demo and grew into a complete, balance-tuned roguelite. The design intent is to show an AI-native production process end to end: procedural generation, an LLM woven into gameplay rather than bolted on, and a real meta-progression loop, all shipped and playable on the web.
