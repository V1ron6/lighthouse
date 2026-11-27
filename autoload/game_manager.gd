extends Node
## Central game state (autoload: GameManager).
## Tracks qubits, points and rank, base health, mission state and inventory.
## Other scenes read from here and listen to EventBus for changes.

const ItemData := preload("res://data/item_data.gd")

enum MissionState { NONE, ACTIVE, BASE_UNDER_ATTACK, COMPLETE, FAILED, ABANDONED }

const SAVE_PATH := "user://lighthouse_save.json"

const STARTING_QUBITS := 3500
const MAX_BASE_HEALTH := 1000
const MAX_CORE_INTEGRITY := 1000

const RANK_NAMES: Array[String] = [
	"Recruit", "Cadet", "Operative", "Sentinel", "Warden", "Commander", "Keeper of the Light",
]
## Points needed to reach each rank. Still placeholders: tune after playtesting.
const RANK_THRESHOLDS: Array[int] = [0, 100, 300, 600, 1000, 1600, 2500]

## Base attack while the player is away on a mission (they chose to continue).
## Each turret stops this many attackers. The rest damage the base.
const DEFENDED_PER_TURRET := 4
const DAMAGE_PER_LEAKED := 60
## Turrets the lighthouse can run at once: this plus one per rank.
const BASE_TURRET_SLOTS := 1
## Rank points lost for leaving the base: a flat part plus a part per leaked attacker.
const PENALTY_BASE := 10
const PENALTY_PER_LEAKED := 12
## Points for repelling a base attack by hand: base plus 2 per attacker.
const DEFEND_POINTS_BASE := 25
## Repair prices, in qubits per hit point.
const BASE_REPAIR_HP_PER_QUBIT := 5.0
const CORE_REPAIR_HP_PER_QUBIT := 2.0

## What the player owns at the start of a new game.
const STARTING_INVENTORY := {
	"fighter_jet": 1,
	"turret": 1,
	"energy_rifle": 1,
	"machete": 1,
}

var qubits: int = STARTING_QUBITS
var points: int = 0
var rank_index: int = 0
var base_health: int = MAX_BASE_HEALTH
var core_integrity: int = MAX_CORE_INTEGRITY
var mission_state: MissionState = MissionState.NONE
var current_mission_id: String = ""
var inventory: Dictionary = {}
var fallen_colonies: Array[String] = []
var has_seen_intro: bool = false
## Set when the player chose to defend the base. Read by the base defence level.
var pending_attack: Dictionary = {}


func _ready() -> void:
	new_game()
	load_game()


# --- New game / reset ---

func new_game() -> void:
	qubits = STARTING_QUBITS
	points = 0
	rank_index = 0
	base_health = MAX_BASE_HEALTH
	core_integrity = MAX_CORE_INTEGRITY
	mission_state = MissionState.NONE
	current_mission_id = ""
	inventory = STARTING_INVENTORY.duplicate()
	fallen_colonies.clear()
	has_seen_intro = false
	pending_attack = {}
	_emit_all()


# --- Qubits ---

func add_qubits(amount: int) -> void:
	if amount <= 0:
		return
	qubits += amount
	EventBus.qubits_changed.emit(qubits)


## Returns false and changes nothing if the player cannot afford it.
func spend_qubits(amount: int) -> bool:
	if amount < 0 or qubits < amount:
		return false
	qubits -= amount
	EventBus.qubits_changed.emit(qubits)
	return true


# --- Points and rank ---

func add_points(amount: int) -> void:
	if amount <= 0:
		return
	points += amount
	EventBus.points_changed.emit(points)
	_update_rank()


## Points can fall below a rank's threshold, which demotes the player.
func remove_points(amount: int) -> void:
	if amount <= 0:
		return
	points = maxi(0, points - amount)
	EventBus.points_changed.emit(points)
	_update_rank()


func get_rank_name() -> String:
	return RANK_NAMES[rank_index]


## 0 when already at the top rank.
func points_to_next_rank() -> int:
	if rank_index >= RANK_NAMES.size() - 1:
		return 0
	return RANK_THRESHOLDS[rank_index + 1] - points


