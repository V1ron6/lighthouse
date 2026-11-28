extends Node3D
## A mission away from the base. Types: eliminate, survive, hunt, boss.
## The base may be attacked while you are out. When that happens the game
## pauses and the player must pick: defend the base (mission lost) or carry
## on (the base fends for itself and the player loses rank points).

const PlayerScene := preload("res://scenes/player/player.tscn")
const HudScript := preload("res://scenes/ui/game_hud.gd")
const ScoutScript := preload("res://scenes/enemies/scout.gd")
const SoldierScript := preload("res://scenes/enemies/soldier.gd")
const HeavyScript := preload("res://scenes/enemies/heavy.gd")
const FlyerScript := preload("res://scenes/enemies/flyer.gd")
const MothershipScript := preload("res://scenes/enemies/mothership.gd")
const Builder := preload("res://scripts/level_builder.gd")
const MissionData := preload("res://data/mission_data.gd")

const FIELD_SIZE := 80.0
const SPAWN_DISTANCE := 30.0

var _mission: Dictionary = {}
var _hud = null
var _player = null
var _kills := 0
var _target_kills := 0
var _boss = null
var _elapsed := 0.0
var _attack_time := -1.0
var _attack_pending := false
var _spawn_timer := 0.0
var _ended := false
## "attack", "result" or "fell"
var _panel_mode := ""
var _summary: Dictionary = {}


func _ready() -> void:
	_mission = MissionData.get_mission(GameManager.current_mission_id)
	if _mission.is_empty():
		get_tree().change_scene_to_file("res://scenes/missions/mission_select.tscn")
		return

	Builder.build_environment(self)
	Builder.build_ground(self, FIELD_SIZE)
	_build_cover()

	_hud = HudScript.new()
	add_child(_hud)
	_player = PlayerScene.instantiate()
	_player.position = Vector3(0, 1, 0)
	_player.touch = _hud.touch
	add_child(_player)
	_hud.bind_player(_player)

	_player.died.connect(_on_player_died)
	_hud.back_pressed.connect(_on_back)
	_hud.panel_choice.connect(_on_panel_choice)
	EventBus.enemy_killed.connect(_on_enemy_killed)

	if randf() < float(_mission["attack_chance"]):
		_attack_time = float(_mission["attack_after"]) + randf_range(-5.0, 5.0)
		_attack_pending = true

	if String(_mission["type"]) == "boss":
		_spawn_boss()

	_hud.show_banner(String(_mission["name"]), 2.5)


func _process(delta: float) -> void:
	if _ended or _mission.is_empty():
		return
	_elapsed += delta

	var type := String(_mission["type"])
	var goal := int(_mission["goal"])
	var alive := get_tree().get_nodes_in_group("enemies").size()
	var risk := int(_mission["risk"])
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and type != "boss":
		var cap := 7
		if type == "eliminate":
			cap = 5 + risk * 2
		elif type == "survive":
			cap = 6 + risk * 2
		var wants_more := true
		if type == "eliminate":
			wants_more = _kills + alive < goal
		if alive < cap and wants_more:
			_spawn_timer = maxf(0.8, 2.4 - 0.4 * risk)
			_spawn_enemy()

	if type == "survive" and _elapsed >= float(goal) and not _ended:
		_complete()
		return

	if _attack_pending and _elapsed >= _attack_time:
		_attack_pending = false
		_trigger_attack()

	var objective := ""
	match type:
		"eliminate":
			objective = "Eliminate aliens %d/%d" % [_kills, goal]
		"survive":
			objective = "Survive %d/%d s" % [mini(int(_elapsed), goal), goal]
		"hunt":
			objective = "Hunt %ss %d/%d" % [String(_mission["target"]), _target_kills, goal]
		"boss":
			objective = "Destroy the Mothership"
			if _boss != null and is_instance_valid(_boss):
				objective += "  [%d/%d, phase %d%s]" % [
					maxi(_boss.health, 0), _boss.max_health, _boss.phase_number(),
					", SHIELDED" if _boss.shielded else ""]
	_hud.set_status("%s\nBase %d/%d   Core %d/%d" % [
		objective,
		GameManager.base_health, GameManager.MAX_BASE_HEALTH,
		GameManager.core_integrity, GameManager.MAX_CORE_INTEGRITY,
	])


func _build_cover() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(_mission["id"]))
	for i in 12:
		var pos := Vector3(rng.randf_range(-30, 30), 0.0, rng.randf_range(-30, 30))
		if pos.length() < 6.0:
			continue
		var size := Vector3(rng.randf_range(2, 5), rng.randf_range(1.2, 2.5), rng.randf_range(1, 3))
		pos.y = size.y / 2.0
		Builder.add_box(self, pos, size, Color(0.3, 0.88, 1.0), true)


