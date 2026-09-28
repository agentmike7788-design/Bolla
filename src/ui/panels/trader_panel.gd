class_name TraderPanel
extends UIPanel
## &"trader" – Ilse Kranich's trade at the west wall (docs/PHASE4_DESIGN.md §2.6, §7, §14.2):
## context {speaker: Npc, inventory: Inventory} from the dialogue action open_panel:trader /
## open_trade (the player's inventory is used when "inventory" is missing). Opens over the
## dialogue; closing returns to it. Her greeting of the piety tier on top; left „Verkaufen“ –
## the goods she buys (UtilizationConfig.sell_prices) with her price incl. the piety bonus (the
## +1 shown quietly), „1 verkaufen“ / „Alle verkaufen“ and the sum; right „Kaufen“ – her small
## shop (TraderConfig.shop) with tonight's stock. Coins change hands at once through
## NightTrade.sell / buy; every button is off while she is not at the wall (is_present).
## After each trade one of her quiet lines. Never shows piety as a number.

const NIGHT_TRADE_GROUP := &"night_trade"
const PIETY_GROUP := &"piety"
const COIN_ITEM := &"coin"

@export var panel_width: float = 1240.0
@export var icon_edge: float = 46.0

var night_trade: Node
var greeting_label: Label
var reply_label: Label
var coins_label: Label
var sum_label: Label
var bonus_label: Label
var empty_label: Label
var away_label: Label
var back_button: Button
## item id -> {row, count, price, bonus, one, all}
var sell_rows: Dictionary[StringName, Dictionary] = {}
## item id -> {row, price, stock, buy}
var buy_rows: Dictionary[StringName, Dictionary] = {}
## Last reply of Ilse ("" = the greeting only).
var reply: String = ""

var _sell_box: VBoxContainer
var _buy_box: VBoxContainer


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(14)
	add_child(box)
	var head := UIKit.hbox(16)
	var titles := UIKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIKit.label(Phase4Texts.TRADE_TITLE, &"HeaderLabel"))
	titles.add_child(UIKit.label(Phase4Texts.TRADE_SUBTITLE, &"DimLabel"))
	head.add_child(titles)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	greeting_label = UIKit.label("", &"WhisperLabel", true)
	greeting_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(greeting_label)
	box.add_child(UIKit.separator())
	var columns := UIKit.hbox(24)
	box.add_child(columns)
	_sell_box = _column(columns, Phase4Texts.TRADE_SELL)
	_buy_box = _column(columns, Phase4Texts.TRADE_BUY)
	_build_sell_rows()
	_build_buy_rows()
	reply_label = UIKit.label("", &"WhisperLabel", true)
	reply_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(reply_label)
	away_label = UIKit.label(Phase4Texts.TRADE_AWAY, &"WarningLabel")
	box.add_child(away_label)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	coins_label = UIKit.label("", &"SubheaderLabel")
	coins_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(coins_label)
	var hint := UIKit.label(Phase4Texts.TRADE_HINT, &"DimLabel")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(hint)
	back_button = UIKit.button(TEXT_CLOSE)
	back_button.pressed.connect(request_close)
	bottom.add_child(back_button)
	box.add_child(bottom)


func _column(parent: Container, title: String) -> VBoxContainer:
	var section := UIKit.panel(&"SectionPanel")
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := UIKit.vbox(10)
	inner.add_child(UIKit.label(title, &"AccentLabel"))
	section.add_child(inner)
	parent.add_child(section)
	return inner


