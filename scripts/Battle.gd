extends Node2D

# Turn-based battle screen: your summoned Auraling vs a wild one. Everything is
# built in code so the scene file stays trivial. This is the slice that turns the
# summon viewer into an actual GAME: HP bars, an attack + an element ability on a
# cooldown, type effectiveness, and juice (screen shake, hit flash, floating
# damage numbers, tweened HP bars) so hits FEEL like they land.

signal battle_over(player_won: bool)

const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")

const W := 720
const H := 1280

# Element cycle: each element is strong against exactly one other. Attacker strong
# vs defender = 1.5x ("super effective"); the reverse = 0.66x ("resisted"); else 1x.
const STRONG := {
	"ember": "moss", "moss": "tide", "tide": "ember",
	"spark": "frost", "frost": "bloom", "bloom": "spark",
	"void": "dusk", "dusk": "void",
}

const ABILITY_CD := 3  # turns between ability uses

var player: Dictionary = {}
var enemy: Dictionary = {}
var player_hp: int = 0
var enemy_hp: int = 0
var player_cd: int = 0
var enemy_cd: int = 0
var busy: bool = false
var finished: bool = false

var world: Node2D          # shaken container (creatures + floating numbers)
var ui: Node2D             # steady container (bars, buttons, labels)
var p_view
var e_view
var p_fill: ColorRect
var e_fill: ColorRect
var p_hp_label: Label
var e_hp_label: Label
var log_label: Label
var attack_btn: Button
var ability_btn: Button
var banner: Label
var back_btn: Button

var _p_bar_w := 300.0
var _e_bar_w := 300.0
var _shake := 0.0

func setup(player_creature: Dictionary) -> void:
	player = player_creature.duplicate(true)
	enemy = CreatureGenScript.generate(randi())
	player_hp = int(player["max_hp"])
	enemy_hp = int(enemy["max_hp"])

func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	ui = Node2D.new()
	add_child(ui)
	_build()

func _draw() -> void:
	# opaque arena backdrop (covers the summon screen behind it)
	var top := Color("1c2740")
	var bot := Color("3a2f52")
	var steps := 32
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(Rect2(0, H * t, W, H / steps + 1), top.lerp(bot, t))
	# a soft ground line between the two combatants
	draw_rect(Rect2(0, 640, W, 4), Color(1, 1, 1, 0.06))

func _process(delta: float) -> void:
	if _shake > 0.0:
		world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = max(0.0, _shake - delta * 42.0)
	else:
		world.position = Vector2.ZERO

func _build() -> void:
	queue_redraw()

	# --- enemy (top), faces left; its info sits top-left ---
	e_view = CreatureViewScript.new()
	e_view.scale = Vector2(0.82, 0.82)
	e_view.facing = -1.0
	e_view.position = Vector2(W * 0.66, 360)
	e_view.set_creature(enemy)
	world.add_child(e_view)
	_info_panel(Vector2(46, 120), enemy, false)

	# --- player (bottom), faces right; its info sits bottom-right ---
	p_view = CreatureViewScript.new()
	p_view.scale = Vector2(0.92, 0.92)
	p_view.facing = 1.0
	p_view.position = Vector2(W * 0.34, 860)
	p_view.set_creature(player)
	world.add_child(p_view)
	_info_panel(Vector2(W - 366, 700), player, true)

	# --- action log ---
	log_label = Label.new()
	log_label.position = Vector2(46, 1000)
	log_label.size = Vector2(W - 92, 60)
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 24)
	log_label.add_theme_color_override("font_color", Color("e8dcff"))
	ui.add_child(log_label)
	log_label.text = "A wild %s appears!" % enemy["name"]

	# --- buttons ---
	attack_btn = _action_button("ATTACK", Vector2(46, 1090), Color("ffe9c7"))
	attack_btn.pressed.connect(func(): _player_act(false))
	ability_btn = _action_button("✦ " + String(player["ability_name"]), Vector2(W * 0.5 + 8, 1090), Color("9ff0d0"))
	ability_btn.add_theme_font_size_override("font_size", 24)
	ability_btn.pressed.connect(func(): _player_act(true))

	_refresh_buttons()

func _info_panel(pos: Vector2, c: Dictionary, is_player: bool) -> void:
	var card := ColorRect.new()
	card.color = Color(1, 1, 1, 0.08)
	card.position = pos
	card.size = Vector2(320, 96)
	ui.add_child(card)

	var name_l := Label.new()
	name_l.position = pos + Vector2(16, 8)
	name_l.add_theme_font_size_override("font_size", 28)
	name_l.add_theme_color_override("font_color", Color("ffffff"))
	name_l.text = "%s  ·  %s" % [c["name"], String(c["element"]).capitalize()]
	ui.add_child(name_l)

	# hp bar: dark back + colored fill
	var bar_pos := pos + Vector2(16, 50)
	var bar_w := 288.0
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.4)
	back.position = bar_pos
	back.size = Vector2(bar_w, 22)
	ui.add_child(back)

	var pal: Dictionary = preload("res://scripts/Palettes.gd").get_palette(c["element"])
	var fill := ColorRect.new()
	fill.color = pal["body"]
	fill.position = bar_pos
	fill.size = Vector2(bar_w, 22)
	ui.add_child(fill)

	var hp_l := Label.new()
	hp_l.position = pos + Vector2(16, 46)
	hp_l.size = Vector2(bar_w, 22)
	hp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_l.add_theme_font_size_override("font_size", 18)
	hp_l.add_theme_color_override("font_color", Color("12121a"))
	hp_l.text = "%d / %d" % [int(c["max_hp"]), int(c["max_hp"])]
	ui.add_child(hp_l)

	if is_player:
		p_fill = fill
		p_hp_label = hp_l
		_p_bar_w = bar_w
	else:
		e_fill = fill
		e_hp_label = hp_l
		_e_bar_w = bar_w

