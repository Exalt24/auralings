extends Node

# Headless Monte Carlo balance sim. Mirrors Battle.gd's combat math (type chart, 1.8x
# ability, 2.5x charge, burn, speed order, role signatures), the gauntlet ramp
# (_scaled_enemy), and the boon/level/upgrade bonuses (_start_run/_apply_boon), then runs
# thousands of full gauntlet runs and reports the streak distribution + per role/rarity.
# Purpose: gauge whether runs wall too early / snowball, and whether roles are balanced.

const CreatureGenScript = preload("res://scripts/CreatureGen.gd")

const STRONG := {
	"ember": "moss", "moss": "tide", "tide": "ember",
	"spark": "frost", "frost": "bloom", "bloom": "spark",
	"void": "dusk", "dusk": "void",
}
const ABILITY_CD := 3

func _type_mult(a: String, d: String) -> float:
	if STRONG.get(a, "") == d: return 1.5
	if STRONG.get(d, "") == a: return 0.66
	return 1.0

func _choose(cd: int) -> String:
	if cd <= 0 and randf() < 0.8: return "ability"
	if randf() < 0.12: return "charge"
	return "attack"

# returns [won: bool, champ_hp_after: int]
func simulate_battle(P: Dictionary, php_in: int, E: Dictionary) -> Array:
	var php := php_in
	var ehp := int(E["max_hp"])
	var pcd := 0; var ecd := 0; var pburn := 0; var eburn := 0
	var pchg := false; var echg := false
	var guard := 0
	while php > 0 and ehp > 0 and guard < 400:
		guard += 1
		var pa := _choose(pcd)
		var ea := _choose(ecd)
		var p_init := int(P["spd"]) - (3 if pa == "charge" else 0)
		var e_init := int(E["spd"]) - (3 if ea == "charge" else 0)
		var order := [["p", pa], ["e", ea]] if p_init >= e_init else [["e", ea], ["p", pa]]
		for step in order:
			if php <= 0 or ehp <= 0: break
			var who: String = step[0]
			var act: String = step[1]
			# burn tick at start of the actor's turn
			if who == "p" and pburn > 0:
				php = max(0, php - max(1, int(float(P["max_hp"]) * 0.06))); pburn -= 1
				if php <= 0: break
			elif who == "e" and eburn > 0:
				ehp = max(0, ehp - max(1, int(float(E["max_hp"]) * 0.06))); eburn -= 1
				if ehp <= 0: break
			if act == "charge":
				if who == "p": pchg = true
				else: echg = true
				continue
			var attacker: Dictionary = P if who == "p" else E
			var defender: Dictionary = E if who == "p" else P
			var atk_hp := php if who == "p" else ehp
			var mult := 1.0
			if act == "ability":
				mult = 1.8
				var cd := ABILITY_CD - (1 if String(attacker.get("role", "")) == "Adept" else 0)
				if who == "p": pcd = cd
				else: ecd = cd
			if who == "p" and pchg: mult *= 2.5; pchg = false
			elif who == "e" and echg: mult *= 2.5; echg = false
			var tm := _type_mult(String(attacker["element"]), String(defender["element"]))
			var dmg := int(round(max(1.0, float(attacker["atk"]) * mult * tm * randf_range(0.9, 1.1))))
			if String(attacker.get("role", "")) == "Berserker" and float(atk_hp) < 0.4 * float(attacker["max_hp"]):
				dmg = int(round(float(dmg) * 1.3))
			var def_role := String(defender.get("role", ""))
			var dodged := def_role == "Skirmisher" and randf() < 0.18
			if dodged: dmg = 0
			elif def_role == "Warden": dmg = int(round(float(dmg) * 0.85))
			if who == "p":
				ehp = max(0, ehp - dmg)
				if not dodged and tm > 1.0 and act == "ability": eburn = 3
			else:
				php = max(0, php - dmg)
				if not dodged and tm > 1.0 and act == "ability": pburn = 3
		if pcd > 0: pcd -= 1
		if ecd > 0: ecd -= 1
	return [ehp <= 0 and php > 0, php]

