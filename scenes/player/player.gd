extends CharacterBody3D
## First-person player.
## Desktop: WASD to move, mouse to look (click to capture, Esc to release),
##          left click or Space to fire.
## Phone:   TouchControls node assigned to `touch` (joystick, look area, fire button).

signal died
signal health_changed(current: int, maximum: int)
signal weapon_changed(weapon_name: String)
signal weapon_heat_changed(heat: float, overheated: bool)

const RifleScript := preload("res://scenes/weapons/energy_rifle.gd")
const MacheteScript := preload("res://scenes/weapons/machete.gd")
const WeaponData := preload("res://data/weapon_data.gd")

const SPEED := 6.0
const EYE_HEIGHT := 1.6
const MAX_PITCH := PI * 85.0 / 180.0
const MAX_HEALTH := 100

@export var mouse_sensitivity: float = 0.0025
@export var touch_sensitivity: float = 0.004

## Set by the level. Anything with move_vector, fire_held and consume_look().
var touch = null
## The active weapon (Variant on purpose, so its script members resolve at runtime).
var rifle = null
var weapons: Array = []
var _weapon_index := 0

var health: int = MAX_HEALTH
var head: Node3D
var camera: Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
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

	_build_weapons()
	_select_weapon(0)


## One node per owned weapon the current rank may use. The rifle is always available.
func _build_weapons() -> void:
	for id in WeaponData.ORDER:
		if id != "energy_rifle" and not (GameManager.has_item(id) and GameManager.can_use(id)):
			continue
		var weapon: Node3D
		if id == "machete":
			weapon = MacheteScript.new()
		else:
			weapon = RifleScript.new()
			weapon.configure(id)
		weapon.exclude_rid = get_rid()
		weapon.heat_changed.connect(_on_weapon_heat.bind(weapon))
		camera.add_child(weapon)
		weapon.visible = false
		weapon.set_physics_process(false)
		weapons.append(weapon)


func _select_weapon(index: int) -> void:
	if weapons.is_empty():
		return
	if rifle != null:
		rifle.trigger_held = false
		rifle.visible = false
		rifle.set_physics_process(false)
	_weapon_index = index % weapons.size()
	rifle = weapons[_weapon_index]
	rifle.visible = true
	rifle.set_physics_process(true)
	weapon_changed.emit(rifle.weapon_name)
	weapon_heat_changed.emit(rifle.heat, rifle.overheated)


func next_weapon() -> void:
	_select_weapon(_weapon_index + 1)


func _on_weapon_heat(heat: float, overheated: bool, weapon: Node) -> void:
	if weapon == rifle:
		weapon_heat_changed.emit(heat, overheated)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("swap_weapon"):
		next_weapon()
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

	rifle.trigger_held = Input.is_action_pressed("fire") or (touch != null and touch.fire_held)


func take_damage(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		died.emit()


## Full health again. The level moves the player back to the start.
func reset() -> void:
	health = MAX_HEALTH
	velocity = Vector3.ZERO
	health_changed.emit(health, MAX_HEALTH)


func _rotate_view(amount: Vector2) -> void:
	rotate_y(-amount.x)
	head.rotation.x = clampf(head.rotation.x - amount.y, -MAX_PITCH, MAX_PITCH)


func _ensure_actions() -> void:
	var first_time := not InputMap.has_action("fire")
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("fire", KEY_SPACE)
	_add_key_action("swap_weapon", KEY_Q)
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
