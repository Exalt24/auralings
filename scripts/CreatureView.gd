extends Node2D

const Pal = preload("res://scripts/Palettes.gd")

# Draws an Auraling entirely in code from its trait dict. A curated palette (jittered
# inside a harmony), a shape-language body, an independent face (eye style + mouth),
# and layered appendages (horns/spikes/fins/tail/arms) combine into a distinct look.
# Idle squash-and-stretch breathing + a dark outline read "intentional," not "slop."

var data: Dictionary = {}
var _pal: Dictionary = {}
var _phase: float = 0.0
var _blink: float = 0.0
var _blink_timer: float = 2.0
var _hit_flash: float = 0.0
var facing: float = 1.0

const RARITY_AURA := {"common": 0.0, "rare": 1.10, "epic": 1.28, "legendary": 1.46}

func set_creature(d: Dictionary) -> void:
	data = d
	_pal = Pal.varied(d.get("element", "tide"), d.get("hue_shift", 0.0), d.get("sat_mul", 1.0), d.get("val_mul", 1.0))
	queue_redraw()

func content_extent() -> float:
	if data.is_empty():
		return 1.0
	var r: float = data["body_radius"]
	var asp: float = data.get("aspect_y", 0.94)
	var harm_sum := 0.0
	for h in data["harmonics"]:
		harm_sum += abs(float(h["a"]))
	var reach: float = r * (1.0 + harm_sum) * maxf(asp, 1.0)
	reach = maxf(reach, r * 1.12)
	if data.get("horn_style", "none") != "none":
		reach = maxf(reach, r * 0.72 + float(data.get("horn_len", 0.0)) + 14.0)
	if data.get("has_tail", false):
		reach = maxf(reach, r * 1.30)
	var rar: String = data.get("rarity", "common")
	if RARITY_AURA.get(rar, 0.0) > 0.0:
		reach = maxf(reach, r * (RARITY_AURA[rar] + 0.10))
	return reach

func fit_to(target: float) -> void:
	var e := content_extent()
	if e > 0.0:
		var s := target / e
		scale = Vector2(s, s)

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
	var pal := _pal
	var r: float = data["body_radius"]

	var bob0 := sin(_phase * 2.2) * 6.0
	var shadow_squish := 1.0 + bob0 * 0.012
	_ellipse(Vector2(0, r * 1.08), r * 0.72 * shadow_squish, r * 0.16, Color(0, 0, 0, 0.22))

	_draw_aura(r, pal)

	var breathe := sin(_phase * 2.2) * 0.035
	var sx: float = data["squash"] * (1.0 - breathe) * facing
	var sy: float = (1.0 / data["squash"]) * (1.0 + breathe)
	var bob := sin(_phase * 2.2) * 6.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(sx, sy))

	var body: Color = pal["body"]
	if _hit_flash > 0.0:
		body = body.lerp(Color.WHITE, _hit_flash * 0.7)

	# --- behind-body layers ---
	if data.get("has_tail", false):
		_tail(r, pal)
	if data["foot_count"] == 2:
		_ellipse(Vector2(-r * 0.42, r * 0.88), 34, 22, pal["shade"])
		_ellipse(Vector2(r * 0.42, r * 0.88), 34, 22, pal["shade"])
	_arms(r, pal)
	if data.get("has_fins", false):
		_fins(r, pal)
	if data.get("has_spikes", false):
		_spikes(r, pal)
	_headgear(r, pal)

	# --- body: outline then fill ---
	var pts := _blob_points(r)
	var outline := _blob_points(r + 7.0)
	_poly(outline, pal["shade"])
	_poly(pts, body)

	# belly + pattern
	_ellipse(Vector2(0, r * 0.34 + data.get("top_bias", 0.0) * r), r * 0.52, r * 0.44, pal["belly"])
	_pattern(r, pal)

	_draw_face(r, pal)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- aura / rarity flair ---
func _draw_aura(r: float, pal: Dictionary) -> void:
	var rar: String = data.get("rarity", "common")
	var mult: float = RARITY_AURA.get(rar, 0.0)
	if mult <= 0.0:
		return
	var acc: Color = pal["accent"]
	var pulse := 0.5 + 0.5 * sin(_phase * 3.0)
	var rings := 3 if rar == "rare" else (4 if rar == "epic" else 5)
	for i in rings:
		var rr := r * (1.02 + i * 0.11)
		var a := 0.16 * (1.0 - i * 0.20) * (0.6 + 0.4 * pulse)
		draw_arc(Vector2.ZERO, rr, 0, TAU, 48, Color(acc.r, acc.g, acc.b, a), 3.0 + i)
	var sparks := 6 if rar == "rare" else (9 if rar == "epic" else 12)
	for i in sparks:
		var ang := _phase * 0.9 + TAU * float(i) / float(sparks)
		var sp := Vector2(cos(ang), sin(ang)) * r * (mult + 0.04)
		draw_circle(sp, 4.0 + 2.0 * pulse, Color(acc.r, acc.g, acc.b, 0.85))

