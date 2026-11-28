extends Control
## Mission list. Pick a mission, check base status, repair the base.

const MissionData := preload("res://data/mission_data.gd")

var _status: Label
var _repair_button: Button
## Each entry: {"button": Button, "mission": Dictionary}
var _mission_buttons: Array = []


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "MISSIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	box.add_child(_status)

	for mission in MissionData.MISSIONS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(620, 100)
		button.pressed.connect(_start_mission.bind(mission["id"]))
		box.add_child(button)
		_mission_buttons.append({"button": button, "mission": mission})

	_repair_button = Button.new()
	_repair_button.custom_minimum_size = Vector2(620, 56)
	_repair_button.pressed.connect(_repair)
	box.add_child(_repair_button)

	var back := Button.new()
	back.text = "Back to menu"
	back.custom_minimum_size = Vector2(620, 56)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/levels/main.tscn"))
	box.add_child(back)

	EventBus.qubits_changed.connect(_refresh)
	EventBus.points_changed.connect(_refresh)
	EventBus.rank_changed.connect(_refresh)
	EventBus.base_health_changed.connect(_refresh)
	EventBus.core_integrity_changed.connect(_refresh)
	_refresh()


func _refresh(_a: Variant = null, _b: Variant = null) -> void:
	_status.text = "%s  (%d pts)   |   %d qubits\nBase %d/%d   Core %d/%d" % [
		GameManager.get_rank_name(), GameManager.points, GameManager.qubits,
		GameManager.base_health, GameManager.MAX_BASE_HEALTH,
		GameManager.core_integrity, GameManager.MAX_CORE_INTEGRITY,
	]

	for entry in _mission_buttons:
		var mission: Dictionary = entry["mission"]
		var button: Button = entry["button"]
		var text := "%s  [%s]   (Risk %d/3)\n%s\nReward: %d qubits, %d points" % [
			mission["name"], String(mission["type"]).to_upper(), mission["risk"], mission["description"],
			mission["reward_qubits"], mission["reward_points"],
		]
		var locked: bool = GameManager.rank_index < int(mission["min_rank"])
		if locked:
			text += "\nRequires rank: %s" % GameManager.RANK_NAMES[int(mission["min_rank"])]
		button.text = text
		button.disabled = locked

	var cost := GameManager.repair_cost()
	if cost == 0:
		_repair_button.text = "Base is fully repaired"
	else:
		_repair_button.text = "Repair base and core (%d qubits)" % cost
	_repair_button.disabled = cost == 0 or GameManager.qubits < cost


func _repair() -> void:
	GameManager.repair_all()
	GameManager.save_game()


func _start_mission(mission_id: String) -> void:
	GameManager.start_mission(mission_id)
	get_tree().change_scene_to_file("res://scenes/missions/mission_level.tscn")
