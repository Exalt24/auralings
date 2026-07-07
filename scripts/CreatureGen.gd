extends RefCounted

const Pal = preload("res://scripts/Palettes.gd")

# Deterministic creature generator. Everything about an Auraling is derived from a
# single integer seed, so any creature is reproducible and shareable.
#
# Variety comes from CURATED ORTHOGONAL PARTS (not more randomness on one base): a
# shape-language body family, an independent face (eye style + mouth), layered
# appendages (horns/spikes/fins/tail/arms), and a per-creature color jitter inside a
# harmony. Traits are orthogonal so they combine into a huge distinct space.

const SYL_A := ["mo", "lu", "pi", "za", "no", "fi", "ku", "ta", "vy", "sha", "bo", "we", "dra", "ky", "ori", "sel"]
const SYL_B := ["ru", "mi", "la", "po", "nu", "ki", "sa", "to", "fu", "byn", "lo", "qua", "xis", "ven", "dor", "eth"]
const ARCHETYPES := ["Sprout", "Guardian", "Trickster", "Wanderer", "Ember", "Sage", "Brawler", "Dreamer"]

# Shape language: each element leans to a temperament, but with off-picks for variety.
# round=friendly, spike=fierce(triangle), chonk=sturdy(square), tall=lanky, teardrop=pear.
const SHAPES := ["round", "tall", "wide", "teardrop", "spike", "chonk"]
const SHAPE_BIAS := {
	"ember": ["spike", "spike", "tall", "round", "chonk", "teardrop"],
	"spark": ["spike", "spike", "tall", "teardrop", "round", "wide"],
	"void":  ["spike", "tall", "teardrop", "round", "chonk", "wide"],
	"tide":  ["round", "round", "wide", "teardrop", "tall", "chonk"],
	"frost": ["round", "tall", "teardrop", "round", "wide", "spike"],
	"bloom": ["round", "teardrop", "round", "wide", "tall", "spike"],
	"moss":  ["chonk", "wide", "round", "chonk", "teardrop", "tall"],
	"dusk":  ["chonk", "tall", "chonk", "round", "spike", "wide"],
}

const EYE_STYLES := ["round", "round", "sleepy", "angry", "sharp", "wide", "cute"]
const MOUTHS := ["smile", "smile", "fang", "open", "cat", "frown", "beak"]
const HORN_STYLES := ["nub", "curved", "antenna", "long", "crown"]

# rarity ladder -> the variable-reward jackpot. weights sum to 1.
const RARITY := ["common", "rare", "epic", "legendary"]
const RARITY_W := [0.70, 0.20, 0.08, 0.02]

