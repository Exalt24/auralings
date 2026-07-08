extends Node2D

# Summon screen. The whole UI is a proper Control LAYOUT TREE (MarginContainer ->
# VBoxContainer with separation -> HBox rows), NOT hand-placed pixel coordinates, so
# spacing is consistent and nothing crowds. All UI lives under summon_layer so battle/
# bestiary can hide it (Controls are CanvasItems, so they respect the Node2D's
# visibility — a CanvasLayer would NOT, which is why we don't use one here).

const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")
const LLMScript = preload("res://scripts/LLM.gd")
const BattleScript = preload("res://scripts/Battle.gd")
const Fx = preload("res://scripts/Fx.gd")
const Pal = preload("res://scripts/Palettes.gd")
const UI = preload("res://scripts/UI.gd")
const CollectionScript = preload("res://scripts/Collection.gd")
const SfxScript = preload("res://scripts/Sfx.gd")
const Settings = preload("res://scripts/Settings.gd")
const SettingsMenuScript = preload("res://scripts/SettingsMenu.gd")
const BoonChoiceScript = preload("res://scripts/BoonChoice.gd")
const RunOverScript = preload("res://scripts/RunOver.gd")
const AchievementsScript = preload("res://scripts/Achievements.gd")
const ShopViewScript = preload("res://scripts/ShopView.gd")
const META_PATH := "user://meta.json"

# gauntlet boon pool (run-altering choice; 3 offered each win)
const BOONS := [
	{"id": "heal", "name": "Second Wind", "desc": "Restore 55% of max HP"},
	{"id": "fortify", "name": "Fortify", "desc": "+30 max HP, and heal 30"},
	{"id": "power", "name": "Power Up", "desc": "+6 ATK"},
	{"id": "focus", "name": "Battle Focus", "desc": "Full heal, +2 ATK"},
	{"id": "swift", "name": "Swift", "desc": "+4 SPD, +3 ATK"},
]

const W := 720
const H := 1280
const SAVE_PATH := "user://collection.json"

var summon_layer: Node2D
var creature_view
var stage: Control
var name_label: Label
var rarity_pill_holder: HBoxContainer
var sub_label: Label
var lore_label: Label
var stat_label: Label
var ability_label: Label
var seed_label: Label
var toast_label: Label
var count_label: Label
var hint_label: Label
var summon_btn: Button
var battle_btn: Button
var share_btn: Button
var bestiary_btn: Button
var llm
var sfx
var settings_menu
var current_seed := 0
var current_creature: Dictionary = {}
var battle = null
var collection_view = null
var boon_view = null
var run_over_view = null
var collection: Array = []
var _champion: Dictionary = {}
var _current_enemy: Dictionary = {}
var _round := 1
var _streak := 0
var _best_streak := 0
var _run_set_best := false
var _achievements: Array = []
var _essence := 0
var _upgrades := {"vigor": 0, "might": 0, "insight": 0}
var _boon_count := 3
var shop_view = null
var _last_rarity := ""

# bounded meta upgrades (kept small so the enemy ramp still ends runs; final tuning is
# a playtest job). cost[i] = essence to buy level i+1.
const UPGRADES := [
	{"id": "vigor", "name": "Vigor", "desc": "+8 champion start HP per level", "max": 3, "cost": [4, 8, 14]},
	{"id": "might", "name": "Might", "desc": "+2 champion start ATK per level", "max": 3, "cost": [5, 10, 16]},
	{"id": "insight", "name": "Insight", "desc": "Draft 4 boons instead of 3", "max": 1, "cost": [12]},
]
var _ach_layer: CanvasLayer
var _ach_panel: PanelContainer
var _ach_queue: Array = []
var _ach_busy := false
var _share_cb = null
const CheckIconScript = preload("res://scripts/CheckIcon.gd")
var _toast_layer: CanvasLayer
var _toast_panel: PanelContainer
var _toast_tw: Tween = null
var _ach_label: Label
var _ach_view = null
var _summons_done := 0
var bg_top := Color("2a2140")
var bg_bot := Color("453763")

