extends Node2D

# Turn-based battle: your Auraling vs a wild one. Depth beyond "trade hits": SPEED
# decides turn order each round, ABILITY on a cooldown can inflict BURN (damage over
# time) when super-effective, and CHARGE is a risk/reward move (skip a turn, next hit
# hits far harder). Juice = hitstop, screen shake, hit flash, floating numbers, tweened
# bars, SFX. UI is a proper Control layout (UI kit), not hand-placed ColorRects.

signal battle_over(player_won: bool)
signal round_over(player_won: bool, champion_hp: int)

const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")
const Fx = preload("res://scripts/Fx.gd")
const Pal = preload("res://scripts/Palettes.gd")
const UI = preload("res://scripts/UI.gd")
const Settings = preload("res://scripts/Settings.gd")

const W := 720
const H := 1280

const STRONG := {
	"ember": "moss", "moss": "tide", "tide": "ember",
	"spark": "frost", "frost": "bloom", "bloom": "spark",
	"void": "dusk", "dusk": "void",
}
const ABILITY_CD := 3

var sfx = null
var player: Dictionary = {}
var enemy: Dictionary = {}
var player_hp := 0
var enemy_hp := 0
var player_cd := 0
var enemy_cd := 0
var player_burn := 0
var enemy_burn := 0
var player_charged := false
var enemy_charged := false
var busy := false
var finished := false
var turbo := false
var round_num := 1
var streak := 0

var world: Node2D
var p_view
var e_view
var p_fill: ColorRect
var e_fill: ColorRect
var p_hp_label: Label
var e_hp_label: Label
var p_status: Label
var e_status: Label
var log_label: Label
var attack_btn: Button
var ability_btn: Button
var charge_btn: Button
var turbo_btn: Button
var banner: Label
var action_bar: HBoxContainer
var _ui_root: Control
var _p_bar_w := 268.0
var _e_bar_w := 268.0
var _shake := 0.0

func setup(player_creature: Dictionary) -> void:
	# standalone one-off (used by the capture tool): full HP, fresh wild enemy
	player = player_creature.duplicate(true)
	enemy = CreatureGenScript.generate(randi())
	player_hp = int(player["max_hp"])
	enemy_hp = int(enemy["max_hp"])

func gauntlet_setup(champion: Dictionary, foe: Dictionary, round_val: int, streak_val: int) -> void:
	# gauntlet round: champion carries its current HP; the foe is pre-scaled
	player = champion.duplicate(true)
	enemy = foe
	player_hp = clampi(int(champion.get("hp", champion["max_hp"])), 1, int(player["max_hp"]))
	enemy_hp = int(enemy["max_hp"])
	round_num = round_val
	streak = streak_val

func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	_build()

func _draw() -> void:
	var top := Color("1c2740")
	var bot := Color("3a2f52")
	var steps := 40
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(Rect2(0, H * t, W, H / steps + 1), top.lerp(bot, t))
	draw_rect(Rect2(0, 636, W, 3), Color(1, 1, 1, 0.05))

func _process(delta: float) -> void:
	if _shake > 0.0:
		world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = max(0.0, _shake - delta * 42.0)
	else:
		world.position = Vector2.ZERO

func _t(base: float) -> float:
	return base * (0.35 if turbo else 1.0)

