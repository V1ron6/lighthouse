extends Node3D
## Stage 2 test arena: a flat floor, walls, some cover, practice targets,
## the player and the on-screen touch controls. Everything is built in code.

const PlayerScene := preload("res://scenes/player/player.tscn")
const TouchScene := preload("res://scenes/ui/touch_controls.tscn")
const TargetScript := preload("res://scenes/levels/target.gd")

var _hud_label: Label
var _touch: Control


func _ready() -> void:
	_build_environment()
	_build_arena()
	_build_targets()
	_build_ui()
	_spawn_player()


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
	var player := PlayerScene.instantiate()
	player.position = Vector3(0, 1, 14)
	player.touch = _touch
	add_child(player)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_touch = TouchScene.instantiate()
	layer.add_child(_touch)

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
		hint.text = "WASD move   |   mouse look (click to capture, Esc to release)   |   left click or Space to fire"
		hint.position = Vector2(24, 660)
		layer.add_child(hint)

	EventBus.qubits_changed.connect(_refresh_hud)
	EventBus.points_changed.connect(_refresh_hud)
	EventBus.rank_changed.connect(_refresh_hud)
	_refresh_hud()


func _refresh_hud(_a: Variant = null, _b: Variant = null) -> void:
	_hud_label.text = "%s   |   %d qubits" % [GameManager.get_rank_name(), GameManager.qubits]


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
