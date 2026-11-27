extends RefCounted
## The ten NPC colonies. Trade partners for the Market.
## A fallen colony pays less when you sell and charges less when you buy.

const COLONIES: Array[Dictionary] = [
	{"id": "ashgrove", "name": "Ashgrove"},
	{"id": "northreach", "name": "Northreach"},
	{"id": "helix_point", "name": "Helix Point"},
	{"id": "dunmore", "name": "Dunmore"},
	{"id": "sable_bay", "name": "Sable Bay"},
	{"id": "ironvale", "name": "Ironvale"},
	{"id": "kestrel_hold", "name": "Kestrel Hold"},
	{"id": "lumen_reach", "name": "Lumen Reach"},
	{"id": "tidewater", "name": "Tidewater"},
	{"id": "vantage", "name": "Vantage"},
]


static func colony_name(colony_id: String) -> String:
	for colony in COLONIES:
		if colony["id"] == colony_id:
			return colony["name"]
	return colony_id


static func ids() -> Array[String]:
	var result: Array[String] = []
	for colony in COLONIES:
		result.append(colony["id"])
	return result
