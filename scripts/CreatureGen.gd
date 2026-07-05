extends RefCounted

const Pal = preload("res://scripts/Palettes.gd")

# Deterministic creature generator. Everything about an Auraling is derived from
# a single integer seed, so any creature is reproducible and shareable.
# For v0.1 the name/lore/ability are procedural placeholders; the LLM layer
# (Groq) will later author these while the SEED still drives the visuals.

const SYL_A := ["mo", "lu", "pi", "za", "no", "fi", "ku", "ta", "vy", "sha", "bo", "we"]
const SYL_B := ["ru", "mi", "la", "po", "nu", "ki", "sa", "to", "fu", "byn", "lo", "qua"]
const ARCHETYPES := ["Sprout", "Guardian", "Trickster", "Wanderer", "Ember", "Sage", "Brawler", "Dreamer"]

static func generate(seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var element: String = Pal.ELEMENTS[rng.randi() % Pal.ELEMENTS.size()]

	# smooth blob silhouette from a few low-frequency harmonics. Summing 3 gentle
	# sine lobes around the circle gives an organic potato shape, NOT a spiky star
	# (independent per-vertex noise is the classic slop tell).
	var harmonics := []
	var freqs := [2, 3, 3, 4]
	for k in 3:
		harmonics.append({
			"f": freqs[rng.randi() % freqs.size()],
			"a": rng.randf_range(0.03, 0.08),
			"p": rng.randf_range(0.0, TAU),
		})

	var name: String = (SYL_A[rng.randi() % SYL_A.size()] + SYL_B[rng.randi() % SYL_B.size()])
	name = name.substr(0, 1).to_upper() + name.substr(1)

	var hp := rng.randi_range(60, 120)
	var atk := rng.randi_range(12, 26)

	return {
		"seed": seed_val,
		"name": name,
		"element": element,
		"archetype": ARCHETYPES[rng.randi() % ARCHETYPES.size()],
		"hp": hp,
		"max_hp": hp,
		"atk": atk,
		"ability_name": _ability_name(rng),
		"lore": "",  # LLM fills this later
		# --- visual traits ---
		"body_radius": rng.randf_range(150.0, 190.0),
		"squash": rng.randf_range(0.9, 1.12),
		"harmonics": harmonics,
		"eye_count": (2 if rng.randf() < 0.78 else (1 if rng.randf() < 0.5 else 3)),
		"eye_size": rng.randf_range(24.0, 40.0),
		"eye_spacing": rng.randf_range(46.0, 70.0),
		"eye_y": rng.randf_range(-30.0, 10.0),
		"has_horns": rng.randf() < 0.55,
		"horn_count": (2 if rng.randf() < 0.7 else 1),
		"horn_len": rng.randf_range(34.0, 62.0),
		"has_ears": rng.randf() < 0.5,
		"foot_count": (2 if rng.randf() < 0.75 else 0),
		"pattern": ["none", "spots", "belly"][rng.randi() % 3],
		"spot_count": rng.randi_range(3, 7),
		"pattern_rng": rng.randi(),
	}

static func _ability_name(rng: RandomNumberGenerator) -> String:
	var a := ["Radiant", "Tidal", "Thorn", "Static", "Glacial", "Shadow", "Petal", "Twilight"]
	var b := ["Burst", "Veil", "Crash", "Bloom", "Fang", "Wisp", "Surge", "Lullaby"]
	return a[rng.randi() % a.size()] + " " + b[rng.randi() % b.size()]
