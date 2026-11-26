extends StaticBody3D
## The lighthouse. Enemies attack it. Damage hits the structure (base health)
## first. Once that is gone, damage goes to the power core. Core at 0 is game over.

const ATTACK_RADIUS := 3.2
## Enemy bites are scaled down against the lighthouse so it can take a beating.
const DAMAGE_FACTOR := 0.4

const STEEL := Color(0.18, 0.3, 0.5)
const DARK := Color(0.07, 0.11, 0.2)
const CYAN := Color(0.3, 0.88, 1.0)
const AMBER := Color(1.0, 0.8, 0.4)
const CORE_LOW := Color(1.0, 0.15, 0.1)

var _beam_pivot: Node3D
var _window_material: StandardMaterial3D
var _flash_time := 0.0
var _time := 0.0


func _ready() -> void:
	add_to_group("base")

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 2.4
	cylinder.height = 12.0
	shape.shape = cylinder
	shape.position = Vector3(0.0, 6.0, 0.0)
	add_child(shape)

	_add_cylinder(Vector3(0.0, 0.05, 0.0), 5.5, 5.5, 0.1, DARK, false)
	_add_cylinder(Vector3(0.0, 5.0, 0.0), 1.6, 2.4, 10.0, STEEL, false)
	for stripe_y in [1.6, 4.4, 7.2]:
		var radius := lerpf(2.4, 1.6, stripe_y / 10.0) + 0.04
		_add_cylinder(Vector3(0.0, stripe_y, 0.0), radius, radius, 1.2, CYAN, true)
	_add_cylinder(Vector3(0.0, 10.2, 0.0), 2.3, 2.3, 0.3, DARK, false)
	_add_cylinder(Vector3(0.0, 11.1, 0.0), 0.9, 0.9, 1.5, AMBER, true)
	_add_cylinder(Vector3(0.0, 12.4, 0.0), 0.0, 1.3, 1.2, DARK, false)

	var light := OmniLight3D.new()
	light.light_color = AMBER
	light.omni_range = 35.0
	light.light_energy = 2.0
	light.position = Vector3(0.0, 11.1, 0.0)
	add_child(light)

	_beam_pivot = Node3D.new()
	_beam_pivot.position = Vector3(0.0, 11.1, 0.0)
	add_child(_beam_pivot)
	for beam_z in [-11.0, 11.0]:
		var beam := MeshInstance3D.new()
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(0.5, 0.5, 22.0)
		var beam_material := StandardMaterial3D.new()
		beam_material.albedo_color = Color(AMBER.r, AMBER.g, AMBER.b, 0.3)
		beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_mesh.material = beam_material
		beam.mesh = beam_mesh
		beam.position = Vector3(0.0, 0.0, beam_z)
		_beam_pivot.add_child(beam)

	# Window on the front of the tower showing the power core inside.
	_window_material = StandardMaterial3D.new()
	_window_material.albedo_color = AMBER
	_window_material.emission_enabled = true
	_window_material.emission = AMBER
	var window := MeshInstance3D.new()
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(1.0, 1.0, 0.2)
	window_mesh.material = _window_material
	window.mesh = window_mesh
	window.position = Vector3(0.0, 1.6, 2.25)
	add_child(window)


func _process(delta: float) -> void:
	_time += delta
	_beam_pivot.rotation.y += delta * 0.9

	var ratio := float(GameManager.core_integrity) / float(GameManager.MAX_CORE_INTEGRITY)
	var color := CORE_LOW.lerp(AMBER, ratio)
	if _flash_time > 0.0:
		_flash_time -= delta
		color = Color.WHITE
	_window_material.albedo_color = color
	_window_material.emission = color
	_window_material.emission_energy_multiplier = 1.2 + 0.6 * sin(_time * 3.0)


func get_attack_radius() -> float:
	return ATTACK_RADIUS


func take_damage(amount: int) -> void:
	var scaled := maxi(1, roundi(amount * DAMAGE_FACTOR))
	if GameManager.base_health > 0:
		GameManager.damage_base(scaled)
	else:
		GameManager.damage_core(scaled)
	_flash_time = 0.1


func _add_cylinder(pos: Vector3, top_radius: float, bottom_radius: float, height: float, color: Color, glow: bool) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.6
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	add_child(instance)
	return instance
