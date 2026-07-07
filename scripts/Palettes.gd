extends RefCounted

# Hand-curated palettes per element. Curated (never random-RGB) is the #1 thing
# that keeps procedural creatures from looking like slop. Each palette:
#   body, body_shade (darker, for outline + belly base), belly (lighter),
#   accent (horns/pattern), cheek.
const TABLE := {
	"ember":  {"body": Color("ff8a5c"), "shade": Color("c14b2e"), "belly": Color("ffd7a8"), "accent": Color("ffcf4d"), "cheek": Color("ff5d6c")},
	"tide":   {"body": Color("4fc4d6"), "shade": Color("2b7a99"), "belly": Color("cdf3f5"), "accent": Color("7ef0d0"), "cheek": Color("ff9bb0")},
	"moss":   {"body": Color("8bd66b"), "shade": Color("4f9440"), "belly": Color("e6f7c9"), "accent": Color("f6e05e"), "cheek": Color("ff9d8a")},
	"spark":  {"body": Color("ffd23f"), "shade": Color("d99a1c"), "belly": Color("fff3c4"), "accent": Color("ff8a3d"), "cheek": Color("ff6f91")},
	"frost":  {"body": Color("a9c9ff"), "shade": Color("5f82c4"), "belly": Color("eaf1ff"), "accent": Color("d9c6ff"), "cheek": Color("ffb3c6")},
	"void":   {"body": Color("9b6bd6"), "shade": Color("5e3a94"), "belly": Color("e3d4f7"), "accent": Color("ff7ad0"), "cheek": Color("ff8fb0")},
	"bloom":  {"body": Color("ff9ec7"), "shade": Color("d95f96"), "belly": Color("ffe1ef"), "accent": Color("ffe08a"), "cheek": Color("ff6b9d")},
	"dusk":   {"body": Color("6b7bd6"), "shade": Color("3d4a94"), "belly": Color("d6ddf7"), "accent": Color("ffb15c"), "cheek": Color("ff8fa8")},
}

const ELEMENTS := ["ember", "tide", "moss", "spark", "frost", "void", "bloom", "dusk"]

static func get_palette(element: String) -> Dictionary:
	return TABLE.get(element, TABLE["tide"])

# Per-creature palette variation. Two same-element creatures should not be the same
# color, but we stay INSIDE a harmony (small hue rotation + gentle sat/val nudges in
# HSV) so the result is still curated, never random-RGB slop. hue_shift in [-1,1] maps
# to ~±22deg; sat_mul / val_mul are small multipliers.
static func varied(element: String, hue_shift: float, sat_mul: float, val_mul: float) -> Dictionary:
	var base: Dictionary = get_palette(element)
	var out := {}
	for k in base.keys():
		out[k] = _nudge(base[k], hue_shift, sat_mul, val_mul)
	return out

static func _nudge(c: Color, hue_shift: float, sat_mul: float, val_mul: float) -> Color:
	var h := c.h + hue_shift * 0.061   # ~±22deg at full shift
	h = fposmod(h, 1.0)
	var s := clampf(c.s * sat_mul, 0.0, 1.0)
	var v := clampf(c.v * val_mul, 0.0, 1.0)
	return Color.from_hsv(h, s, v, c.a)
