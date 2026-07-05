extends Node2D

# v0.1 shell: a summon screen that generates and displays a procedural Auraling.
# Battle + LLM-authored identity land in the next slices. Everything is built in
# code so the scene file stays trivial and unbreakable.

const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")
const LLMScript = preload("res://scripts/LLM.gd")
const BattleScript = preload("res://scripts/Battle.gd")
const Fx = preload("res://scripts/Fx.gd")
const Pal = preload("res://scripts/Palettes.gd")
const CollectionScript = preload("res://scripts/Collection.gd")

const W := 720
const H := 1280
const SAVE_PATH := "user://collection.json"

var summon_layer: Node2D   # all summon UI lives here so battle can hide it
var creature_view
var name_label: Label
var sub_label: Label
var lore_label: Label
var stat_label: Label
var ability_label: Label
var seed_label: Label
var toast_label: Label
var summon_btn: Button
var battle_btn: Button
var share_btn: Button
var bestiary_btn: Button
var llm
var current_seed := 0
var current_creature: Dictionary = {}
var battle = null
var collection_view = null
var collection: Array = []   # [{seed:int, name:String}], newest first
var bg_top := Color("2a2140")
var bg_bot := Color("4a3a6b")

func _ready() -> void:
	_load_collection()
	_build_ui()
	# share-a-seed: on web, ?seed=N summons that exact creature on load
	var shared := _shared_seed()
	if shared >= 0:
		_summon(shared)
	else:
		_summon()

func _draw() -> void:
	# vertical gradient backdrop
	draw_rect(Rect2(0, 0, W, H), bg_bot)
	var steps := 32
	for i in steps:
		var t := float(i) / float(steps)
		var c := bg_top.lerp(bg_bot, t)
		draw_rect(Rect2(0, H * t, W, H / steps + 1), c)

func _build_ui() -> void:
	summon_layer = Node2D.new()
	add_child(summon_layer)
	# title
	var title := Label.new()
	title.text = "AURALINGS"
	title.position = Vector2(0, 54)
	title.size = Vector2(W, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("ffe9c7"))
	summon_layer.add_child(title)

	var tagline := Label.new()
	tagline.text = "every creature is generated, never hand-drawn"
	tagline.position = Vector2(0, 104)
	tagline.size = Vector2(W, 24)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 20)
	tagline.add_theme_color_override("font_color", Color("c9b8e8"))
	summon_layer.add_child(tagline)

	# creature stage
	creature_view = CreatureViewScript.new()
	creature_view.position = Vector2(W * 0.5, 470)
	summon_layer.add_child(creature_view)

	# info card
	var card := ColorRect.new()
	card.color = Color(1, 1, 1, 0.10)
	card.position = Vector2(60, 716)
	card.size = Vector2(W - 120, 284)
	summon_layer.add_child(card)

	name_label = _mk_label(Vector2(90, 728), 40, Color("ffffff"))
	sub_label = _mk_label(Vector2(90, 774), 20, Color("c9b8e8"))
	lore_label = _mk_label(Vector2(90, 804), 21, Color("e8dcff"))
	lore_label.size = Vector2(W - 180, 70)
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_label = _mk_label(Vector2(90, 890), 26, Color("ffe9c7"))
	ability_label = _mk_label(Vector2(90, 926), 22, Color("9ff0d0"))
	ability_label.size = Vector2(W - 180, 56)
	ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# seed line + share (share-a-seed): a link that re-summons this exact creature.
	# sits in its own row with a clear gap above (card ends at 1000) and below.
	seed_label = Label.new()
	seed_label.position = Vector2(90, 1026)
	seed_label.size = Vector2(300, 34)
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_label.add_theme_font_size_override("font_size", 18)
	seed_label.add_theme_color_override("font_color", Color("9a8cc0"))
	summon_layer.add_child(seed_label)

	share_btn = Button.new()
	share_btn.text = "SHARE"
	share_btn.position = Vector2(W - 220, 1018)
	share_btn.size = Vector2(160, 50)
	share_btn.add_theme_font_size_override("font_size", 22)
	share_btn.pressed.connect(_share_seed)
	summon_layer.add_child(share_btn)

	# summon + battle buttons, side by side
	summon_btn = Button.new()
	summon_btn.text = "SUMMON"
	summon_btn.position = Vector2(60, 1086)
	summon_btn.size = Vector2(288, 84)
	summon_btn.add_theme_font_size_override("font_size", 32)
	summon_btn.pressed.connect(_summon.bind(-1))
	summon_layer.add_child(summon_btn)

	battle_btn = Button.new()
	battle_btn.text = "BATTLE"
	battle_btn.position = Vector2(W - 348, 1086)
	battle_btn.size = Vector2(288, 84)
	battle_btn.add_theme_font_size_override("font_size", 32)
	battle_btn.add_theme_color_override("font_color", Color("9ff0d0"))
	battle_btn.pressed.connect(_enter_battle)
	summon_layer.add_child(battle_btn)

	# bestiary of everything summoned so far
	bestiary_btn = Button.new()
	bestiary_btn.text = "BESTIARY"
	bestiary_btn.position = Vector2(60, 1188)
	bestiary_btn.size = Vector2(W - 120, 74)
	bestiary_btn.add_theme_font_size_override("font_size", 30)
	bestiary_btn.add_theme_color_override("font_color", Color("ffd7a8"))
	bestiary_btn.pressed.connect(_open_collection)
	summon_layer.add_child(bestiary_btn)

	# transient toast ("link copied!")
	toast_label = Label.new()
	toast_label.position = Vector2(0, 664)
	toast_label.size = Vector2(W, 34)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 24)
	toast_label.add_theme_color_override("font_color", Color("9ff0d0"))
	toast_label.modulate.a = 0.0
	summon_layer.add_child(toast_label)

	# LLM loremaster
	llm = LLMScript.new()
	summon_layer.add_child(llm)
	llm.identity_ready.connect(_on_identity_ready)

	queue_redraw()

