extends CharacterBody3D
## The Mothership: the boss. A huge bio-mechanical hive-ship that circles over the field.
##
## Shield: while any escort it has launched is alive, damage is cut to 10%. Kill the
## escorts, then hit the core before it launches more.
## It thinks in three phases, chosen by its health:
##   1 (above 66%)   launches flyers, slow bolts
##   2 (33% to 66%)  drops soldiers as well, faster fire
##   3 (below 33%)   drops heavies, rapid three-bolt volleys, launches faster
## It always hunts the player first, otherwise the lighthouse.

signal died

const Fx := preload("res://scripts/fx.gd")
const FlyerScript := preload("res://scenes/enemies/flyer.gd")
const SoldierScript := preload("res://scenes/enemies/soldier.gd")
const HeavyScript := preload("res://scenes/enemies/heavy.gd")

const MAX_HEALTH := 1200
const ALTITUDE := 18.0
const ORBIT_RADIUS := 12.0
const ORBIT_SPEED := 0.25
const SHIELD_FACTOR := 0.1
const FIRE_RANGE := 70.0
const BOLT_DAMAGE := 12
## Per phase: seconds between volleys, seconds between launches, escorts allowed at once.
const FIRE_INTERVALS := [1.6, 1.1, 0.9]
const LAUNCH_INTERVALS := [9.0, 7.0, 5.5]
const MAX_ESCORTS := [3, 4, 5]

const HULL_COLOR := Color(0.32, 0.2, 0.3)
const RING_COLOR := Color(0.85, 0.3, 0.9)
const CORE_COLOR := Color(1.0, 0.7, 0.3)

var health := MAX_HEALTH
var max_health := MAX_HEALTH
var shielded := false

var _center := Vector3.ZERO
var _angle := 0.0
var _fire_cooldown := 3.0
var _launch_timer := 2.0
var _escorts: Array[Node] = []
var _target: Node3D = null
var _think_timer := 0.0
var _dead := false
var _shape: CollisionShape3D
var _hull_material: StandardMaterial3D
var _shield_mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("enemies")
	_center = global_position
	_center.y = 0.0
	global_position = _orbit_position()

	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 4.5
	_shape.shape = sphere
	add_child(_shape)

	_hull_material = StandardMaterial3D.new()
	_hull_material.albedo_color = HULL_COLOR
	_hull_material.metallic = 0.5
	_hull_material.roughness = 0.5
	var hull := MeshInstance3D.new()
	var hull_mesh := SphereMesh.new()
	hull_mesh.radius = 4.5
	hull_mesh.height = 3.6
	hull_mesh.material = _hull_material
	hull.mesh = hull_mesh
	add_child(hull)

	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 6.5
	ring_mesh.bottom_radius = 6.5
	ring_mesh.height = 0.25
	ring_mesh.material = Fx.glow_material(RING_COLOR)
	ring.mesh = ring_mesh
	add_child(ring)

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.1
	core_mesh.height = 2.2
	core_mesh.material = Fx.glow_material(CORE_COLOR)
	core.mesh = core_mesh
	core.position = Vector3(0.0, -1.8, 0.0)
	add_child(core)

	_shield_mesh = MeshInstance3D.new()
	var shield := SphereMesh.new()
	shield.radius = 7.2
	shield.height = 14.4
	var shield_material := StandardMaterial3D.new()
	shield_material.albedo_color = Color(0.3, 0.88, 1.0, 0.18)
	shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield.material = shield_material
	_shield_mesh.mesh = shield
	add_child(_shield_mesh)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_angle += ORBIT_SPEED * delta
	global_position = _orbit_position()
	rotation.y += delta * 0.3

	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 0.4
		_pick_target()
		_update_shield()

	var phase := _phase()
	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0 and _target != null:
		_fire_cooldown = FIRE_INTERVALS[phase]
		_fire_volley(phase)

	_launch_timer -= delta
	if _launch_timer <= 0.0:
		_launch_timer = LAUNCH_INTERVALS[phase]
		if _escort_count() < MAX_ESCORTS[phase]:
			_launch_escort(phase)


func _orbit_position() -> Vector3:
	return _center + Vector3(cos(_angle) * ORBIT_RADIUS, ALTITUDE, sin(_angle) * ORBIT_RADIUS)


## 0, 1 or 2.
func _phase() -> int:
	var fraction := float(health) / max_health
	if fraction > 0.66:
		return 0
	if fraction > 0.33:
		return 1
	return 2


func phase_number() -> int:
	return _phase() + 1


func _pick_target() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		_target = player
		return
	_target = get_tree().get_first_node_in_group("base") as Node3D


func _fire_volley(phase: int) -> void:
	var bolts := 3 if phase == 2 else 1
	for i in bolts:
		var aim := _target.global_position + Vector3(randf_range(-1.5, 1.5), 1.0, randf_range(-1.5, 1.5))
		if global_position.distance_to(aim) > FIRE_RANGE:
			return
		if _target.has_method("take_damage") and randf() < 0.6:
			_target.take_damage(BOLT_DAMAGE)
		Fx.tracer(self, global_position + Vector3(0.0, -2.0, 0.0), aim, RING_COLOR, 0.12)
	Sfx.play("alien_bolt", -6.0)


func _launch_escort(phase: int) -> void:
	var roll := randf()
	var escort: CharacterBody3D
	if phase == 2 and roll < 0.35:
		escort = HeavyScript.new()
	elif phase >= 1 and roll < 0.6:
		escort = SoldierScript.new()
	else:
		escort = FlyerScript.new()
	escort.position = Vector3(global_position.x + randf_range(-3.0, 3.0), 0.2, global_position.z + randf_range(-3.0, 3.0))
	get_tree().current_scene.add_child(escort)
	_escorts.append(escort)
	Sfx.play("radio", -10.0)


func _escort_count() -> int:
	var alive: Array[Node] = []
	for escort in _escorts:
		if is_instance_valid(escort) and escort.is_in_group("enemies"):
			alive.append(escort)
	_escorts = alive
	return alive.size()


func _update_shield() -> void:
	shielded = _escort_count() > 0
	_shield_mesh.visible = shielded


# --- Damage ---

func take_hit(damage: int) -> void:
	if _dead:
		return
	var factor := SHIELD_FACTOR if shielded else 1.0
	health -= maxi(1, roundi(damage * factor))
	Sfx.play("hit", -12.0)
	_hull_material.albedo_color = Color.WHITE
	get_tree().create_timer(0.08).timeout.connect(_restore_color)
	if health <= 0:
		_die()


func _restore_color() -> void:
	if not _dead:
		_hull_material.albedo_color = HULL_COLOR


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	_shape.set_deferred("disabled", true)
	_shield_mesh.visible = false
	for escort in _escorts:
		if is_instance_valid(escort) and escort.has_method("take_hit"):
			escort.take_hit(9999)
	died.emit()
	EventBus.enemy_killed.emit("mothership")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 1.2)
	tween.tween_callback(queue_free)
