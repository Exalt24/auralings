extends Node2D

# Dev-only: forces a RARE, horned creature so the new polish (aura rings, ground
# shadow, blunt horns) is guaranteed visible, and fires a summon burst so the
# particles are caught mid-flight. Saves a PNG and quits.

const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")
const Fx = preload("res://scripts/Fx.gd")
const Pal = preload("res://scripts/Palettes.gd")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 720, 1280), Color("2a2140"))

func _ready() -> void:
	queue_redraw()
	var c = CreatureGenScript.generate(randi())
	c["rare"] = true
	c["has_horns"] = true
	c["horn_count"] = 2
	c["horn_len"] = 56.0
	c["has_ears"] = false
	c["element"] = "spark"
	var view = CreatureViewScript.new()
	view.position = Vector2(360, 560)
	add_child(view)
	view.set_creature(c)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))
	# a couple of frames in, fire the burst, then grab it while particles are live
	for i in 8:
		await get_tree().process_frame
	Fx.burst(self, view.position, Pal.get_palette(c["element"])["accent"], 40)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shots/polish.png")
	get_tree().quit()
