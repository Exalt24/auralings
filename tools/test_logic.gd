extends Node2D

# Integration test for the spot-check items: upgrade stat application, each boon's
# effect, the end-run transition, and the 4-boon (Insight) render. Drives the real
# Main + BoonChoice code and prints PASS/FAIL.

const BoonChoiceScript = preload("res://scripts/BoonChoice.gd")
const CreatureGenScript = preload("res://scripts/CreatureGen.gd")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_shots"))
	var main = preload("res://scenes/Main.tscn").instantiate()
	add_child(main)
	for i in 20: await get_tree().process_frame

	# ---- (1) upgrades carry into the run ----
	main.current_creature = CreatureGenScript.generate(1234)
	var base_hp := int(main.current_creature["max_hp"])
	var base_atk := int(main.current_creature["atk"])
	main._upgrades = {"vigor": 3, "might": 3, "insight": 1}
	main._start_run()
	for i in 6: await get_tree().process_frame
	var run_hp := int(main.battle.player["max_hp"])
	var run_atk := int(main.battle.player["atk"])
	print("TEST1 upgrades: base_hp=%d run_hp=%d (want +24)  base_atk=%d run_atk=%d (want +6)  boon_count=%d (want 4)" % [base_hp, run_hp, base_atk, run_atk, main._boon_count])
	print("TEST1 %s" % ("PASS" if run_hp == base_hp + 24 and run_atk == base_atk + 6 and main._boon_count == 4 else "FAIL"))
	if main.battle: main.battle.queue_free(); main.battle = null
	for i in 3: await get_tree().process_frame

	# ---- (2) each boon applies ----
	var ok := true
	main._champion = {"max_hp": 100, "hp": 50, "atk": 20, "spd": 10}
	main._apply_boon("heal")
	if int(main._champion["hp"]) <= 50: ok = false
	print("TEST2 heal: hp 50 -> %d (want >50)" % int(main._champion["hp"]))
	main._champion = {"max_hp": 100, "hp": 50, "atk": 20, "spd": 10}
	main._apply_boon("fortify")
	print("TEST2 fortify: max_hp 100 -> %d (want 130), hp -> %d (want 80)" % [int(main._champion["max_hp"]), int(main._champion["hp"])])
	if int(main._champion["max_hp"]) != 130: ok = false
	main._champion = {"max_hp": 100, "hp": 50, "atk": 20, "spd": 10}
	main._apply_boon("power")
	print("TEST2 power: atk 20 -> %d (want 26)" % int(main._champion["atk"]))
	if int(main._champion["atk"]) != 26: ok = false
	main._champion = {"max_hp": 100, "hp": 50, "atk": 20, "spd": 10}
	main._apply_boon("focus")
	print("TEST2 focus: hp -> %d (want 100), atk -> %d (want 22)" % [int(main._champion["hp"]), int(main._champion["atk"])])
	if int(main._champion["hp"]) != 100 or int(main._champion["atk"]) != 22: ok = false
	main._champion = {"max_hp": 100, "hp": 50, "atk": 20, "spd": 10}
	main._apply_boon("swift")
	print("TEST2 swift: spd 10 -> %d (want 14), atk 20 -> %d (want 23)" % [int(main._champion["spd"]), int(main._champion["atk"])])
	if int(main._champion["spd"]) != 14 or int(main._champion["atk"]) != 23: ok = false
	print("TEST2 %s" % ("PASS" if ok else "FAIL"))

	# ---- (3) end-run returns to summon ----
	main.run_over_view = null
	main.summon_layer.visible = false
	main._end_run()
	for i in 3: await get_tree().process_frame
	print("TEST3 end_run: summon visible=%s (want true)  %s" % [str(main.summon_layer.visible), "PASS" if main.summon_layer.visible else "FAIL"])

	# ---- (5) champion leveling from wins (persist + apply) ----
	var seed5 := 55501
	main.collection = []
	main.current_creature = CreatureGenScript.generate(seed5)
	main.current_seed = seed5
	main._add_to_collection(seed5, "Testo")
	for i in 9: main._add_win(seed5)
	var w5: int = main._wins_for(seed5)
	var lv5: int = main._level_from_wins(w5)
	main._add_to_collection(seed5, "Testo")  # re-summon: wins must survive
	var w5_after: int = main._wins_for(seed5)
	main._upgrades = {"vigor": 0, "might": 0, "insight": 0}
	var base_hp5 := int(main.current_creature["max_hp"])
	var base_atk5 := int(main.current_creature["atk"])
	main._start_run()
	for i in 6: await get_tree().process_frame
	var rhp5 := int(main.battle.player["max_hp"])
	var ratk5 := int(main.battle.player["atk"])
	print("TEST5 wins=%d(want9) lv=%d(want3) wins_after_resummon=%d(want9) hp+%d(want12) atk+%d(want3)" % [w5, lv5, w5_after, rhp5 - base_hp5, ratk5 - base_atk5])
	print("TEST5 %s" % ("PASS" if w5 == 9 and lv5 == 3 and w5_after == 9 and rhp5 - base_hp5 == 12 and ratk5 - base_atk5 == 3 else "FAIL"))
	if main.battle: main.battle.queue_free(); main.battle = null
	for i in 3: await get_tree().process_frame

	# ---- (6) underdog essence multiplier ----
	var em_c: float = main._essence_mult("common")
	var em_l: float = main._essence_mult("legendary")
	var e_common: int = int(round(10.0 * em_c))
	var e_leg: int = int(round(10.0 * em_l))
	print("TEST6 mult common=%.2f(want1.5) legendary=%.2f(want1.0)  streak10 -> common %d(want15) leg %d(want10)" % [em_c, em_l, e_common, e_leg])
	print("TEST6 %s" % ("PASS" if em_c == 1.5 and em_l == 1.0 and e_common == 15 and e_leg == 10 else "FAIL"))

	main.queue_free()
	for i in 3: await get_tree().process_frame

	# ---- (4) 4-boon (Insight) render ----
	var champ = CreatureGenScript.generate(777)
	var boon = BoonChoiceScript.new()
	boon.setup(champ, [
		{"id":"heal","name":"Second Wind","desc":"Restore 55% of max HP"},
		{"id":"power","name":"Power Up","desc":"+6 ATK"},
		{"id":"fortify","name":"Fortify","desc":"+30 max HP, and heal 30"},
		{"id":"swift","name":"Swift","desc":"+4 SPD, +3 ATK"},
	], 6)
	add_child(boon)
	for i in 18: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shots/boon4.png")
	print("TEST4 rendered 4-boon screen -> _shots/boon4.png")
	get_tree().quit()
