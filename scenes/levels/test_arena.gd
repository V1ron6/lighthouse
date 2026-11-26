extends Node3D
## Test arena: a flat floor, walls, some cover, practice targets, the player,
## the on-screen touch controls and a timed spawner of scouts.
## Everything is built in code.

const PlayerScene := preload("res://scenes/player/player.tscn")
const TouchScene := preload("res://scenes/ui/touch_controls.tscn")
const TargetScript := preload("res://scenes/levels/target.gd")
const ScoutScript := preload("res://scenes/enemies/scout.gd")

const MAX_SCOUTS := 6
const SPAWN_INTERVAL := 2.5
const PLAYER_START := Vector3(0, 1, 14)

var _hud_label: Label
var _heat_bar: ProgressBar
var _damage_flash: ColorRect
var _touch: Control
var _player = null
var _kills := 0
var _last_health := 100


func _ready() -> void:
	_build_environment()
	_build_arena()
	_build_targets()
	_build_ui()
	_spawn_player()
	_build_spawner()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.5, 0.75)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.light_energy = 1.0
	add_child(sun)


func _build_arena() -> void:
	var floor_color := Color(0.08, 0.13, 0.22)
	var wall_color := Color(0.12, 0.2, 0.34)
	_add_box(Vector3(0, -0.5, 0), Vector3(60, 1, 60), floor_color)
	_add_box(Vector3(0, 2, -30.5), Vector3(61, 4, 1), wall_color)
	_add_box(Vector3(0, 2, 30.5), Vector3(61, 4, 1), wall_color)
	_add_box(Vector3(-30.5, 2, 0), Vector3(1, 4, 61), wall_color)
	_add_box(Vector3(30.5, 2, 0), Vector3(1, 4, 61), wall_color)

	var cover_color := Color(0.3, 0.88, 1.0)
	_add_box(Vector3(-8, 0.75, 4), Vector3(4, 1.5, 1), cover_color, true)
	_add_box(Vector3(8, 0.75, 2), Vector3(4, 1.5, 1), cover_color, true)
	_add_box(Vector3(0, 1.0, -2), Vector3(1.5, 2, 1.5), cover_color, true)


func _build_targets() -> void:
	for i in 5:
		var target: StaticBody3D = TargetScript.new()
		target.position = Vector3(-12.0 + i * 6.0, 1.0, -10.0 - (i % 2) * 8.0)
		add_child(target)


func _spawn_player() -> void:
	_player = PlayerScene.instantiate()
	_player.position = PLAYER_START
	_player.touch = _touch
	add_child(_player)
	_player.health_changed.connect(_on_player_health_changed)
	_player.died.connect(_on_player_died)
	_player.rifle.heat_changed.connect(_on_heat_changed)
	_refresh_hud()


func _build_spawner() -> void:
	var timer := Timer.new()
	timer.wait_time = SPAWN_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_spawn_scout)
	add_child(timer)


func _spawn_scout() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= MAX_SCOUTS:
		return
	var scout: CharacterBody3D = ScoutScript.new()
	var angle := randf() * TAU
	scout.position = Vector3(cos(angle) * 26.0, 0.2, sin(angle) * 26.0)
	add_child(scout)


func _on_player_health_changed(current: int, _maximum: int) -> void:
	if current < _last_health:
		_damage_flash.color.a = 0.35
		create_tween().tween_property(_damage_flash, "color:a", 0.0, 0.3)
	_last_health = current
	_refresh_hud()


func _on_player_died() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	_player.global_position = PLAYER_START
	_player.reset()


func _on_heat_changed(heat: float, overheated: bool) -> void:
	_heat_bar.value = heat
	_heat_bar.modulate = Color(1.0, 0.3, 0.3) if overheated else Color(0.3, 0.88, 1.0)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_touch = TouchScene.instantiate()
	layer.add_child(_touch)

	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(1.0, 0.1, 0.1, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_damage_flash)

	_heat_bar = ProgressBar.new()
	_heat_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_heat_bar.offset_left = -150.0
	_heat_bar.offset_right = 150.0
	_heat_bar.offset_top = 24.0
	_heat_bar.offset_bottom = 40.0
	_heat_bar.max_value = 100.0
	_heat_bar.show_percentage = false
	_heat_bar.modulate = Color(0.3, 0.88, 1.0)
	layer.add_child(_heat_bar)

	_hud_label = Label.new()
	_hud_label.position = Vector2(24, 20)
	_hud_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_hud_label)

	var back := Button.new()
	back.text = "Back"
	back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -170.0
	back.offset_right = -20.0
	back.offset_top = 20.0
	back.offset_bottom = 76.0
	back.pressed.connect(_go_back)
	layer.add_child(back)

	if not _touch.visible:
		var hint := Label.new()
		hint.text = "WASD move   |   mouse look (click to capture, Esc to release)   |   left click or Space to fire   |   the rifle overheats"
		hint.position = Vector2(24, 660)
		layer.add_child(hint)

	EventBus.qubits_changed.connect(_refresh_hud)
	EventBus.points_changed.connect(_refresh_hud)
	EventBus.rank_changed.connect(_refresh_hud)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	_refresh_hud()


func _refresh_hud(_a: Variant = null, _b: Variant = null) -> void:
	var health: int = _player.health if _player != null else 100
	_hud_label.text = "%s   |   %d qubits\nHealth %d   Kills %d" % [GameManager.get_rank_name(), GameManager.qubits, health, _kills]


func _on_enemy_killed(_enemy_type: String) -> void:
	_kills += 1
	_refresh_hud()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")


func _add_box(pos: Vector3, box_size: Vector3, color: Color, glow: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box_size
	shape.shape = box_shape
	body.add_child(shape)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.6
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	box_mesh.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box_mesh
	body.add_child(mesh)

	add_child(body)
	return body