func _ready() -> void:
	_load_collection()
	_load_meta()
	sfx = SfxScript.new()
	add_child(sfx)
	_build_ui()
	_build_ach_toast()
	var shared := _shared_seed()
	if shared >= 0:
		_summon(shared)
	else:
		_summon()

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), bg_bot)
	var steps := 40
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(Rect2(0, H * t, W, H / steps + 1), bg_top.lerp(bg_bot, t))
	for i in 6:
		draw_circle(Vector2(W * 0.5, 400), 150.0 + i * 34.0, Color(0.55, 0.42, 0.85, 0.03))

func _build_ui() -> void:
	summon_layer = Node2D.new()
	add_child(summon_layer)

	# creature is a Node2D drawn in world space, centered on the stage slot each layout
	creature_view = CreatureViewScript.new()
	summon_layer.add_child(creature_view)

	var root := Control.new()
	root.size = Vector2(W, H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summon_layer.add_child(root)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 34)
	root.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	# --- header ---
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	col.add_child(header)
	header.add_child(UI.label("AURALINGS", 46, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(UI.label("summon infinite creatures, drawn by code, named by AI", 18, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	count_label = UI.label("", 17, UI.MINT, HORIZONTAL_ALIGNMENT_CENTER)
	header.add_child(count_label)

	# --- stage (creature slot; grows to fill spare space) ---
	stage = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stage)
	stage.resized.connect(_place_creature)
	# hint + toast pinned to the bottom of the stage, centered
	hint_label = UI.label("tap SUMMON to call a new one", 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -60; hint_label.offset_bottom = -30
	stage.add_child(hint_label)
	# toast lives on its own CanvasLayer so it shows over EVERY screen (summon is
	# hidden during battle/boon/run-over, so a summon-parented toast would be invisible
	# there — that's why SHARE on the run-over screen gave no feedback). Styled as a
	# rounded pill w/ icon + shadow, centered at the bottom, slide+overshoot in/out.
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 51
	add_child(_toast_layer)
	var toast_holder := Control.new()
	toast_holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_holder.offset_top = -150; toast_holder.offset_bottom = -70
	toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(toast_holder)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_holder.add_child(center)
	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", UI.panel(Color("241d40"), 26, Color(0.62, 0.94, 0.82, 0.55), 2, 16))
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.modulate.a = 0.0
	center.add_child(_toast_panel)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 12)
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	_toast_panel.add_child(trow)
	var tcheck := CheckIconScript.new()
	trow.add_child(tcheck)
	toast_label = UI.label("", 25, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trow.add_child(toast_label)

	# --- info card ---
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.panel(UI.CARD, 26, Color(1,1,1,0.06), 2, 10))
	col.add_child(card)
	var cpad := MarginContainer.new()
	cpad.add_theme_constant_override("margin_left", 26)
	cpad.add_theme_constant_override("margin_right", 26)
	cpad.add_theme_constant_override("margin_top", 18)
	cpad.add_theme_constant_override("margin_bottom", 18)
	card.add_child(cpad)
	var cvb := VBoxContainer.new()
	cvb.add_theme_constant_override("separation", 7)
	cpad.add_child(cvb)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	cvb.add_child(name_row)
	name_label = UI.label("", 38, UI.TEXT)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(name_label)
	rarity_pill_holder = HBoxContainer.new()
	rarity_pill_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(rarity_pill_holder)

	sub_label = UI.label("", 20, UI.TEXT_DIM)
	cvb.add_child(sub_label)
	lore_label = UI.label("", 21, Color("e8dcff"))
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_label.custom_minimum_size = Vector2(0, 58)
	cvb.add_child(lore_label)
	cvb.add_child(_spacer(4))
	stat_label = UI.label("", 26, UI.GOLD)
	cvb.add_child(stat_label)
	ability_label = UI.label("", 21, UI.MINT)
	ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cvb.add_child(ability_label)

	# --- seed + share row ---
	var share_row := HBoxContainer.new()
	share_row.add_theme_constant_override("separation", 14)
	col.add_child(share_row)
	seed_label = UI.label("", 18, Color("9a8cc0"))
	seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	share_row.add_child(seed_label)
	share_btn = Button.new()
	share_btn.text = "SHARE"
	share_btn.custom_minimum_size = Vector2(170, 56)
	UI.style_button(share_btn, UI.INK_SOFT, UI.TEXT, 22)
	share_btn.pressed.connect(_share_seed)
	share_row.add_child(share_btn)

	# --- action row: summon + battle (equal width) ---
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	col.add_child(actions)
	summon_btn = Button.new()
	summon_btn.text = "SUMMON"
	summon_btn.custom_minimum_size = Vector2(0, 88)
	summon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(summon_btn, Color("6b4fd0"), Color.WHITE, 34)
	summon_btn.pressed.connect(_summon.bind(-1))
	actions.add_child(summon_btn)
	battle_btn = Button.new()
	battle_btn.text = "GAUNTLET"
	battle_btn.custom_minimum_size = Vector2(0, 88)
	battle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(battle_btn, Color("2f8f6b"), Color.WHITE, 32)
	battle_btn.pressed.connect(_start_run)
	actions.add_child(battle_btn)

	# --- bestiary + upgrades row ---
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 16)
	col.add_child(nav)
	bestiary_btn = Button.new()
	bestiary_btn.text = "BESTIARY"
	bestiary_btn.custom_minimum_size = Vector2(0, 66)
	bestiary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(bestiary_btn, UI.INK_SOFT, UI.GOLD, 26)
	bestiary_btn.pressed.connect(_open_collection)
	nav.add_child(bestiary_btn)
	var up_btn := Button.new()
	up_btn.text = "UPGRADES"
	up_btn.custom_minimum_size = Vector2(0, 66)
	up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(up_btn, UI.INK_SOFT, UI.MINT, 26)
	up_btn.pressed.connect(_open_shop)
	nav.add_child(up_btn)

	# gear settings menu, added LAST so it sits on top of the layout and is clickable
	settings_menu = SettingsMenuScript.new()
	settings_menu.sfx = sfx
	root.add_child(settings_menu)

	llm = LLMScript.new()
	summon_layer.add_child(llm)
	llm.identity_ready.connect(_on_identity_ready)
	_refresh_count()
	call_deferred("_place_creature")
	queue_redraw()

func _build_ach_toast() -> void:
	# a CanvasLayer stays visible over every screen (summon/battle/boon/run-over), so
	# achievement pops show even mid-run when summon_layer is hidden
	_ach_layer = CanvasLayer.new()
	_ach_layer.layer = 50
	add_child(_ach_layer)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel(Color("2f2650"), 16, UI.GOLD, 2, 8))
	pc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	pc.offset_left = 90; pc.offset_right = -90; pc.offset_top = 150; pc.offset_bottom = 214
	pc.visible = false
	_ach_layer.add_child(pc)
	_ach_panel = pc
	_ach_label = UI.label("", 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	pc.add_child(_ach_label)

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

func _place_creature() -> void:
	if stage and creature_view:
		var c := stage.get_global_rect().get_center()
		creature_view.position = c
		creature_view.fit_to(min(stage.size.x, stage.size.y) * 0.5 - 8.0)

func _refresh_count() -> void:
	if _best_streak > 0:
		count_label.text = "%d discovered  ·  best streak %d" % [collection.size(), _best_streak]
	else:
		count_label.text = "%d discovered" % collection.size()

func _summon(seed_val: int = -1) -> void:
	var use_seed := seed_val if seed_val >= 0 else randi()
	var c: Dictionary = CreatureGenScript.generate(use_seed)
	if seed_val < 0 and _summons_done == 0:
		var tries := 0
		while c.get("rarity", "common") == "common" and tries < 6:
			use_seed = randi(); c = CreatureGenScript.generate(use_seed); tries += 1
	_summons_done += 1
	current_seed = int(c["seed"])
	current_creature = c
	seed_label.text = "seed  %d" % current_seed
	creature_view.set_creature(c)
	_place_creature()
	creature_view.flash_hit()
	if hint_label:
		hint_label.modulate.a = max(0.0, hint_label.modulate.a - 1.0)
	var pal: Dictionary = Pal.varied(c["element"], c.get("hue_shift", 0.0), c.get("sat_mul", 1.0), c.get("val_mul", 1.0))
	var rar: String = c.get("rarity", "common")
	Fx.burst(summon_layer, creature_view.position, pal["accent"], (46 if rar != "common" else 26))
	# skip SFX on the very first (auto) summon at load: browsers block audio until a
	# user gesture, and playing before the first tap gets dropped + warns
	if sfx and _summons_done > 1:
		sfx.play("summon")
		if rar != "common":
			sfx.play("rare", 1.0)
	_add_to_collection(current_seed, String(c["name"]))
	_refresh_count()
	_last_rarity = rar
	_check_achievements()
	name_label.text = c["name"]
	name_label.add_theme_color_override("font_color", UI.rarity_color(rar) if rar != "common" else UI.TEXT)
	_set_rarity_pill(rar)
	sub_label.text = "%s  ·  %s" % [String(c["element"]).capitalize(), c["archetype"]]
	stat_label.text = "HP %d    ATK %d    SPD %d" % [c["hp"], c["atk"], c["spd"]]
	ability_label.text = "• " + c["ability_name"]
	if llm.has_key():
		lore_label.text = "summoning its story..."
		summon_btn.disabled = true
		summon_btn.text = "SUMMONING..."
		llm.request_identity(c)
	else:
		lore_label.text = "A wandering %s spirit." % String(c["element"]).capitalize()

func _set_rarity_pill(rarity: String) -> void:
	for ch in rarity_pill_holder.get_children():
		ch.queue_free()
	if rarity == "common":
		return
	rarity_pill_holder.add_child(UI.rarity_pill(rarity))

func _on_identity_ready(seed_val: int, identity: Dictionary) -> void:
	summon_btn.disabled = false
	summon_btn.text = "SUMMON"
	if seed_val != current_seed:
		return
	if identity.is_empty():
		lore_label.text = "Its story is lost to static..."
		return
	if identity.has("name") and String(identity["name"]).length() > 0:
		name_label.text = String(identity["name"])
		current_creature["name"] = String(identity["name"])
		_update_collection_name(seed_val, String(identity["name"]))
	var title := String(identity.get("title", ""))
	if title.length() > 0:
		sub_label.text = title + "  ·  " + sub_label.text
	lore_label.text = String(identity.get("lore", lore_label.text))
	var abil_name := String(identity.get("ability_name", ""))
	var abil_desc := String(identity.get("ability_desc", ""))
	if abil_name.length() > 0:
		ability_label.text = "• %s: %s" % [abil_name, abil_desc]
		current_creature["ability_name"] = abil_name

# --- The Gauntlet: a roguelite run ---
func _start_run() -> void:
	if current_creature.is_empty() or battle != null:
		return
	if sfx: sfx.play("tap")
	if settings_menu: settings_menu.collapse()
	_champion = current_creature.duplicate(true)
	# apply bounded meta upgrades to the champion for this run
	_champion["max_hp"] = int(_champion["max_hp"]) + 8 * int(_upgrades["vigor"])
	_champion["atk"] = int(_champion["atk"]) + 2 * int(_upgrades["might"])
	_champion["hp"] = int(_champion["max_hp"])
	_boon_count = 3 + (1 if int(_upgrades["insight"]) > 0 else 0)
	_round = 1
	_streak = 0
	_run_set_best = false
	summon_layer.visible = false
	_spawn_fight()

func _spawn_fight() -> void:
	_current_enemy = _scaled_enemy(_round)
	battle = BattleScript.new()
	battle.sfx = sfx
	battle.gauntlet_setup(_champion, _current_enemy, _round, _streak)
	battle.round_over.connect(_on_round_over)
	add_child(battle)

func _scaled_enemy(rnd: int) -> Dictionary:
	# gradual stat ramp: round 1 is fair, later rounds pull ahead so the run has a wall
	var c: Dictionary = CreatureGenScript.generate(randi())
	var hp_mul := 1.0 + 0.20 * float(rnd - 1)
	var atk_mul := 1.0 + 0.13 * float(rnd - 1)
	c["max_hp"] = int(round(float(c["max_hp"]) * hp_mul))
	c["hp"] = int(c["max_hp"])
	c["atk"] = int(round(float(c["atk"]) * atk_mul))
	return c

func _on_round_over(player_won: bool, champ_hp: int) -> void:
	if battle != null:
		battle.queue_free()
		battle = null
	if player_won:
		_streak += 1
		_champion["hp"] = champ_hp
		_discover(_current_enemy)
		if _streak > _best_streak:
			_best_streak = _streak
			_run_set_best = true
			_save_meta()
		_check_achievements()
		_show_boon()
	else:
		_show_run_over()

func _show_boon() -> void:
	var pool := BOONS.duplicate()
	pool.shuffle()
	boon_view = BoonChoiceScript.new()
	boon_view.sfx = sfx
	boon_view.setup(_champion, pool.slice(0, _boon_count), _streak)
	boon_view.picked.connect(_on_boon_picked)
	add_child(boon_view)

func _on_boon_picked(id: String) -> void:
	if boon_view != null:
		boon_view.queue_free()
		boon_view = null
	_apply_boon(id)
	_round += 1
	_spawn_fight()

func _apply_boon(id: String) -> void:
	var mx := int(_champion["max_hp"])
	match id:
		"heal": _champion["hp"] = min(mx, int(_champion["hp"]) + int(mx * 0.55))
		"fortify":
			_champion["max_hp"] = mx + 30
			_champion["hp"] = min(mx + 30, int(_champion["hp"]) + 30)
		"power": _champion["atk"] = int(_champion["atk"]) + 6
		"focus":
			_champion["hp"] = int(_champion["max_hp"])
			_champion["atk"] = int(_champion["atk"]) + 2
		"swift":
			_champion["spd"] = int(_champion["spd"]) + 4
			_champion["atk"] = int(_champion["atk"]) + 3

func _show_run_over() -> void:
	# award meta essence for the run (= streak reached), spent later on upgrades
	_essence += _streak
	_save_meta()
	run_over_view = RunOverScript.new()
	run_over_view.sfx = sfx
	run_over_view.setup(_champion, _streak, _best_streak, _run_set_best, _streak)
	run_over_view.share_pressed.connect(_share_streak)
	run_over_view.continue_pressed.connect(_end_run)
	run_over_view.shop_pressed.connect(_open_shop)
	add_child(run_over_view)

func _open_shop() -> void:
	if shop_view != null:
		return
	if sfx: sfx.play("tap")
	shop_view = ShopViewScript.new()
	shop_view.sfx = sfx
	shop_view.setup(_essence, _upgrades, UPGRADES)
	shop_view.bought.connect(_buy_upgrade)
	shop_view.closed.connect(_close_shop)
	add_child(shop_view)

func _buy_upgrade(id: String) -> void:
	for d in UPGRADES:
		if String(d["id"]) == id:
			var lvl := int(_upgrades.get(id, 0))
			if lvl < int(d["max"]) and _essence >= int(d["cost"][lvl]):
				_essence -= int(d["cost"][lvl])
				_upgrades[id] = lvl + 1
				_save_meta()
				if shop_view != null:
					shop_view.refresh(_essence, _upgrades)
			return

func _close_shop() -> void:
	if shop_view != null:
		shop_view.queue_free()
		shop_view = null

func _end_run() -> void:
	if run_over_view != null:
		run_over_view.queue_free()
		run_over_view = null
	summon_layer.visible = true
	_summon()

func _discover(c: Dictionary) -> void:
	var sv := int(c.get("seed", 0))
	for e in collection:
		if int(e.get("seed", -1)) == sv:
			return
	collection.push_front({"seed": sv, "name": String(c.get("name", "?")), "rarity": String(c.get("rarity", "common"))})
	if collection.size() > 300:
		collection.resize(300)
	_save_collection()
	_refresh_count()

func _open_collection() -> void:
	if collection_view != null:
		return
	if sfx: sfx.play("tap")
	if settings_menu: settings_menu.collapse()
	summon_layer.visible = false
	collection_view = CollectionScript.new()
	collection_view.sfx = sfx
	collection_view.setup(collection)
	collection_view.closed.connect(_on_collection_closed)
	add_child(collection_view)

func _on_collection_closed() -> void:
	if collection_view != null:
		collection_view.queue_free()
		collection_view = null
	summon_layer.visible = true

func _add_to_collection(seed_val: int, nm: String) -> void:
	for i in collection.size():
		if int(collection[i].get("seed", -1)) == seed_val:
			collection.remove_at(i)
			break
	var rar := "common"
	if not current_creature.is_empty():
		rar = String(current_creature.get("rarity", "common"))
	collection.push_front({"seed": seed_val, "name": nm, "rarity": rar})
	if collection.size() > 300:
		collection.resize(300)
	_save_collection()

func _update_collection_name(seed_val: int, nm: String) -> void:
	for e in collection:
		if int(e.get("seed", -1)) == seed_val:
			e["name"] = nm
			_save_collection()
			return

func _load_collection() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_ARRAY:
		collection = data

func _save_collection() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(collection))

func _load_meta() -> void:
	if not FileAccess.file_exists(META_PATH):
		return
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("best_streak"):
			_best_streak = int(data["best_streak"])
		if data.has("achievements") and typeof(data["achievements"]) == TYPE_ARRAY:
			_achievements = data["achievements"]
		if data.has("essence"):
			_essence = int(data["essence"])
		if data.has("upgrades") and typeof(data["upgrades"]) == TYPE_DICTIONARY:
			for k in _upgrades.keys():
				if data["upgrades"].has(k):
					_upgrades[k] = int(data["upgrades"][k])

func _save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"best_streak": _best_streak, "achievements": _achievements,
			"essence": _essence, "upgrades": _upgrades,
		}))

