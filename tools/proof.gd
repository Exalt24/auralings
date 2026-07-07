extends Node2D

# Dev-only: renders a GRID of many creatures into one contact sheet so variety is
# verifiable at a glance (the bestiary-sameness check). Not shipped.

const CreatureViewScript = preload("res://scripts/CreatureView.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")

const COLS := 4
const ROWS := 6
const W := 720
const H := 1280

func _ready() -> void:
	var cell_w := float(W) / COLS
	var cell_h := float(H) / ROWS
	# fixed seed spread so the sheet is reproducible run-to-run
	var start := 1000
	for i in COLS * ROWS:
		var c = CreatureGenScript.generate(start + i * 7919)
		var v = CreatureViewScript.new()
		var col := i % COLS
		var row := i / COLS
		v.position = Vector2((col + 0.5) * cell_w, (row + 0.42) * cell_h)
		add_child(v)
		v.set_creature(c)
		v.fit_to(min(cell_w, cell_h) * 0.34)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://_shots/proof.png")
	get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("2a2140"))
