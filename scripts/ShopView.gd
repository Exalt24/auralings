extends Node2D

# Meta upgrade shop: spend Essence (earned per run) on a few BOUNDED permanent perks.
# Kept small and capped on purpose so it never trivializes the enemy ramp.

signal bought(id)
signal closed

const UI = preload("res://scripts/UI.gd")
const W := 720
const H := 1280

var essence := 0
var upgrades := {}
var defs: Array = []
var sfx = null
var _rows_root: Node2D
var _essence_label: Label

func setup(ess: int, ups: Dictionary, definitions: Array) -> void:
	essence = ess
	upgrades = ups
	defs = definitions

func _ready() -> void:
	# input blocker: the shop can open over a still-visible screen (summon / run-over),
	# and the _draw background doesn't stop input, so this Control absorbs stray clicks
	# so they can't fall through to the buttons behind
	var blocker := Control.new()
	blocker.size = Vector2(W, H)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	_build_chrome()
	_rows_root = Node2D.new()
	add_child(_rows_root)
	_render()
	queue_redraw()

func _draw() -> void:
	var top := Color("241b38")
	var bot := Color("3a2f52")
	for i in 40:
		var t := float(i) / 40.0
		draw_rect(Rect2(0, H * t, W, H / 40 + 1), top.lerp(bot, t))

func refresh(ess: int, ups: Dictionary) -> void:
	essence = ess
	upgrades = ups
	_essence_label.text = "Essence:  %d" % essence
	_render()

func _build_chrome() -> void:
	var head := VBoxContainer.new()
	head.position = Vector2(40, 66); head.size = Vector2(W - 80, 110)
	head.add_theme_constant_override("separation", 6)
	add_child(head)
	head.add_child(UI.label("UPGRADES", 44, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_essence_label = UI.label("Essence:  %d" % essence, 26, UI.MINT, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_child(_essence_label)

	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(W * 0.5 - 130, H - 120); back.size = Vector2(260, 72)
	UI.style_button(back, Color("6b4fd0"), Color.WHITE, 28)
	back.pressed.connect(func():
		if sfx: sfx.play("tap")
		closed.emit())
	add_child(back)

func _render() -> void:
	for ch in _rows_root.get_children():
		ch.queue_free()
	# lay the cards out in a centered VBox that fills the space between the header and the
	# BACK button, with generous spacing — was hand-placed at the top with a big dead void
	var box := VBoxContainer.new()
	box.position = Vector2(50, 200)
	box.size = Vector2(W - 100, H - 200 - 168)
	box.add_theme_constant_override("separation", 30)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_rows_root.add_child(box)
	for d in defs:
		box.add_child(_row(d))

func _row(d: Dictionary) -> PanelContainer:
	var id := String(d["id"])
	var lvl := int(upgrades.get(id, 0))
	var mx := int(d["max"])
	var maxed := lvl >= mx
	var next_cost := 0 if maxed else int(d["cost"][lvl])
	var afford := not maxed and essence >= next_cost

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.panel(UI.CARD, 18, Color(1, 1, 1, 0.06), 2, 6))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 196)
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 18)
	card.add_child(pad)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(vb)
	var titlerow := HBoxContainer.new()
	vb.add_child(titlerow)
	var nm := UI.label(String(d["name"]), 28, UI.GOLD)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titlerow.add_child(nm)
	titlerow.add_child(UI.label("Lv %d/%d" % [lvl, mx], 22, UI.TEXT_DIM))
	var desc := UI.label(String(d["desc"]), 20, UI.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)
	var buy := Button.new()
	buy.text = ("MAXED" if maxed else "BUY  ·  %d essence" % next_cost)
	buy.custom_minimum_size = Vector2(0, 56)
	buy.disabled = maxed or not afford
	UI.style_button(buy, (UI.INK_SOFT if not afford else Color("2f8f6b")), (UI.TEXT_DIM if not afford else Color.WHITE), 22)
	buy.pressed.connect(func():
		if sfx: sfx.play("ability")
		bought.emit(id))
	vb.add_child(buy)
	return card