func _build() -> void:
	queue_redraw()

	e_view = CreatureViewScript.new()
	e_view.facing = -1.0
	e_view.position = Vector2(W * 0.70, 350)
	e_view.set_creature(enemy)
	e_view.fit_to(148.0)
	world.add_child(e_view)

	p_view = CreatureViewScript.new()
	p_view.facing = 1.0
	p_view.position = Vector2(W * 0.30, 812)
	p_view.set_creature(player)
	p_view.fit_to(156.0)
	world.add_child(p_view)

	# all UI lives on one root Control (creatures stay in `world`); every piece is
	# anchored to its region so nothing is raw-positioned and it scales on any device
	_ui_root = Control.new()
	_ui_root.size = Vector2(W, H)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	# info panels pinned to opposite corners (anchored, so they never drift onto a creature)
	_info_panel(false)   # enemy -> top-left
	_info_panel(true)    # player -> right side

	# gauntlet round/streak banner (centered, between the two combatants)
	var rlabel := UI.label("ROUND %d   ·   STREAK %d" % [round_num, streak], 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	rlabel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rlabel.offset_top = 590; rlabel.offset_bottom = 622
	_ui_root.add_child(rlabel)

	# action log: a rounded strip anchored just above the action bar
	var log_bg := PanelContainer.new()
	log_bg.add_theme_stylebox_override("panel", UI.panel(Color(0,0,0,0.22), 16))
	log_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	log_bg.offset_left = 40; log_bg.offset_right = -40
	log_bg.offset_top = -294; log_bg.offset_bottom = -220
	_ui_root.add_child(log_bg)
	log_label = UI.label("A wild %s appears!" % enemy["name"], 23, Color("e8dcff"), HORIZONTAL_ALIGNMENT_CENTER)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_bg.add_child(log_label)

	# action bar (container-driven, equal widths, consistent gaps)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -160; margin.offset_left = 0; margin.offset_right = 0; margin.offset_bottom = -26
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	_ui_root.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	action_bar = HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 12)
	action_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(action_bar)
	attack_btn = _act_btn("ATTACK", Color("6b4fd0"), Color.WHITE)
	attack_btn.pressed.connect(func(): _player_act("attack"))
	ability_btn = _act_btn("• " + String(player["ability_name"]), Color("2f8f6b"), Color.WHITE, 22)
	ability_btn.pressed.connect(func(): _player_act("ability"))
	charge_btn = _act_btn("CHARGE", Color("b8862f"), Color.WHITE, 24)
	charge_btn.pressed.connect(func(): _player_act("charge"))

	turbo_btn = Button.new()
	turbo_btn.text = "SPEED: 1x"
	turbo_btn.custom_minimum_size = Vector2(0, 44)
	turbo_btn.toggle_mode = true
	UI.style_button(turbo_btn, UI.INK_SOFT, UI.TEXT_DIM, 20)
	turbo_btn.toggled.connect(func(on):
		turbo = on
		turbo_btn.text = "SPEED: 3x" if on else "SPEED: 1x"
		if sfx: sfx.play("tap"))
	vb.add_child(turbo_btn)

	_refresh_buttons()

func _act_btn(txt: String, bg: Color, fg: Color, fs := 28) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 80)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(b, bg, fg, fs)
	action_bar.add_child(b)
	return b