func _check_achievements() -> void:
	var earned: Array = AchievementsScript.earned(_streak, _best_streak, collection.size(), _last_rarity)
	for id in earned:
		if not _achievements.has(id):
			_achievements.append(id)
			_save_meta()
			_ach_toast(AchievementsScript.name_of(id))

func _ach_toast(nm: String) -> void:
	# queue pops so multiple achievements earned at once show one-after-another instead
	# of stacking tweens on the shared panel (which flickered / dropped all but the last)
	if _ach_panel == null:
		return
	_ach_queue.append(nm)
	if not _ach_busy:
		_drain_ach_queue()

func _drain_ach_queue() -> void:
	if _ach_queue.is_empty():
		_ach_busy = false
		return
	_ach_busy = true
	var nm: String = _ach_queue.pop_front()
	# shown on a CanvasLayer so it appears over ANY screen (summon/battle/boon/run-over)
	if sfx: sfx.play("rare")
	_ach_label.text = "Achievement:  %s" % nm
	_ach_panel.modulate.a = 0.0
	_ach_panel.visible = true
	var tw := create_tween()
	tw.tween_property(_ach_panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.9)
	tw.tween_property(_ach_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		_ach_panel.visible = false
		_drain_ach_queue())

func _share_streak() -> void:
	if sfx: sfx.play("tap")
	var line := "I hit a %d-win streak with %s in Auralings! Beat it:" % [_streak, _champion.get("name", "my Auraling")]
	_share_line(line, _site_link(-1))

