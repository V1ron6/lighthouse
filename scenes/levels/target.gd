extends StaticBody3D
## Shootable practice target. Flashes when hit, disappears when destroyed,
## and comes back after a couple of seconds.

const MAX_HEALTH := 100
const RESPAWN_TIME := 2.0
const NORMAL_COLOR := Color(0.9, 0.35, 0.3)

var health := MAX_HEALTH

var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	var size := Vector3(1.0, 2.0, 1.0)

	_shape = CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	_shape.shape = box_shape
	add_child(_shape)

	_material = StandardMaterial3D.new()
	_material.albedo_color = NORMAL_COLOR
	_material.emission_enabled = true
	_material.emission = NORMAL_COLOR
	_material.emission_energy_multiplier = 0.4

	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = _material
	_mesh = MeshInstance3D.new()
	_mesh.mesh = box_mesh
	add_child(_mesh)


func take_hit(damage: int) -> void:
	if health <= 0:
		return
	health -= damage
	_material.albedo_color = Color.WHITE
	get_tree().create_timer(0.08).timeout.connect(_restore_color)
	if health <= 0:
		_destroy()


func _restore_color() -> void:
	_material.albedo_color = NORMAL_COLOR


func _destroy() -> void:
	_mesh.visible = false
	_shape.set_deferred("disabled", true)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_respawn)


func _respawn() -> void:
	health = MAX_HEALTH
	_mesh.visible = true
	_shape.set_deferred("disabled", false)
	_restore_color()
