# Auralings — Test Checklist

Play at **https://auralings.vercel.app** (best on a phone, it's a mobile game).

Legend: ✅ = already auto-verified (Playwright/render/logic test, 0 console errors) · ⭐ = needs your human judgment.

## Load + summon
- [ ] ✅ Branded AURALINGS loader → game appears
- [ ] Tap SUMMON ~6x → each creature clearly different
- [ ] ⭐ After the FIRST tap you hear a summon blip (audio) — Daniel confirmed working 2026-07-08
- [ ] Occasionally hit RARE / EPIC / LEGENDARY (colored pill + aura)
- [ ] ✅ Gear (top-right) expands → Sound + Reduce Motion toggle & flip; re-tap collapses; resets after leaving a screen
- [ ] ✅ SHARE → share sheet on phone / clipboard fallback; ⭐ confirm you now SEE a "copied to clipboard!" / "opening share..." toast pop (fixed 2026-07-08, it was invisible before)

## The Gauntlet (core loop)
- [ ] ✅ GAUNTLET → fight shows "ROUND 1 · STREAK 0"
- [ ] ATTACK / ability / CHARGE work; "Super effective!" / "Resisted" show; BURN can proc; ⭐ SPEED: 1x/3x toggle speeds the battle up (renamed from TURBO 2026-07-08)
- [ ] ✅ Win → CHOOSE A BOON → pick one → ROUND 2 · STREAK 1, HP carried over
- [ ] ✅ Boons apply correctly (heal / fortify / power / focus / swift, all logic-tested)
- [ ] Climb a few rounds → lose → RUN OVER shows streak, best, "+N essence"
- [ ] ✅ NEW CHAMPION returns cleanly to summon

## Meta (achievements + upgrades)
- [ ] ✅ "Achievement: …" toast pops (shows even mid-battle)
- [ ] ✅ UPGRADES: Essence shown, BUY deducts, BACK works
- [ ] ✅ Buy Vigor/Might → next run champion starts stronger (logic-tested: +8 HP/lvl, +2 ATK/lvl)
- [ ] ✅ Buy Insight → boon screen shows 4 cards, no overflow

## Bestiary + persistence
- [ ] ✅ Rarity-bordered cards, "N discovered", SORT flips Newest/Rarity, PREV/NEXT page
- [ ] ✅ Reload page → discovered count + best streak survive (verified)
- [ ] ⭐ **Pick your champion:** tap any bestiary card → "X is your champion" toast, back on summon that creature is loaded, GAUNTLET runs with it (new 2026-07-08)
- [ ] ⭐ **Leveling:** run a creature a few times → it earns Lv (1 per 3 wins, cap 5); summon card shows "Lv N", bestiary shows a gold Lv badge; a leveled champ starts a bit stronger (+4 HP/+1 ATK per lvl). Logic auto-verified (TEST5)
- [ ] ⭐ **New toast look:** SHARE / champion-pick show a rounded pill w/ checkmark that slides up (was plain text)

## The one thing only you can judge
- [ ] ⭐ **Balance / feel:** does a run last a satisfying number of rounds, or snowball too long / wall too early? If it's off, tell Claude and the enemy-scaling / boon / upgrade numbers get tuned (`_scaled_enemy` in `scripts/Main.gd`, boon values in `_apply_boon`, upgrade steps in `UPGRADES`).

---
Almost everything is auto-verified. The real remaining task is the ⭐ **balance playtest**, then send the L7V email + Tally on your GO.
