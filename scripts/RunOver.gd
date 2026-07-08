extends Node2D

# End-of-run screen: your streak, your best, the champion who carried you, and a
# shareable flex + a button back to summon a fresh champion.

signal share_pressed
signal continue_pressed
signal shop_pressed

const UI = preload("res://scripts/UI.gd")
const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const W := 720
const H := 1280

var champion: Dictionary = {}
var streak := 0
var best := 0
var is_new_best := false
var essence_earned := 0
var sfx = null

func setup(champ: Dictionary, streak_val: int, best_val: int, new_best: bool, essence: int = 0) -> void:
	champion = champ
	streak = streak_val
	best = best_val
	is_new_best = new_best
	essence_earned = essence

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
	var head := VBoxContainer.new()
	head.position = Vector2(40, 90); head.size = Vector2(W - 80, 160)
	head.add_theme_constant_override("separation", 6)
	add_child(head)
	head.add_child(UI.label("RUN OVER", 52, Color("ff8090"), HORIZONTAL_ALIGNMENT_CENTER))
	head.add_child(UI.label("%s fell in battle" % champion.get("name", "?"), 20, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	var view = CreatureViewScript.new()
	view.position = Vector2(W * 0.5, 420)
	add_child(view)
	view.set_creature(champion)
	view.fit_to(130.0)

	# streak + best block
	var stats := VBoxContainer.new()
	stats.position = Vector2(60, 640); stats.size = Vector2(W - 120, 220)
	stats.add_theme_constant_override("separation", 8)
	add_child(stats)
	stats.add_child(UI.label("STREAK", 24, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	stats.add_child(UI.label(str(streak), 84, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var best_txt := ("NEW BEST!" if is_new_best else "best  %d" % best)
	stats.add_child(UI.label(best_txt, 26, UI.MINT if is_new_best else UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	stats.add_child(UI.label("+%d essence" % essence_earned, 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	# buttons
	var row := VBoxContainer.new()
	row.position = Vector2(60, H - 320); row.size = Vector2(W - 120, 290)
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	row.add_child(top)
	var share := Button.new()
	share.text = "SHARE"
	share.custom_minimum_size = Vector2(0, 68)
	share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(share, UI.INK_SOFT, UI.MINT, 24)
	share.pressed.connect(func():
		if sfx: sfx.play("tap")
		share_pressed.emit())
	top.add_child(share)
	var shop := Button.new()
	shop.text = "UPGRADES"
	shop.custom_minimum_size = Vector2(0, 68)
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(shop, UI.INK_SOFT, UI.GOLD, 24)
	shop.pressed.connect(func():
		if sfx: sfx.play("tap")
		shop_pressed.emit())
	top.add_child(shop)
	var cont := Button.new()
	cont.text = "NEW CHAMPION"
	cont.custom_minimum_size = Vector2(0, 84)
	UI.style_button(cont, Color("6b4fd0"), Color.WHITE, 30)
	cont.pressed.connect(func():
		if sfx: sfx.play("tap")
		continue_pressed.emit())
	row.add_child(cont)
