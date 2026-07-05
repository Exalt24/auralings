extends Node

# Dev-only: loads Main, lets it settle a few frames, saves a PNG of the render,
# then quits. Lets Claude SEE the game without the GUI. Not shipped in the build.

@export var shots := 1

func _ready() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))
	for n in shots:
		if n > 0 and main.has_method("_summon"):
			main._summon()
		# wait long enough for the async LLM identity call to land
		for i in 170:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://_shots/shot_%d.png" % n)
	get_tree().quit()
