extends RefCounted
## Small visual-effect helpers shared by weapons and turrets.


static func glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## A thin glowing bolt between two points that disappears after `life` seconds.
static func tracer(node: Node, from: Vector3, to: Vector3, color: Color, life: float = 0.05) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var bolt := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, length)
	mesh.material = glow_material(color)
	bolt.mesh = mesh
	node.get_tree().current_scene.add_child(bolt)
	bolt.global_position = (from + to) / 2.0
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	bolt.look_at(to, up)
	node.get_tree().create_timer(life).timeout.connect(bolt.queue_free)
