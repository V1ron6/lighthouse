extends StaticBody3D
## Automatic defence turret. Aims at the nearest enemy in range and fires.
## One turret is part of the starting loadout.

const Fx := preload("res://scripts/fx.gd")

const RANGE := 28.0
const FIRE_INTERVAL := 0.45
const DAMAGE := 18
const BOLT_COLOR := Color(1.0, 0.8, 0.4)

var _head: Node3D
var _cooldown := 0.0


func _ready() -> void:
	add_to_group("turrets")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.5
	cylinder.height = 0.8
	shape.shape = cylinder
	shape.position = Vector3(0.0, 0.4, 0.0)
	add_child(shape)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.2, 0.26, 0.36)
	metal.metallic = 0.7

	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.45
	base_mesh.bottom_radius = 0.55
	base_mesh.height = 0.8
	base_mesh.material = metal
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.4, 0.0)
	add_child(base)

	_head = Node3D.new()
	_head.position = Vector3(0.0, 1.0, 0.0)
	add_child(_head)

	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.5, 0.3, 0.5)
	head_mesh.material = metal
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	_head.add_child(head)

	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.12, 0.12, 0.8)
	barrel_mesh.material = Fx.glow_material(Color(0.3, 0.88, 1.0))
	var barrel := MeshInstance3D.new()
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0.0, 0.0, -0.55)
	_head.add_child(barrel)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	var target := _nearest_enemy()
	if target == null:
		return
	var aim_point := target.global_position + Vector3(0.0, 0.5, 0.0)
	var to_target := aim_point - _head.global_position
	if absf(to_target.normalized().dot(Vector3.UP)) < 0.99:
		_head.look_at(aim_point, Vector3.UP)
	if _cooldown <= 0.0:
		_cooldown = FIRE_INTERVAL
		target.take_hit(DAMAGE)
		var muzzle := _head.global_position + (-_head.global_transform.basis.z) * 0.95
		Fx.tracer(self, muzzle, aim_point, BOLT_COLOR)


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_distance := RANGE
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_3d := enemy as Node3D
		if enemy_3d == null or not is_instance_valid(enemy_3d):
			continue
		var distance := global_position.distance_to(enemy_3d.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy_3d
	return best
