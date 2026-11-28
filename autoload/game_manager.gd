extends Node
## Central game state (autoload: GameManager).
## Tracks qubits, points and rank, base health, mission state and inventory.
## Other scenes read from here and listen to EventBus for changes.

const ItemData := preload("res://data/item_data.gd")
const ColonyData := preload("res://data/colony_data.gd")

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
## Each comrade left at the base stops this many attackers while the player is away.
const DEFENDED_PER_COMRADE := 2
## Comrades the lighthouse can station: this plus one per rank.
const BASE_COMRADE_SLOTS := 2
const DAMAGE_PER_LEAKED := 60
## Turrets the lighthouse can run at once: this plus one per rank.
const BASE_TURRET_SLOTS := 1
## Market. Selling returns this share of the price. Fallen colonies pay less and charge less.
const SELL_SHARE := 0.5
const FALLEN_SELL_FACTOR := 0.7
const FALLEN_BUY_FACTOR := 0.8
const MAX_TRADE_ORDERS := 6
## Raw goods prices move by up to this much each roll, within 50% to 150% of base.
const PRICE_SWING := 0.15
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
	"comrade": 2,
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
## Current prices of raw goods: item_id -> qubits.
var raw_prices: Dictionary = {}
## Automated trades: item_id -> {"mode": "buy" or "sell", "colony": colony_id}.
## One unit of each is traded per trade cycle (after every mission).
var trade_orders: Dictionary = {}
var last_trade_log: Array[String] = []


func _ready() -> void:
	new_game()
	load_game()
	EventBus.mission_completed.connect(func(_id, _ok): run_trade_cycle())


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
	trade_orders = {}
	last_trade_log.clear()
	_reset_prices()
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


## Comrades stationed at the lighthouse: owned, capped by rank.
func usable_comrades() -> int:
	return mini(inventory.get("comrade", 0), max_comrades())


func max_comrades() -> int:
	return BASE_COMRADE_SLOTS + rank_index


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
	var comrades: int = usable_comrades()
	var defended := turrets * DEFENDED_PER_TURRET + comrades * DEFENDED_PER_COMRADE
	var leaked := maxi(0, strength - defended)
	var raw_damage := leaked * DAMAGE_PER_LEAKED
	var base_damage := mini(base_health, raw_damage)
	return {
		"turrets": turrets,
		"comrades": comrades,
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


# --- Market ---

func _reset_prices() -> void:
	raw_prices = {}
	for id in ItemData.ITEMS:
		if ItemData.is_raw(id):
			raw_prices[id] = ItemData.base_price(id)


func current_price(item_id: String) -> int:
	if ItemData.is_raw(item_id):
		return int(raw_prices.get(item_id, ItemData.base_price(item_id)))
	return ItemData.base_price(item_id)


## Nudges every raw good price up or down.
func roll_prices() -> void:
	for id in raw_prices:
		var base := ItemData.base_price(id)
		var moved := roundi(raw_prices[id] * randf_range(1.0 - PRICE_SWING, 1.0 + PRICE_SWING))
		raw_prices[id] = clampi(moved, roundi(base * 0.5), roundi(base * 1.5))


func buy_price(item_id: String, colony_id: String) -> int:
	var factor := FALLEN_BUY_FACTOR if colony_id in fallen_colonies else 1.0
	return maxi(1, roundi(current_price(item_id) * factor))


func sell_price(item_id: String, colony_id: String) -> int:
	var factor := FALLEN_SELL_FACTOR if colony_id in fallen_colonies else 1.0
	return maxi(1, roundi(current_price(item_id) * SELL_SHARE * factor))


## False if unknown item or not enough qubits.
func buy_item(item_id: String, colony_id: String) -> bool:
	if not ItemData.exists(item_id):
		return false
	var price := buy_price(item_id, colony_id)
	if not spend_qubits(price):
		return false
	add_item(item_id)
	EventBus.item_purchased.emit(item_id, price)
	return true


## False if the player does not own the item.
func sell_item(item_id: String, colony_id: String) -> bool:
	if not ItemData.exists(item_id) or not has_item(item_id):
		return false
	var price := sell_price(item_id, colony_id)
	remove_item(item_id)
	add_qubits(price)
	EventBus.item_sold.emit(item_id, price)
	return true


## Sets, changes or (mode "") removes an automated trade. False if the order list is full.
func set_trade_order(item_id: String, mode: String, colony_id: String) -> bool:
	if mode == "":
		trade_orders.erase(item_id)
		return true
	if not trade_orders.has(item_id) and trade_orders.size() >= MAX_TRADE_ORDERS:
		return false
	trade_orders[item_id] = {"mode": mode, "colony": colony_id}
	return true


## Runs every automated trade once and moves raw prices. Called after each mission.
func run_trade_cycle() -> void:
	last_trade_log.clear()
	for id in trade_orders:
		var order: Dictionary = trade_orders[id]
		var colony_name := ColonyData.colony_name(order["colony"])
		var item_name := ItemData.item_name(id)
		if order["mode"] == "buy":
			var price := buy_price(id, order["colony"])
			if buy_item(id, order["colony"]):
				last_trade_log.append("Bought %s from %s for %d" % [item_name, colony_name, price])
			else:
				last_trade_log.append("Could not buy %s (not enough qubits)" % item_name)
		else:
			var price := sell_price(id, order["colony"])
			if sell_item(id, order["colony"]):
				last_trade_log.append("Sold %s to %s for %d" % [item_name, colony_name, price])
			else:
				last_trade_log.append("Could not sell %s (none owned)" % item_name)
	roll_prices()


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
		"raw_prices": raw_prices,
		"trade_orders": trade_orders,
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
	_reset_prices()
	var saved_prices: Variant = data.get("raw_prices", {})
	if typeof(saved_prices) == TYPE_DICTIONARY:
		for key in saved_prices:
			if raw_prices.has(str(key)):
				raw_prices[str(key)] = int(saved_prices[key])
	trade_orders = {}
	var saved_orders: Variant = data.get("trade_orders", {})
	if typeof(saved_orders) == TYPE_DICTIONARY:
		for key in saved_orders:
			var order: Variant = saved_orders[key]
			if typeof(order) == TYPE_DICTIONARY and ItemData.exists(str(key)):
				trade_orders[str(key)] = {"mode": str(order.get("mode", "buy")), "colony": str(order.get("colony", "ashgrove"))}
	rank_index = 0
	_update_rank()
	_emit_all()
	return true


func _emit_all() -> void:
	EventBus.qubits_changed.emit(qubits)
	EventBus.points_changed.emit(points)
	EventBus.base_health_changed.emit(base_health, MAX_BASE_HEALTH)
	EventBus.core_integrity_changed.emit(core_integrity, MAX_CORE_INTEGRITY)
