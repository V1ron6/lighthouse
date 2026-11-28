extends CharacterBody3D
## Scout: small, fast, weak. Bio-mechanical: mostly flesh with a metal implant
## and a glowing eye. Chases the player in a weaving line and bites on contact.
## Goes for the lighthouse, but turns on the player if the player gets close.
## With no lighthouse in the level (the test arena) it just hunts the player.
## Steering only, no navigation mesh: it slides along walls and cover.

signal died

const MAX_HEALTH := 40
const SPEED := 7.0
const ATTACK_RANGE := 1.8
const ATTACK_DAMAGE := 10
const ATTACK_INTERVAL := 0.8
const TURN_SPEED := 10.0
## Distance at which a scout switches from the lighthouse to the player.
const AGGRO_RANGE := 12.0

const FLESH_COLOR := Color(0.75, 0.35, 0.4)
const METAL_COLOR := Color(0.45, 0.5, 0.58)
const EYE_COLOR := Color(1.0, 0.65, 0.2)

var health := MAX_HEALTH
var target: Node3D = null

var _player: Node3D = null
var _base: Node3D = null
var _wall_normal := Vector3.ZERO
var _side := 1.0 if randf() < 0.5 else -1.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _attack_cooldown := 0.0
var _weave_phase := randf() * TAU
var _dead := false
var _shape: CollisionShape3D
var _body_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("enemies")

	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.0
	capsule.radius = 0.4
	_shape.shape = capsule
	_shape.position = Vector3(0.0, 0.5, 0.0)
	add_child(_shape)

	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = FLESH_COLOR
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 0.8
	body_mesh.material = _body_material
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.5, 0.0)
	add_child(body)

	var metal_material := StandardMaterial3D.new()
	metal_material.albedo_color = METAL_COLOR
	metal_material.metallic = 0.8
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.5, 0.12, 0.35)
	plate_mesh.material = metal_material
	plate.mesh = plate_mesh
	plate.position = Vector3(0.0, 0.85, 0.05)
	add_child(plate)

	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = EYE_COLOR
	eye_material.emission_enabled = true
	eye_material.emission = EYE_COLOR
	eye_material.emission_energy_multiplier = 1.5
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.1
	eye_mesh.height = 0.2
	eye_mesh.material = eye_material
	eye.mesh = eye_mesh
	eye.position = Vector3(0.0, 0.55, -0.34)
	add_child(eye)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_pick_target()
	if target == null:
		return

	var reach_offset := 0.0
	if target.has_method("get_attack_radius"):
		reach_offset = target.get_attack_radius()

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	var edge_distance := distance - reach_offset
	var direction := to_target / distance if distance > 0.01 else Vector3.ZERO

	# Weave from side to side while far away, so a group does not move as one line.
	var side := Vector3(-direction.z, 0.0, direction.x)
	var weave := sin(Time.get_ticks_msec() * 0.004 + _weave_phase) * 0.35 * clampf(edge_distance / 10.0, 0.0, 1.0)
	var move_direction := (direction + side * weave).normalized()

	# If last frame ran into something, go along it instead of pushing into it.
	if _wall_normal != Vector3.ZERO:
		var slid := move_direction.slide(_wall_normal)
		if slid.length() < 0.3:
			slid = Vector3(-_wall_normal.z, 0.0, _wall_normal.x) * _side
		move_direction = slid.normalized()

	if edge_distance > ATTACK_RANGE * 0.8:
		velocity.x = move_direction.x * SPEED
		velocity.z = move_direction.z * SPEED
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	if distance > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)

	move_and_slide()

	_wall_normal = Vector3.ZERO
	if is_on_wall():
		var normal := get_wall_normal()
		normal.y = 0.0
		if normal.length() > 0.01:
			_wall_normal = normal.normalized()

	_attack_cooldown -= delta
	if edge_distance <= ATTACK_RANGE and _attack_cooldown <= 0.0 and target.has_method("take_damage"):
		target.take_damage(ATTACK_DAMAGE)
		_attack_cooldown = ATTACK_INTERVAL


## The player if close (or if there is no lighthouse), otherwise the lighthouse.
func _pick_target() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _base == null or not is_instance_valid(_base):
		_base = get_tree().get_first_node_in_group("base") as Node3D

	if _base == null:
		target = _player
		return
	if _player != null:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() <= AGGRO_RANGE:
			target = _player
			return
	var ally := _nearest_ally(5.0)
	target = ally if ally != null else _base


## A comrade close by that is worth biting on the way to the lighthouse.
func _nearest_ally(max_distance: float) -> Node3D:
	var best: Node3D = null
	var best_distance := max_distance
	for node in get_tree().get_nodes_in_group("allies"):
		var ally := node as Node3D
		if ally == null:
			continue
		var distance := ally.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = ally
	return best


func take_hit(damage: int) -> void:
	if _dead:
		return
	health -= damage
	_body_material.albedo_color = Color.WHITE
	get_tree().create_timer(0.08).timeout.connect(_restore_color)
	if health <= 0:
		_die()


func _restore_color() -> void:
	if not _dead:
		_body_material.albedo_color = FLESH_COLOR


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	_shape.set_deferred("disabled", true)
	died.emit()
	EventBus.enemy_killed.emit("scout")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(queue_free)
