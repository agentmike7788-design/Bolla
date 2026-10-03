class_name OrdersPanel
extends UIPanel
## &"orders" – orders on the parish board or in a dialogue (docs/PHASE7_DESIGN.md §2.5, §7): context
## {board: bool, orders: Array[StringName], header?, empty_text?, inventory, player, speaker}
## (VillageBoard.panel_context / dialogue action order_offer). One card per order: title, giver, the
## request, the conditions as a checklist („8× Holunderbeeren 3/8 ✓ / –"), the deadline („Frist: 4 Tage",
## „noch 2 Tage"), the reward (coins, relationship as an arrow, reputation) and „Annehmen" – dimmed with
## Orders' reason („Vier Aufträge laufen schon."). The board head names the gravekeeper's reputation.
## [ / ] (journal_page_prev / _next) page when more cards are there than fit. Only Orders.accept changes
## anything.

const ORDERS_GROUP := &"orders"
const CARDS_PER_PAGE := 2

@export var panel_width: float = 1240.0

var orders: Orders
var title_label: Label
var header_label: Label
var cards_box: HBoxContainer
var empty_label: Label
var page_label: Label
var count_label: Label
## order id -> {card, accept, state, reason}
var cards: Dictionary[StringName, Dictionary] = {}
var ids: Array[StringName] = []
var page: int = 0

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
	header_label = UIKit.label("", &"AccentLabel")
	titles.add_child(header_label)
	head.add_child(titles)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	box.add_child(UIKit.separator())
	cards_box = UIKit.hbox(20)
	box.add_child(cards_box)
	empty_label = UIKit.label("", &"DimLabel", true)
	box.add_child(empty_label)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	count_label = UIKit.label("", &"DimLabel")
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(count_label)
	page_label = UIKit.label("", &"DimLabel")
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	page_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(page_label)
	var back := UIKit.button(TEXT_CLOSE)
	back.pressed.connect(request_close)
	bottom.add_child(back)
	box.add_child(bottom)


func _on_opened() -> void:
	orders = get_tree().get_first_node_in_group(ORDERS_GROUP) as Orders if is_inside_tree() else null
	ids.clear()
	for id: Variant in context.get("orders", []):
		ids.append(StringName(str(id)))
	page = 0
	_inventory = _player_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree() or UIState.top() != panel_id:
		return
	if event.is_action_pressed(&"journal_page_prev"):
		turn_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"journal_page_next"):
		turn_page(1)
		get_viewport().set_input_as_handled()


func is_board() -> bool:
	return bool(context.get("board", false))


func _refresh() -> void:
	title_label.text = Phase7Texts.ORDERS_TITLE_BOARD if is_board() else Phase7Texts.ORDERS_TITLE_ASK
	var header := str(context.get("header", ""))
	if header == "" and is_board():
		header = VillageBoard.header_text()
	header_label.text = header
	header_label.visible = header != ""
	page = clampi(page, 0, page_count() - 1)
	UIKit.clear_children(cards_box)
	cards.clear()
	for i: int in range(page * CARDS_PER_PAGE, mini(ids.size(), (page + 1) * CARDS_PER_PAGE)):
		var c := card_data(ids[i])
		if c.is_empty():
			continue
		cards_box.add_child(_card(c))
	empty_label.text = str(context.get("empty_text", Phase7Texts.ORDERS_EMPTY))
	empty_label.visible = cards.is_empty()
	page_label.text = Phase7Texts.ORDER_PAGE % [page + 1, page_count()]
	page_label.visible = page_count() > 1
	var cfg := orders.config if orders != null and orders.config != null else OrdersConfig.new()
	count_label.text = Phase7Texts.ORDER_ACTIVE_COUNT % [orders.active().size() if orders != null else 0, cfg.max_active]


## Phase7Texts.order_card of `id` with this world's state and deadline ({} = unknown order).
func card_data(id: StringName) -> Dictionary:
	var o := orders.order_data(id) if orders != null else Database.order_data(id) as OrderData
	if o == null:
		return {}
	var state := orders.state(id) if orders != null else &""
	var left := -1
	if orders != null and state == Orders.STATE_ACCEPTED:
		left = Phase7Texts.days_left(orders.deadline_day(id), TimeManager.day)
		if orders.deadline_day(id) <= 0:
			left = -1
	var c := Phase7Texts.order_card(o, state, _inventory, left)
	c["reason"] = accept_reason(id)
	return c


