# Auralings — Upgrade Spec (research-grounded)

Built from a web sweep across procedural generation, shape language, color theory,
game feel, creature-collector loops, turn-based depth, UI/UX, onboarding, QOL, web
perf, audio, accessibility, and viral/social loops. Sources cited inline per topic.
Goal: turn the demo from "competent weekend prototype" into something that survives a
$110M-exit founder's 10-second scan AND rewards a real play.

## THE ROOT PROBLEM (verified in the baseline proof sheet)
Every creature shares the SAME face (eyes/pupil/smile/cheeks) and the same soft blob
body. Random ≠ variety — devs call this "procedural blandness." Fix = curated,
ORTHOGONAL parts combined widely, not more randomness on one base.
(gamedeveloper.com "use but not abuse procedural generation"; positech "procedurally generated blandness")

## WAVE 1 — VISUAL DISTINCTNESS (make the tagline true)
1. Shape language: element -> temperament -> body shape family. Round=friendly,
   triangle/spike=fierce, square/chonk=sturdy. Vary silhouette HARD, not just color.
   (CGWire character-shape-language; Spore metaball/rigblock breakdown)
2. Face orthogonality: eye_style (round/sleepy/angry/sharp/wide), eye_count 1/2/3,
   mouth_type (smile/fang/open/frown/beak/cat). This alone kills the sameness.
3. Appendages as layered curated parts: horns (nub/curved/antenna/long/crown), spikes
   (dorsal row), fins, tail, arms/nubs, ears. Attach at varied points. (Spore rigblocks)
4. Color jitter inside a harmony: rotate hue ~±22deg + gentle sat/val in HSV so two
   same-element creatures differ but stay curated. (devmag procedural colour algorithms)
5. Rarity ladder: common/rare/epic/legendary (variable-reward jackpot), escalating aura.
   (Core loop / compulsion loop; creature-collector retention)

## WAVE 2 — GAME FEEL / JUICE
- Hitstop 60-80ms on hits, short eased screenshake (50-300ms), squash-stretch, KO
  particle bursts, summon reveal beat. Juice must echo the core action.
  (valdemird game-feel-on-the-web; gameanalytics squeezing-more-juice)
- Procedural SFX (AudioStreamGenerator, zero assets): summon, tap, hit, crit, KO,
  victory. Silent games feel dead; juicy audio raises presence/immersion.
  (ACM "Juicy Audio"; sfxengine sound-design)

## WAVE 3 — BATTLE DEPTH (interesting decisions)
- Speed stat -> dynamic turn order. One status effect (burn OR freeze). A risk/reward
  third option (Charge: skip a turn, next hit 2.5x) so every turn is a small dilemma.
  Keep the 8-element chart but SHOW effectiveness in words ("super effective!").
  (gamedeveloper "12 ways to improve turn-based combat"; Untamed Tactics dev)
- QOL: turbo/anim-skip toggle for battle (turn-based QOL players love). (missi QOL list)

## WAVE 4 — UI/UX + ONBOARDING + QOL
- 30-second hook: first load auto-summons a striking (biased-rare) creature + a one-line
  "tap SUMMON" nudge; quick win < 90s. Teach through play, no wall of text.
  (hypehype FTUE; yukaichou 4-second rule)
- Touch targets >= 48px, actions in bottom thumb zone (already mostly true), every tap
  gives visual+audio feedback, consistent styling, micro-interactions on buttons.
  (Apple HIG 44pt / Material 48dp; uxplanet game UX)
- Bestiary shows rarity + discovered count ("12 discovered") = collection completion hook.

## WAVE 5 — VIRAL / SOCIAL + ACCESSIBILITY
- Shareable result upgraded to a Wordle-style text card (name + element + rarity +
  seed link) so a share reads as a flex, not a bare URL. (Wordle grid; viral core-loop)
- Accessibility: element/effectiveness conveyed by TEXT not color alone (colorblind);
  respect reduced-motion (damp shake/particles). (Game Accessibility Guidelines)

## WEB PERF GUARDRAILS
- Keep draw calls low (already single-canvas code draw); async LLM already non-blocking;
  procedural everything = tiny build, fast first paint. (gamedevjs WebGL best practices)
</content>