func _info_panel(is_player: bool) -> void:
	var c: Dictionary = player if is_player else enemy
	var rar := String(c.get("rarity", "common"))
	var border := UI.rarity_color(rar) if rar != "common" else Color(1,1,1,0.06)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel(Color("2f2650"), 18, border, (3 if rar != "common" else 2), 6))
	# anchored to a corner (same regions as before, but resolution-robust): enemy
	# top-left, player on the right, so neither can drift onto its creature
	if is_player:
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		panel.offset_left = -336; panel.offset_right = -36
		panel.offset_top = 690; panel.offset_bottom = 806
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		panel.offset_left = 36; panel.offset_right = 336
		panel.offset_top = 96; panel.offset_bottom = 212
	_ui_root.add_child(panel)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(pad)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	pad.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vb.add_child(top)
	var nm := UI.label(String(c["name"]), 24, UI.rarity_color(rar) if rar != "common" else UI.TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	top.add_child(UI.label("ATK %d" % int(c["atk"]), 17, UI.GOLD))
	top.add_child(UI.label("SPD %d" % int(c["spd"]), 17, UI.TEXT_DIM))

	vb.add_child(UI.label(String(c["element"]).capitalize(), 16, UI.TEXT_DIM))

	# hp bar
	var bar_holder := Control.new()
	bar_holder.custom_minimum_size = Vector2(0, 24)
	vb.add_child(bar_holder)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.4)
	back.position = Vector2(0, 0); back.size = Vector2(268, 24)
	bar_holder.add_child(back)
	var fill := ColorRect.new()
	fill.color = Pal.varied(c["element"], c.get("hue_shift", 0.0), c.get("sat_mul", 1.0), c.get("val_mul", 1.0))["body"]
	fill.position = Vector2(0, 0); fill.size = Vector2(268, 24)
	bar_holder.add_child(fill)
	var hp_l := UI.label("%d / %d" % [int(c["max_hp"]), int(c["max_hp"])], 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# light text + dark outline stays readable whether it sits on the fill or the empty track
	hp_l.add_theme_color_override("font_outline_color", Color("12121a"))
	hp_l.add_theme_constant_override("outline_size", 5)
	hp_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_holder.add_child(hp_l)
	var status := UI.label("", 16, Color("ffb15c"))
	vb.add_child(status)

	if is_player:
		p_fill = fill; p_hp_label = hp_l; p_status = status
	else:
		e_fill = fill; e_hp_label = hp_l; e_status = status

# --- turn logic (speed-ordered) ---
func _player_act(action: String) -> void:
	if busy or finished:
		return
	if action == "ability" and player_cd > 0:
		return
	busy = true
	_refresh_buttons()

	var enemy_action := _enemy_choose()
	# resolve in SPEED order; charge lowers your effective initiative slightly
	var p_init := int(player["spd"]) - (3 if action == "charge" else 0)
	var e_init := int(enemy["spd"]) - (3 if enemy_action == "charge" else 0)
	var player_first := p_init >= e_init

	if player_first:
		await _resolve(true, action)
		if not finished:
			await get_tree().create_timer(_t(0.45)).timeout
			await _resolve(false, enemy_action)
	else:
		await _resolve(false, enemy_action)
		if not finished:
			await get_tree().create_timer(_t(0.45)).timeout
			await _resolve(true, action)

	if finished:
		return
	# end of round: tick cooldowns
	if player_cd > 0: player_cd -= 1
	if enemy_cd > 0: enemy_cd -= 1
	busy = false
	_refresh_buttons()

func _enemy_choose() -> String:
	if enemy_cd <= 0 and randf() < 0.7:
		return "ability"
	if not enemy_charged and randf() < 0.2:
		return "charge"
	return "attack"

# one actor takes its action
func _resolve(is_player: bool, action: String) -> void:
	# burn tick at the start of this actor's turn
	await _burn_tick(is_player)
	if finished:
		return
	var attacker := player if is_player else enemy
	var name := String(attacker["name"])

	if action == "charge":
		if is_player: player_charged = true
		else: enemy_charged = true
		log_label.text = "%s is charging up!" % name
		if sfx: sfx.play("ability", 0.8)
		var v = p_view if is_player else e_view
		v.flash_hit()
		await get_tree().create_timer(_t(0.4)).timeout
		return

	var mult := 1.0
	if action == "ability":
		mult = 1.8
		if is_player: player_cd = ABILITY_CD
		else: enemy_cd = ABILITY_CD
		log_label.text = "%s unleashes %s!" % [name, attacker["ability_name"]]
		if sfx: sfx.play("ability")
	else:
		log_label.text = "%s attacks!" % name
		if sfx: sfx.play("hit")

	# consume charge
	var charged := player_charged if is_player else enemy_charged
	if charged:
		mult *= 2.5
		if is_player: player_charged = false
		else: enemy_charged = false
		log_label.text += " (charged!)"

	await _strike(is_player, mult, action == "ability")

func _strike(player_is_attacker: bool, mult: float, is_ability: bool) -> void:
	var attacker := player if player_is_attacker else enemy
	var defender := enemy if player_is_attacker else player
	var type_mult := _type_mult(attacker["element"], defender["element"])
	var dmg := int(round(max(1.0, float(attacker["atk"]) * mult * type_mult * randf_range(0.9, 1.1))))
	var crit := mult >= 2.5 or type_mult > 1.0

	# hitstop: a brief freeze so the blow lands with weight
	await get_tree().create_timer(_t(0.07)).timeout

	var target_view = e_view if player_is_attacker else p_view
	target_view.flash_hit()
	_shake = (14.0 if crit else 7.0) * Settings.motion_scale()
	_float_number(target_view.position, dmg, Color("fff0a0") if crit else Color.WHITE)
	if sfx: sfx.play("crit" if crit else "hurt")

	if player_is_attacker:
		enemy_hp = max(0, enemy_hp - dmg)
		_set_bar(e_fill, e_hp_label, enemy_hp, int(enemy["max_hp"]), _e_bar_w)
	else:
		player_hp = max(0, player_hp - dmg)
		_set_bar(p_fill, p_hp_label, player_hp, int(player["max_hp"]), _p_bar_w)

	if type_mult > 1.0:
		log_label.text += " Super effective!"
		# super-effective ability inflicts BURN
		if is_ability:
			if player_is_attacker: enemy_burn = 3; _set_status(e_status, "BURN")
			else: player_burn = 3; _set_status(p_status, "BURN")
	elif type_mult < 1.0:
		log_label.text += " Resisted..."

	var dead := enemy_hp <= 0 if player_is_attacker else player_hp <= 0
	if dead:
		Fx.burst(world, target_view.position, Pal.get_palette(defender["element"])["accent"], 48, 360.0)
		await get_tree().create_timer(_t(0.4)).timeout
		_end(player_is_attacker)
		return
	await get_tree().create_timer(_t(0.4)).timeout

func _burn_tick(is_player: bool) -> void:
	var burn := player_burn if is_player else enemy_burn
	if burn <= 0:
		return
	var who := player if is_player else enemy
	var dmg := int(max(1.0, float(who["max_hp"]) * 0.06))
	var view = p_view if is_player else e_view
	view.flash_hit()
	_float_number(view.position, dmg, Color("ff8a3d"))
	if sfx: sfx.play("hurt", 1.2)
	if is_player:
		player_hp = max(0, player_hp - dmg); player_burn -= 1
		_set_bar(p_fill, p_hp_label, player_hp, int(player["max_hp"]), _p_bar_w)
		_set_status(p_status, "BURN" if player_burn > 0 else "")
	else:
		enemy_hp = max(0, enemy_hp - dmg); enemy_burn -= 1
		_set_bar(e_fill, e_hp_label, enemy_hp, int(enemy["max_hp"]), _e_bar_w)
		_set_status(e_status, "BURN" if enemy_burn > 0 else "")
	log_label.text = "%s is hurt by its burn!" % String(who["name"])
	await get_tree().create_timer(_t(0.35)).timeout
	if (is_player and player_hp <= 0) or (not is_player and enemy_hp <= 0):
		_end(not is_player)

func _set_status(l: Label, txt: String) -> void:
	if l: l.text = txt

func _type_mult(atk_elem: String, def_elem: String) -> float:
	if STRONG.get(atk_elem, "") == def_elem:
		return 1.5
	if STRONG.get(def_elem, "") == atk_elem:
		return 0.66
	return 1.0

func _set_bar(fill: ColorRect, hp_l: Label, hp: int, max_hp: int, full_w: float) -> void:
	var frac := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(fill, "size:x", full_w * frac, _t(0.3)).set_trans(Tween.TRANS_QUAD)
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
	tw.tween_property(l, "position:y", l.position.y - 90, _t(0.7)).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, _t(0.7)).set_delay(_t(0.2))
	tw.set_parallel(false)
	tw.tween_callback(l.queue_free)

