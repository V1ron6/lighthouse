extends CanvasLayer
## Shared in-game HUD: touch controls, rank and qubits, a status line,
## heat bar, damage flash, banner messages, Back button and a game-over panel.
## Keeps working while the game is paused.

signal back_pressed
## A button on the centre panel was pressed. Index follows the labels given to show_panel.
signal panel_choice(index: int)
## The context button (board the jet, land) was pressed.
signal action_pressed

const TouchScene := preload("res://scenes/ui/touch_controls.tscn")

## The touch controls node. Hand this to the player as `touch`.
var touch: Control

var _flash: ColorRect
var _heat_bar: ProgressBar
var _info: Label
var _status: Label
var _banner: Label
var _banner_tween: Tween
var _action_button: Button
var _over_panel: ColorRect
var _over_label: Label
var _over_buttons: VBoxContainer
var _last_health := 100


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.start_ambience()

	touch = TouchScene.instantiate()
	add_child(touch)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1.0, 0.1, 0.1, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_heat_bar = ProgressBar.new()
	_heat_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_heat_bar.offset_left = -150.0
	_heat_bar.offset_right = 150.0
	_heat_bar.offset_top = 24.0
	_heat_bar.offset_bottom = 40.0
	_heat_bar.max_value = 100.0
	_heat_bar.show_percentage = false
	_heat_bar.modulate = Color(0.3, 0.88, 1.0)
	add_child(_heat_bar)

	_info = Label.new()
	_info.position = Vector2(24, 20)
	_info.add_theme_font_size_override("font_size", 22)
	add_child(_info)

	_status = Label.new()
	_status.position = Vector2(24, 54)
	_status.add_theme_font_size_override("font_size", 22)
	add_child(_status)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 110.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

	var back := _make_button("Back", func(): back_pressed.emit())
	back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -170.0
	back.offset_right = -20.0
	back.offset_top = 20.0
	back.offset_bottom = 76.0
	add_child(back)

	_action_button = _make_button("", func(): action_pressed.emit())
	_action_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_action_button.offset_left = -160.0
	_action_button.offset_right = 160.0
	_action_button.offset_top = -170.0
	_action_button.offset_bottom = -106.0
	_action_button.visible = false
	add_child(_action_button)

	_build_panel()

	EventBus.qubits_changed.connect(_refresh_info)
	EventBus.points_changed.connect(_refresh_info)
	EventBus.rank_changed.connect(_refresh_info)
	EventBus.rank_changed.connect(_on_rank_changed)
	EventBus.radio_message.connect(_on_radio_message)
	_refresh_info()


func _exit_tree() -> void:
	Sfx.stop_ambience()


## Connect the player's health and rifle heat to the HUD.
func bind_player(player) -> void:
	player.health_changed.connect(_on_player_health_changed)
	player.rifle.heat_changed.connect(_on_heat_changed)
	_last_health = player.health


func set_status(text: String) -> void:
	_status.text = text


## A button at the bottom centre for the thing you can do right now.
func show_action(text: String) -> void:
	_action_button.text = text
	_action_button.visible = true


func hide_action() -> void:
	_action_button.visible = false


func show_banner(text: String, seconds: float = 2.0) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func show_game_over(text: String) -> void:
	show_panel(text, ["Try again", "Back to menu"])


## Centre panel with a message and one button per label. Releases the mouse.
func show_panel(text: String, labels: Array) -> void:
	_over_label.text = text
	for child in _over_buttons.get_children():
		child.queue_free()
	for i in labels.size():
		var index := i
		_over_buttons.add_child(_make_button(labels[i], func(): _on_panel_button(index)))
	_over_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_panel_button(index: int) -> void:
	_over_panel.visible = false
	panel_choice.emit(index)


func _build_panel() -> void:
	_over_panel = ColorRect.new()
	_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_panel.color = Color(0.0, 0.0, 0.0, 0.7)
	_over_panel.visible = false
	add_child(_over_panel)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 20)
	_over_panel.add_child(box)

	_over_label = Label.new()
	_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_label.add_theme_font_size_override("font_size", 30)
	box.add_child(_over_label)

	_over_buttons = VBoxContainer.new()
	_over_buttons.add_theme_constant_override("separation", 14)
	box.add_child(_over_buttons)


func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 64)
	button.pressed.connect(action)
	return button


func _refresh_info(_a: Variant = null, _b: Variant = null) -> void:
	var to_next := GameManager.points_to_next_rank()
	var progress := "MAX" if to_next == 0 else "%d to next" % to_next
	_info.text = "%s (%s)   |   %d qubits" % [GameManager.get_rank_name(), progress, GameManager.qubits]


func _on_radio_message(title: String) -> void:
	show_banner("RADIO: " + title, 4.0)


func _on_rank_changed(new_index: int, old_index: int) -> void:
	var word := "PROMOTED" if new_index > old_index else "DEMOTED"
	show_banner("%s: %s" % [word, GameManager.RANK_NAMES[new_index]], 3.0)


func _on_player_health_changed(current: int, maximum: int) -> void:
	if current < _last_health:
		_flash.color.a = 0.35
		create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
	_last_health = current


func _on_heat_changed(heat: float, overheated: bool) -> void:
	_heat_bar.value = heat
	_heat_bar.modulate = Color(1.0, 0.3, 0.3) if overheated else Color(0.3, 0.88, 1.0)
