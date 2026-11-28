extends CharacterBody3D
## Soldier: the first alien that thinks. Bio-mechanical, armed with a ranged bio-bolt.
##
## Scouts run on instinct. Soldiers run a small decision loop every 0.4s:
##   intelligence 1 (tactical): holds range and strafes, shoots from a distance,
##       falls back to heal when badly hurt, then returns.
##   intelligence 2 (cunning): also flanks when it has allies, shoots while
##       retreating, and judges the whole fight (allies, threats, recent losses).
##       It pulls back early when the battle is going badly, and comes back when
##       it has healed or help has arrived.
## The player's rank raises intelligence: from Sentinel up, soldiers are cunning.
## A soldier retreats at most twice, then fights on.

signal died

enum State { ADVANCE, ENGAGE, FLANK, RETREAT, REGROUP }

const Fx := preload("res://scripts/fx.gd")

const MAX_HEALTH := 70
const SPEED := 5.0
const TURN_SPEED := 8.0
const PREFERRED_RANGE := 13.0
const FIRE_RANGE := 18.0
const FIRE_INTERVAL := 1.3
const SHOT_DAMAGE := 8
const THINK_INTERVAL := 0.4
const MAX_RETREATS := 2
const REGEN_PER_SECOND := 6.0
const RETREAT_DISTANCE := 30.0
const RETREAT_MAX_TIME := 5.0
const REGROUP_MAX_TIME := 8.0
const FLANK_TIME := 3.0
const ALLY_RADIUS := 20.0
const TURRET_THREAT_RADIUS := 28.0
const LOSS_MEMORY := 6.0
## From this player rank (Sentinel) soldiers become cunning.
const CUNNING_RANK := 3

const FLESH_COLOR := Color(0.62, 0.3, 0.42)
const METAL_COLOR := Color(0.4, 0.46, 0.56)
const EYE_COLOR := Color(1.0, 0.35, 0.3)
const BOLT_COLOR := Color(1.0, 0.35, 0.3)

var intelligence := 1
var health := MAX_HEALTH
var state: State = State.ADVANCE
var target: Node3D = null

var _player: Node3D = null
var _base: Node3D = null
var _wall_normal := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _think_timer := randf() * THINK_INTERVAL
var _state_time := 0.0
var _fire_cooldown := randf() * FIRE_INTERVAL
var _strafe := 1.0 if randf() < 0.5 else -1.0
var _flank_side := 1.0 if randf() < 0.5 else -1.0
var _flank_point := Vector3.ZERO
var _flanked := false
var _retreats := 0
var _loss_times: Array[float] = []
var _dead := false
var _shape: CollisionShape3D
var _body_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("enemies")
	intelligence = 2 if GameManager.rank_index >= CUNNING_RANK else 1
	EventBus.enemy_killed.connect(_on_enemy_killed)

	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.6
	capsule.radius = 0.4
	_shape.shape = capsule
	_shape.position = Vector3(0.0, 0.8, 0.0)
	add_child(_shape)

	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = FLESH_COLOR
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.6
	body_mesh.material = _body_material
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.8, 0.0)
	add_child(body)

	var metal_material := StandardMaterial3D.new()
	metal_material.albedo_color = METAL_COLOR
	metal_material.metallic = 0.8
	var armour := MeshInstance3D.new()
	var armour_mesh := BoxMesh.new()
	armour_mesh.size = Vector3(0.75, 0.5, 0.3)
	armour_mesh.material = metal_material
	armour.mesh = armour_mesh
	armour.position = Vector3(0.0, 1.0, -0.15)
	add_child(armour)

	var eye_material := Fx.glow_material(EYE_COLOR)
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.1
	eye_mesh.height = 0.2
	eye_mesh.material = eye_material
	eye.mesh = eye_mesh
	eye.position = Vector3(0.0, 1.35, -0.36)
	add_child(eye)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_state_time += delta
	_fire_cooldown -= delta
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_think()
	if target == null:
		return

	if state == State.REGROUP:
		health = mini(MAX_HEALTH, health + int(REGEN_PER_SECOND * delta + randf()))

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	var direction := to_target / distance if distance > 0.01 else Vector3.ZERO
	var move_direction := _desired_direction(direction, distance)
	var speed := SPEED
	if state == State.RETREAT:
		speed *= 1.2
	if state == State.ENGAGE or state == State.REGROUP:
		speed *= 0.6

	if _wall_normal != Vector3.ZERO and move_direction != Vector3.ZERO:
		var slid := move_direction.slide(_wall_normal)
		if slid.length() < 0.3:
			slid = Vector3(-_wall_normal.z, 0.0, _wall_normal.x) * _strafe
		move_direction = slid.normalized()

	if state == State.REGROUP:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	# Face the target while fighting, face the way it runs when retreating.
	var face := direction if state != State.RETREAT or move_direction == Vector3.ZERO else move_direction
	if face != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), TURN_SPEED * delta)

	move_and_slide()
	_wall_normal = Vector3.ZERO
	if is_on_wall():
		var normal := get_wall_normal()
		normal.y = 0.0
		if normal.length() > 0.01:
			_wall_normal = normal.normalized()

	_try_fire(distance)


## Where to move this frame, depending on the current state.
func _desired_direction(direction: Vector3, distance: float) -> Vector3:
	var side := Vector3(-direction.z, 0.0, direction.x)
	match state:
		State.ADVANCE:
			return direction
		State.ENGAGE:
			if distance < PREFERRED_RANGE - 4.0:
				return -direction
			return side * _strafe
		State.FLANK:
			var to_point := _flank_point - global_position
			to_point.y = 0.0
			return to_point.normalized() if to_point.length() > 1.0 else Vector3.ZERO
		State.RETREAT:
			return (-direction + side * _strafe * 0.3).normalized()
	return Vector3.ZERO


