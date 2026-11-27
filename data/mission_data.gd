extends RefCounted
## Mission definitions. Three starter missions. More are added in later stages.
##   kills          scouts to eliminate to complete the mission
##   risk           1 to 3, shown to the player. Higher risk pays more.
##   min_rank       rank index needed (0 = Recruit)
##   attack_chance  chance (0 to 1) that the base is attacked during the mission
##   attack_after   seconds into the mission when the attack hits (plus or minus 5)
##   attack_strength  number of attackers in the base attack

const MISSIONS: Array[Dictionary] = [
	{
		"id": "perimeter_sweep",
		"name": "Perimeter sweep",
		"description": "Clear scouts from the outer ring.",
		"kills": 8,
		"risk": 1,
		"min_rank": 0,
		"reward_qubits": 300,
		"reward_points": 40,
		"attack_chance": 0.35,
		"attack_after": 25.0,
		"attack_strength": 4,
	},
	{
		"id": "nest_raid",
		"name": "Nest raid",
		"description": "Hit the nest and thin out the swarm.",
		"kills": 14,
		"risk": 2,
		"min_rank": 1,
		"reward_qubits": 700,
		"reward_points": 90,
		"attack_chance": 0.6,
		"attack_after": 30.0,
		"attack_strength": 8,
	},
	{
		"id": "deep_strike",
		"name": "Deep strike",
		"description": "Push deep into alien ground. Big reward, big risk.",
		"kills": 22,
		"risk": 3,
		"min_rank": 2,
		"reward_qubits": 1400,
		"reward_points": 180,
		"attack_chance": 0.85,
		"attack_after": 35.0,
		"attack_strength": 12,
	},
]


static func get_mission(id: String) -> Dictionary:
	for mission in MISSIONS:
		if mission["id"] == id:
			return mission
	return {}
