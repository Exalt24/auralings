extends Node2D

# Dev-only: builds a bestiary with MANY creatures and screenshots every page so
# pagination is verified end-to-end (partial last page, gaps, alignment).

const CollectionScript = preload("res://scripts/Collection.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")

func _ready() -> void:
	var entries := []
	for i in 23:
		var c = CreatureGenScript.generate(3000 + i * 4643)
		entries.append({"seed": 3000 + i * 4643, "name": c["name"], "rarity": c["rarity"]})
	var col = CollectionScript.new()
	col.setup(entries)
	add_child(col)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))
	for page in 3:
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://_shots/page_%d.png" % page)
		col._turn(1)
	get_tree().quit()
