extends Node2D

# v0.1 shell: a summon screen that generates and displays a procedural Auraling.
# Battle + LLM-authored identity land in the next slices. Everything is built in
# code so the scene file stays trivial and unbreakable.

const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")
const LLMScript = preload("res://scripts/LLM.gd")
const BattleScript = preload("res://scripts/Battle.gd")

const W := 720
const H := 1280

var summon_layer: Node2D   # all summon UI lives here so battle can hide it
var creature_view
var name_label: Label
var sub_label: Label
var lore_label: Label
var stat_label: Label
var ability_label: Label
var summon_btn: Button
var battle_btn: Button
var llm
var current_seed := 0
var current_creature: Dictionary = {}
var battle = null
var bg_top := Color("2a2140")
var bg_bot := Color("4a3a6b")

func _ready() -> void:
	_build_ui()
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
	card.position = Vector2(60, 720)
	card.size = Vector2(W - 120, 300)
	summon_layer.add_child(card)

	name_label = _mk_label(Vector2(90, 742), 40, Color("ffffff"))
	sub_label = _mk_label(Vector2(90, 790), 20, Color("c9b8e8"))
	lore_label = _mk_label(Vector2(90, 822), 21, Color("e8dcff"))
	lore_label.size = Vector2(W - 180, 70)
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_label = _mk_label(Vector2(90, 908), 26, Color("ffe9c7"))
	ability_label = _mk_label(Vector2(90, 952), 22, Color("9ff0d0"))
	ability_label.size = Vector2(W - 180, 60)
	ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# summon + battle buttons, side by side
	summon_btn = Button.new()
	summon_btn.text = "SUMMON"
	summon_btn.position = Vector2(55, 1080)
	summon_btn.size = Vector2(290, 84)
	summon_btn.add_theme_font_size_override("font_size", 32)
	summon_btn.pressed.connect(_summon)
	summon_layer.add_child(summon_btn)

	battle_btn = Button.new()
	battle_btn.text = "BATTLE ►"
	battle_btn.position = Vector2(W - 345, 1080)
	battle_btn.size = Vector2(290, 84)
	battle_btn.add_theme_font_size_override("font_size", 32)
	battle_btn.add_theme_color_override("font_color", Color("9ff0d0"))
	battle_btn.pressed.connect(_enter_battle)
	summon_layer.add_child(battle_btn)

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

func _summon() -> void:
	var c = CreatureGenScript.generate(randi())
	current_seed = int(c["seed"])
	current_creature = c
	creature_view.set_creature(c)
	creature_view.flash_hit()
	# show the body + procedural fallback instantly; the LLM enriches the words
	name_label.text = c["name"]
	sub_label.text = "%s  ·  %s" % [String(c["element"]).capitalize(), c["archetype"]]
	stat_label.text = "HP %d      ATK %d" % [c["hp"], c["atk"]]
	ability_label.text = "✦ " + c["ability_name"]
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
	var title := String(identity.get("title", ""))
	if title.length() > 0:
		sub_label.text = title + "  ·  " + sub_label.text
	lore_label.text = String(identity.get("lore", lore_label.text))
	var abil_name := String(identity.get("ability_name", ""))
	var abil_desc := String(identity.get("ability_desc", ""))
	if abil_name.length() > 0:
		ability_label.text = "✦ %s — %s" % [abil_name, abil_desc]
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
