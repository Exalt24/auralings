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
var collection: Array = []
var _summons_done := 0
var bg_top := Color("2a2140")
var bg_bot := Color("453763")

func _ready() -> void:
	_load_collection()
	sfx = SfxScript.new()
	add_child(sfx)
	_build_ui()
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
	toast_label = UI.label("", 24, UI.MINT, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_top = -28; toast_label.offset_bottom = 2
	toast_label.modulate.a = 0.0
	stage.add_child(toast_label)

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
	battle_btn.text = "BATTLE"
	battle_btn.custom_minimum_size = Vector2(0, 88)
	battle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(battle_btn, Color("2f8f6b"), Color.WHITE, 34)
	battle_btn.pressed.connect(_enter_battle)
	actions.add_child(battle_btn)

	# --- bestiary (full width) ---
	bestiary_btn = Button.new()
	bestiary_btn.text = "BESTIARY"
	bestiary_btn.custom_minimum_size = Vector2(0, 66)
	UI.style_button(bestiary_btn, UI.INK_SOFT, UI.GOLD, 28)
	bestiary_btn.pressed.connect(_open_collection)
	col.add_child(bestiary_btn)

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

func _enter_battle() -> void:
	if current_creature.is_empty() or battle != null:
		return
	if sfx: sfx.play("tap")
	if settings_menu: settings_menu.collapse()
	summon_layer.visible = false
	battle = BattleScript.new()
	battle.sfx = sfx
	battle.setup(current_creature)
	battle.battle_over.connect(_on_battle_over)
	add_child(battle)

func _on_battle_over(_player_won: bool) -> void:
	if battle != null:
		battle.queue_free()
		battle = null
	summon_layer.visible = true
	_summon()

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
	var link := "seed %d" % current_seed
	if OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("window.location.origin + window.location.pathname", true)
		if typeof(origin) == TYPE_STRING:
			link = String(origin) + "?seed=" + str(current_seed)
	var full := line + "\n" + link
	if OS.has_feature("web"):
		# Prefer the native share sheet (Web Share API, great on mobile: opens the OS
		# "share to..." menu). Fall back to clipboard copy (navigator.clipboard, then a
		# textarea/execCommand fallback). All inside the button-press gesture browsers require.
		var has_share = JavaScriptBridge.eval("(typeof navigator!=='undefined' && typeof navigator.share==='function')", true)
		var js := "(function(txt,url){var full=txt+'\\n'+url;function copy(){try{if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(full);return;}}catch(e){}var a=document.createElement('textarea');a.value=full;a.style.position='fixed';a.style.opacity='0';document.body.appendChild(a);a.focus();a.select();try{document.execCommand('copy');}catch(_){}document.body.removeChild(a);}if(navigator.share){navigator.share({title:'Auralings',text:txt,url:url}).catch(function(){copy();});return;}copy();})(%s,%s);" % [JSON.stringify(line), JSON.stringify(link)]
		JavaScriptBridge.eval(js)
		_toast("opening share..." if has_share == true else "copied! share your Auraling")
	else:
		DisplayServer.clipboard_set(full)
		_toast("copied! share your Auraling")

func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.6)
