extends Node
## Spawns scouts in waves around the edge of the map.
## Wave n has 4 + 2 * (n - 1) aliens, at most 8 alive at once.
## Waves 1 and 2 are all scouts. Soldiers join from wave 3 (15% more each wave, up to
## 60%), flyers from wave 4 (up to 30%), heavies from wave 5 (up to 25%).
## Short break between waves. Waves keep coming until the core falls.

const ScoutScript := preload("res://scenes/enemies/scout.gd")
const SoldierScript := preload("res://scenes/enemies/soldier.gd")
const HeavyScript := preload("res://scenes/enemies/heavy.gd")
const FlyerScript := preload("res://scenes/enemies/flyer.gd")

const FIRST_WAVE_DELAY := 4.0
const INTERMISSION := 8.0
const BASE_COUNT := 4
const COUNT_STEP := 2
const MAX_ALIVE := 8
const SPAWN_INTERVAL := 1.2
const SPAWN_RADIUS := 42.0

## Where spawned enemies are added. Set before adding this node to the tree.
var enemy_parent: Node
var wave := 0
var running := true
## Run one wave only, then stop. Used for base attacks during missions.
var single_wave := false
## If above 0, every wave has this many enemies.
var wave_size_override := 0

var _active := false
var _to_spawn := 0
var _spawn_timer := 0.0
var _countdown := FIRST_WAVE_DELAY


func _process(delta: float) -> void:
	if not running:
		return
	var alive := get_tree().get_nodes_in_group("enemies").size()

	if not _active:
		_countdown -= delta
		if _countdown <= 0.0:
			_start_wave()
		return

	if _to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and alive < MAX_ALIVE:
			_spawn_enemy()
			_spawn_timer = SPAWN_INTERVAL
	elif alive == 0:
		_active = false
		_countdown = INTERMISSION
		if single_wave:
			running = false
		EventBus.wave_cleared.emit(wave)


func is_active() -> bool:
	return _active


func seconds_to_next_wave() -> float:
	return maxf(0.0, _countdown)


## Enemies still to spawn plus enemies alive.
func enemies_left() -> int:
	return _to_spawn + get_tree().get_nodes_in_group("enemies").size()


func _start_wave() -> void:
	wave += 1
	_active = true
	_to_spawn = wave_size_override if wave_size_override > 0 else BASE_COUNT + COUNT_STEP * (wave - 1)
	_spawn_timer = 0.0
	EventBus.wave_started.emit(wave)


func _make_enemy() -> CharacterBody3D:
	var flyer_chance := clampf((wave - 3) * 0.1, 0.0, 0.3)
	var heavy_chance := clampf((wave - 4) * 0.08, 0.0, 0.25)
	var soldier_chance := clampf((wave - 2) * 0.15, 0.0, 0.6)
	if randf() < flyer_chance:
		return FlyerScript.new()
	if randf() < heavy_chance:
		return HeavyScript.new()
	if randf() < soldier_chance:
		return SoldierScript.new()
	return ScoutScript.new()


func _spawn_enemy() -> void:
	var scout: CharacterBody3D = _make_enemy()
	var angle := randf() * TAU
	scout.position = Vector3(cos(angle) * SPAWN_RADIUS, 0.2, sin(angle) * SPAWN_RADIUS)
	enemy_parent.add_child(scout)
	_to_spawn -= 1
