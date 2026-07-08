extends Node2D

# Dev-only: renders the SHARE toast AND the achievement toast OVER the run-over
# screen exactly as Main.gd builds them, so we can SEE whether they actually show.

const RunOverScript = preload("res://scripts/RunOver.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")
const UI = preload("res://scripts/UI.gd")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))
	var champ = CreatureGenScript.generate(4242)

	var ro = RunOverScript.new()
	ro.setup(champ, 7, 7, true, 7)
	add_child(ro)

	# --- exact replica of the SHARE toast from Main.gd ---
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 51
	add_child(toast_layer)
	var toast_label = UI.label("copied to clipboard!", 26, UI.MINT, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_left = 40; toast_label.offset_right = -40
	toast_label.offset_top = -120; toast_label.offset_bottom = -70
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.modulate.a = 1.0
	toast_layer.add_child(toast_label)

	# --- exact replica of the achievement toast from Main.gd ---
	var ach_layer := CanvasLayer.new()
	ach_layer.layer = 50
	add_child(ach_layer)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel(Color("2f2650"), 16, UI.GOLD, 2, 8))
	pc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	pc.offset_left = 90; pc.offset_right = -90; pc.offset_top = 150; pc.offset_bottom = 214
	pc.modulate.a = 1.0
	ach_layer.add_child(pc)
	var ach_label = UI.label("Achievement: First Blood", 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	pc.add_child(ach_label)

	for i in 24: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shots/toast_test.png")
	for i in 4: await get_tree().process_frame
	get_tree().quit()
