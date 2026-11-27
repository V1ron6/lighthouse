extends RefCounted
## Helpers for building simple levels in code.


static func build_environment(parent: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.5, 0.75)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.light_energy = 0.9
	parent.add_child(sun)


## Flat square floor with invisible walls around the edge.
static func build_ground(parent: Node3D, size: float) -> void:
	add_box(parent, Vector3(0, -0.5, 0), Vector3(size, 1, size), Color(0.08, 0.13, 0.22))
	var half := size / 2.0
	for wall in [
		[Vector3(0, 2, -half - 0.5), Vector3(size + 1, 4, 1)],
		[Vector3(0, 2, half + 0.5), Vector3(size + 1, 4, 1)],
		[Vector3(-half - 0.5, 2, 0), Vector3(1, 4, size + 1)],
		[Vector3(half + 0.5, 2, 0), Vector3(1, 4, size + 1)],
	]:
		var body := StaticBody3D.new()
		body.position = wall[0]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall[1]
		shape.shape = box
		body.add_child(shape)
		parent.add_child(body)


static func add_box(parent: Node3D, pos: Vector3, box_size: Vector3, color: Color, glow: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box_size
	shape.shape = box_shape
	body.add_child(shape)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.6
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	box_mesh.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box_mesh
	body.add_child(mesh)

	parent.add_child(body)
	return body