func _refresh_buttons() -> void:
	attack_btn.disabled = busy or finished
	charge_btn.disabled = busy or finished or player_charged
	ability_btn.disabled = busy or finished or player_cd > 0
	if player_cd > 0:
		ability_btn.text = "• ready in %d" % player_cd
	else:
		ability_btn.text = "• " + String(player["ability_name"])
	charge_btn.text = "CHARGED!" if player_charged else "CHARGE"

func _end(player_won: bool) -> void:
	if finished:
		return
	finished = true
	busy = true
	action_bar.visible = false
	turbo_btn.visible = false
	if sfx: sfx.play("victory" if player_won else "defeat")

	banner = UI.label("VICTORY" if player_won else "DEFEATED", 72, Color("ffe9c7") if player_won else Color("ff8090"), HORIZONTAL_ALIGNMENT_CENTER)
	banner.add_theme_color_override("font_outline_color", Color("12121a"))
	banner.add_theme_constant_override("outline_size", 8)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 440; banner.offset_bottom = 540
	_ui_root.add_child(banner)

	# hand back to the run controller: it shows the boon pick (win) or run-over (lose)
	await get_tree().create_timer(_t(1.35)).timeout
	round_over.emit(player_won, player_hp)
	battle_over.emit(player_won)   # kept for any standalone listener

func debug_attack(use_ability: bool = false) -> void:
	_player_act("ability" if use_ability else "attack")
