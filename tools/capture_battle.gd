extends Node

# Dev-only: builds a Battle directly (no LLM wait), drives a couple of turns so the
# juice is visible, and saves PNGs at initial / mid-hit / post-exchange. Lets Claude
# SEE the battle without the GUI. Not shipped in the build.

const BattleScript = preload("res://scripts/Battle.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")

var battle

func _ready() -> void:
	battle = BattleScript.new()
	battle.setup(CreatureGenScript.generate(randi()))
	add_child(battle)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))

	await _wait(0.3)
	await _shoot(0)  # initial arena

	battle.debug_attack(true)  # player uses ability
	await _wait(0.2)
	await _shoot(1)  # mid-hit: shake + floating number + bar tween

	# drive the fight in real time until someone is knocked out
	var shot := 2
	var guard := 0
	while not battle.finished and guard < 40:
		guard += 1
		if not battle.busy:
			battle.debug_attack(battle.player_cd <= 0)
			await _wait(0.25)
			await _shoot(shot)  # exchange snapshots
			shot = min(shot + 1, 4)
		await _wait(0.2)

	await _wait(0.4)
	await _shoot(5)  # VICTORY / DEFEATED banner
	get_tree().quit()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _shoot(n: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://_shots/battle_%d.png" % n)
