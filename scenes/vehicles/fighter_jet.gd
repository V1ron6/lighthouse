extends Node3D
## Fighter jet. Boarded from the hangar at the lighthouse, flown with the same on-screen
## controls as walking:
##   stick left/right = turn (the jet banks), stick up/down = nose up/down
##   throttle is automatic, fire button (or Space) shoots the twin cannons
## The cannons lean toward the nearest enemy in front of the nose (aim assist), so
## it is playable with a thumb. Flyers, which can hurt the jet, arrive in a later stage;
## for now the jet takes no damage.

const Fx := preload("res://scripts/fx.gd")

const SPEED := 32.0
const YAW_RATE := 1.6
const PITCH_RATE := 1.2
const MAX_PITCH := PI * 55.0 / 180.0
const MIN_ALTITUDE := 5.0
const MAX_ALTITUDE := 90.0
const ARENA_RADIUS := 55.0
const FIRE_INTERVAL := 0.1
const DAMAGE := 20
const RANGE := 140.0
## Aim assist: enemies within about 10 degrees of the nose.
const ASSIST_DOT := 0.985
const BOLT_COLOR := Color(1.0, 0.85, 0.35)
const HULL_COLOR := Color(0.55, 0.62, 0.72)
const GLOW_COLOR := Color(0.3, 0.88, 1.0)

## False while parked on the pad.
var active := false
## Anything with move_vector, fire_held and consume_look(). Set by the level.
var touch = null
var camera: Camera3D

var _model: Node3D
var _cooldown := 0.0
var _side := 1.0


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)

	var hull := StandardMaterial3D.new()
	hull.albedo_color = HULL_COLOR
	hull.metallic = 0.7
	hull.roughness = 0.4

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.55
	body_mesh.height = 5.0
	body_mesh.material = hull
	body.mesh = body_mesh
	body.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_model.add_child(body)

	var wings := MeshInstance3D.new()
	var wings_mesh := BoxMesh.new()
	wings_mesh.size = Vector3(6.0, 0.1, 1.8)
	wings_mesh.material = hull
	wings.mesh = wings_mesh
	wings.position = Vector3(0.0, 0.0, 0.6)
	_model.add_child(wings)

	var fin := MeshInstance3D.new()
	var fin_mesh := BoxMesh.new()
	fin_mesh.size = Vector3(0.1, 1.2, 1.0)
	fin_mesh.material = hull
	fin.mesh = fin_mesh
	fin.position = Vector3(0.0, 0.7, 2.0)
	_model.add_child(fin)

	var cockpit := MeshInstance3D.new()
	var cockpit_mesh := SphereMesh.new()
	cockpit_mesh.radius = 0.4
	cockpit_mesh.height = 0.8
	cockpit_mesh.material = Fx.glow_material(GLOW_COLOR.darkened(0.3))
	cockpit.mesh = cockpit_mesh
	cockpit.position = Vector3(0.0, 0.4, -0.8)
	_model.add_child(cockpit)

	var engine := MeshInstance3D.new()
	var engine_mesh := SphereMesh.new()
	engine_mesh.radius = 0.35
	engine_mesh.height = 0.7
	engine_mesh.material = Fx.glow_material(GLOW_COLOR)
	engine.mesh = engine_mesh
	engine.position = Vector3(0.0, 0.0, 2.6)
	_model.add_child(engine)

	camera = Camera3D.new()
	camera.fov = 80.0
	camera.position = Vector3(0.0, 2.8, 9.0)
	camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	add_child(camera)


## Sit on the pad, engines off.
func park(pad: Vector3) -> void:
	active = false
	global_position = pad + Vector3(0.0, 0.6, 0.0)
	rotation = Vector3.ZERO
	_model.rotation = Vector3.ZERO


## Take off from the pad, heading toward the middle of the map.
func take_off(pad: Vector3) -> void:
	active = true
	global_position = pad + Vector3(0.0, MIN_ALTITUDE + 1.0, 0.0)
	var toward := Vector3(-pad.x, 0.0, -pad.z).normalized()
	rotation = Vector3(0.0, atan2(-toward.x, -toward.z), 0.0)
	camera.make_current()


func _physics_process(delta: float) -> void:
	if not active:
		return
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var firing := Input.is_action_pressed("fire")
	if touch != null:
		stick += touch.move_vector
		firing = firing or touch.fire_held
		touch.consume_look()
	stick = stick.limit_length(1.0)

	rotate_y(-stick.x * YAW_RATE * delta)
	var pitch_input := -stick.y
	var forward := -global_transform.basis.z
	var limit := sin(MAX_PITCH)
	if (pitch_input > 0.0 and forward.y < limit) or (pitch_input < 0.0 and forward.y > -limit):
		rotate_object_local(Vector3.RIGHT, pitch_input * PITCH_RATE * delta)
	_model.rotation.z = lerpf(_model.rotation.z, -stick.x * 0.6, minf(1.0, 6.0 * delta))

	forward = -global_transform.basis.z
	global_position += forward * SPEED * delta
	global_position.y = clampf(global_position.y, MIN_ALTITUDE, MAX_ALTITUDE)

	# Past the edge of the map, turn back toward the middle.
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > ARENA_RADIUS:
		var heading := Vector2(forward.x, forward.z)
		var angle := heading.angle_to(-flat)
		var step := YAW_RATE * delta
		rotate_y(-clampf(angle, -step, step))

	_cooldown -= delta
	if firing and _cooldown <= 0.0:
		_cooldown = FIRE_INTERVAL
		_fire(forward)


func altitude() -> float:
	return global_position.y


func _fire(forward: Vector3) -> void:
	_side = -_side
	var nose := global_position + forward * 3.0 + global_transform.basis.x * _side * 1.2
	var end := nose + forward * RANGE
	var victim: Node = null

	# Aim assist: the enemy closest to straight ahead.
	var best_dot := ASSIST_DOT
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var node := enemy as Node3D
		if node == null:
			continue
		var aim := node.global_position + Vector3(0.0, 0.6, 0.0) - global_position
		var distance := aim.length()
		if distance > RANGE or distance < 1.0:
			continue
		var dot := forward.dot(aim / distance)
		if dot > best_dot:
			best_dot = dot
			victim = node
			end = node.global_position + Vector3(0.0, 0.6, 0.0)

	if victim == null:
		var query := PhysicsRayQueryParameters3D.create(nose, nose + forward * RANGE)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit["position"]
			victim = hit["collider"] as Node

	if victim != null and victim.has_method("take_hit"):
		victim.take_hit(DAMAGE)
	Fx.tracer(self, nose, end, BOLT_COLOR, 0.08)
