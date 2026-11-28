extends Control
## Hub. Shows the game state and leads to everything. The right-hand column holds
## test buttons that will go away before release.

const StoryData := preload("res://data/story_data.gd")
const ColonyData := preload("res://data/colony_data.gd")

var _label: Label


func _ready() -> void:
	# First launch: show the intro story first.
	if not GameManager.has_seen_intro:
		GameManager.call_deferred("open_story", StoryData.INTRO_PAGES, "HOW IT CAME TO THIS", "intro")
		return

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	root.add_child(_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	root.add_child(columns)
	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 8)
	columns.add_child(main_col)
	var test_col := VBoxContainer.new()
	test_col.add_theme_constant_override("separation", 8)
	columns.add_child(test_col)

	_add_button(main_col, "Missions", func(): get_tree().change_scene_to_file("res://scenes/missions/mission_select.tscn"))
	_add_button(main_col, "Market", func(): get_tree().change_scene_to_file("res://scenes/ui/market.tscn"))
	_add_button(main_col, "Armoury", func(): get_tree().change_scene_to_file("res://scenes/ui/armoury.tscn"))
	_add_button(main_col, "Defend the lighthouse (hangar and jet)", func(): get_tree().change_scene_to_file("res://scenes/base/base_defence.tscn"))
	_add_button(main_col, "Radio log", _open_radio_log)
	_add_button(main_col, "Colonies", _open_colonies)
	if GameManager.can_make_final_choice():
		_add_button(main_col, "FINAL TRANSMISSION", _open_final)

	_add_button(test_col, "Start test arena", func(): get_tree().change_scene_to_file("res://scenes/levels/test_arena.tscn"))
	_add_button(test_col, "+100 points", func(): GameManager.add_points(100))
	_add_button(test_col, "-100 points (demotion test)", func(): GameManager.remove_points(100))
	_add_button(test_col, "Spend 500 qubits", func(): GameManager.spend_qubits(500))
	_add_button(test_col, "Attack base (-150 health)", func(): _attack_base())
	_add_button(test_col, "Save game", func(): GameManager.save_game())
	_add_button(test_col, "New game", func(): _new_game())

	EventBus.qubits_changed.connect(_refresh)
	EventBus.points_changed.connect(_refresh)
	EventBus.rank_changed.connect(_refresh)
	EventBus.base_health_changed.connect(_refresh)
	EventBus.core_integrity_changed.connect(_refresh)
	_refresh()


func _new_game() -> void:
	GameManager.new_game()
	get_tree().reload_current_scene()


func _attack_base() -> void:
	GameManager.trigger_base_attack(150)
	GameManager.damage_base(150)


func _open_radio_log() -> void:
	var pages: Array = []
	for i in range(GameManager.radio_log.size() - 1, -1, -1):
		var entry: Dictionary = GameManager.radio_log[i]
		pages.append("%s\n\n%s" % [entry["title"], entry["text"]])
	if pages.is_empty():
		pages.append("No transmissions yet. Win a mission to hear from Command.")
	GameManager.open_story(pages, "RADIO LOG (newest first)")


func _open_colonies() -> void:
	var lines: Array[String] = []
	for id in ColonyData.ids():
		var colony := ColonyData.colony_name(id)
		if id in GameManager.fallen_colonies:
			var left: int = GameManager.RETAKE_AFTER - int(GameManager.colony_progress.get(id, 0))
			lines.append("%s: FALLEN (retaken after %d more won missions)" % [colony, left])
		else:
			lines.append("%s: standing" % colony)
	GameManager.open_story(["\n".join(lines)], "COLONIES  |  %d of %d standing" % [
		ColonyData.COLONIES.size() - GameManager.fallen_colonies.size(), ColonyData.COLONIES.size()])


func _open_final() -> void:
	GameManager.open_story(StoryData.FINAL_PAGES, "FINAL TRANSMISSION", "", [
		{"label": "Sever the Core", "key": "sever"},
		{"label": "Keep the light", "key": "keep"},
	])


func _add_button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(400, 52)
	button.pressed.connect(action)
	parent.add_child(button)


func _refresh(_a: Variant = null, _b: Variant = null) -> void:
	var ending_line := ""
	if GameManager.ending != "":
		ending_line = "   Ending reached: %s" % ("The Dark Dawn" if GameManager.ending == "sever" else "The Eternal Watch")
	_label.text = "LIGHTHOUSE  |  Stage 11\nRank: %s  (%d pts, %d to next)   Qubits: %d\nBase: %d/%d   Core: %d/%d   Colonies standing: %d/10%s" % [
		GameManager.get_rank_name(),
		GameManager.points,
		GameManager.points_to_next_rank(),
		GameManager.qubits,
		GameManager.base_health,
		GameManager.MAX_BASE_HEALTH,
		GameManager.core_integrity,
		GameManager.MAX_CORE_INTEGRITY,
		ColonyData.COLONIES.size() - GameManager.fallen_colonies.size(),
		ending_line,
	]
