extends Node3D
## Defend the lighthouse. Waves of scouts attack the base. The player and
## the turrets hold them off. If the power core is destroyed, it is game over.

const PlayerScene := preload("res://scenes/player/player.tscn")
const HudScript := preload("res://scenes/ui/game_hud.gd")
const BaseScript := preload("res://scenes/base/lighthouse_base.gd")
const TurretScript := preload("res://scenes/base/turret.gd")
const ComradeScript := preload("res://scenes/base/comrade.gd")
const JetScript := preload("res://scenes/vehicles/fighter_jet.gd")
const Fx := preload("res://scripts/fx.gd")
const WaveScript := preload("res://scenes/base/wave_manager.gd")

const MAIN_SCENE := "res://scenes/levels/main.tscn"
const SELECT_SCENE := "res://scenes/missions/mission_select.tscn"
const PLAYER_START := Vector3(0, 1, 11)
const TURRET_SPOTS: Array[Vector3] = [
	Vector3(7, 0, 6), Vector3(-7, 0, 6), Vector3(7, 0, -6), Vector3(-7, 0, -6),
]
## The hangar and its launch pad. The jet is boarded from the pad.
const HANGAR_POS := Vector3(16, 0, 17)
const PAD_POS := Vector3(16, 0, 9)
const BOARD_DISTANCE := 6.0
const LAND_DISTANCE := 14.0
const LAND_ALTITUDE := 14.0
## Base health restored when a wave is cleared (endless mode only).
const WAVE_REPAIR := 150

var _hud = null
var _player = null
var _waves = null
var _jet = null
var _flying := false
var _prompt_shown := false
## True when the player chose to defend the base during a mission.
var _attack_mode := false
var _attack_strength := 0
## "gameover", "fell" or "repelled"
var _panel_mode := ""


func _ready() -> void:
	_attack_mode = not GameManager.pending_attack.is_empty()
	if _attack_mode:
		_attack_strength = int(GameManager.pending_attack["strength"])
	else:
		GameManager.reset_base()
	_build_environment()
	_build_ground()

	add_child(BaseScript.new())
	_build_turrets()
	_build_comrades()
	_build_hangar()

	_hud = HudScript.new()
	add_child(_hud)
	_spawn_player()
	_hud.action_pressed.connect(_on_action_pressed)

	_waves = WaveScript.new()
	_waves.enemy_parent = self
	if _attack_mode:
		_waves.single_wave = true
		_waves.wave_size_override = _attack_strength
	add_child(_waves)

	_hud.back_pressed.connect(_go_back)
	_hud.panel_choice.connect(_on_panel_choice)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.core_destroyed.connect(_on_core_destroyed)
	_hud.show_banner("The lighthouse is under attack!" if _attack_mode else "Defend the lighthouse", 3.0)


func _process(_delta: float) -> void:
	var wave_line := ""
	if _attack_mode:
		wave_line = "Attackers left: %d" % _waves.enemies_left()
	elif _waves.is_active():
		wave_line = "Wave %d   |   %d left" % [_waves.wave, _waves.enemies_left()]
	else:
		wave_line = "Next wave in %d" % ceili(_waves.seconds_to_next_wave())
	if _flying:
		wave_line += "\nJET   altitude %d   (land at the pad)" % int(_jet.altitude())
	_hud.set_status("Base %d/%d   Core %d/%d\n%s" % [
		GameManager.base_health, GameManager.MAX_BASE_HEALTH,
		GameManager.core_integrity, GameManager.MAX_CORE_INTEGRITY,
		wave_line,
	])
	_update_jet_prompt()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.5, 0.75)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50.0, 40.0, 0.0)
	moon.light_energy = 0.6
	moon.light_color = Color(0.7, 0.8, 1.0)
	add_child(moon)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.position = Vector3(0, -0.5, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	shape.shape = box
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(100, 1, 100)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.13, 0.22)
	box_mesh.material = material
	mesh.mesh = box_mesh
	ground.add_child(mesh)
	add_child(ground)

	# Invisible walls so nobody walks off the map.
	_add_wall(Vector3(0, 2, -50.5), Vector3(101, 4, 1))
	_add_wall(Vector3(0, 2, 50.5), Vector3(101, 4, 1))
	_add_wall(Vector3(-50.5, 2, 0), Vector3(1, 4, 101))
	_add_wall(Vector3(50.5, 2, 0), Vector3(1, 4, 101))


func _add_wall(pos: Vector3, wall_size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = wall_size
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)


func _build_turrets() -> void:
	var owned: int = GameManager.usable_turrets()
	for i in mini(owned, TURRET_SPOTS.size()):
		var turret: StaticBody3D = TurretScript.new()
		turret.position = TURRET_SPOTS[i]
		add_child(turret)


## The player's comrades, stationed in a ring around the lighthouse.
func _build_comrades() -> void:
	var count: int = GameManager.usable_comrades()
	for i in count:
		var angle := TAU * float(i) / maxf(1.0, float(count)) + 0.4
		var comrade: CharacterBody3D = ComradeScript.new()
		comrade.post = Vector3(cos(angle) * 5.5, 0.0, sin(angle) * 5.5)
		comrade.position = comrade.post + Vector3(0.0, 0.1, 0.0)
		add_child(comrade)


# --- Hangar and jet ---

