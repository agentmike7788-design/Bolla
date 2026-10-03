class_name ShopPanel
extends UIPanel
## &"shop" – a village shop (docs/PHASE7_DESIGN.md §2.3, §7): context {shop_id, speaker, inventory, player}
## (ShopCounter, dialogue action open_shop). Parchment like Ilse's panel: the head names the person with
## the relationship as a word and five dots; two columns „Kaufen" (VillageShops.offers) and „Verkaufen"
## (VillageShops.wants), each row with icon, name, price (the base price struck through for a discount,
## „+1 (Ruf)" for the surcharge), today's stock / how many the shop still takes, „du hast 6", buttons
## 1 / 5 (Umschalt + Klick on 1 = 5), dimmed with the system's reason. Coins change hands at once through
## VillageShops.buy / sell (atomic there); the panel changes nothing itself.

const SHOPS_GROUP := &"village_shops"
const RELATIONSHIPS_GROUP := &"relationships"
const COIN_ITEM := &"coin"
const MANY := 5

@export var panel_width: float = 1280.0
@export var icon_edge: float = 44.0

var shops: VillageShops
var shop_id: StringName = &""
var title_label: Label
var person_label: Label
var rel_label: Label
var coins_label: Label
var reply_label: Label
var closed_label: Label
## item -> {row, price (RichTextLabel), surcharge, stock, held, one, five, reason}
var buy_rows: Dictionary[StringName, Dictionary] = {}
var sell_rows: Dictionary[StringName, Dictionary] = {}
var reply: String = ""

var _buy_box: VBoxContainer
var _sell_box: VBoxContainer
var _buy_empty: Label
var _sell_empty: Label
var _inventory: Inventory


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	var head := UIKit.hbox(16)
	var titles := UIKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label = UIKit.label("", &"HeaderLabel")
	titles.add_child(title_label)
	var who := UIKit.hbox(14)
	person_label = UIKit.label("", &"SubheaderLabel")
	who.add_child(person_label)
	rel_label = UIKit.label("", &"AccentLabel")
	rel_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(rel_label)
	titles.add_child(who)
	head.add_child(titles)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	box.add_child(UIKit.separator())
	var columns := UIKit.hbox(24)
	box.add_child(columns)
	_buy_box = _column(columns, Phase7Texts.SHOP_BUY)
	_sell_box = _column(columns, Phase7Texts.SHOP_SELL)
	_buy_empty = UIKit.label(Phase7Texts.SHOP_NOTHING_SOLD, &"DimLabel")
	_buy_box.add_child(_buy_empty)
	_sell_empty = UIKit.label(Phase7Texts.SHOP_NOTHING_BOUGHT, &"DimLabel")
	_sell_box.add_child(_sell_empty)
	reply_label = UIKit.label("", &"WhisperLabel", true)
	reply_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(reply_label)
	closed_label = UIKit.label(Phase7Texts.SHOP_CLOSED, &"WarningLabel")
	box.add_child(closed_label)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	coins_label = UIKit.label("", &"SubheaderLabel")
	coins_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(coins_label)
	var hint := UIKit.label(Phase7Texts.SHOP_HINT, &"DimLabel")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(hint)
	var back := UIKit.button(TEXT_CLOSE)
	back.pressed.connect(request_close)
	bottom.add_child(back)
	box.add_child(bottom)


func _column(parent: Container, title: String) -> VBoxContainer:
	var section := UIKit.panel(&"SectionPanel")
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var inner := UIKit.vbox(8)
	inner.add_child(UIKit.label(title, &"AccentLabel"))
	section.add_child(inner)
	parent.add_child(section)
	return inner


func _on_opened() -> void:
	shops = get_tree().get_first_node_in_group(SHOPS_GROUP) as VillageShops if is_inside_tree() else null
	shop_id = StringName(str(context.get("shop_id", "")))
	reply = ""
	_inventory = _resolve_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)
	_rebuild_rows()


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