func _build_sell_rows() -> void:
	for id: StringName in _util().sell_prices:
		var row := UIKit.panel(&"TradeRowPanel")
		var line := UIKit.hbox(12)
		line.add_child(UIKit.icon(Database.icon(id), icon_edge))
		var names := UIKit.vbox(0)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var count := UIKit.label("", &"")
		names.add_child(count)
		var price_row := UIKit.hbox(6)
		var price := UIKit.label("", &"DimLabel")
		price_row.add_child(price)
		var bonus := UIKit.label("", &"GoodLabel")
		bonus.tooltip_text = Phase4Texts.TRADE_BONUS_LINE
		bonus.mouse_filter = Control.MOUSE_FILTER_PASS
		price_row.add_child(bonus)
		names.add_child(price_row)
		line.add_child(names)
		var one := UIKit.button(Phase4Texts.TRADE_SELL_ONE)
		one.pressed.connect(sell.bind(id, false))
		line.add_child(one)
		var all := UIKit.button(Phase4Texts.TRADE_SELL_ALL, &"AccentButton")
		all.pressed.connect(sell.bind(id, true))
		line.add_child(all)
		row.add_child(line)
		_sell_box.add_child(row)
		sell_rows[id] = {"row": row, "count": count, "price": price, "bonus": bonus, "one": one, "all": all}
	empty_label = UIKit.label(Phase4Texts.TRADE_NOTHING, &"DimLabel")
	_sell_box.add_child(empty_label)
	sum_label = UIKit.label("", &"SubheaderLabel")
	_sell_box.add_child(sum_label)
	bonus_label = UIKit.label(Phase4Texts.TRADE_BONUS_LINE, &"DimLabel")
	_sell_box.add_child(bonus_label)
	_sell_box.add_child(UIKit.label(Phase4Texts.TRADE_VALUABLES, &"DimLabel", true))


func _build_buy_rows() -> void:
	for id: StringName in _trader().shop:
		var row := UIKit.panel(&"TradeRowPanel")
		var line := UIKit.hbox(12)
		line.add_child(UIKit.icon(Database.icon(id), icon_edge))
		var names := UIKit.vbox(0)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_child(UIKit.label(UIKit.item_name(id), &""))
		var info := UIKit.hbox(12)
		var price := UIKit.label("", &"DimLabel")
		info.add_child(price)
		var stock := UIKit.label("", &"DimLabel")
		info.add_child(stock)
		names.add_child(info)
		line.add_child(names)
		var buy_button := UIKit.button(Phase4Texts.TRADE_BUY_ONE)
		buy_button.pressed.connect(buy.bind(id))
		line.add_child(buy_button)
		row.add_child(line)
		_buy_box.add_child(row)
		buy_rows[id] = {"row": row, "price": price, "stock": stock, "buy": buy_button}


func _on_opened() -> void:
	night_trade = get_tree().get_first_node_in_group(NIGHT_TRADE_GROUP) if is_inside_tree() else null
	reply = ""
	var inv := _player_inventory()
	if inv != null and not inv.changed.is_connected(refresh):
		inv.changed.connect(refresh)


func _on_closed() -> void:
	var inv := _player_inventory()
	if inv != null and inv.changed.is_connected(refresh):
		inv.changed.disconnect(refresh)


func _refresh() -> void:
	var inv := _player_inventory()
	var present := is_present()
	var greet := str(night_trade.call(&"greeting")) if night_trade != null and night_trade.has_method(&"greeting") else ""
	greeting_label.text = Phase4Texts.greeting_text(greet)
	var bonus := buyer_bonus()
	var total := 0
	var any_goods := false
	for id: StringName in sell_rows:
		var r: Dictionary = sell_rows[id]
		var n := inv.count(id) if inv != null else 0
		any_goods = any_goods or n > 0
		(r.count as Label).text = "%s ×%d" % [UIKit.item_name(id), n]
		(r.count as Label).theme_type_variation = &"" if n > 0 else &"DimLabel"
		var each := quote(id, 1)
		(r.price as Label).text = Phase4Texts.price_text(each)
		(r.bonus as Label).text = Phase4Texts.TRADE_BONUS % bonus if bonus > 0 else ""
		(r.bonus as Label).visible = bonus > 0
		(r.one as Button).disabled = not present or n <= 0
		(r.all as Button).disabled = not present or n <= 0
		total += quote(id, n) if n > 0 else 0
	empty_label.visible = not any_goods
	sum_label.text = Phase4Texts.sum_text(total)
	sum_label.visible = any_goods
	bonus_label.visible = bonus > 0
	var coins := inv.count(COIN_ITEM) if inv != null else 0
	for id: StringName in buy_rows:
		var r: Dictionary = buy_rows[id]
		var price := _trader().price(id)
		var left := stock_left(id)
		(r.price as Label).text = "%d %s" % [price, Phase4Texts.coins(price)]
		(r.stock as Label).text = Phase4Texts.stock_text(left)
		(r.stock as Label).theme_type_variation = &"DimLabel" if left > 0 else &"WarningLabel"
		var b := r.buy as Button
		b.disabled = not present or left <= 0 or coins < price
		b.tooltip_text = Phase4Texts.TRADE_NO_COINS if coins < price else ""
	coins_label.text = Phase4Texts.TRADE_COINS % coins
	reply_label.text = reply
	reply_label.visible = reply != ""
	away_label.visible = not present