func _action_button(text: String, pos: Vector2, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(W * 0.5 - 54, 76)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", col)
	ui.add_child(b)
	return b

# --- turn logic ---

func _player_act(use_ability: bool) -> void:
	if busy or finished:
		return
	if use_ability and player_cd > 0:
		return
	busy = true
	_refresh_buttons()

	var mult := 1.0
	var label := "%s attacks!" % player["name"]
	if use_ability:
		mult = 1.8
		player_cd = ABILITY_CD
		label = "%s unleashes %s!" % [player["name"], player["ability_name"]]
	log_label.text = label
	await _strike(player, enemy, true, mult)

	if enemy_hp <= 0:
		_end(true)
		return

	await get_tree().create_timer(0.55).timeout

	# --- enemy turn ---
	if enemy_cd > 0:
		enemy_cd -= 1
	var e_ability := enemy_cd <= 0
	var e_mult := 1.0
	if e_ability:
		e_mult = 1.8
		enemy_cd = ABILITY_CD
		log_label.text = "%s unleashes %s!" % [enemy["name"], enemy["ability_name"]]
	else:
		log_label.text = "%s attacks!" % enemy["name"]
	await _strike(enemy, player, false, e_mult)

	if player_hp <= 0:
		_end(false)
		return

	if player_cd > 0:
		player_cd -= 1
	busy = false
	_refresh_buttons()

func _strike(attacker: Dictionary, defender: Dictionary, player_is_attacker: bool, mult: float) -> void:
	var type_mult := _type_mult(attacker["element"], defender["element"])
	var raw: float = float(attacker["atk"]) * mult * type_mult * randf_range(0.9, 1.1)
	var dmg := int(round(max(1.0, raw)))

	# apply + juice
	var target_view = e_view if player_is_attacker else p_view
	target_view.flash_hit()
	_shake = 10.0 if mult > 1.0 else 6.0
	_float_number(target_view.position, dmg, Color("fff0a0") if type_mult > 1.0 else Color("ffffff"))

	if player_is_attacker:
		enemy_hp = max(0, enemy_hp - dmg)
		_set_bar(e_fill, e_hp_label, enemy_hp, int(enemy["max_hp"]), _e_bar_w)
	else:
		player_hp = max(0, player_hp - dmg)
		_set_bar(p_fill, p_hp_label, player_hp, int(player["max_hp"]), _p_bar_w)

	if type_mult > 1.0:
		log_label.text += "  It's super effective!"
	elif type_mult < 1.0:
		log_label.text += "  It's resisted…"

	await get_tree().create_timer(0.45).timeout

func _type_mult(atk_elem: String, def_elem: String) -> float:
	if STRONG.get(atk_elem, "") == def_elem:
		return 1.5
	if STRONG.get(def_elem, "") == atk_elem:
		return 0.66
	return 1.0

func _set_bar(fill: ColorRect, hp_l: Label, hp: int, max_hp: int, full_w: float) -> void:
	var frac := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(fill, "size:x", full_w * frac, 0.3).set_trans(Tween.TRANS_QUAD)
	hp_l.text = "%d / %d" % [hp, max_hp]
	if frac < 0.3:
		fill.color = Color("ff5d6c")

func _float_number(pos: Vector2, amount: int, col: Color) -> void:
	var l := Label.new()
	l.text = str(amount)
	l.position = pos + Vector2(-20, -60)
	l.z_index = 20
	l.add_theme_font_size_override("font_size", 46)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("2b2b3a"))
	l.add_theme_constant_override("outline_size", 6)
	world.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 90, 0.7).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tw.set_parallel(false)
	tw.tween_callback(l.queue_free)

func _refresh_buttons() -> void:
	attack_btn.disabled = busy or finished
	ability_btn.disabled = busy or finished or player_cd > 0
	if player_cd > 0:
		ability_btn.text = "✦ ready in %d" % player_cd
	else:
		ability_btn.text = "✦ " + String(player["ability_name"])

func _end(player_won: bool) -> void:
	finished = true
	busy = true
	attack_btn.visible = false
	ability_btn.visible = false

	banner = Label.new()
	banner.text = "VICTORY" if player_won else "DEFEATED"
	banner.position = Vector2(0, 470)
	banner.size = Vector2(W, 80)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 72)
	banner.add_theme_color_override("font_color", Color("ffe9c7") if player_won else Color("ff8090"))
	banner.add_theme_color_override("font_outline_color", Color("12121a"))
	banner.add_theme_constant_override("outline_size", 8)
	ui.add_child(banner)

	back_btn = Button.new()
	back_btn.text = "SUMMON ANOTHER"
	back_btn.position = Vector2(W * 0.5 - 180, 1090)
	back_btn.size = Vector2(360, 76)
	back_btn.add_theme_font_size_override("font_size", 30)
	back_btn.pressed.connect(func(): battle_over.emit(player_won))
	ui.add_child(back_btn)

# dev hook so the capture tool can drive a turn without input
func debug_attack(use_ability: bool = false) -> void:
	_player_act(use_ability)