static func generate(seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var element: String = Pal.ELEMENTS[rng.randi() % Pal.ELEMENTS.size()]

	# --- shape family (drives silhouette, proportions, harmonic drama, corners) ---
	var bias: Array = SHAPE_BIAS.get(element, SHAPES)
	var shape: String = bias[rng.randi() % bias.size()]
	var aspect_y := 0.94
	var squash := rng.randf_range(0.94, 1.08)
	var corner := 0.0          # 0 = organic, ->1 = squared (chonk)
	var harm_amp := 0.06       # base harmonic wobble
	var top_bias := 0.0        # >0 pushes mass upward (spike/tall)
	match shape:
		"tall":     aspect_y = rng.randf_range(1.12, 1.28)
		"wide":     aspect_y = rng.randf_range(0.66, 0.80)
		"teardrop": aspect_y = rng.randf_range(0.98, 1.06); top_bias = -0.10
		"spike":    aspect_y = rng.randf_range(1.04, 1.20); harm_amp = 0.12; top_bias = 0.16
		"chonk":    aspect_y = rng.randf_range(0.74, 0.86); corner = rng.randf_range(0.5, 0.85); squash = rng.randf_range(1.02, 1.14)
		_:          aspect_y = rng.randf_range(0.90, 1.0)

	# organic silhouette from a few low-freq harmonics (summed sine lobes = potato, not
	# a spiky-noise star). spike shapes get one higher, sharper lobe.
	var harmonics := []
	var freqs := [2, 3, 3, 4]
	for k in 3:
		harmonics.append({
			"f": freqs[rng.randi() % freqs.size()],
			"a": rng.randf_range(harm_amp * 0.5, harm_amp),
			"p": rng.randf_range(0.0, TAU),
		})
	if shape == "spike":
		harmonics.append({"f": rng.randi_range(5, 7), "a": 0.09, "p": rng.randf_range(0.0, TAU)})
	if shape == "teardrop":
		harmonics.append({"f": 1, "a": 0.10, "p": 0.0})

	var name: String = (SYL_A[rng.randi() % SYL_A.size()] + SYL_B[rng.randi() % SYL_B.size()])
	name = name.substr(0, 1).to_upper() + name.substr(1)

	# --- rarity (weighted) ---
	var roll := rng.randf()
	var rarity := "common"
	var acc := 0.0
	for i in RARITY.size():
		acc += RARITY_W[i]
		if roll <= acc:
			rarity = RARITY[i]
			break
	var rare := rarity != "common"

	var hp := rng.randi_range(60, 120)
	var atk := rng.randi_range(12, 26)
	var spd := rng.randi_range(8, 20)
	match rarity:
		"rare":      hp += 15; atk += 4; spd += 2
		"epic":      hp += 30; atk += 8; spd += 4
		"legendary": hp += 50; atk += 14; spd += 7

	# --- face: independent of element (orthogonal) ---
	var eye_style: String = EYE_STYLES[rng.randi() % EYE_STYLES.size()]
	var mouth: String = MOUTHS[rng.randi() % MOUTHS.size()]
	# fierce shapes lean toward fiercer faces a little
	if shape == "spike" and rng.randf() < 0.5:
		eye_style = ["angry", "sharp"][rng.randi() % 2]
		mouth = ["fang", "open"][rng.randi() % 2]

	# --- appendages: curated layered parts ---
	var horn_style: String = ("none" if rng.randf() > 0.55 else HORN_STYLES[rng.randi() % HORN_STYLES.size()])
	if rarity == "legendary" and horn_style == "none":
		horn_style = "crown"

	return {
		"seed": seed_val,
		"name": name,
		"element": element,
		"archetype": ARCHETYPES[rng.randi() % ARCHETYPES.size()],
		"rarity": rarity,
		"rare": rare,
		"hp": hp, "max_hp": hp, "atk": atk, "spd": spd,
		"ability_name": _ability_name(rng),
		"lore": "",
		# --- visual traits ---
		"shape": shape,
		"aspect_y": aspect_y,
		"corner": corner,
		"top_bias": top_bias,
		"body_radius": rng.randf_range(150.0, 190.0),
		"squash": squash,
		"harmonics": harmonics,
		"eye_style": eye_style,
		"eye_count": (2 if rng.randf() < 0.74 else (1 if rng.randf() < 0.5 else 3)),
		"eye_size": rng.randf_range(24.0, 40.0),
		"eye_spacing": rng.randf_range(46.0, 72.0),
		"eye_y": rng.randf_range(-28.0, 8.0),
		"mouth": mouth,
		"horn_style": horn_style,
		"horn_count": (2 if rng.randf() < 0.72 else 1),
		"horn_len": rng.randf_range(34.0, 66.0),
		"has_ears": horn_style == "none" and rng.randf() < 0.5,
		"has_spikes": rng.randf() < 0.32,          # dorsal row
		"spike_rows": rng.randi_range(3, 6),
		"has_fins": rng.randf() < 0.28,
		"has_tail": rng.randf() < 0.42,
		"arm_style": ["none", "nubs", "nubs", "arms"][rng.randi() % 4],
		"foot_count": (2 if rng.randf() < 0.72 else 0),
		"pattern": ["none", "spots", "belly", "stripes"][rng.randi() % 4],
		"spot_count": rng.randi_range(3, 7),
		"pattern_rng": rng.randi(),
		# --- color jitter inside the element's harmony ---
		"hue_shift": rng.randf_range(-1.0, 1.0),
		"sat_mul": rng.randf_range(0.88, 1.12),
		"val_mul": rng.randf_range(0.92, 1.10),
	}

static func _ability_name(rng: RandomNumberGenerator) -> String:
	var a := ["Radiant", "Tidal", "Thorn", "Static", "Glacial", "Shadow", "Petal", "Twilight", "Molten", "Astral"]
	var b := ["Burst", "Veil", "Crash", "Bloom", "Fang", "Wisp", "Surge", "Lullaby", "Nova", "Howl"]
	return a[rng.randi() % a.size()] + " " + b[rng.randi() % b.size()]
