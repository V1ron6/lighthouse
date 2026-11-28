extends Node3D
## Starter energy rifle. Child of the player's camera.
## Hitscan, hold to fire. Each shot builds heat. At 100 the rifle overheats and
## locks until it has cooled to 40. No reloading, so it suits touch controls.

signal fired
signal heat_changed(heat: float, overheated: bool)

const DAMAGE := 25
const FIRE_INTERVAL := 0.15
const RANGE := 100.0
const HEAT_PER_SHOT := 8.0
const COOL_RATE := 28.0
const COOL_DELAY := 0.35
const OVERHEAT_AT := 100.0
const RECOVER_AT := 40.0

const BOLT_COLOR := Color(0.3, 0.88, 1.0)

var trigger_held := false
var exclude_rid: RID
var heat := 0.0
var overheated := false

var _cooldown := 0.0
var _since_shot := 0.0
var _camera: Camera3D
var _muzzle: Node3D
var _flash: MeshInstance3D
var _last_heat := -1.0
var _last_overheated := false


func _ready() -> void:
	_camera = get_parent() as Camera3D
	_build_model()


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_since_shot += delta

	if trigger_held and not overheated and _cooldown <= 0.0:
		_shoot()
	elif _since_shot >= COOL_DELAY and heat > 0.0:
		heat = maxf(0.0, heat - COOL_RATE * delta)

	if overheated and heat <= RECOVER_AT:
		overheated = false

	if heat != _last_heat or overheated != _last_overheated:
		_last_heat = heat
		_last_overheated = overheated
		heat_changed.emit(heat, overheated)


func _shoot() -> void:
	_cooldown = FIRE_INTERVAL
	_since_shot = 0.0
	heat += HEAT_PER_SHOT
	if heat >= OVERHEAT_AT:
		heat = OVERHEAT_AT
		overheated = true
	fired.emit()
	_show_flash()

	var from := _camera.global_position
	var to := from + (-_camera.global_transform.basis.z) * RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [exclude_rid]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var end := to
	if not hit.is_empty():
		end = hit["position"]
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("take_hit"):
			collider.take_hit(DAMAGE)
		_spawn_impact(end)
	_spawn_tracer(_muzzle.global_position, end)
	Sfx.play("rifle", -4.0)


func _build_model() -> void:
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.12, 0.12, 0.6)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.12, 0.16, 0.24)
	body_material.metallic = 0.6
	body_mesh.material = body_material
	body.mesh = body_mesh
	body.position = Vector3(0.22, -0.2, -0.5)
	add_child(body)

	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.125, 0.03, 0.4)
	strip_mesh.material = _glow_material(BOLT_COLOR)
	strip.mesh = strip_mesh
	strip.position = Vector3(0.22, -0.13, -0.5)
	add_child(strip)

	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.22, -0.2, -0.85)
	add_child(_muzzle)

	_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.07
	flash_mesh.height = 0.14
	flash_mesh.material = _glow_material(Color(1.0, 0.8, 0.4))
	_flash.mesh = flash_mesh
	_flash.visible = false
	_muzzle.add_child(_flash)


func _show_flash() -> void:
	_flash.visible = true
	get_tree().create_timer(0.04).timeout.connect(func(): _flash.visible = false)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, length)
	mesh.material = _glow_material(BOLT_COLOR)
	tracer.mesh = mesh
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (from + to) / 2.0
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	tracer.look_at(to, up)
	get_tree().create_timer(0.05).timeout.connect(tracer.queue_free)


func _spawn_impact(position_in_world: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	sphere.material = _glow_material(Color(1.0, 0.8, 0.4))
	marker.mesh = sphere
	get_tree().current_scene.add_child(marker)
	marker.global_position = position_in_world
	get_tree().create_timer(0.2).timeout.connect(marker.queue_free)


func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
