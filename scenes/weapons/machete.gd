extends Node3D
## Machete: melee. Hold to swing. Hits every enemy in a short forward cone.
## Same interface as the energy rifle so the player can swap freely.

signal fired
signal heat_changed(heat: float, overheated: bool)

const REACH := 2.8
const CONE_DOT := 0.5
const DAMAGE := 45
const INTERVAL := 0.5

var weapon_id := "machete"
var weapon_name := "Machete"
var trigger_held := false
var exclude_rid: RID
var heat := 0.0
var overheated := false

var _cooldown := 0.0
var _swing := 0.0
var _camera: Camera3D
var _blade: Node3D


func _ready() -> void:
	_camera = get_parent() as Camera3D
	_blade = Node3D.new()
	_blade.position = Vector3(0.3, -0.3, -0.5)
	add_child(_blade)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.6, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.8, 0.9)
	mat.metallic = 0.8
	box.material = mat
	mesh.mesh = box
	mesh.position = Vector3(0.0, 0.3, 0.0)
	_blade.add_child(mesh)
	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.06, 0.18, 0.06)
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, -0.05, 0.0)
	_blade.add_child(grip)
	_blade.rotation_degrees = Vector3(0.0, 0.0, -20.0)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _swing > 0.0:
		_swing = maxf(0.0, _swing - delta * 5.0)
		_blade.rotation_degrees = Vector3(-110.0 * sin(_swing * PI), 0.0, -20.0)
	if trigger_held and _cooldown <= 0.0:
		_swipe()


func _swipe() -> void:
	_cooldown = INTERVAL
	_swing = 1.0
	fired.emit()
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("take_hit"):
			continue
		var offset: Vector3 = enemy.global_position + Vector3(0.0, 1.0, 0.0) - origin
		if offset.length() <= REACH + 1.0 and offset.normalized().dot(forward) >= CONE_DOT:
			enemy.take_hit(DAMAGE)
	Sfx.play("hit", -3.0)