# --- actions ----------------------------------------------------------------------------------

## Sells one / all of `item_id` (NightTrade.sell); returns the coins paid.
func sell(item_id: StringName, all: bool) -> int:
	var inv := _player_inventory()
	if night_trade == null or inv == null or not night_trade.has_method(&"sell"):
		return 0
	var n := inv.count(item_id) if all else mini(1, inv.count(item_id))
	if n <= 0:
		return 0
	var coins := int(night_trade.call(&"sell", item_id, n, inv))
	if coins > 0:
		reply = Phase4Texts.TRADE_AFTER_SELL
	refresh()
	return coins


## Buys one `item_id` (NightTrade.buy) – atomic in NightTrade.
func buy(item_id: StringName) -> bool:
	var inv := _player_inventory()
	if night_trade == null or inv == null or not night_trade.has_method(&"buy"):
		return false
	var ok := bool(night_trade.call(&"buy", item_id, 1, inv))
	if ok:
		reply = Phase4Texts.after_buy(item_id)
	elif inv.count(COIN_ITEM) < _trader().price(item_id):
		reply = Phase4Texts.TRADE_NO_COINS
	elif not inv.can_add(item_id, 1):
		reply = Phase4Texts.TRADE_NO_ROOM
	refresh()
	return ok


func is_present() -> bool:
	return night_trade != null and night_trade.has_method(&"is_present") and bool(night_trade.call(&"is_present"))


func quote(item_id: StringName, amount: int) -> int:
	if night_trade != null and night_trade.has_method(&"quote"):
		return int(night_trade.call(&"quote", item_id, amount))
	return UtilizationRules.sale_value({item_id: amount}, buyer_bonus(), _util())


func stock_left(item_id: StringName) -> int:
	if night_trade != null and night_trade.has_method(&"stock_left"):
		return int(night_trade.call(&"stock_left", item_id))
	return _trader().per_night(item_id)


## Ilse's +1 per item at a low piety tier (Piety.buyer_bonus; 0 without the node).
func buyer_bonus() -> int:
	var piety := get_tree().get_first_node_in_group(PIETY_GROUP) if is_inside_tree() else null
	return int(piety.call(&"buyer_bonus")) if piety != null and piety.has_method(&"buyer_bonus") else 0


## Player inventory from the context, else the player's.
func _player_inventory() -> Inventory:
	var inv := super._player_inventory()
	if inv != null:
		return inv
	var p := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	return p.get(&"inventory") as Inventory if p != null else null


func _util() -> UtilizationConfig:
	var cfg: Variant = night_trade.get(&"utilization_config") if night_trade != null else null
	return cfg if cfg is UtilizationConfig else UtilizationRules._cfg(null)


func _trader() -> TraderConfig:
	var cfg: Variant = night_trade.get(&"trader_config") if night_trade != null else null
	if cfg is TraderConfig:
		return cfg
	var real := Database.config(&"trader_config") as TraderConfig
	return real if real != null else TraderConfig.new()