func _rebuild_rows() -> void:
	for d: Dictionary in [buy_rows, sell_rows]:
		for id: StringName in d:
			(d[id].row as Node).queue_free()
	buy_rows.clear()
	sell_rows.clear()
	var data := shop_data()
	if data == null:
		return
	for item: StringName in data.sells:
		buy_rows[item] = _row(_buy_box, item, true)
	for item: StringName in data.buys:
		sell_rows[item] = _row(_sell_box, item, false)
	_buy_box.move_child(_buy_empty, _buy_box.get_child_count() - 1)
	_sell_box.move_child(_sell_empty, _sell_box.get_child_count() - 1)


func _row(parent: VBoxContainer, item: StringName, buying: bool) -> Dictionary:
	var row := UIKit.panel(&"TradeRowPanel")
	var line := UIKit.hbox(10)
	line.add_child(UIKit.icon(Database.icon(item), icon_edge))
	var names := UIKit.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UIKit.label(UIKit.item_name(item), &""))
	var info := UIKit.hbox(10)
	var price := RichTextLabel.new()
	price.bbcode_enabled = true
	price.fit_content = true
	price.scroll_active = false
	price.autowrap_mode = TextServer.AUTOWRAP_OFF
	price.custom_minimum_size.x = 120.0
	price.theme_type_variation = &"DimRichLabel"
	price.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(price)
	var surcharge := UIKit.label("", &"WarningLabel")
	info.add_child(surcharge)
	var stock := UIKit.label("", &"DimLabel")
	info.add_child(stock)
	var held := UIKit.label("", &"DimLabel")
	info.add_child(held)
	names.add_child(info)
	var reason := UIKit.label("", &"DimLabel")
	names.add_child(reason)
	line.add_child(names)
	var one := UIKit.button(Phase7Texts.SHOP_ONE)
	one.custom_minimum_size.x = 52.0
	one.gui_input.connect(_on_one_input.bind(item, buying))
	one.pressed.connect(_trade.bind(item, 1, buying))
	line.add_child(one)
	var five := UIKit.button(Phase7Texts.SHOP_FIVE, &"AccentButton")
	five.custom_minimum_size.x = 52.0
	five.pressed.connect(_trade.bind(item, MANY, buying))
	line.add_child(five)
	row.add_child(line)
	parent.add_child(row)
	return {"row": row, "price": price, "surcharge": surcharge, "stock": stock, "held": held, "one": one, "five": five,
			"reason": reason}


func _refresh() -> void:
	var data := shop_data()
	var speaker: Variant = context.get("speaker")
	var npc_id := data.npc_id if data != null else &""
	title_label.text = data.title if data != null and data.title != "" else Phase7Texts.SHOP_TITLE_FALLBACK
	person_label.text = Phase7Texts.person_name(npc_id) if npc_id != &"" else (str((speaker as Node).get(&"display_name")) if is_instance_valid(speaker) else "")
	var rel := _relationships()
	rel_label.text = Phase7Texts.rel_line(rel.value(npc_id), rel.tier(npc_id)) if rel != null and npc_id != &"" and rel.met(npc_id) else ""
	var inv := _inventory
	var open := shops != null and shops.is_open(shop_id)
	for item: StringName in buy_rows:
		var r: Dictionary = buy_rows[item]
		var base := ShopRules.row_price(data.sells[item]) if data != null else 0
		var p := shops.sell_price(shop_id, item) if shops != null else base
		var shown := Phase7Texts.shop_price(base, p)
		(r.price as RichTextLabel).text = str(shown.bb)
		(r.price as RichTextLabel).tooltip_text = Phase7Texts.SHOP_DISCOUNT_TIP if bool(shown.discount) else ""
		(r.surcharge as Label).text = str(shown.surcharge)
		(r.surcharge as Label).visible = str(shown.surcharge) != ""
		var left := shops.stock_left(shop_id, item) if shops != null else 0
		(r.stock as Label).text = Phase7Texts.stock_text(left)
		(r.stock as Label).theme_type_variation = &"DimLabel" if left > 0 else &"WarningLabel"
		(r.held as Label).text = Phase7Texts.SHOP_HELD % (inv.count(item) if inv != null else 0)
		var reason := buy_reason(item, 1)
		_set_buttons(r, reason, buy_reason(item, MANY), open)
		(r.row as Control).visible = reason != ShopRules.TEXT_TIER
	for item: StringName in sell_rows:
		var r: Dictionary = sell_rows[item]
		var p := shops.buy_price(shop_id, item) if shops != null else ShopRules.row_price(data.buys[item])
		(r.price as RichTextLabel).text = Phase7Texts.SHOP_PRICE % [p, Phase7Texts.coins(p)]
		(r.surcharge as Label).visible = false
		var left := shops.bought_left(shop_id, item) if shops != null else 0
		(r.stock as Label).text = Phase7Texts.bought_text(left)
		(r.stock as Label).theme_type_variation = &"DimLabel" if left > 0 else &"WarningLabel"
		var n := inv.count(item) if inv != null else 0
		(r.held as Label).text = Phase7Texts.SHOP_HELD % n
		(r.held as Label).theme_type_variation = &"GoodLabel" if n > 0 else &"DimLabel"
		_set_buttons(r, sell_reason(item, 1), sell_reason(item, MANY), open)
	_buy_empty.visible = buy_rows.is_empty()
	_sell_empty.visible = sell_rows.is_empty()
	coins_label.text = Phase7Texts.SHOP_COINS % (inv.count(COIN_ITEM) if inv != null else 0)
	reply_label.text = reply
	reply_label.visible = reply != ""
	closed_label.visible = not open


