extends Node2D

const CreatureGenScript = preload("res://scripts/CreatureGen.gd")
const BoonChoiceScript = preload("res://scripts/BoonChoice.gd")
const RunOverScript = preload("res://scripts/RunOver.gd")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))
	var champ = CreatureGenScript.generate(4242)
	champ["hp"] = int(champ["max_hp"]) * 0.6

	var boon = BoonChoiceScript.new()
	boon.setup(champ, [
		{"id":"heal","name":"Second Wind","desc":"Restore 55% of max HP"},
		{"id":"power","name":"Power Up","desc":"+6 ATK"},
		{"id":"fortify","name":"Fortify","desc":"+30 max HP, and heal 30"},
	], 4)
	add_child(boon)
	for i in 20: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shots/boon.png")
	boon.queue_free()
	for i in 4: await get_tree().process_frame

	var ro = RunOverScript.new()
	ro.setup(champ, 7, 7, true)
	add_child(ro)
	for i in 20: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shots/runover.png")
	get_tree().quit()