## Weighted pick from the mission's mix. Non-scouts are held back for the first few kills.
func _pick_enemy() -> CharacterBody3D:
	var mix: Dictionary = _mission["mix"]
	var weights := {}
	for key in ["scout", "soldier", "flyer", "heavy"]:
		weights[key] = float(mix.get(key, 0.0))
	if _kills < 3:
		weights["soldier"] = 0.0
		weights["flyer"] = 0.0
		weights["heavy"] = 0.0
		weights["scout"] = maxf(1.0, weights["scout"])
	var total := 0.0
	for key in weights:
		total += weights[key]
	if total <= 0.0:
		return ScoutScript.new()
	var roll := randf() * total
	for key in ["scout", "soldier", "flyer", "heavy"]:
		roll -= weights[key]
		if roll <= 0.0:
			match key:
				"soldier":
					return SoldierScript.new()
				"flyer":
					return FlyerScript.new()
				"heavy":
					return HeavyScript.new()
				_:
					return ScoutScript.new()
	return ScoutScript.new()


func _spawn_boss() -> void:
	_boss = MothershipScript.new()
	_boss.position = Vector3(0.0, 0.0, -10.0)
	add_child(_boss)


func _spawn_enemy() -> void:
	var scout: CharacterBody3D = _pick_enemy()
	var angle := randf() * TAU
	var spawn: Vector3 = _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * SPAWN_DISTANCE
	var limit := FIELD_SIZE / 2.0 - 2.0
	spawn.x = clampf(spawn.x, -limit, limit)
	spawn.z = clampf(spawn.z, -limit, limit)
	spawn.y = 0.2
	scout.position = spawn
	add_child(scout)


# --- The choice ---

func _trigger_attack() -> void:
	var strength := int(_mission["attack_strength"])
	GameManager.trigger_base_attack(strength)
	var preview := GameManager.preview_unattended_attack(strength)
	var text := "ALERT: the lighthouse is under attack!\nAttackers: %d\n\n" % strength
	text += "Defend the base: this mission is abandoned and its reward (%d qubits, %d points) is lost.\n\n" % [
		int(_mission["reward_qubits"]), int(_mission["reward_points"])]
	text += "Carry on: your %d turrets and %d comrades stop %d attackers. The base takes about %d damage and you lose about %d rank points." % [
		int(preview["turrets"]), int(preview["comrades"]), int(preview["defended"]), int(preview["base_damage"]) + int(preview["core_damage"]), int(preview["points_lost"])]
	_panel_mode = "attack"
	get_tree().paused = true
	_hud.show_panel(text, ["Defend the base", "Carry on with the mission"])


func _on_panel_choice(index: int) -> void:
	get_tree().paused = false
	match _panel_mode:
		"attack":
			if index == 0:
				_defend_base()
			else:
				_carry_on()
		"fell":
			GameManager.reset_base()
			GameManager.save_game()
			get_tree().change_scene_to_file("res://scenes/missions/mission_select.tscn")
		"result":
			if index == 0:
				get_tree().change_scene_to_file("res://scenes/missions/mission_select.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/levels/main.tscn")


func _defend_base() -> void:
	var strength := int(_mission["attack_strength"])
	GameManager.abandon_mission()
	GameManager.pending_attack = {"strength": strength, "mission_id": String(_mission["id"])}
	EventBus.base_attack_resolved.emit("defend")
	get_tree().change_scene_to_file("res://scenes/base/base_defence.tscn")


func _carry_on() -> void:
	_summary = GameManager.resolve_unattended_attack(int(_mission["attack_strength"]))
	if GameManager.core_integrity == 0:
		_ended = true
		_panel_mode = "fell"
		GameManager.end_mission(false)
		get_tree().paused = true
		_hud.show_panel("While you were away the lighthouse fell.\nThe power core was destroyed.", ["Rebuild the lighthouse"])
	else:
		_hud.show_banner("The base is on its own. Finish the job.", 3.0)


# --- Ending the mission ---

func _on_enemy_killed(enemy_type: String) -> void:
	if _ended:
		return
	_kills += 1
	var type := String(_mission["type"])
	var goal := int(_mission["goal"])
	match type:
		"eliminate":
			if _kills >= goal:
				_complete()
		"hunt":
			if enemy_type == String(_mission["target"]):
				_target_kills += 1
				if _target_kills >= goal:
					_complete()
		"boss":
			if enemy_type == "mothership":
				GameManager.broadcast("mothership_down")
				_complete()


func _complete() -> void:
	_ended = true
	GameManager.end_mission(true)
	var qubits := int(_mission["reward_qubits"])
	var points := int(_mission["reward_points"])
	GameManager.add_qubits(qubits)
	GameManager.add_points(points)
	GameManager.save_game()

	var text := "MISSION COMPLETE\n+%d qubits   +%d points" % [qubits, points]
	if not _summary.is_empty():
		text += "\n\nWhile you were away: %d attackers got through, the base lost %d health and the core lost %d. You lost %d rank points." % [
			int(_summary["leaked"]), int(_summary["base_damage"]), int(_summary["core_damage"]), int(_summary["points_lost"])]
	_show_result(text)


func _on_player_died() -> void:
	if _ended:
		return
	_ended = true
	GameManager.end_mission(false)
	GameManager.save_game()
	_show_result("MISSION FAILED\nYou were taken down.")


func _show_result(text: String) -> void:
	_panel_mode = "result"
	get_tree().paused = true
	_hud.show_panel(text, ["Back to missions", "Main menu"])


func _on_back() -> void:
	get_tree().paused = false
	if not _ended:
		GameManager.abandon_mission()
	get_tree().change_scene_to_file("res://scenes/missions/mission_select.tscn")
