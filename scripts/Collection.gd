extends Node2D

# The bestiary: a grid of every creature you've summoned (deduped by seed, newest
# first). Built in code from the saved {seed, name} list; each portrait is a live
# CreatureView regenerated from its seed (creatures are fully deterministic), so
# rares still show their aura here too.

signal closed

const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")

const W := 720
const H := 1280
const COLS := 3
const MAX_SHOWN := 12

var entries: Array = []  # [{seed:int, name:String}], newest first

func setup(collection: Array) -> void:
	entries = collection

func _ready() -> void:
	queue_redraw()
	_build()

func _draw() -> void:
	var top := Color("241b38")
	var bot := Color("3a2f52")
	var steps := 32
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(Rect2(0, H * t, W, H / steps + 1), top.lerp(bot, t))

func _build() -> void:
	var title := Label.new()
	title.text = "BESTIARY  (%d)" % entries.size()
	title.position = Vector2(0, 54)
	title.size = Vector2(W, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("ffe9c7"))
	add_child(title)

	if entries.is_empty():
		var empty := Label.new()
		empty.text = "No creatures yet. Summon some!"
		empty.position = Vector2(0, 560)
		empty.size = Vector2(W, 40)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 26)
		empty.add_theme_color_override("font_color", Color("c9b8e8"))
		add_child(empty)

	var cell_w := 200.0
	var cell_h := 250.0
	var x0 := 40.0
	var y0 := 140.0
	var gap := 20.0
	var shown: int = min(entries.size(), MAX_SHOWN)
	for i in shown:
		var e: Dictionary = entries[i]
		var col := i % COLS
		var row := i / COLS
		var cx := x0 + col * (cell_w + gap) + cell_w * 0.5
		var cy := y0 + row * cell_h + 96.0

		var c = CreatureGenScript.generate(int(e["seed"]))
		var view = CreatureViewScript.new()
		view.position = Vector2(cx, cy)
		add_child(view)
		view.set_creature(c)
		view.fit_to(80.0)   # uniform cell footprint so grid stays tidy

		var nm := Label.new()
		nm.text = String(e.get("name", c["name"]))
		nm.position = Vector2(x0 + col * (cell_w + gap), y0 + row * cell_h + 196.0)
		nm.size = Vector2(cell_w, 30)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 22)
		nm.add_theme_color_override("font_color", Color("ffe08a") if c.get("rare", false) else Color("ffffff"))
		add_child(nm)

	if entries.size() > MAX_SHOWN:
		var more := Label.new()
		more.text = "+ %d more" % (entries.size() - MAX_SHOWN)
		more.position = Vector2(0, 1096)
		more.size = Vector2(W, 30)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		more.add_theme_font_size_override("font_size", 22)
		more.add_theme_color_override("font_color", Color("c9b8e8"))
		add_child(more)

	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(W * 0.5 - 180, 1150)
	back.size = Vector2(360, 78)
	back.add_theme_font_size_override("font_size", 32)
	back.pressed.connect(func(): closed.emit())
	add_child(back)
