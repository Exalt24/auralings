extends Node2D

const Pal = preload("res://scripts/Palettes.gd")

# Draws an Auraling entirely in code from its trait dict. Soft rounded blob body,
# curated-palette fill, dark outline (the outline is what reads "intentional"
# instead of "slop"), plus idle squash-and-stretch breathing = game juice.

var data: Dictionary = {}
var _phase: float = 0.0
var _blink: float = 0.0
var _blink_timer: float = 2.0
var _hit_flash: float = 0.0
var facing: float = 1.0  # 1 = faces right, -1 = faces left

func set_creature(d: Dictionary) -> void:
	data = d
	queue_redraw()

func flash_hit() -> void:
	_hit_flash = 1.0

func _process(delta: float) -> void:
	_phase += delta
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.0, 5.0)
	_blink = max(0.0, _blink - delta * 6.0)
	_hit_flash = max(0.0, _hit_flash - delta * 3.0)
	queue_redraw()

func _draw() -> void:
	if data.is_empty():
		return
	var pal: Dictionary = Pal.get_palette(data["element"])
	var r: float = data["body_radius"]

	# ground contact shadow (unscaled, sits under the creature so it feels planted)
	var bob0 := sin(_phase * 2.2) * 6.0
	var shadow_squish := 1.0 + bob0 * 0.012
	_ellipse(Vector2(0, r * 1.06), r * 0.72 * shadow_squish, r * 0.16, Color(0, 0, 0, 0.22))

	# radiant rare: glowing aura rings + orbiting sparkles behind the body
	if data.get("rare", false):
		var acc: Color = pal["accent"]
		var pulse := 0.5 + 0.5 * sin(_phase * 3.0)
		for i in 3:
			var rr := r * (1.12 + i * 0.13)
			var a := 0.14 * (1.0 - i * 0.28) * (0.6 + 0.4 * pulse)
			draw_arc(Vector2.ZERO, rr, 0, TAU, 48, Color(acc.r, acc.g, acc.b, a), 3.0 + i)
		for i in 6:
			var ang := _phase * 0.9 + TAU * float(i) / 6.0
			var sp := Vector2(cos(ang), sin(ang)) * r * 1.28
			draw_circle(sp, 4.0 + 2.0 * pulse, Color(acc.r, acc.g, acc.b, 0.85))

	# breathing: squash-and-stretch around a fixed baseline
	var breathe := sin(_phase * 2.2) * 0.035
	var sx: float = data["squash"] * (1.0 - breathe) * facing
	var sy: float = (1.0 / data["squash"]) * (1.0 + breathe)
	var bob := sin(_phase * 2.2) * 6.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(sx, sy))

	var body: Color = pal["body"]
	if _hit_flash > 0.0:
		body = body.lerp(Color.WHITE, _hit_flash * 0.7)

	# feet (behind body)
	if data["foot_count"] == 2:
		_ellipse(Vector2(-r * 0.42, r * 0.86), 34, 22, pal["shade"])
		_ellipse(Vector2(r * 0.42, r * 0.86), 34, 22, pal["shade"])

	# horns (behind body, on top)
	if data["has_horns"]:
		var hl: float = data["horn_len"]
		_horn(Vector2(-r * 0.34, -r * 0.72), -0.35, hl, pal["accent"], pal["shade"])
		if data["horn_count"] == 2:
			_horn(Vector2(r * 0.34, -r * 0.72), 0.35, hl, pal["accent"], pal["shade"])
	elif data["has_ears"]:
		_ellipse(Vector2(-r * 0.5, -r * 0.66), 26, 40, pal["shade"])
		_ellipse(Vector2(r * 0.5, -r * 0.66), 26, 40, pal["shade"])

	# body blob: outline first (slightly larger), then fill
	var pts := _blob_points(r)
	var outline := _blob_points(r + 7.0)
	draw_colored_polygon(outline, pal["shade"])
	draw_colored_polygon(pts, body)

	# belly highlight
	_ellipse(Vector2(0, r * 0.34), r * 0.52, r * 0.44, pal["belly"])

	# spots pattern
	if data["pattern"] == "spots":
		var srng := RandomNumberGenerator.new()
		srng.seed = data["pattern_rng"]
		for i in int(data["spot_count"]):
			var a := srng.randf_range(-PI, PI)
			var dist := srng.randf_range(0.3, 0.75) * r
			var pos := Vector2(cos(a), sin(a)) * dist
			_ellipse(pos, srng.randf_range(12, 22), srng.randf_range(12, 22), pal["shade"])

	_draw_face(r, pal)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_face(r: float, pal: Dictionary) -> void:
	var ey: float = data["eye_y"]
	var es: float = data["eye_size"]
	var spacing: float = data["eye_spacing"]
	var positions: Array[Vector2] = []
	match int(data["eye_count"]):
		1: positions = [Vector2(0, ey)]
		3: positions = [Vector2(-spacing, ey), Vector2(0, ey - 10), Vector2(spacing, ey)]
		_: positions = [Vector2(-spacing * 0.5, ey), Vector2(spacing * 0.5, ey)]

	# cheeks
	_ellipse(Vector2(-spacing * 0.62, ey + es * 0.9), 16, 11, pal["cheek"])
	_ellipse(Vector2(spacing * 0.62, ey + es * 0.9), 16, 11, pal["cheek"])

	for p in positions:
		var openness: float = 1.0 - _blink
		if openness <= 0.05:
			draw_line(p + Vector2(-es * 0.6, 0), p + Vector2(es * 0.6, 0), pal["shade"], 4.0)
			continue
		_ellipse(p, es, es * openness, Color.WHITE)
		draw_arc(p, es, 0, TAU, 20, pal["shade"], 3.0)
		# pupil looks slightly toward facing direction
		var pup: Vector2 = p + Vector2(es * 0.22, es * 0.12)
		draw_circle(pup, es * 0.5 * openness, Color("2b2b3a"))
		draw_circle(pup + Vector2(-es * 0.15, -es * 0.18), es * 0.16, Color.WHITE)

	# mouth (small friendly arc)
	var mouth_y := ey + es * 1.5
	draw_arc(Vector2(0, mouth_y), 12, 0.15 * PI, 0.85 * PI, 12, pal["shade"], 3.0)

# --- helpers ---

func _blob_points(r: float) -> PackedVector2Array:
	var harm: Array = data["harmonics"]
	var n := 64
	var out := PackedVector2Array()
	for i in n:
		var ang := TAU * float(i) / float(n)
		var m := 1.0
		for h in harm:
			m += float(h["a"]) * sin(ang * float(h["f"]) + float(h["p"]))
		var rr := r * m
		out.append(Vector2(cos(ang) * rr, sin(ang) * rr * 0.94))
	return out

func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var n := 24
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _horn(base: Vector2, lean: float, length: float, col: Color, edge: Color) -> void:
	# wider base + a short blunt tip (a 4-point shape, not a needle) so horns read
	# as sturdy little nubs instead of thin spikes
	var tip := base + Vector2(sin(lean) * length * 0.5, -length)
	var w := 24.0
	var tw := 7.0  # tip half-width (blunt, not a point)
	var tdir := (tip - base).normalized()
	var perp := Vector2(-tdir.y, tdir.x)
	var pts := PackedVector2Array([
		base + Vector2(-w, 6), base + Vector2(w, 6),
		tip + perp * tw, tip - perp * tw,
	])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([
		base + Vector2(-w, 6), tip - perp * tw, tip + perp * tw, base + Vector2(w, 6)
	]), edge, 3.0)
