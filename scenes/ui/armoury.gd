extends Control
## Armoury: every item, grouped by type, with the rank it needs.
## Shows what the player owns and what is still locked. Buying comes in Stage 7.

const ItemData := preload("res://data/item_data.gd")
const TYPE_TITLES := {"weapon": "WEAPONS", "defence": "LIGHTHOUSE DEFENCES", "vehicle": "VEHICLES"}

var _list: VBoxContainer
var _header: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 28)
	root.add_child(_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 64)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/levels/main.tscn"))
	root.add_child(back)

	_rebuild()


func _rebuild() -> void:
	_header.text = "ARMOURY  |  %s  |  turret slots: %d" % [GameManager.get_rank_name(), GameManager.max_turrets()]
	for child in _list.get_children():
		child.queue_free()
	for type in ItemData.TYPE_ORDER:
		var title := Label.new()
		title.text = TYPE_TITLES[type]
		title.add_theme_font_size_override("font_size", 22)
		title.modulate = Color(0.3, 0.88, 1.0)
		_list.add_child(title)
		for id in ItemData.ids_of_type(type):
			_list.add_child(_make_row(id))


func _make_row(id: String) -> Label:
	var info := ItemData.get_item(id)
	var need: int = info["min_rank"]
	var owned: int = GameManager.inventory.get(id, 0)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	var status := ""
	if GameManager.rank_index < need:
		status = "LOCKED - needs %s" % GameManager.RANK_NAMES[need]
		label.modulate = Color(0.55, 0.55, 0.6)
	elif owned > 0:
		status = "owned x%d - ready" % owned
	else:
		status = "unlocked - not owned"
	if owned > 0 and GameManager.rank_index < need:
		status += " (owned x%d, rank too low)" % owned
	label.text = "  %s   |   %d qubits   |   %s" % [info["name"], info["price"], status]
	return label
