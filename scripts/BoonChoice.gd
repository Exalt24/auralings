extends Node2D

# The run-altering choice shown after each gauntlet win: pick 1 of 3 boons, the
# others are locked, so every pick carries weight (the roguelite hook). Built on the
# shared UI kit, container-laid-out.

signal picked(boon_id)

const UI = preload("res://scripts/UI.gd")
const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const W := 720
const H := 1280

var champion: Dictionary = {}
var boons: Array = []
var streak := 0
var sfx = null

func setup(champ: Dictionary, choices: Array, streak_val: int) -> void:
	champion = champ
	boons = choices
	streak = streak_val

func _ready() -> void:
	_build()
	queue_redraw()

func _draw() -> void:
	var top := Color("241b38")
	var bot := Color("3a2f52")
	for i in 40:
		var t := float(i) / 40.0
		draw_rect(Rect2(0, H * t, W, H / 40 + 1), top.lerp(bot, t))

func _build() -> void:
	var root := Control.new()
	root.size = Vector2(W, H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var head := VBoxContainer.new()
	head.position = Vector2(40, 70); head.size = Vector2(W - 80, 120)
	head.add_theme_constant_override("separation", 4)
	add_child(head)
	head.add_child(UI.label("CHOOSE A BOON", 40, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	head.add_child(UI.label("streak %d  ·  %s survives" % [streak, champion.get("name", "?")], 20, UI.MINT, HORIZONTAL_ALIGNMENT_CENTER))

	# champion portrait
	var view = CreatureViewScript.new()
	view.position = Vector2(W * 0.5, 330)
	add_child(view)
	view.set_creature(champion)
	view.fit_to(120.0)

	# boon cards, centered in the region below the portrait so they fill the space
	# (handles 3 or 4 cards) instead of clustering high with a dead void beneath
	var col := VBoxContainer.new()
	col.position = Vector2(60, 450); col.size = Vector2(W - 120, H - 450 - 60)
	col.add_theme_constant_override("separation", 24)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)
	for b in boons:
		col.add_child(_card(b))

func _card(boon: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 150)
	UI.style_button(btn, UI.CARD, UI.TEXT, 20, 22)
	# lay name + desc inside the button
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 20)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(pad)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(vb)
	vb.add_child(UI.label(String(boon["name"]), 30, UI.GOLD))
	var d := UI.label(String(boon["desc"]), 22, UI.MINT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(d)
	btn.pressed.connect(func():
		if sfx: sfx.play("ability")
		picked.emit(String(boon["id"])))
	return btn
