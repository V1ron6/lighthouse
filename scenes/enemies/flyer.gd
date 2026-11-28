extends CharacterBody3D
## Flyer: a fast bio-mechanical wing-beast that attacks from the air in strafing passes.
## Decision loop every 0.4s:
##   CIRCLE     orbit above the target at height, waiting for its moment
##   DIVE       swoop at the target and fire
##   BREAK_OFF  climb away after a pass
##   RETREAT    below 35% health: flee high and far, heal, come back (at most twice)
## It hunts the player's jet first when one is airborne, then the player, then the lighthouse.

signal died

enum State { CIRCLE, DIVE, BREAK_OFF, RETREAT }

const Fx := preload("res://scripts/fx.gd")

const MAX_HEALTH := 45
const CIRCLE_RADIUS := 14.0
const CIRCLE_ALTITUDE := 12.0
const START_ALTITUDE := 14.0
const CRUISE_SPEED := 14.0
const DIVE_SPEED := 24.0
const THINK_INTERVAL := 0.4
const FIRE_INTERVAL := 0.35
const FIRE_RANGE := 28.0
const SHOT_DAMAGE := 10
const MAX_RETREATS := 2
const MIN_ALTITUDE := 2.5
const MAX_ALTITUDE := 70.0
const REGEN_PER_SECOND := 4.0
const FALL_BACK_HEALTH := 0.35
const RECOVER_HEALTH := 0.7

const FLESH_COLOR := Color(0.55, 0.3, 0.5)
const METAL_COLOR := Color(0.4, 0.46, 0.56)
const EYE_COLOR := Color(0.6, 1.0, 0.4)

var health := MAX_HEALTH
var state: State = State.CIRCLE
var target: Node3D = null

var _angle := randf() * TAU
var _spin := 1.0 if randf() < 0.5 else -1.0
var _state_time := 0.0
var _circle_time := randf_range(3.0, 5.0)
var _think_timer := randf() * THINK_INTERVAL
var _fire_cooldown := 0.0
var _retreats := 0
var _dead := false
var _shape: CollisionShape3D
var _body_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	position.y = START_ALTITUDE

	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	_shape.shape = sphere
	add_child(_shape)

	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = FLESH_COLOR
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.6
	body_mesh.height = 1.0
	body_mesh.material = _body_material
	body.mesh = body_mesh
	add_child(body)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL_COLOR
	metal.metallic = 0.8
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(1.8, 0.06, 0.8)
		wing_mesh.material = metal
		wing.mesh = wing_mesh
		wing.position = Vector3(side * 1.2, 0.0, 0.1)
		wing.rotation.z = side * -0.25
		add_child(wing)

	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.12
	eye_mesh.height = 0.24
	eye_mesh.material = Fx.glow_material(EYE_COLOR)
	eye.mesh = eye_mesh
	eye.position = Vector3(0.0, 0.1, -0.55)
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
	if target == null or not is_instance_valid(target):
		return

	var target_pos := target.global_position
	var desired := Vector3.ZERO
	var speed := CRUISE_SPEED
	match state:
		State.CIRCLE:
			_angle += _spin * delta * 0.9
			var spot := target_pos + Vector3(cos(_angle) * CIRCLE_RADIUS, CIRCLE_ALTITUDE, sin(_angle) * CIRCLE_RADIUS)
			desired = (spot - global_position).normalized()
		State.DIVE:
			var aim := target_pos + Vector3(0.0, 1.0, 0.0)
			desired = (aim - global_position).normalized()
			speed = DIVE_SPEED
			_fire_at(aim)
		State.BREAK_OFF:
			desired = (_away_from(target_pos) + Vector3.UP * 0.6).normalized()
			speed = DIVE_SPEED
		State.RETREAT:
			desired = (_away_from(target_pos) + Vector3.UP * 0.3).normalized()
			speed = DIVE_SPEED
			health = mini(MAX_HEALTH, health + int(REGEN_PER_SECOND * delta + randf()))

	velocity = velocity.lerp(desired * speed, minf(1.0, 4.0 * delta))
	move_and_slide()
	global_position.y = clampf(global_position.y, MIN_ALTITUDE, MAX_ALTITUDE)

	if velocity.length() > 1.0:
		var heading := velocity.normalized()
		if absf(heading.dot(Vector3.UP)) < 0.97:
			look_at(global_position + heading, Vector3.UP)


func _away_from(point: Vector3) -> Vector3:
	var away := global_position - point
	away.y = 0.0
	if away.length() < 0.1:
		return Vector3.FORWARD
	return away.normalized()


# --- Thinking ---

func _think() -> void:
	_pick_target()
	if target == null:
		return
	var hp := float(health) / MAX_HEALTH
	var distance := global_position.distance_to(target.global_position)
	match state:
		State.CIRCLE:
			if hp < FALL_BACK_HEALTH and _retreats < MAX_RETREATS:
				_enter(State.RETREAT)
			elif _state_time >= _circle_time:
				_enter(State.DIVE)
		State.DIVE:
			if hp < FALL_BACK_HEALTH and _retreats < MAX_RETREATS:
				_enter(State.RETREAT)
			elif distance < 6.0 or _state_time > 3.0:
				_enter(State.BREAK_OFF)
		State.BREAK_OFF:
			if _state_time >= 1.6:
				_circle_time = randf_range(3.0, 5.0)
				_enter(State.CIRCLE)
		State.RETREAT:
			if _state_time >= 4.0 and (hp >= RECOVER_HEALTH or _state_time >= 8.0):
				_circle_time = 1.0
				_enter(State.CIRCLE)


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state == State.RETREAT:
		_retreats += 1


## The jet if one is up, otherwise the player if near, otherwise the lighthouse.
func _pick_target() -> void:
	var jet := get_tree().get_first_node_in_group("jet") as Node3D
	if jet != null and jet.global_position.distance_to(global_position) <= 90.0:
		target = jet
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null and player.global_position.distance_to(global_position) <= 45.0:
		target = player
		return
	var base := get_tree().get_first_node_in_group("base") as Node3D
	target = base if base != null else player


func _fire_at(aim: Vector3) -> void:
	if _fire_cooldown > 0.0 or not target.has_method("take_damage"):
		return
	if global_position.distance_to(aim) > FIRE_RANGE:
		return
	_fire_cooldown = FIRE_INTERVAL
	var accuracy := 0.7
	if target.is_in_group("jet"):
		accuracy = 0.5
	elif target.is_in_group("base"):
		accuracy = 1.0
	var end := aim
	if randf() <= accuracy:
		target.take_damage(SHOT_DAMAGE)
	else:
		end += Vector3(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0), randf_range(-1.5, 1.5))
	Fx.tracer(self, global_position, end, EYE_COLOR)


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
	EventBus.enemy_killed.emit("flyer")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.25)
	tween.tween_callback(queue_free)
