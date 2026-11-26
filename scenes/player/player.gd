extends CharacterBody3D
## First-person player.
## Desktop: WASD to move, mouse to look (click to capture, Esc to release),
##          left click or Space to fire.
## Phone:   TouchControls node assigned to `touch` (joystick, look area, fire button).

signal fired

const SPEED := 6.0
const EYE_HEIGHT := 1.6
const MAX_PITCH := PI * 85.0 / 180.0
const FIRE_INTERVAL := 0.15
const FIRE_RANGE := 100.0
const FIRE_DAMAGE := 25

@export var mouse_sensitivity: float = 0.0025
@export var touch_sensitivity: float = 0.004

## Set by the level. Anything with move_vector, fire_held and consume_look().
var touch = null

var head: Node3D
var camera: Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _cooldown := 0.0
var _has_touchscreen := false


func _ready() -> void:
	_has_touchscreen = DisplayServer.is_touchscreen_available()
	_ensure_actions()
	add_to_group("player")

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.4
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	add_child(shape)

	head = Node3D.new()
	head.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 75.0
	camera.current = true
	head.add_child(camera)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if _has_touchscreen:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_rotate_view(motion.relative * mouse_sensitivity)


func _physics_process(delta: float) -> void:
	if touch != null:
		_rotate_view(touch.consume_look() * touch_sensitivity)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch != null:
		input += touch.move_vector
	input = input.limit_length(1.0)

	var direction := transform.basis * Vector3(input.x, 0.0, input.y)
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()

	_cooldown -= delta
	var wants_fire := Input.is_action_pressed("fire") or (touch != null and touch.fire_held)
	if wants_fire and _cooldown <= 0.0:
		_cooldown = FIRE_INTERVAL
		_fire()


func _rotate_view(amount: Vector2) -> void:
	rotate_y(-amount.x)
	head.rotation.x = clampf(head.rotation.x - amount.y, -MAX_PITCH, MAX_PITCH)


## Placeholder hitscan shot. The real energy rifle comes in Stage 3.
func _fire() -> void:
	fired.emit()
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z) * FIRE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	if collider != null and collider.has_method("take_hit"):
		collider.take_hit(FIRE_DAMAGE)
	_spawn_impact(hit["position"])


func _spawn_impact(position_in_world: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.4)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.4)
	sphere.material = material
	marker.mesh = sphere
	get_parent().add_child(marker)
	marker.global_position = position_in_world
	get_tree().create_timer(0.2).timeout.connect(marker.queue_free)


func _ensure_actions() -> void:
	var first_time := not InputMap.has_action("fire")
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("fire", KEY_SPACE)
	# Touch devices turn taps into mouse clicks, so only bind the mouse without a touchscreen.
	if first_time and not _has_touchscreen:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", click)


func _add_key_action(action: String, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	InputMap.action_add_event(action, key)
