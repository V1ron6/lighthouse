extends Control
## Test screen. Shows the game state and has buttons to try the
## autoloads. Replaced by the real menu and test arena in later stages.

var _label: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 30)
	box.add_child(_label)

	_add_button(box, "Defend the lighthouse", func(): get_tree().change_scene_to_file("res://scenes/base/base_defence.tscn"))
	_add_button(box, "Start test arena", func(): get_tree().change_scene_to_file("res://scenes/levels/test_arena.tscn"))
	_add_button(box, "+100 points", func(): GameManager.add_points(100))
	_add_button(box, "-100 points (demotion test)", func(): GameManager.remove_points(100))
	_add_button(box, "Spend 500 qubits", func(): GameManager.spend_qubits(500))
	_add_button(box, "Attack base (-150 health)", func(): _attack_base())
	_add_button(box, "Save game", func(): GameManager.save_game())
	_add_button(box, "New game", func(): GameManager.new_game())

	EventBus.qubits_changed.connect(_refresh)
	EventBus.points_changed.connect(_refresh)
	EventBus.rank_changed.connect(_refresh)
	EventBus.base_health_changed.connect(_refresh)
	EventBus.core_integrity_changed.connect(_refresh)
	_refresh()


func _attack_base() -> void:
	GameManager.trigger_base_attack(150)
	GameManager.damage_base(150)


func _add_button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 60)
	button.pressed.connect(action)
	parent.add_child(button)


func _refresh(_a: Variant = null, _b: Variant = null) -> void:
	_label.text = "LIGHTHOUSE  |  Stage 4\nRank: %s  (%d pts, %d to next)\nQubits: %d\nBase: %d/%d   Core: %d/%d" % [
		GameManager.get_rank_name(),
		GameManager.points,
		GameManager.points_to_next_rank(),
		GameManager.qubits,
		GameManager.base_health,
		GameManager.MAX_BASE_HEALTH,
		GameManager.core_integrity,
		GameManager.MAX_CORE_INTEGRITY,
	]