func _mk_label(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(W - 180, 44)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	summon_layer.add_child(l)
	return l

func _summon(seed_val: int = -1) -> void:
	var use_seed := seed_val if seed_val >= 0 else randi()
	var c = CreatureGenScript.generate(use_seed)
	current_seed = int(c["seed"])
	current_creature = c
	seed_label.text = "seed  %d" % current_seed
	creature_view.set_creature(c)
	creature_view.fit_to(190.0)   # uniform footprint regardless of body/horns/aura
	creature_view.flash_hit()
	# summon spark burst, tinted by the creature's element (brighter for rares)
	var pal: Dictionary = Pal.get_palette(c["element"])
	Fx.burst(summon_layer, creature_view.position, pal["accent"], (40 if c.get("rare", false) else 26))
	_add_to_collection(current_seed, String(c["name"]))
	# show the body + procedural fallback instantly; the LLM enriches the words
	name_label.text = c["name"]
	var prefix := "RARE  ·  " if c.get("rare", false) else ""
	sub_label.text = "%s%s  ·  %s" % [prefix, String(c["element"]).capitalize(), c["archetype"]]
	stat_label.text = "HP %d      ATK %d" % [c["hp"], c["atk"]]
	ability_label.text = "*" + c["ability_name"]
	if llm.has_key():
		lore_label.text = "summoning its story…"
		summon_btn.disabled = true
		summon_btn.text = "SUMMONING…"
		llm.request_identity(c)
	else:
		lore_label.text = "A wandering %s spirit." % String(c["element"]).capitalize()

func _on_identity_ready(seed_val: int, identity: Dictionary) -> void:
	summon_btn.disabled = false
	summon_btn.text = "SUMMON"
	if seed_val != current_seed:
		return  # a newer summon superseded this one
	if identity.is_empty():
		lore_label.text = "Its story is lost to static…"
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
		ability_label.text = "*%s: %s" % [abil_name, abil_desc]
		current_creature["ability_name"] = abil_name

func _enter_battle() -> void:
	if current_creature.is_empty() or battle != null:
		return
	summon_layer.visible = false
	battle = BattleScript.new()
	battle.setup(current_creature)
	battle.battle_over.connect(_on_battle_over)
	add_child(battle)

func _on_battle_over(_player_won: bool) -> void:
	if battle != null:
		battle.queue_free()
		battle = null
	summon_layer.visible = true
	_summon()

# --- collection / bestiary ---

func _open_collection() -> void:
	if collection_view != null:
		return
	summon_layer.visible = false
	collection_view = CollectionScript.new()
	collection_view.setup(collection)
	collection_view.closed.connect(_on_collection_closed)
	add_child(collection_view)

func _on_collection_closed() -> void:
	if collection_view != null:
		collection_view.queue_free()
		collection_view = null
	summon_layer.visible = true

func _add_to_collection(seed_val: int, nm: String) -> void:
	# dedupe by seed, newest first
	for i in collection.size():
		if int(collection[i].get("seed", -1)) == seed_val:
			collection.remove_at(i)
			break
	collection.push_front({"seed": seed_val, "name": nm})
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

# --- share-a-seed ---

func _shared_seed() -> int:
	if not OS.has_feature("web"):
		return -1
	var v = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('seed')", true)
	if typeof(v) == TYPE_STRING and String(v).is_valid_int():
		return int(String(v))
	return -1

func _share_seed() -> void:
	var link := "seed %d" % current_seed
	if OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("window.location.origin + window.location.pathname", true)
		if typeof(origin) == TYPE_STRING:
			link = String(origin) + "?seed=" + str(current_seed)
	DisplayServer.clipboard_set(link)
	_toast("link copied!")

func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.6)
