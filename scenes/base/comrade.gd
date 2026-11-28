extends CharacterBody3D
## Comrade: one of the player's own soldiers, stationed at the lighthouse.
## Fights beside the player when the base is attacked. The player goes on missions
## alone, so while away the comrades hold the base (see GameManager.DEFENDED_PER_COMRADE).
##
## Decision loop every 0.3s:
##   GUARD      stand at an assigned post near the lighthouse
##   ENGAGE     pick the best target in range (enemies closest to the base first,
##              weakest first among those), keep distance, strafe, shoot
##   FALL_BACK  below 35% health: take cover on the far side of the lighthouse
##              from the nearest enemy, heal, return at 70%
##   DOWN       out of the fight; back at the post after a delay (never lost for good)

enum State { GUARD, ENGAGE, FALL_BACK, DOWN }

const Fx := preload("res://scripts/fx.gd")

const MAX_HEALTH := 100
const SPEED := 5.5
const TURN_SPEED := 9.0
const FIRE_RANGE := 24.0
const PREFERRED_RANGE := 12.0
const FIRE_INTERVAL := 0.6
const DAMAGE := 12
const ACCURACY := 0.8
const THINK_INTERVAL := 0.3
const LEASH := 15.0
const FALL_BACK_HEALTH := 0.35
const RECOVER_HEALTH := 0.7
const REGEN_PER_SECOND := 5.0
const RESPAWN_TIME := 25.0

const BODY_COLOR := Color(0.25, 0.55, 0.8)
const ARMOUR_COLOR := Color(0.3, 0.88, 1.0)
const BOLT_COLOR := Color(0.4, 0.95, 1.0)

signal downed

## Where this comrade stands when idle. Set by the level before adding to the tree.
var post := Vector3.ZERO
var health := MAX_HEALTH
var state: State = State.GUARD

var _base: Node3D = null
var _target: Node3D = null
var _wall_normal := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _think_timer := randf() * THINK_INTERVAL
var _fire_cooldown := 0.0
var _strafe := 1.0 if randf() < 0.5 else -1.0
var _down_timer := 0.0
var _shape: CollisionShape3D
var _visual: Node3D


func _ready() -> void:
	add_to_group("allies")
	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.4
	_shape.shape = capsule
	_shape.position = Vector3(0.0, 0.9, 0.0)
	add_child(_shape)

	_visual = Node3D.new()
	add_child(_visual)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = BODY_COLOR
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.8
	body_mesh.material = body_material
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.9, 0.0)
	_visual.add_child(body)

	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.5, 0.14, 0.12)
	visor_mesh.material = Fx.glow_material(ARMOUR_COLOR)
	visor.mesh = visor_mesh
	visor.position = Vector3(0.0, 1.5, -0.34)
	_visual.add_child(visor)

	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.7, 0.5, 0.2)
	plate_mesh.material = Fx.glow_material(ARMOUR_COLOR.darkened(0.5))
	plate.mesh = plate_mesh
	plate.position = Vector3(0.0, 1.1, -0.28)
	_visual.add_child(plate)


func _physics_process(delta: float) -> void:
	if state == State.DOWN:
		_down_timer -= delta
		if _down_timer <= 0.0:
			_stand_up()
		return

	_fire_cooldown -= delta
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_think()

	var move_direction := Vector3.ZERO
	var face := Vector3.ZERO
	var speed := SPEED
	match state:
		State.GUARD:
			move_direction = _toward(post, 1.0)
		State.ENGAGE:
			if _target != null and is_instance_valid(_target):
				var to_target := _target.global_position - global_position
				to_target.y = 0.0
				var distance := to_target.length()
				face = to_target.normalized()
				var side := Vector3(-face.z, 0.0, face.x)
				if distance < PREFERRED_RANGE - 4.0:
					move_direction = -face
				elif distance > PREFERRED_RANGE + 4.0 and _within_leash(face):
					move_direction = face
				else:
					move_direction = side * _strafe
					speed *= 0.5
		State.FALL_BACK:
			move_direction = _toward(_cover_point(), 1.0)
			health = mini(MAX_HEALTH, health + int(REGEN_PER_SECOND * delta + randf()))

	if _wall_normal != Vector3.ZERO and move_direction != Vector3.ZERO:
		var slid := move_direction.slide(_wall_normal)
		if slid.length() < 0.3:
			slid = Vector3(-_wall_normal.z, 0.0, _wall_normal.x) * _strafe
		move_direction = slid.normalized()

	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	var look := face if face != Vector3.ZERO else move_direction
	if look != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), TURN_SPEED * delta)

	move_and_slide()
	_wall_normal = Vector3.ZERO
	if is_on_wall():
		var normal := get_wall_normal()
		normal.y = 0.0
		if normal.length() > 0.01:
			_wall_normal = normal.normalized()

	if state == State.ENGAGE or state == State.FALL_BACK:
		_try_fire()


