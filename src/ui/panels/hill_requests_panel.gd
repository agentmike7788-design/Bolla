class_name HillRequestsPanel
extends UIPanel
## &"hill_requests" – the requests on the cemetery gate's notice board (G8 Runde 6 „Bitten vom Hügel",
## docs/PHASE8_DESIGN.md G8 Runde 6 §5), opened by NoticeBoard ({player, inventory}). Docked at the right edge below
## the HUD's resource panel like the work panels of rounds 4/5 (dock_right, no dim), one parchment column: one card
## per request on the board – title, giver, the request, the deadline („Frist: 2 Tage" / „noch 1 Tag" / „heute der
## letzte Tag"), how long an offered one still hangs, the reward („3 Münzen · Ruf +1 · 1× Leinen"), for a delivery
## where it is handed over – and „Annehmen" (dimmed with HillRequests' reason, „Zwei Bitten laufen schon."). Mouse
## and keyboard (↑/↓ or Tab between the buttons, Enter, Esc). Only HillRequests.accept changes anything.

const HILL_GROUP := &"hill_requests"

## One narrow column at the right edge (like the crafting panel).
@export var panel_width: float = 600.0
@export var max_list_height: float = 760.0

var hill: HillRequests
var title_label: Label
var head_label: Label
var count_label: Label
var hint_label: Label
var close_button: Button
## request id -> {card, accept, state, reason}
var cards: Dictionary[StringName, Dictionary] = {}
var _scroll: ScrollContainer
var _list: VBoxContainer
var _inventory: Inventory
var _focus_id: StringName = &""


func _init() -> void:
	super._init()
	dock_right = true


func _ready() -> void:
	super._ready()
	EventBus.hill_request_changed.connect(_on_request_changed)
	get_viewport().size_changed.connect(_fit_scroll)


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	title_label = _make_header(box, HillTexts.PANEL_TITLE)
	head_label = UIKit.label(HillTexts.PANEL_HEAD, &"DimLabel", true)
	head_label.custom_minimum_size.x = panel_width - 60.0
	box.add_child(head_label)
	box.add_child(UIKit.separator())
	var dock := make_dock_scroll(box, 10)
	_scroll = dock[0] as ScrollContainer
	_list = dock[1] as VBoxContainer
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	count_label = UIKit.label("", &"DimLabel")
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(count_label)
	close_button = UIKit.button(TEXT_CLOSE)
	close_button.pressed.connect(request_close)
	bottom.add_child(close_button)
	box.add_child(bottom)
	hint_label = UIKit.label(HillTexts.PANEL_HINT, &"DimLabel")
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint_label)


func _on_opened() -> void:
	hill = get_tree().get_first_node_in_group(HILL_GROUP) as HillRequests if is_inside_tree() else null
	_focus_id = &""
	_scroll.scroll_vertical = 0
	_inventory = _player_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


## Ids shown (the board, in pinning order).
func ids() -> Array[StringName]:
	return hill.board() if hill != null else ([] as Array[StringName])


func _refresh() -> void:
	for id: StringName in cards:
		var old: Button = cards[id].accept
		if is_instance_valid(old) and old.has_focus():
			_focus_id = id
	UIKit.clear_children(_list)
	cards.clear()
	var shown := ids()
	if shown.is_empty():
		var empty := UIKit.label(HillTexts.BOARD_EMPTY + " " + HillTexts.PANEL_NEXT, &"DimLabel", true)
		empty.custom_minimum_size.x = panel_width - 60.0
		_list.add_child(empty)
	for id: StringName in shown:
		var c := card_data(id)
		if not c.is_empty():
			_list.add_child(_card(c))
	var cap := hill.max_active() if hill != null else 0
	count_label.text = HillTexts.PANEL_COUNT % [hill.active().size() if hill != null else 0, cap]
	_fit_scroll.call_deferred()


