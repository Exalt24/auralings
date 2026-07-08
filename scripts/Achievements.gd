extends RefCounted

# Achievement definitions + unlock evaluation. Pure data/logic; Main owns the unlocked
# set (persisted in meta.json) and fires the toast. Milestone achievements drive the
# "unlock them all" replay hook without touching run balance (they grant no power).

const LIST := [
	{"id": "first_win", "name": "First Blood", "desc": "Win your first gauntlet fight"},
	{"id": "streak_3", "name": "On a Roll", "desc": "Reach a 3-win streak"},
	{"id": "streak_7", "name": "Gauntlet Runner", "desc": "Reach a 7-win streak"},
	{"id": "streak_12", "name": "Unstoppable", "desc": "Reach a 12-win streak"},
	{"id": "collect_10", "name": "Collector", "desc": "Discover 10 Auralings"},
	{"id": "collect_25", "name": "Archivist", "desc": "Discover 25 Auralings"},
	{"id": "got_rare", "name": "Lucky Find", "desc": "Summon a rare or better"},
	{"id": "got_legendary", "name": "Mythmaker", "desc": "Summon a legendary"},
]

static func name_of(id: String) -> String:
	for a in LIST:
		if a["id"] == id:
			return String(a["name"])
	return id

# returns the list of ids that SHOULD be unlocked given the current stats (Main
# filters out the ones already unlocked and toasts the newly-earned ones)
static func earned(streak: int, best_streak: int, discovered: int, last_rarity: String) -> Array:
	var out := []
	var top := max(streak, best_streak)
	if best_streak >= 1 or streak >= 1: out.append("first_win")
	if top >= 3: out.append("streak_3")
	if top >= 7: out.append("streak_7")
	if top >= 12: out.append("streak_12")
	if discovered >= 10: out.append("collect_10")
	if discovered >= 25: out.append("collect_25")
	if last_rarity != "" and last_rarity != "common": out.append("got_rare")
	if last_rarity == "legendary": out.append("got_legendary")
	return out