## Points still needed for the next rank as a 0..1 fraction of this rank's span.
func rank_progress() -> float:
	if rank_index >= RANK_NAMES.size() - 1:
		return 1.0
	var low := RANK_THRESHOLDS[rank_index]
	var high := RANK_THRESHOLDS[rank_index + 1]
	return clampf(float(points - low) / float(high - low), 0.0, 1.0)


## True if the player owns the item and has the rank to use it.
func can_use(item_id: String) -> bool:
	return has_item(item_id) and rank_index >= ItemData.min_rank(item_id)


## Turrets the lighthouse can run: owned, capped by rank.
func usable_turrets() -> int:
	return mini(inventory.get("turret", 0), max_turrets())


func max_turrets() -> int:
	return BASE_TURRET_SLOTS + rank_index


func _update_rank() -> void:
	var new_index := 0
	for i in RANK_THRESHOLDS.size():
		if points >= RANK_THRESHOLDS[i]:
			new_index = i
	if new_index != rank_index:
		var old_index := rank_index
		rank_index = new_index
		EventBus.rank_changed.emit(rank_index, old_index)


# --- Base ---

func damage_base(amount: int) -> void:
	if amount <= 0:
		return
	base_health = maxi(0, base_health - amount)
	EventBus.base_health_changed.emit(base_health, MAX_BASE_HEALTH)


func repair_base(amount: int) -> void:
	if amount <= 0:
		return
	base_health = mini(MAX_BASE_HEALTH, base_health + amount)
	EventBus.base_health_changed.emit(base_health, MAX_BASE_HEALTH)


func repair_core(amount: int) -> void:
	if amount <= 0:
		return
	core_integrity = mini(MAX_CORE_INTEGRITY, core_integrity + amount)
	EventBus.core_integrity_changed.emit(core_integrity, MAX_CORE_INTEGRITY)


## Full health for the base and core, and no mission running.
func reset_base() -> void:
	base_health = MAX_BASE_HEALTH
	core_integrity = MAX_CORE_INTEGRITY
	mission_state = MissionState.NONE
	current_mission_id = ""
	EventBus.base_health_changed.emit(base_health, MAX_BASE_HEALTH)
	EventBus.core_integrity_changed.emit(core_integrity, MAX_CORE_INTEGRITY)


func damage_core(amount: int) -> void:
	if amount <= 0:
		return
	core_integrity = maxi(0, core_integrity - amount)
	EventBus.core_integrity_changed.emit(core_integrity, MAX_CORE_INTEGRITY)
	if core_integrity == 0:
		EventBus.core_destroyed.emit()


## Starts an attack on the base. If a mission is running, the player must choose
## between defending and continuing (handled in a later stage).
func trigger_base_attack(strength: int) -> void:
	if mission_state == MissionState.ACTIVE:
		mission_state = MissionState.BASE_UNDER_ATTACK
	EventBus.base_attacked.emit(strength)


## What would happen if the player carried on with the mission while the base
## is attacked by `strength` enemies. Changes nothing.
func preview_unattended_attack(strength: int) -> Dictionary:
	var turrets: int = usable_turrets()
	var defended := turrets * DEFENDED_PER_TURRET
	var leaked := maxi(0, strength - defended)
	var raw_damage := leaked * DAMAGE_PER_LEAKED
	var base_damage := mini(base_health, raw_damage)
	return {
		"turrets": turrets,
		"defended": mini(defended, strength),
		"leaked": leaked,
		"base_damage": base_damage,
		"core_damage": raw_damage - base_damage,
		"points_lost": PENALTY_BASE + leaked * PENALTY_PER_LEAKED,
	}


## The player carries on with the mission. The base fends for itself and the
## player pays the rank penalty. Returns the same dictionary as the preview.
func resolve_unattended_attack(strength: int) -> Dictionary:
	var result := preview_unattended_attack(strength)
	damage_base(result["base_damage"])
	damage_core(result["core_damage"])
	remove_points(result["points_lost"])
	if mission_state == MissionState.BASE_UNDER_ATTACK:
		mission_state = MissionState.ACTIVE
	EventBus.base_attack_resolved.emit("continue")
	return result