## {id, title, giver_name, text, deadline, hangs, reward, deliver, state, reason} of request `id`.
func card_data(id: StringName) -> Dictionary:
	if hill == null:
		return {}
	var r := hill.request_data(id)
	if r == null:
		return {}
	var state := hill.state(id)
	var hangs := ""
	if state == HillRequests.STATE_OFFERED:
		var cfg := hill.config if hill.config != null else HillRequestsConfig.new()
		var left := maxi(1, hill.posted_day(id) + maxi(1, cfg.offer_days) - TimeManager.day)
		hangs = HillTexts.PANEL_HANGS % HillTexts.days(left)
	return {"id": id, "title": hill.title_of(id), "giver_name": HillRules.giver_name(r.giver), "text": hill.text_of(id),
			"deadline": HillTexts.deadline(r.days_limit, hill.days_left(id)), "hangs": hangs,
			"reward": HillTexts.PANEL_REWARD % HillTexts.SEP.join(HillRules.reward_parts(r)),
			"deliver": r.kind == HillRules.KIND_DELIVER, "state": state, "reason": hill.accept_reason(id)}


## HillRequests.accept(id) – refreshes; returns success.
func accept(id: StringName) -> bool:
	if hill == null or hill.accept_reason(id) != "":
		return false
	_focus_id = id
	var ok := hill.accept(id)
	refresh()
	return ok


func accept_button(id: StringName) -> Button:
	return cards[id].accept as Button if cards.has(id) else null


## After a rebuild the focus stays on the card used last (its button, else the first enabled one).
func focus_default() -> void:
	var again := accept_button(_focus_id)
	if again != null and again.visible and not again.disabled and again.is_visible_in_tree():
		again.grab_focus()
		reveal.call_deferred(again)
		return
	super.focus_default()


func _fit_scroll() -> void:
	fit_dock_scroll(_scroll, _list, max_list_height)


func _fit_dock() -> void:
	_fit_scroll()


func _card(c: Dictionary) -> Control:
	var id := StringName(str(c.id))
	var card := UIKit.panel(&"SectionPanel")
	card.set_meta(&"request_id", id)
	var box := UIKit.vbox(6)
	card.add_child(box)
	var width := panel_width - 90.0
	var head := UIKit.hbox(10)
	var title := UIKit.label(str(c.title), &"SubheaderLabel", true)
	title.custom_minimum_size.x = width - 150.0
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var state := StringName(str(c.state))
	var stamp := UIKit.label(HillTexts.PANEL_ACCEPTED if state == HillRequests.STATE_ACCEPTED else "", &"AccentLabel")
	stamp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stamp.visible = stamp.text != ""
	head.add_child(stamp)
	box.add_child(head)
	box.add_child(UIKit.label(HillTexts.PANEL_FROM % str(c.giver_name), &"DimLabel"))
	var text := UIKit.label(str(c.text), &"", true)
	text.custom_minimum_size.x = width
	box.add_child(text)
	if bool(c.deliver):
		var where := UIKit.label(HillTexts.PANEL_DELIVER, &"DimLabel", true)
		where.custom_minimum_size.x = width
		box.add_child(where)
	var times := PackedStringArray([str(c.deadline)])
	if str(c.hangs) != "":
		times.append(str(c.hangs))
	box.add_child(UIKit.label(HillTexts.SEP.join(times), &"DimLabel", true))
	var reward := UIKit.label(str(c.reward), &"GoodLabel", true)
	reward.custom_minimum_size.x = width
	box.add_child(reward)
	var reason := str(c.reason)
	var reason_label := UIKit.label("", &"WarningLabel", true)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var button := UIKit.button(HillTexts.PANEL_ACCEPT, &"AccentButton")
	var open := state == HillRequests.STATE_OFFERED
	button.visible = open
	button.disabled = reason != ""
	button.tooltip_text = reason
	button.pressed.connect(accept.bind(id))
	reason_label.text = reason if open else ""
	reason_label.visible = reason_label.text != ""
	box.add_child(reason_label)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(button)
	row.visible = open
	box.add_child(row)
	cards[id] = {"card": card, "accept": button, "state": stamp, "reason": reason_label}
	return card


func _on_request_changed(_id: StringName, _state: StringName) -> void:
	if is_open:
		refresh()