var HP_BASE := 0.42
var HP_STEP := 0.10
var ATK_BASE := 0.52
var ATK_STEP := 0.06

func _scaled_enemy(r: int) -> Dictionary:
	var e: Dictionary = CreatureGenScript.generate(randi())
	e["max_hp"] = maxi(1, int(round(float(e["max_hp"]) * (HP_BASE + HP_STEP * float(r - 1)))))
	e["atk"] = maxi(1, int(round(float(e["atk"]) * (ATK_BASE + ATK_STEP * float(r - 1)))))
	return e

func run_gauntlet(champ: Dictionary, vigor: int, might: int, lvl: int) -> int:
	var C := champ.duplicate(true)
	C["max_hp"] = int(C["max_hp"]) + 8 * vigor + 4 * lvl
	C["atk"] = int(C["atk"]) + 2 * might + 1 * lvl
	var php := int(C["max_hp"])
	var streak := 0
	var rnd := 1
	while rnd < 120:
		var res := simulate_battle(C, php, _scaled_enemy(rnd))
		if not res[0]: break
		streak += 1
		php = int(res[1])
		rnd += 1
		var mx := int(C["max_hp"])
		if float(php) / float(mx) < 0.55:
			php = min(mx, php + int(float(mx) * 0.55))  # heal boon
		else:
			C["atk"] = int(C["atk"]) + 6  # power boon
	return streak

func _stats(arr: Array) -> Dictionary:
	arr.sort()
	var n := arr.size()
	if n == 0: return {"n": 0}
	var sum := 0
	for v in arr: sum += v
	return {
		"n": n, "mean": float(sum) / float(n),
		"p25": arr[int(n * 0.25)], "median": arr[int(n * 0.5)],
		"p75": arr[int(n * 0.75)], "max": arr[n - 1],
	}

func _line(label: String, s: Dictionary) -> void:
	if s.get("n", 0) == 0:
		print("  %s: (none)" % label); return
	print("  %-12s n=%-5d mean=%.1f  p25=%d median=%d p75=%d max=%d" % [label, s["n"], s["mean"], s["p25"], s["median"], s["p75"], s["max"]])

func _run_scenario(title: String, vigor: int, might: int, lvl: int, iters: int) -> void:
	var all: Array = []
	var by_role := {"Warden": [], "Berserker": [], "Skirmisher": [], "Adept": []}
	var by_rar := {"common": [], "rare": [], "epic": [], "legendary": []}
	for i in iters:
		var champ: Dictionary = CreatureGenScript.generate(randi())
		var streak := run_gauntlet(champ, vigor, might, lvl)
		all.append(streak)
		by_role[String(champ["role"])].append(streak)
		by_rar[String(champ["rarity"])].append(streak)
	print("\n=== %s ===" % title)
	_line("OVERALL", _stats(all))
	for r in ["Warden", "Berserker", "Skirmisher", "Adept"]:
		_line(r, _stats(by_role[r]))
	for r in ["common", "rare", "epic", "legendary"]:
		_line(r, _stats(by_rar[r]))

func _median_fresh(iters: int) -> Dictionary:
	var all: Array = []
	for i in iters:
		all.append(run_gauntlet(CreatureGenScript.generate(randi()), 0, 0, 0))
	return _stats(all)

func _ready() -> void:
	var N := 3000
	print("Auralings balance sim — tuned ramp hpB=%.2f/%.2f atkB=%.2f/%.2f  (%d runs)" % [HP_BASE, HP_STEP, ATK_BASE, ATK_STEP, N])
	_run_scenario("FRESH (lvl 0, no upgrades)", 0, 0, 0, N)
	_run_scenario("LEVELED champion (lvl 5)", 0, 0, 5, N)
	_run_scenario("MAXED meta (vigor 3, might 3)", 3, 3, 0, N)
	get_tree().quit()
