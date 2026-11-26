extends Control
## On-screen controls for phones:
##   left side  - floating move joystick (appears where the thumb lands)
##   right side - drag anywhere to look around
##   fire button - bottom right
## Shown automatically on devices with a touchscreen.

@export var force_show: bool = false

const JOY_RADIUS := 110.0
const KNOB_RADIUS := 44.0
const FIRE_RADIUS := 80.0
## Left of this fraction of the screen width is the joystick zone.
const SPLIT := 0.45

## Same convention as Input.get_vector: x right, y positive is backward.
var move_vector := Vector2.ZERO
var fire_held := false

var _look_accum := Vector2.ZERO
var _move_finger := -1
var _look_finger := -1
var _fire_finger := -1
var _joy_origin := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = force_show or DisplayServer.is_touchscreen_available()
	resized.connect(queue_redraw)


## Look movement collected since the last call, in pixels.
func consume_look() -> Vector2:
	var delta := _look_accum
	_look_accum = Vector2.ZERO
	return delta


func _fire_center() -> Vector2:
	return Vector2(size.x - 170.0, size.y - 170.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_drag(drag.index, drag.position, drag.relative)


func _press(index: int, pos: Vector2) -> void:
	if _fire_finger == -1 and pos.distance_to(_fire_center()) <= FIRE_RADIUS * 1.25:
		_fire_finger = index
		fire_held = true
	elif _move_finger == -1 and pos.x < size.x * SPLIT:
		_move_finger = index
		_joy_origin = pos
		move_vector = Vector2.ZERO
	elif _look_finger == -1 and pos.x >= size.x * SPLIT:
		_look_finger = index
	queue_redraw()


func _release(index: int) -> void:
	if index == _fire_finger:
		_fire_finger = -1
		fire_held = false
	elif index == _move_finger:
		_move_finger = -1
		move_vector = Vector2.ZERO
	elif index == _look_finger:
		_look_finger = -1
	queue_redraw()


func _drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _move_finger:
		move_vector = ((pos - _joy_origin) / JOY_RADIUS).limit_length(1.0)
	elif index == _look_finger:
		_look_accum += relative
	queue_redraw()


func _draw() -> void:
	var cyan := Color(0.3, 0.88, 1.0)
	var amber := Color(1.0, 0.8, 0.4)

	# Crosshair
	var c := size / 2.0
	var cross := Color(cyan.r, cyan.g, cyan.b, 0.85)
	draw_line(c + Vector2(-14, 0), c + Vector2(-5, 0), cross, 2.0)
	draw_line(c + Vector2(5, 0), c + Vector2(14, 0), cross, 2.0)
	draw_line(c + Vector2(0, -14), c + Vector2(0, -5), cross, 2.0)
	draw_line(c + Vector2(0, 5), c + Vector2(0, 14), cross, 2.0)

	# Joystick (faint hint when idle)
	var active := _move_finger != -1
	var origin := _joy_origin if active else Vector2(200.0, size.y - 200.0)
	var a := 0.35 if active else 0.15
	draw_circle(origin, JOY_RADIUS, Color(cyan.r, cyan.g, cyan.b, a * 0.4))
	draw_arc(origin, JOY_RADIUS, 0.0, TAU, 48, Color(cyan.r, cyan.g, cyan.b, a + 0.15), 3.0)
	draw_circle(origin + move_vector * JOY_RADIUS, KNOB_RADIUS, Color(cyan.r, cyan.g, cyan.b, a + 0.2))

	# Fire button
	var fc := _fire_center()
	var fa := 0.55 if fire_held else 0.25
	draw_circle(fc, FIRE_RADIUS, Color(amber.r, amber.g, amber.b, fa * 0.6))
	draw_arc(fc, FIRE_RADIUS, 0.0, TAU, 48, Color(amber.r, amber.g, amber.b, fa + 0.3), 4.0)
	draw_circle(fc, 14.0, Color(amber.r, amber.g, amber.b, fa + 0.3))