## "" = can be accepted now; else Orders.block_reason (or the state's word).
func accept_reason(id: StringName) -> String:
	if orders == null:
		return OrderRules.TEXT_NOT_YET
	return orders.block_reason(id)


## Orders.accept(id) – refreshes; returns success.
func accept(id: StringName) -> bool:
	if orders == null or accept_reason(id) != "":
		return false
	var ok := orders.accept(id)
	refresh()
	return ok


func turn_page(delta: int) -> void:
	page = clampi(page + delta, 0, page_count() - 1)
	refresh()


func page_count() -> int:
	return maxi(1, ceili(float(ids.size()) / CARDS_PER_PAGE))


func _card(c: Dictionary) -> Control:
	var id := StringName(str(c.id))
	var card := UIKit.panel(&"CardPanel")
	card.custom_minimum_size.x = (panel_width - 100.0) / CARDS_PER_PAGE
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.set_meta(&"order_id", id)
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label(str(c.title), &"InkHeaderLabel", true))
	var from := Phase7Texts.ORDER_FROM % str(c.giver_name)
	if str(c.get("recipient_name", "")) != "":
		from += Phase7Texts.SEP + Phase7Texts.ORDER_FOR % str(c.recipient_name)
	box.add_child(UIKit.label(from, &"InkDimLabel"))
	var text := UIKit.label(str(c.text), &"InkLabel", true)
	text.custom_minimum_size.x = card.custom_minimum_size.x - 50.0
	box.add_child(text)
	var checks := PackedStringArray()
	for raw: Variant in c.get("checks", []):
		var ch := raw as Dictionary
		checks.append("%s %s" % [str(ch.label), Phase7Texts.CHECK_ON if bool(ch.ok) else Phase7Texts.CHECK_OFF])
	var check_label := UIKit.label(Phase7Texts.SEP.join(checks), &"InkLabel", true)
	check_label.custom_minimum_size.x = card.custom_minimum_size.x - 50.0
	check_label.visible = not checks.is_empty()
	box.add_child(check_label)
	box.add_child(UIKit.label(str(c.deadline), &"InkDimLabel"))
	var reward := UIKit.label(Phase7Texts.SEP.join(PackedStringArray(c.get("reward", PackedStringArray()))), &"InkHeaderLabel", true)
	reward.custom_minimum_size.x = card.custom_minimum_size.x - 50.0
	box.add_child(reward)
	var state := StringName(str(c.get("state", "")))
	var state_label := UIKit.label("", &"InkStampLabel")
	var accept_button := UIKit.button(Phase7Texts.ORDER_ACCEPT, &"InkButton")
	var reason_label := UIKit.label("", &"InkDimLabel", true)
	reason_label.custom_minimum_size.x = card.custom_minimum_size.x - 50.0
	match state:
		Orders.STATE_ACCEPTED:
			state_label.text = Phase7Texts.ORDER_ACCEPTED
		Orders.STATE_COMPLETED:
			state_label.text = Phase7Texts.ORDER_DONE
		Orders.STATE_FAILED:
			state_label.text = Phase7Texts.ORDER_FAILED
	var open := state == &"" or state == Orders.STATE_OFFERED
	accept_button.visible = open
	var reason := str(c.get("reason", ""))
	accept_button.disabled = action_running or reason != ""
	accept_button.tooltip_text = reason
	accept_button.pressed.connect(accept.bind(id))
	reason_label.text = reason if open else ""
	reason_label.visible = reason_label.text != ""
	state_label.visible = state_label.text != ""
	var row := UIKit.hbox(12)
	row.add_child(state_label)
	row.add_child(UIKit.spacer())
	row.add_child(accept_button)
	box.add_child(row)
	box.add_child(reason_label)
	card.add_child(box)
	cards[id] = {"card": card, "accept": accept_button, "state": state_label, "reason": reason_label, "checks": check_label,
			"reward": reward}
	return card