# --- body silhouette ---
func _blob_points(r: float) -> PackedVector2Array:
	var harm: Array = data["harmonics"]
	var corner: float = data.get("corner", 0.0)
	var tb: float = data.get("top_bias", 0.0)
	var asp: float = data.get("aspect_y", 0.94)
	var n := 72
	var out := PackedVector2Array()
	for i in n:
		var ang := TAU * float(i) / float(n)
		var m := 1.0
		for h in harm:
			m += float(h["a"]) * sin(ang * float(h["f"]) + float(h["p"]))
		# squared-corner blend for "chonk" (superellipse-ish pull toward a rounded box)
		var cx := cos(ang)
		var cy := sin(ang)
		if corner > 0.0:
			var sq: float = 1.0 / max(0.35, pow(pow(abs(cx), 4.0) + pow(abs(cy), 4.0), 0.25))
			m = lerp(m, m * sq, corner)
		var rr := r * m
		var x := cx * rr
		var y := cy * rr * asp
		# top_bias shifts mass up (spike) or the point down (teardrop)
		y += tb * r * (0.5 - 0.5 * cy)
		out.append(Vector2(x, y))
	return out

# --- appendages ---
func _headgear(r: float, pal: Dictionary) -> void:
	var style: String = data.get("horn_style", "none")
	if style == "none":
		if data.get("has_ears", false):
			_ellipse(Vector2(-r * 0.5, -r * 0.66), 26, 40, pal["shade"])
			_ellipse(Vector2(r * 0.5, -r * 0.66), 26, 40, pal["shade"])
		return
	var hl: float = data.get("horn_len", 48.0)
	var two: bool = int(data.get("horn_count", 2)) == 2
	match style:
		"nub":
			_horn(Vector2(-r * 0.34, -r * 0.72), -0.35, hl * 0.6, pal["accent"], pal["shade"], 24, 9)
			if two: _horn(Vector2(r * 0.34, -r * 0.72), 0.35, hl * 0.6, pal["accent"], pal["shade"], 24, 9)
		"long":
			_horn(Vector2(-r * 0.32, -r * 0.70), -0.28, hl, pal["accent"], pal["shade"], 20, 4)
			if two: _horn(Vector2(r * 0.32, -r * 0.70), 0.28, hl, pal["accent"], pal["shade"], 20, 4)
		"curved":
			_curved_horn(Vector2(-r * 0.34, -r * 0.68), -1.0, hl, pal["accent"], pal["shade"])
			if two: _curved_horn(Vector2(r * 0.34, -r * 0.68), 1.0, hl, pal["accent"], pal["shade"])
		"antenna":
			_antenna(Vector2(-r * 0.24, -r * 0.74), -0.25, hl, pal["accent"], pal["shade"])
			if two: _antenna(Vector2(r * 0.24, -r * 0.74), 0.25, hl, pal["accent"], pal["shade"])
		"crown":
			_crown(r, pal)

func _crown(r: float, pal: Dictionary) -> void:
	# built from convex pieces (a base bar + one triangle per point) so it can never
	# be a self-intersecting polygon that fails triangulation
	var y := -r * 0.78
	var w := r * 0.5
	var spikes := 5
	_poly(PackedVector2Array([
		Vector2(-w, y + 18), Vector2(w, y + 18), Vector2(w, y + 2), Vector2(-w, y + 2)
	]), pal["accent"])
	for i in spikes:
		var cx: float = lerp(-w, w, (float(i) + 0.5) / float(spikes))
		var hh := 30.0 + (12.0 if i == 2 else 0.0)
		var half := w / float(spikes) * 0.72
		_poly(PackedVector2Array([
			Vector2(cx - half, y + 4), Vector2(cx + half, y + 4), Vector2(cx, y - hh)
		]), pal["accent"])

func _spikes(r: float, pal: Dictionary) -> void:
	var rows := int(data.get("spike_rows", 4))
	for i in rows:
		var t: float = (float(i) / float(max(1, rows - 1))) - 0.5
		var base := Vector2(t * r * 1.0, -r * (0.86 - absf(t) * 0.5))
		var h: float = 26.0 + 10.0 * (1.0 - absf(t) * 1.4)
		var tip := base + Vector2(t * 10.0, -h)
		var pts := PackedVector2Array([base + Vector2(-11, 0), base + Vector2(11, 0), tip])
		_poly(pts, pal["shade"])

