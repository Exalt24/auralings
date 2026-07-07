extends Node2D

# The bestiary: every creature you've summoned (deduped by seed, newest first), on
# polished rarity-bordered cards. Portraits are live CreatureViews regenerated from
# each seed (fully deterministic). Paged so the whole collection is browsable, with a
# completion header — the collection-completion hook that drives creature-collectors.

signal closed

const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")
const UI = preload("res://scripts/UI.gd")

const W := 720
const H := 1280
const COLS := 3
const ROWS := 3
const PAGE := COLS * ROWS

const RARITY_RANK := {"legendary": 0, "epic": 1, "rare": 2, "common": 3}

var entries: Array = []
var _order: Array = []        # the currently displayed order (sorted view)
var sfx = null
var _sort := "newest"
var _sort_btn: Button
var _page := 0
var _grid_root: Node2D
var _page_label: Label
var _prev_btn: Button
var _next_btn: Button

func setup(collection: Array) -> void:
	entries = collection
	_order = entries.duplicate()

func _ready() -> void:
	_build_chrome()
	_grid_root = Node2D.new()
	add_child(_grid_root)
	_render_page()
	queue_redraw()

func _draw() -> void:
	var top := Color("241b38")
	var bot := Color("3a2f52")
	var steps := 40
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(Rect2(0, H * t, W, H / steps + 1), top.lerp(bot, t))

func _build_chrome() -> void:
	var title := UI.label("BESTIARY", 42, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 46); title.size = Vector2(W, 50)
	add_child(title)
	var sub := UI.label("%d discovered" % entries.size(), 22, UI.MINT, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 100); sub.size = Vector2(W, 26)
	add_child(sub)

	# rarity legend
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 18)
	legend.position = Vector2(0, 132); legend.size = Vector2(W, 26)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(legend)
	for r in ["rare", "epic", "legendary"]:
		var dot := UI.label("● " + r, 15, UI.rarity_color(r))
		legend.add_child(dot)

	# sort toggle (newest / rarity). No search or filter — at this collection size that
	# would be over-engineering; a sort is the one control that pays off on a paged grid.
	_sort_btn = Button.new()
	_sort_btn.text = "SORT: NEWEST"
	_sort_btn.position = Vector2(W * 0.5 - 130, 1024); _sort_btn.size = Vector2(260, 42)
	UI.style_button(_sort_btn, UI.INK_SOFT, UI.MINT, 20)
	_sort_btn.pressed.connect(_toggle_sort)
	add_child(_sort_btn)

	_page_label = UI.label("", 20, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_page_label.position = Vector2(0, 1074); _page_label.size = Vector2(W, 28)
	add_child(_page_label)

	_prev_btn = Button.new()
	_prev_btn.text = "‹ PREV"
	_prev_btn.position = Vector2(40, 1116); _prev_btn.size = Vector2(180, 64)
	UI.style_button(_prev_btn, UI.INK_SOFT, UI.TEXT, 24)
	_prev_btn.pressed.connect(func(): _turn(-1))
	add_child(_prev_btn)

	_next_btn = Button.new()
	_next_btn.text = "NEXT ›"
	_next_btn.position = Vector2(W - 220, 1116); _next_btn.size = Vector2(180, 64)
	UI.style_button(_next_btn, UI.INK_SOFT, UI.TEXT, 24)
	_next_btn.pressed.connect(func(): _turn(1))
	add_child(_next_btn)

	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(W * 0.5 - 130, 1116); back.size = Vector2(260, 64)
	UI.style_button(back, Color("6b4fd0"), Color.WHITE, 26)
	back.pressed.connect(func():
		if sfx: sfx.play("tap")
		closed.emit())
	add_child(back)

func _turn(dir: int) -> void:
	var pages := int(ceil(float(_order.size()) / PAGE))
	_page = clampi(_page + dir, 0, max(0, pages - 1))
	if sfx: sfx.play("tap")
	_render_page()

func _toggle_sort() -> void:
	_sort = "rarity" if _sort == "newest" else "newest"
	_sort_btn.text = "SORT: RARITY" if _sort == "rarity" else "SORT: NEWEST"
	if sfx: sfx.play("tap")
	_apply_sort()
	_page = 0
	_render_page()

func _apply_sort() -> void:
	_order = entries.duplicate()
	if _sort == "rarity":
		# stable sort: rarest first, ties keep newest-first order
		var indexed := []
		for i in _order.size():
			indexed.append({"e": _order[i], "i": i})
		indexed.sort_custom(func(a, b):
			var ra: int = RARITY_RANK.get(String(a["e"].get("rarity", "common")), 3)
			var rb: int = RARITY_RANK.get(String(b["e"].get("rarity", "common")), 3)
			if ra == rb:
				return a["i"] < b["i"]
			return ra < rb)
		_order.clear()
		for item in indexed:
			_order.append(item["e"])

func _render_page() -> void:
	for ch in _grid_root.get_children():
		ch.queue_free()

	if _order.is_empty():
		var empty := UI.label("No creatures yet. Go summon some!", 26, Color("c9b8e8"), HORIZONTAL_ALIGNMENT_CENTER)
		empty.position = Vector2(0, 560); empty.size = Vector2(W, 40)
		_grid_root.add_child(empty)
		_page_label.text = ""
		_prev_btn.disabled = true; _next_btn.disabled = true
		return

	var pages := int(ceil(float(_order.size()) / PAGE))
	_page_label.text = "page %d / %d" % [_page + 1, pages]
	_prev_btn.disabled = _page <= 0
	_next_btn.disabled = _page >= pages - 1

	var cell_w := 200.0
	var cell_h := 268.0
	var gap := 14.0
	var x0 := (W - (COLS * cell_w + (COLS - 1) * gap)) * 0.5
	var y0 := 176.0
	var start := _page * PAGE
	for i in range(start, min(start + PAGE, _order.size())):
		var e: Dictionary = _order[i]
		var li := i - start
		var col := li % COLS
		var row := li / COLS
		var rx := x0 + col * (cell_w + gap)
		var ry := y0 + row * (cell_h + gap)
		var c: Dictionary = CreatureGenScript.generate(int(e["seed"]))
		var rar := String(e.get("rarity", c.get("rarity", "common")))
		var rcol: Color = UI.rarity_color(rar)

		# card background (rarity-tinted border for rares)
		var cardbg := PanelContainer.new()
		var border_c := rcol if rar != "common" else Color(1,1,1,0.05)
		var border_w := 3 if rar != "common" else 1
		cardbg.add_theme_stylebox_override("panel", UI.panel(Color("2f2650"), 18, border_c, border_w, 4))
		cardbg.position = Vector2(rx, ry); cardbg.size = Vector2(cell_w, cell_h)
		_grid_root.add_child(cardbg)

		# portrait (Node2D sibling, drawn on top, centered in the card)
		var view = CreatureViewScript.new()
		view.position = Vector2(rx + cell_w * 0.5, ry + cell_h * 0.44)
		_grid_root.add_child(view)
		view.set_creature(c)
		view.fit_to(74.0)

		var nm := UI.label(String(e.get("name", c["name"])), 21, rcol if rar != "common" else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		nm.position = Vector2(rx, ry + cell_h - 66); nm.size = Vector2(cell_w, 26)
		_grid_root.add_child(nm)
		var el := UI.label(String(c["element"]).capitalize() + ("  " + rar if rar != "common" else ""), 15, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		el.position = Vector2(rx, ry + cell_h - 38); el.size = Vector2(cell_w, 22)
		_grid_root.add_child(el)
