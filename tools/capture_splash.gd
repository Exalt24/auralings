extends Node2D

# Dev-only: renders the branded boot-splash image (shown by the web loader while the
# WASM boots) — the AURALINGS wordmark + a creature on the game's backdrop.

const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")

const W := 720
const H := 720

func _ready() -> void:
	var v = CreatureViewScript.new()
	v.position = Vector2(W * 0.5, 430)
	add_child(v)
	v.set_creature(CreatureGenScript.generate(424242))
	v.fit_to(150.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://web"))
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img = img.get_region(Rect2i(0, 0, W, H))
	img.save_png("res://web/splash.png")
	get_tree().quit()

func _draw() -> void:
	var top := Color("2a2140")
	var bot := Color("453763")
	for i in 40:
		var t := float(i) / 40.0
		draw_rect(Rect2(0, H * t, W, H / 40 + 1), top.lerp(bot, t))
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(0, 150), "AURALINGS", HORIZONTAL_ALIGNMENT_CENTER, W, 64, Color("ffe9c7"))
	draw_string(f, Vector2(0, 195), "summon infinite creatures", HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color("c9b8e8"))
	draw_string(f, Vector2(0, 640), "loading…", HORIZONTAL_ALIGNMENT_CENTER, W, 28, Color("9ff0d0"))