func _build_hangar() -> void:
	var wall := StaticBody3D.new()
	wall.position = HANGAR_POS + Vector3(0.0, 2.0, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(9.0, 4.0, 6.0)
	shape.shape = box
	wall.add_child(shape)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.14, 0.2, 0.3)
	material.metallic = 0.6
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(9.0, 4.0, 6.0)
	box_mesh.material = material
	mesh.mesh = box_mesh
	wall.add_child(mesh)
	var sign_light := MeshInstance3D.new()
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(5.0, 0.3, 0.1)
	sign_mesh.material = Fx.glow_material(Color(0.3, 0.88, 1.0))
	sign_light.mesh = sign_mesh
	sign_light.position = Vector3(0.0, 1.2, -3.06)
	wall.add_child(sign_light)
	add_child(wall)

	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 3.0
	pad_mesh.bottom_radius = 3.0
	pad_mesh.height = 0.1
	pad_mesh.material = Fx.glow_material(Color(0.3, 0.88, 1.0).darkened(0.55))
	pad.mesh = pad_mesh
	pad.position = PAD_POS + Vector3(0.0, 0.05, 0.0)
	add_child(pad)

	if GameManager.can_use("fighter_jet"):
		_jet = JetScript.new()
		add_child(_jet)
		_jet.park(PAD_POS)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _update_jet_prompt() -> void:
	if _jet == null:
		return
	var text := ""
	if _flying:
		if _flat_distance(_jet.global_position, PAD_POS) <= LAND_DISTANCE and _jet.altitude() <= LAND_ALTITUDE:
			text = "Land the jet [E]"
	elif _flat_distance(_player.global_position, PAD_POS) <= BOARD_DISTANCE:
		text = "Board the jet [E]"
	if text != "":
		_hud.show_action(text)
	else:
		_hud.hide_action()
	_prompt_shown = text != ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and _prompt_shown:
		_on_action_pressed()


func _on_action_pressed() -> void:
	if _jet == null or not _prompt_shown:
		return
	if _flying:
		_land()
	else:
		_board()


## The player steps into the jet. Aliens stop seeing the player while the jet is up.
func _board() -> void:
	_flying = true
	_player.remove_from_group("player")
	_player.visible = false
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_jet.touch = _hud.touch
	_jet.take_off(PAD_POS)
	_hud.hide_action()
	_hud.show_banner("Airborne", 1.5)


func _land() -> void:
	_flying = false
	_jet.park(PAD_POS)
	_player.global_position = PAD_POS + Vector3(-4.5, 0.1, 0.0)
	_player.velocity = Vector3.ZERO
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_player.visible = true
	_player.add_to_group("player")
	_player.camera.make_current()
	_hud.hide_action()
	_hud.show_banner("Landed", 1.5)


func _spawn_player() -> void:
	_player = PlayerScene.instantiate()
	_player.position = PLAYER_START
	_player.touch = _hud.touch
	add_child(_player)
	_hud.bind_player(_player)
	_player.died.connect(_on_player_died)


func _on_player_died() -> void:
	_player.global_position = PLAYER_START
	_player.reset()
	_hud.show_banner("You were downed. Back in the fight.", 2.0)


func _on_wave_started(wave: int) -> void:
	if not _attack_mode:
		_hud.show_banner("Wave %d" % wave, 2.0)


func _on_wave_cleared(wave: int) -> void:
	if _attack_mode:
		_on_attack_repelled()
		return
	GameManager.repair_base(WAVE_REPAIR)
	_hud.show_banner("Wave %d cleared. Base repaired." % wave, 2.5)


func _on_attack_repelled() -> void:
	var points := GameManager.DEFEND_POINTS_BASE + _attack_strength * 2
	GameManager.add_points(points)
	GameManager.pending_attack = {}
	GameManager.save_game()
	_panel_mode = "repelled"
	get_tree().paused = true
	_hud.show_panel("ATTACK REPELLED\n+%d points\nBase %d/%d" % [points, GameManager.base_health, GameManager.MAX_BASE_HEALTH],
		["Back to missions", "Main menu"])


func _on_core_destroyed() -> void:
	_waves.running = false
	get_tree().paused = true
	if _attack_mode:
		_panel_mode = "fell"
		_hud.show_panel("The power core has been destroyed.", ["Rebuild the lighthouse", "Main menu"])
	else:
		_panel_mode = "gameover"
		var survived := maxi(0, _waves.wave - 1)
		_hud.show_panel("The power core has been destroyed.\nWaves survived: %d" % survived, ["Try again", "Back to menu"])


func _on_panel_choice(index: int) -> void:
	get_tree().paused = false
	match _panel_mode:
		"gameover":
			if index == 0:
				get_tree().reload_current_scene()
			else:
				get_tree().change_scene_to_file(MAIN_SCENE)
		"fell":
			GameManager.reset_base()
			GameManager.pending_attack = {}
			GameManager.save_game()
			get_tree().change_scene_to_file(SELECT_SCENE if index == 0 else MAIN_SCENE)
		"repelled":
			get_tree().change_scene_to_file(SELECT_SCENE if index == 0 else MAIN_SCENE)


func _go_back() -> void:
	get_tree().paused = false
	if _attack_mode:
		GameManager.pending_attack = {}
		get_tree().change_scene_to_file(SELECT_SCENE)
	else:
		get_tree().change_scene_to_file(MAIN_SCENE)