# --- Repairs ---

func repair_cost() -> int:
	var base_missing := MAX_BASE_HEALTH - base_health
	var core_missing := MAX_CORE_INTEGRITY - core_integrity
	return ceili(base_missing / BASE_REPAIR_HP_PER_QUBIT) + ceili(core_missing / CORE_REPAIR_HP_PER_QUBIT)


## Pays for a full repair of the base and core. False if it cannot be afforded.
func repair_all() -> bool:
	var cost := repair_cost()
	if cost == 0 or not spend_qubits(cost):
		return false
	repair_base(MAX_BASE_HEALTH)
	repair_core(MAX_CORE_INTEGRITY)
	return true


# --- Missions ---

func start_mission(mission_id: String) -> void:
	current_mission_id = mission_id
	mission_state = MissionState.ACTIVE
	EventBus.mission_started.emit(mission_id)


func end_mission(success: bool) -> void:
	var finished_id := current_mission_id
	mission_state = MissionState.COMPLETE if success else MissionState.FAILED
	current_mission_id = ""
	EventBus.mission_completed.emit(finished_id, success)


func abandon_mission() -> void:
	var abandoned_id := current_mission_id
	mission_state = MissionState.ABANDONED
	current_mission_id = ""
	EventBus.mission_abandoned.emit(abandoned_id)


# --- Inventory ---

func has_item(item_id: String) -> bool:
	return inventory.get(item_id, 0) > 0


func add_item(item_id: String, count: int = 1) -> void:
	if count <= 0:
		return
	inventory[item_id] = inventory.get(item_id, 0) + count


## Returns false if the player does not have enough of the item.
func remove_item(item_id: String, count: int = 1) -> bool:
	if count <= 0 or inventory.get(item_id, 0) < count:
		return false
	inventory[item_id] -= count
	if inventory[item_id] == 0:
		inventory.erase(item_id)
	return true


# --- Colonies ---

func mark_colony_fallen(colony_id: String) -> void:
	if colony_id in fallen_colonies:
		return
	fallen_colonies.append(colony_id)
	EventBus.colony_fell.emit(colony_id)


func mark_colony_retaken(colony_id: String) -> void:
	if colony_id not in fallen_colonies:
		return
	fallen_colonies.erase(colony_id)
	EventBus.colony_retaken.emit(colony_id)


# --- Save / load ---

func save_game() -> void:
	var data := {
		"qubits": qubits,
		"points": points,
		"base_health": base_health,
		"core_integrity": core_integrity,
		"inventory": inventory,
		"fallen_colonies": fallen_colonies,
		"has_seen_intro": has_seen_intro,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data))


## Returns true if a save was found and loaded.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	qubits = int(data.get("qubits", STARTING_QUBITS))
	points = int(data.get("points", 0))
	base_health = int(data.get("base_health", MAX_BASE_HEALTH))
	core_integrity = int(data.get("core_integrity", MAX_CORE_INTEGRITY))
	has_seen_intro = bool(data.get("has_seen_intro", false))
	inventory = {}
	var saved_inventory: Variant = data.get("inventory", {})
	if typeof(saved_inventory) == TYPE_DICTIONARY:
		for key in saved_inventory:
			inventory[str(key)] = int(saved_inventory[key])
	fallen_colonies.clear()
	var saved_fallen: Variant = data.get("fallen_colonies", [])
	if typeof(saved_fallen) == TYPE_ARRAY:
		for colony in saved_fallen:
			fallen_colonies.append(str(colony))
	rank_index = 0
	_update_rank()
	_emit_all()
	return true


func _emit_all() -> void:
	EventBus.qubits_changed.emit(qubits)
	EventBus.points_changed.emit(points)
	EventBus.base_health_changed.emit(base_health, MAX_BASE_HEALTH)
	EventBus.core_integrity_changed.emit(core_integrity, MAX_CORE_INTEGRITY)
