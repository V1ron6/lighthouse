extends Control
## Market: buy and sell everything with a chosen colony, and set up automated
## trades that run once after every mission. Fallen colonies pay less and charge less.

const ItemData := preload("res://data/item_data.gd")
const ColonyData := preload("res://data/colony_data.gd")
const TYPE_TITLES := {
	"raw": "RAW GOODS (prices change)",
	"weapon": "WEAPONS",
	"defence": "LIGHTHOUSE DEFENCES",
	"crew": "CREW",
	"vehicle": "VEHICLES",
}
const SECTION_ORDER: Array[String] = ["raw", "weapon", "defence", "crew", "vehicle"]

var _colony_ids: Array[String] = []
var _colony_pick: OptionButton
var _header: Label
var _log: Label
var _list: VBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 26)
	root.add_child(_header)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var trade_with := Label.new()
	trade_with.text = "Trade with:"
	top.add_child(trade_with)
	_colony_pick = OptionButton.new()
	_colony_pick.custom_minimum_size = Vector2(300, 48)
	_colony_ids = ColonyData.ids()
	_colony_pick.item_selected.connect(func(_i): _rebuild())
	top.add_child(_colony_pick)
	_fill_colonies()

	_log = Label.new()
	_log.add_theme_font_size_override("font_size", 16)
	_log.modulate = Color(0.7, 0.85, 1.0)
	root.add_child(_log)

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


func _fill_colonies() -> void:
	_colony_pick.clear()
	for id in _colony_ids:
		var text := ColonyData.colony_name(id)
		if id in GameManager.fallen_colonies:
			text += " (fallen)"
		_colony_pick.add_item(text)


func _colony() -> String:
	var index := maxi(0, _colony_pick.selected)
	return _colony_ids[index]


func _rebuild() -> void:
	_header.text = "MARKET  |  %s  |  %d qubits  |  auto trades %d/%d" % [
		GameManager.get_rank_name(), GameManager.qubits,
		GameManager.trade_orders.size(), GameManager.MAX_TRADE_ORDERS,
	]
	_log.text = "\n".join(GameManager.last_trade_log) if not GameManager.last_trade_log.is_empty() else "Automated trades run once after each mission."
	for child in _list.get_children():
		child.queue_free()
	var colony := _colony()
	for type in SECTION_ORDER:
		var title := Label.new()
		title.text = TYPE_TITLES[type]
		title.add_theme_font_size_override("font_size", 20)
		title.modulate = Color(0.3, 0.88, 1.0)
		_list.add_child(title)
		for id in ItemData.ids_of_type(type):
			_list.add_child(_make_row(id, colony))


func _make_row(id: String, colony: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var owned: int = GameManager.inventory.get(id, 0)
	var need := ItemData.min_rank(id)
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text = "%s  x%d   buy %d / sell %d" % [
		ItemData.item_name(id), owned, GameManager.buy_price(id, colony), GameManager.sell_price(id, colony),
	]
	if need > 0:
		info.text += "   (use: %s)" % GameManager.RANK_NAMES[need]
	if GameManager.rank_index < need:
		info.modulate = Color(0.65, 0.65, 0.7)
	row.add_child(info)

	var buy := _small_button("Buy", _on_buy.bind(id, colony))
	buy.disabled = GameManager.qubits < GameManager.buy_price(id, colony)
	row.add_child(buy)

	var sell := _small_button("Sell", _on_sell.bind(id, colony))
	sell.disabled = owned <= 0
	row.add_child(sell)

	var order: Dictionary = GameManager.trade_orders.get(id, {})
	var mode: String = order.get("mode", "")
	var auto_text := "Auto: off"
	if mode == "buy":
		auto_text = "Auto: buy (%s)" % ColonyData.colony_name(order["colony"])
	elif mode == "sell":
		auto_text = "Auto: sell (%s)" % ColonyData.colony_name(order["colony"])
	var auto := _small_button(auto_text, _cycle_order.bind(id, mode, colony))
	auto.custom_minimum_size = Vector2(260, 48)
	row.add_child(auto)
	return row


func _on_buy(id: String, colony: String) -> void:
	GameManager.buy_item(id, colony)
	_rebuild()


func _on_sell(id: String, colony: String) -> void:
	GameManager.sell_item(id, colony)
	_rebuild()


## Off -> auto-buy -> auto-sell -> off, using the colony picked at the top.
func _cycle_order(id: String, mode: String, colony: String) -> void:
	var next := "buy" if mode == "" else ("sell" if mode == "buy" else "")
	if not GameManager.set_trade_order(id, next, colony):
		_log.text = "Auto trade list is full (%d). Turn one off first." % GameManager.MAX_TRADE_ORDERS
		return
	_rebuild()


func _small_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(90, 48)
	button.pressed.connect(action)
	return button