# --- Thinking ---

func _think() -> void:
	if _base == null or not is_instance_valid(_base):
		_base = get_tree().get_first_node_in_group("base") as Node3D
	if randf() < 0.3:
		_strafe = -_strafe

	var hp := float(health) / MAX_HEALTH
	_target = _best_target()
	match state:
		State.GUARD:
			if hp < FALL_BACK_HEALTH:
				state = State.FALL_BACK
			elif _target != null:
				state = State.ENGAGE
		State.ENGAGE:
			if hp < FALL_BACK_HEALTH:
				state = State.FALL_BACK
			elif _target == null:
				state = State.GUARD
		State.FALL_BACK:
			if hp >= RECOVER_HEALTH:
				state = State.GUARD


## Enemies near the lighthouse come first (they are hurting the base), and the
## weakest of those first, so kills happen fast. Needs a clear line of fire.
func _best_target() -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var base_pos := _base.global_position if _base != null else global_position
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var node := enemy as Node3D
		if node == null:
			continue
		var distance := node.global_position.distance_to(global_position)
		if distance > FIRE_RANGE:
			continue
		if not _has_line_of_sight(node):
			continue
		var enemy_health: float = float(node.get("health")) if node.get("health") != null else 50.0
		var score := node.global_position.distance_to(base_pos) + enemy_health * 0.1
		if score < best_score:
			best_score = score
			best = node
	return best


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var node := enemy as Node3D
		if node == null:
			continue
		var distance := node.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


## The spot on the far side of the lighthouse from the nearest enemy.
func _cover_point() -> Vector3:
	if _base == null:
		return post
	var threat := _nearest_enemy()
	if threat == null:
		return post
	var away := _base.global_position - threat.global_position
	away.y = 0.0
	if away.length() < 0.1:
		return post
	return _base.global_position + away.normalized() * 6.0


func _within_leash(direction: Vector3) -> bool:
	if _base == null:
		return true
	var ahead := global_position + direction * 2.0
	return ahead.distance_to(_base.global_position) <= LEASH


func _toward(point: Vector3, stop_distance: float) -> Vector3:
	var delta := point - global_position
	delta.y = 0.0
	if delta.length() <= stop_distance:
		return Vector3.ZERO
	return delta.normalized()


func _has_line_of_sight(node: Node3D) -> bool:
	var from := global_position + Vector3(0.0, 1.4, 0.0)
	var to := node.global_position + Vector3(0.0, 0.8, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit["collider"] == node


# --- Shooting ---

func _try_fire() -> void:
	if _fire_cooldown > 0.0:
		return
	var enemy := _target
	if state == State.FALL_BACK:
		enemy = _nearest_enemy()
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_hit"):
		return
	if enemy.global_position.distance_to(global_position) > FIRE_RANGE or not _has_line_of_sight(enemy):
		return
	_fire_cooldown = FIRE_INTERVAL
	var from := global_position + Vector3(0.0, 1.4, 0.0)
	var to := enemy.global_position + Vector3(0.0, 0.8, 0.0)
	if randf() <= ACCURACY:
		enemy.take_hit(DAMAGE)
	else:
		to += Vector3(randf_range(-1.0, 1.0), randf_range(-0.4, 0.4), randf_range(-1.0, 1.0))
	Fx.tracer(self, from, to, BOLT_COLOR)
	Sfx.play("rifle", -11.0)


# --- Damage ---

func take_damage(amount: int) -> void:
	if state == State.DOWN or amount <= 0:
		return
	health = maxi(0, health - amount)
	if health == 0:
		_go_down()


func _go_down() -> void:
	state = State.DOWN
	_down_timer = RESPAWN_TIME
	remove_from_group("allies")
	_shape.set_deferred("disabled", true)
	_visual.visible = false
	downed.emit()


func _stand_up() -> void:
	health = MAX_HEALTH
	state = State.GUARD
	global_position = post + Vector3(0.0, 0.1, 0.0)
	velocity = Vector3.ZERO
	add_to_group("allies")
	_shape.set_deferred("disabled", false)
	_visual.visible = true
