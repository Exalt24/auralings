extends Node

# Dev-only: summons several creatures (populating the collection), opens the
# bestiary, and screenshots it — verifies the grid + the new body silhouettes in
# one shot. Also grabs a plain summon-screen frame to check the seed/share row.

func _ready() -> void:
	# start from a clean collection so the grid is deterministic
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://collection.json"))
	var main = preload("res://scenes/Main.tscn").instantiate()
	add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))

	for i in 6:
		await get_tree().process_frame
	# summon-screen frame (seed + share + bestiary buttons)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shots/summon_ui.png")

	# populate a handful more, then open the bestiary
	for n in 8:
		main._summon(randi())
		for i in 3:
			await get_tree().process_frame
	main._open_collection()
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shots/bestiary.png")
	get_tree().quit()
