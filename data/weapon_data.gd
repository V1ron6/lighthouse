extends RefCounted
## Firing stats for the ranged weapons. The machete is separate (scenes/weapons/machete.gd).
## `pellets` shots per trigger pull, `spread` in radians, `splash` radius of an area blast,
## `chain` extra enemies an arc jumps to. All numbers are placeholders to tune.

const ORDER: Array[String] = ["energy_rifle", "machete", "scatter_blaster", "pulse_carbine", "plasma_cannon", "arc_launcher"]

const STATS := {
	"energy_rifle": {"name": "Energy rifle", "damage": 25, "interval": 0.15, "pellets": 1, "spread": 0.0,
		"heat": 8.0, "range": 100.0, "splash": 0.0, "chain": 0, "color": Color(0.3, 0.88, 1.0), "sound": "rifle"},
	"scatter_blaster": {"name": "Scatter blaster", "damage": 12, "interval": 0.7, "pellets": 8, "spread": 0.07,
		"heat": 30.0, "range": 40.0, "splash": 0.0, "chain": 0, "color": Color(1.0, 0.6, 0.2), "sound": "rifle"},
	"pulse_carbine": {"name": "Pulse carbine", "damage": 18, "interval": 0.07, "pellets": 1, "spread": 0.012,
		"heat": 5.0, "range": 90.0, "splash": 0.0, "chain": 0, "color": Color(0.5, 1.0, 0.4), "sound": "rifle"},
	"plasma_cannon": {"name": "Plasma cannon", "damage": 90, "interval": 0.9, "pellets": 1, "spread": 0.0,
		"heat": 40.0, "range": 80.0, "splash": 4.0, "chain": 0, "color": Color(1.0, 0.3, 0.9), "sound": "cannon"},
	"arc_launcher": {"name": "Arc launcher", "damage": 40, "interval": 0.5, "pellets": 1, "spread": 0.0,
		"heat": 25.0, "range": 70.0, "splash": 0.0, "chain": 3, "color": Color(0.7, 0.5, 1.0), "sound": "cannon"},
}


static func stats(id: String) -> Dictionary:
	return STATS.get(id, STATS["energy_rifle"])