func _fins(r: float, pal: Dictionary) -> void:
	for s in [-1.0, 1.0]:
		var b := Vector2(s * r * 0.86, r * 0.05)
		var pts := PackedVector2Array([
			b + Vector2(0, -34), b + Vector2(s * 44, -6),
			b + Vector2(s * 40, 30), b + Vector2(0, 30),
		])
		_poly(pts, pal["accent"])
		draw_polyline(PackedVector2Array([b + Vector2(0,-34), b + Vector2(s*44,-6), b + Vector2(s*40,30)]), pal["shade"], 3.0)

func _tail(r: float, pal: Dictionary) -> void:
	var b := Vector2(-r * 0.7, r * 0.5)
	var mid := b + Vector2(-r * 0.42, -r * 0.10)
	var tip := mid + Vector2(-r * 0.18, -r * 0.30)
	draw_polyline(PackedVector2Array([b, mid, tip]), pal["shade"], 16.0)
	draw_circle(tip, 16.0, pal["accent"])

func _arms(r: float, pal: Dictionary) -> void:
	match String(data.get("arm_style", "none")):
		"nubs":
			_ellipse(Vector2(-r * 0.92, r * 0.18), 22, 18, pal["shade"])
			_ellipse(Vector2(r * 0.92, r * 0.18), 22, 18, pal["shade"])
		"arms":
			for s in [-1.0, 1.0]:
				var sh := Vector2(s * r * 0.82, r * 0.02)
				var hand := sh + Vector2(s * r * 0.28, r * 0.22 + sin(_phase * 2.2) * 4.0)
				draw_line(sh, hand, pal["shade"], 14.0)
				draw_circle(hand, 15.0, pal["body"])

func _pattern(r: float, pal: Dictionary) -> void:
	match String(data.get("pattern", "none")):
		"spots":
			var srng := RandomNumberGenerator.new()
			srng.seed = data["pattern_rng"]
			for i in int(data["spot_count"]):
				var a := srng.randf_range(-PI, PI)
				var dist := srng.randf_range(0.3, 0.72) * r
				_ellipse(Vector2(cos(a), sin(a)) * dist, srng.randf_range(12, 22), srng.randf_range(12, 22), pal["shade"])
		"stripes":
			for i in range(-2, 3):
				var y := i * r * 0.24
				var half := sqrt(max(0.0, 1.0 - pow(y / (r * 0.95), 2.0))) * r * 0.8
				if half > 8.0:
					draw_line(Vector2(-half, y), Vector2(half, y), Color(pal["shade"].r, pal["shade"].g, pal["shade"].b, 0.5), 8.0)

# --- face ---
func _draw_face(r: float, pal: Dictionary) -> void:
	var ey: float = data["eye_y"]
	var es: float = data["eye_size"]
	var spacing: float = data["eye_spacing"]
	var style: String = data.get("eye_style", "round")
	var positions: Array[Vector2] = []
	match int(data["eye_count"]):
		1: positions = [Vector2(0, ey)]
		3: positions = [Vector2(-spacing, ey), Vector2(0, ey - 10), Vector2(spacing, ey)]
		_: positions = [Vector2(-spacing * 0.5, ey), Vector2(spacing * 0.5, ey)]

	if style in ["round", "cute", "wide", "sleepy"]:
		_ellipse(Vector2(-spacing * 0.62, ey + es * 0.9), 16, 11, pal["cheek"])
		_ellipse(Vector2(spacing * 0.62, ey + es * 0.9), 16, 11, pal["cheek"])

	for idx in positions.size():
		var p: Vector2 = positions[idx]
		var openness: float = 1.0 - _blink
		if openness <= 0.05:
			draw_line(p + Vector2(-es * 0.6, 0), p + Vector2(es * 0.6, 0), pal["shade"], 4.0)
			continue
		var w := es
		var hgt := es * openness
		match style:
			"wide": w = es * 1.15; hgt = es * 1.15 * openness
			"sleepy": hgt = es * 0.55 * openness
			"sharp": w = es * 1.1; hgt = es * 0.7 * openness
			"cute": w = es * 1.05; hgt = es * 1.05 * openness
		_ellipse(p, w, hgt, Color.WHITE)
		draw_arc(p, w, 0, TAU, 20, pal["shade"], 3.0)
		var pup: Vector2 = p + Vector2(es * 0.20, es * 0.10)
		draw_circle(pup, es * 0.5 * openness, Color("2b2b3a"))
		var shine := (es * 0.20 if style == "cute" else es * 0.16)
		draw_circle(pup + Vector2(-es * 0.15, -es * 0.18), shine, Color.WHITE)
		# angry/sharp: a thick slanted brow biting toward the nose (a line, so it can
		# never be a self-intersecting polygon)
		if style in ["angry", "sharp"]:
			var inner_x := w if p.x < 0.0 else -w   # toward center
			var brow_a := p + Vector2(-inner_x, -hgt * 1.25)
			var brow_b := p + Vector2(inner_x, -hgt * 0.35)
			draw_line(brow_a, brow_b, pal["shade"], 6.0)

	_draw_mouth(r, pal, ey, es)