# --- Thinking ---

func _think() -> void:
	_pick_target()
	if target == null:
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var reach := 0.0
	if target.has_method("get_attack_radius"):
		reach = target.get_attack_radius()
	var distance := to_target.length() - reach
	var sees := _has_line_of_sight()
	var allies := _count_allies()

	if randf() < 0.3:
		_strafe = -_strafe

	match state:
		State.ADVANCE:
			if _should_retreat(allies):
				_enter(State.RETREAT)
			elif distance <= PREFERRED_RANGE + 2.0 and sees:
				_enter(State.ENGAGE)
			elif intelligence >= 2 and not _flanked and allies >= 2 and target == _player and distance > 16.0:
				_start_flank()
		State.ENGAGE:
			if _should_retreat(allies):
				_enter(State.RETREAT)
			elif not sees and distance > PREFERRED_RANGE:
				_enter(State.ADVANCE)
		State.FLANK:
			var to_point := _flank_point - global_position
			to_point.y = 0.0
			if _should_retreat(allies):
				_enter(State.RETREAT)
			elif _state_time >= FLANK_TIME or to_point.length() < 3.0:
				_enter(State.ADVANCE)
		State.RETREAT:
			if distance >= RETREAT_DISTANCE or _state_time >= RETREAT_MAX_TIME:
				_enter(State.REGROUP)
		State.REGROUP:
			var healed := health >= int(MAX_HEALTH * 0.7)
			if _state_time >= REGROUP_MAX_TIME or (_state_time >= 2.0 and (healed or allies >= 3)):
				_enter(State.ADVANCE)


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state == State.RETREAT:
		_retreats += 1


func _start_flank() -> void:
	var from_target := global_position - target.global_position
	from_target.y = 0.0
	if from_target.length() < 0.1:
		return
	var arc := from_target.normalized().rotated(Vector3.UP, deg_to_rad(70.0) * _flank_side) * 14.0
	_flank_point = target.global_position + arc
	_flanked = true
	_enter(State.FLANK)


## Tactical soldiers only run when badly hurt. Cunning ones also run when the fight
## as a whole is going badly: few allies, many threats, comrades dying.
func _should_retreat(allies: int) -> bool:
	if _retreats >= MAX_RETREATS:
		return false
	var hp := float(health) / MAX_HEALTH
	if hp < (0.3 if intelligence == 1 else 0.5):
		return true
	if intelligence < 2:
		return false
	var score := float(allies) + hp * 2.0 - _count_threats() * 1.5 - _recent_losses() * 0.5
	return score < -1.0


## Other living aliens nearby, including this one.
func _count_allies() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var other := enemy as Node3D
		if other != null and other.global_position.distance_to(global_position) <= ALLY_RADIUS:
			count += 1
	return count


## The player, plus every turret that can reach this soldier.
func _count_threats() -> int:
	var count := 1 if _player != null else 0
	for comrade in get_tree().get_nodes_in_group("allies"):
		var friend := comrade as Node3D
		if friend != null and friend.global_position.distance_to(global_position) <= TURRET_THREAT_RADIUS:
			count += 1
	for turret in get_tree().get_nodes_in_group("turrets"):
		var node := turret as Node3D
		if node != null and node.global_position.distance_to(global_position) <= TURRET_THREAT_RADIUS:
			count += 1
	return count


func _recent_losses() -> int:
	var now := Time.get_ticks_msec() / 1000.0
	var recent: Array[float] = []
	for t in _loss_times:
		if now - t <= LOSS_MEMORY:
			recent.append(t)
	_loss_times = recent
	return recent.size()


func _on_enemy_killed(_enemy_type: String) -> void:
	_loss_times.append(Time.get_ticks_msec() / 1000.0)


## Prefers the player when close. Cunning soldiers who cannot see a hiding player
## go for the lighthouse instead.
func _pick_target() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _base == null or not is_instance_valid(_base):
		_base = get_tree().get_first_node_in_group("base") as Node3D
	# The player leaves the "player" group while flying the jet.
	if _player != null and not _player.is_in_group("player"):
		_player = null
	if _base == null:
		target = _player
		return
	if _player != null:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var range_limit := 25.0 if intelligence >= 2 else 18.0
		if to_player.length() <= range_limit:
			target = _player
			return
	var ally := _nearest_ally(12.0)
	target = ally if ally != null else _base


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


func _has_line_of_sight() -> bool:
	if target == null:
		return false
	var from := global_position + Vector3(0.0, 1.4, 0.0)
	var to := target.global_position + Vector3(0.0, 1.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit["collider"]
	return collider == target or (collider is Node and target.is_ancestor_of(collider as Node))


# --- Shooting ---

func _try_fire(distance: float) -> void:
	if _fire_cooldown > 0.0 or target == null:
		return
	var shooting := state == State.ENGAGE or (intelligence >= 2 and (state == State.FLANK or state == State.RETREAT))
	if not shooting or distance > FIRE_RANGE or not target.has_method("take_damage"):
		return
	if not _has_line_of_sight():
		return
	_fire_cooldown = FIRE_INTERVAL
	var from := global_position + Vector3(0.0, 1.4, 0.0)
	var to := target.global_position + Vector3(0.0, 1.0, 0.0)
	var accuracy := 0.65 if intelligence == 1 else 0.85
	if target == _base:
		accuracy = 1.0
	if randf() <= accuracy:
		target.take_damage(SHOT_DAMAGE)
	else:
		to += Vector3(randf_range(-1.2, 1.2), randf_range(-0.5, 0.5), randf_range(-1.2, 1.2))
	Fx.tracer(self, from, to, BOLT_COLOR)


# --- Damage ---

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
	EventBus.enemy_killed.emit("soldier")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(queue_free)