func _shared_seed() -> int:
	if not OS.has_feature("web"):
		return -1
	var v = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('seed')", true)
	if typeof(v) == TYPE_STRING and String(v).is_valid_int():
		return int(String(v))
	return -1

func _share_seed() -> void:
	if sfx: sfx.play("tap")
	var rar := String(current_creature.get("rarity", "common"))
	var elem := String(current_creature.get("element", "")).capitalize()
	var nm := String(current_creature.get("name", "?"))
	var line := ""
	if rar != "common":
		line = "I summoned %s, a %s %s Auraling! Summon yours:" % [nm, rar.to_upper(), elem]
	else:
		line = "I summoned %s the %s Auraling! Summon yours:" % [nm, elem]
	_share_line(line, _site_link(current_seed))

func _site_link(seed_val: int) -> String:
	var link := ("seed %d" % seed_val) if seed_val >= 0 else "auralings.vercel.app"
	if OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("window.location.origin + window.location.pathname", true)
		if typeof(origin) == TYPE_STRING:
			link = String(origin) + ("?seed=" + str(seed_val) if seed_val >= 0 else "")
	return link

# Prefer the native share sheet (Web Share API); fall back to clipboard copy
# (navigator.clipboard, then a textarea/execCommand fallback). All inside the button
# gesture browsers require.
func _share_line(line: String, link: String) -> void:
	var full := line + "\n" + link
	if OS.has_feature("web"):
		# The toast fires from a JS CALLBACK once the share/copy actually settles, not
		# instantly. On mobile the native share sheet covers the screen, so an instant
		# toast would fade before the sheet closes and you'd never see it. Now it shows
		# after. On desktop (no navigator.share, e.g. Firefox) it copies and toasts.
		if _share_cb == null:
			_share_cb = JavaScriptBridge.create_callback(func(args):
				var kind := (String(args[0]) if args.size() > 0 else "copied")
				_toast("shared!" if kind == "shared" else "copied to clipboard!"))
		var win = JavaScriptBridge.get_interface("window")
		win.godotOnShare = _share_cb
		var js := "(function(txt,url){var full=txt+'\\n'+url;function cb(k){try{window.godotOnShare(k);}catch(e){}}function fb(){var a=document.createElement('textarea');a.value=full;a.style.position='fixed';a.style.opacity='0';document.body.appendChild(a);a.focus();a.select();try{document.execCommand('copy');}catch(_){}document.body.removeChild(a);cb('copied');}function copy(){try{if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(full).then(function(){cb('copied');},fb);return;}}catch(e){}fb();}if(navigator.share){navigator.share({title:'Auralings',text:txt,url:url}).then(function(){cb('shared');},copy);return;}copy();})(%s,%s);" % [JSON.stringify(line), JSON.stringify(link)]
		JavaScriptBridge.eval(js)
	else:
		DisplayServer.clipboard_set(full)
		_toast("copied to clipboard!")

func _toast(msg: String) -> void:
	toast_label.text = msg
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	var reduced := Settings.reduced_motion
	_toast_panel.modulate.a = 0.0
	_toast_layer.offset = Vector2(0, 0.0 if reduced else 44.0)
	_toast_tw = create_tween()
	# enter: fade in + slide up with a soft overshoot landing (Ease-Out-Back)
	_toast_tw.tween_property(_toast_panel, "modulate:a", 1.0, 0.28).set_ease(Tween.EASE_OUT)
	if not reduced:
		_toast_tw.parallel().tween_property(_toast_layer, "offset", Vector2.ZERO, 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# hold
	_toast_tw.tween_interval(1.5)
	# exit: fade out + drift down
	_toast_tw.tween_property(_toast_panel, "modulate:a", 0.0, 0.34).set_ease(Tween.EASE_IN)
	if not reduced:
		_toast_tw.parallel().tween_property(_toast_layer, "offset", Vector2(0, 22), 0.34).set_ease(Tween.EASE_IN)
