extends RefCounted
## Every item in the game, with the rank needed to use it and its fixed price.
## Prices are placeholders until the Market arrives in Stage 7.
## `min_rank` is an index into GameManager.RANK_NAMES.

const ITEMS := {
	"energy_rifle": {"name": "Energy rifle", "type": "weapon", "min_rank": 0, "price": 800},
	"machete": {"name": "Machete", "type": "weapon", "min_rank": 0, "price": 300},
	"scatter_blaster": {"name": "Scatter blaster", "type": "weapon", "min_rank": 1, "price": 1500},
	"pulse_carbine": {"name": "Pulse carbine", "type": "weapon", "min_rank": 2, "price": 2800},
	"plasma_cannon": {"name": "Plasma cannon", "type": "weapon", "min_rank": 4, "price": 6000},
	"arc_launcher": {"name": "Arc launcher", "type": "weapon", "min_rank": 5, "price": 9500},

	"turret": {"name": "Auto turret", "type": "defence", "min_rank": 0, "price": 1200},
	"shield_barrier": {"name": "Shield barrier", "type": "defence", "min_rank": 1, "price": 2000},
	"heavy_turret": {"name": "Heavy turret", "type": "defence", "min_rank": 3, "price": 4500},
	"beam_amplifier": {"name": "Beam amplifier", "type": "defence", "min_rank": 5, "price": 12000},

	"fighter_jet": {"name": "Fighter jet", "type": "vehicle", "min_rank": 0, "price": 3000},
	"interceptor": {"name": "Interceptor jet", "type": "vehicle", "min_rank": 2, "price": 7000},
	"gunship": {"name": "Gunship", "type": "vehicle", "min_rank": 4, "price": 15000},
}

const TYPE_ORDER: Array[String] = ["weapon", "defence", "vehicle"]


static func exists(item_id: String) -> bool:
	return ITEMS.has(item_id)


static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func item_name(item_id: String) -> String:
	return ITEMS.get(item_id, {}).get("name", item_id)


static func min_rank(item_id: String) -> int:
	return ITEMS.get(item_id, {}).get("min_rank", 0)


static func ids_of_type(type: String) -> Array:
	var result: Array = []
	for id in ITEMS:
		if ITEMS[id]["type"] == type:
			result.append(id)
	result.sort_custom(func(a, b): return ITEMS[a]["min_rank"] < ITEMS[b]["min_rank"])
	return result