func _draw_mouth(r: float, pal: Dictionary, ey: float, es: float) -> void:
	var my := ey + es * 1.7
	match String(data.get("mouth", "smile")):
		"smile":
			draw_arc(Vector2(0, my), 13, 0.15 * PI, 0.85 * PI, 14, pal["shade"], 3.0)
		"frown":
			draw_arc(Vector2(0, my + 10), 13, 1.15 * PI, 1.85 * PI, 14, pal["shade"], 3.0)
		"cat":
			draw_arc(Vector2(-7, my), 7, 0.1 * PI, 0.9 * PI, 8, pal["shade"], 3.0)
			draw_arc(Vector2(7, my), 7, 0.1 * PI, 0.9 * PI, 8, pal["shade"], 3.0)
		"open":
			_ellipse(Vector2(0, my + 2), 14, 12, Color("5b2b3a"))
			draw_arc(Vector2(0, my + 2), 14, 0, TAU, 18, pal["shade"], 2.0)
		"fang":
			draw_arc(Vector2(0, my), 15, 0.12 * PI, 0.88 * PI, 14, pal["shade"], 3.0)
			for fx in [-9.0, 9.0]:
				_poly(PackedVector2Array([
					Vector2(fx - 4, my + 2), Vector2(fx + 4, my + 2), Vector2(fx, my + 14)
				]), Color.WHITE)
		"beak":
			_poly(PackedVector2Array([
				Vector2(-11, my - 3), Vector2(11, my - 3), Vector2(0, my + 13)
			]), pal["accent"])
			draw_polyline(PackedVector2Array([Vector2(-11, my-3), Vector2(0, my+13), Vector2(11, my-3)]), pal["shade"], 2.0)

# --- primitives ---
# Guarded polygon draw: strips NaN/inf and duplicate-adjacent points and skips
# anything with fewer than 3 valid vertices, so degenerate appendage shapes never
# spam "triangulation failed" (Godot silently drops those, but the console noise
# looks bad to anyone with devtools open).
func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var clean := PackedVector2Array()
	for pt in pts:
		if not (is_finite(pt.x) and is_finite(pt.y)):
			continue
		if clean.size() > 0 and clean[clean.size() - 1].distance_to(pt) < 0.5:
			continue
		clean.append(pt)
	if clean.size() >= 3:
		draw_colored_polygon(clean, col)

func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var n := 24
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	_poly(pts, col)

func _horn(base: Vector2, lean: float, length: float, col: Color, edge: Color, w: float = 24.0, tw: float = 7.0) -> void:
	var tip := base + Vector2(sin(lean) * length * 0.5, -length)
	var tdir := (tip - base).normalized()
	var perp := Vector2(-tdir.y, tdir.x)
	var pts := PackedVector2Array([
		base + Vector2(-w, 6), base + Vector2(w, 6),
		tip + perp * tw, tip - perp * tw,
	])
	_poly(pts, col)
	draw_polyline(PackedVector2Array([
		base + Vector2(-w, 6), tip - perp * tw, tip + perp * tw, base + Vector2(w, 6)
	]), edge, 3.0)

func _curved_horn(base: Vector2, dir: float, length: float, col: Color, edge: Color) -> void:
	# drawn as per-segment convex trapezoids (perpendicular width) so the tapering
	# curve never folds into a self-intersecting polygon
	var segs := 8
	var center: Array[Vector2] = []
	for i in segs + 1:
		var t := float(i) / float(segs)
		var ang := dir * (0.3 + t * 1.1)
		center.append(base + Vector2(sin(ang) * length * 0.6 * dir, -cos(ang) * length))
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var a: Vector2 = center[i]
		var b: Vector2 = center[i + 1]
		var d := (b - a).normalized()
		var perp := Vector2(-d.y, d.x)
		var w0 := 8.0 * (1.0 - t0)
		var w1 := 8.0 * (1.0 - t1)
		_poly(PackedVector2Array([a + perp * w0, b + perp * w1, b - perp * w1, a - perp * w0]), col)

func _antenna(base: Vector2, lean: float, length: float, col: Color, edge: Color) -> void:
	var wob := sin(_phase * 2.4 + base.x) * 6.0
	var tip := base + Vector2(sin(lean) * length * 0.5 + wob, -length)
	draw_line(base, tip, edge, 4.0)
	draw_circle(tip, 8.0, col)
