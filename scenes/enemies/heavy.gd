extends "res://scenes/enemies/soldier.gd"
## Heavy: a slow armoured bio-mechanical brute. Uses the soldier's brain, always cunning
## (it flanks, judges the fight and retreats when it is going badly).
##
## Armour: shots do half damage. Its weak spot is the organic core in its chest, which it
## has to open to fire. For a short moment after each shot the core glows and hits do double.
## Learn the rhythm: shoot it when it shoots.

const EXPOSED_TIME := 1.2
const ARMOUR_FACTOR := 0.5
const EXPOSED_FACTOR := 2.0
const CLOSED_COLOR := Color(0.35, 0.2, 0.25)
const OPEN_COLOR := Color(1.0, 0.75, 0.3)

var _exposed := 0.0
var _core_material: StandardMaterial3D


func _ready() -> void:
	super()
	intelligence = 2
	max_health = 220
	health = max_health
	move_speed = 3.2
	fire_interval = 1.8
	shot_damage = 14
	enemy_type = "heavy"

	for child in get_children():
		if child is MeshInstance3D:
			child.scale = Vector3.ONE * 1.5
			child.position *= 1.5
	var capsule := _shape.shape as CapsuleShape3D
	capsule.height = 2.5
	capsule.radius = 0.6
	_shape.position = Vector3(0.0, 1.25, 0.0)

	_core_material = Fx.glow_material(CLOSED_COLOR)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.22
	core_mesh.height = 0.44
	core_mesh.material = _core_material
	core.mesh = core_mesh
	core.position = Vector3(0.0, 1.55, -0.72)
	add_child(core)


func _physics_process(delta: float) -> void:
	super(delta)
	if _exposed > 0.0:
		_exposed -= delta
		if _exposed <= 0.0 and _core_material != null:
			_core_material.albedo_color = CLOSED_COLOR
			_core_material.emission = CLOSED_COLOR


func _try_fire(distance: float) -> void:
	var before := _fire_cooldown
	super(distance)
	if _fire_cooldown > before:
		_exposed = EXPOSED_TIME
		_core_material.albedo_color = OPEN_COLOR
		_core_material.emission = OPEN_COLOR


func take_hit(damage: int) -> void:
	var factor := EXPOSED_FACTOR if _exposed > 0.0 else ARMOUR_FACTOR
	super(maxi(1, roundi(damage * factor)))