func _set_buttons(r: Dictionary, reason_one: String, reason_five: String, open: bool) -> void:
	var one := r.one as Button
	var five := r.five as Button
	one.disabled = action_running or reason_one != ""
	one.tooltip_text = reason_one
	five.disabled = action_running or reason_five != ""
	five.tooltip_text = reason_five
	var shown := reason_one if open and reason_one != VillageShops.TEXT_CLOSED else ""
	(r.reason as Label).text = shown
	(r.reason as Label).visible = shown != ""


# --- actions ---------------------------------------------------------------------------------------

## "" or why `n` × `item` cannot be bought now (VillageShops.buy_block_reason).
func buy_reason(item: StringName, n: int) -> String:
	if shops == null:
		return VillageShops.TEXT_CLOSED
	return shops.buy_block_reason(shop_id, item, n, _inventory)


func sell_reason(item: StringName, n: int) -> String:
	if shops == null:
		return VillageShops.TEXT_CLOSED
	return shops.sell_block_reason(shop_id, item, n, _inventory)


## Buys `n` × `item` (VillageShops.buy, atomic). Returns success.
func buy(item: StringName, n: int = 1) -> bool:
	if shops == null or _inventory == null:
		return false
	var reason := buy_reason(item, n)
	if reason != "":
		reply = reason
		refresh()
		return false
	var ok := shops.buy(shop_id, item, n, _inventory)
	reply = Phase7Texts.SHOP_AFTER_BUY if ok else buy_reason(item, n)
	refresh()
	return ok


## Sells `n` × `item` (VillageShops.sell, atomic). Returns the coins paid.
func sell(item: StringName, n: int = 1) -> int:
	if shops == null or _inventory == null:
		return 0
	var reason := sell_reason(item, n)
	if reason != "":
		reply = reason
		refresh()
		return 0
	var coins := shops.sell(shop_id, item, n, _inventory)
	reply = Phase7Texts.SHOP_AFTER_SELL if coins > 0 else sell_reason(item, n)
	refresh()
	return coins


func shop_data() -> ShopData:
	if shops != null:
		return shops.shop(shop_id)
	return Database.shop(shop_id) as ShopData


func _trade(item: StringName, n: int, buying: bool) -> void:
	if buying:
		buy(item, n)
	else:
		sell(item, n)


## Umschalt + Klick on „1" trades five.
func _on_one_input(event: InputEvent, item: StringName, buying: bool) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed:
		_trade(item, MANY, buying)
		get_viewport().set_input_as_handled()


func _relationships() -> Relationships:
	return get_tree().get_first_node_in_group(RELATIONSHIPS_GROUP) as Relationships if is_inside_tree() else null


func _resolve_inventory() -> Inventory:
	var inv := _player_inventory()
	if inv != null:
		return inv
	var p := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	return p.get(&"inventory") as Inventory if p != null else null
