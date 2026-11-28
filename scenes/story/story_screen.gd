extends Control
## Plain full-screen page reader used for the intro, the radio log, colony status and
## the endings. Reads its content from GameManager.pending_story:
##   pages    Array of strings
##   title    shown at the top
##   return   scene to go to afterwards (default: the hub)
##   done     key passed to GameManager.finish_story when the last page is closed
##   choices  optional: [{label, key}]. Shown on the last page instead of Done.

const MAIN_SCENE := "res://scenes/levels/main.tscn"

var _pages: Array = []
var _index := 0
var _story: Dictionary = {}
var _title: Label
var _body: Label
var _counter: Label
var _next: Button
var _choices: VBoxContainer


func _ready() -> void:
	_story = GameManager.pending_story
	GameManager.pending_story = {}
	_pages = _story.get("pages", ["(nothing here yet)"])

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.09)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	_title = Label.new()
	_title.text = str(_story.get("title", ""))
	_title.add_theme_font_size_override("font_size", 26)
	_title.modulate = Color(0.3, 0.88, 1.0)
	root.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("font_size", 28)
	root.add_child(_body)

	_counter = Label.new()
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_counter)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 10)
	root.add_child(_choices)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	root.add_child(row)
	var skip := Button.new()
	skip.text = "Skip"
	skip.custom_minimum_size = Vector2(160, 64)
	skip.pressed.connect(_finish)
	row.add_child(skip)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(0, 64)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(_advance)
	row.add_child(_next)

	_show_page()


func _show_page() -> void:
	_body.text = str(_pages[_index])
	_counter.text = "%d / %d" % [_index + 1, _pages.size()]
	var last := _index >= _pages.size() - 1
	var choices: Array = _story.get("choices", [])
	_next.visible = not (last and not choices.is_empty())
	_next.text = "Done" if last else "Next"
	for child in _choices.get_children():
		child.queue_free()
	if last and not choices.is_empty():
		for choice in choices:
			var button := Button.new()
			button.text = str(choice["label"])
			button.custom_minimum_size = Vector2(0, 64)
			button.pressed.connect(_choose.bind(str(choice["key"])))
			_choices.add_child(button)


func _advance() -> void:
	if _index >= _pages.size() - 1:
		_finish()
		return
	_index += 1
	_show_page()


func _choose(key: String) -> void:
	GameManager.choose_ending(key)
	get_tree().reload_current_scene()


func _finish() -> void:
	GameManager.finish_story(str(_story.get("done", "")))
	get_tree().change_scene_to_file(str(_story.get("return", MAIN_SCENE)))
