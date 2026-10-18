class_name HillRequestsPanel
extends UIPanel
## &"hill_requests" – the requests on the cemetery gate's notice board (G8 Runde 6 „Bitten vom Hügel",
## docs/PHASE8_DESIGN.md G8 Runde 6 §5), opened by NoticeBoard ({player, inventory}). Docked at the right edge below
## the HUD's resource panel like the work panels of rounds 4/5 (dock_right, no dim), one parchment column: one card
## per request on the board – title, giver, the request, the deadline („Frist: 2 Tage" / „noch 1 Tag" / „heute der
## letzte Tag"), how long an offered one still hangs, the reward („3 Münzen · Ruf +1 · 1× Leinen"), for a delivery
## where it is handed over – and „Annehmen" (dimmed with HillRequests' reason, „Zwei Bitten laufen schon."). Mouse
## and keyboard (↑/↓ or Tab between the buttons, Enter, Esc). Only HillRequests.accept changes anything.
## Phase 9 „Größere Bitten" (docs/PHASE9_DESIGN.md §2.3.4, W1-Anschluss 9): context + {place gate | village, large,
## large_cards} (NoticeBoard / VillageBoard): the large requests of the place come first as the card of a big folded
## sheet – title, giver, the request, the parts as a list with ✓ (done) / ○ (open) and their count („2/3 Holz"), „der
## Reihe nach" for parts_in_order, deadline, how long it still hangs, the reward without a number for the reputation
## („Die Gemeinde wird es dir danken. 4 Münzen."), the stamp „halb" when more than half is done, „Annehmen" or the
## reason. At the parish board (place village) only the large request is shown (the orders stay in &"orders").

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
## request id -> {card, accept, state, reason} – the small slips
var cards: Dictionary[StringName, Dictionary] = {}
## Phase 9: large request id -> {card, accept, state, reason, parts: [Label], half: Label}
var large_cards: Dictionary[StringName, Dictionary] = {}
## Phase 9: the accept buttons in the order shown (large sheet first) – the focus moves on along it.
var _order: Array[StringName] = []
## Phase 9: &"gate" | &"village" (context place).
var place: StringName = &"gate"
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
	EventBus.hill_request_part.connect(_on_part_changed)
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
	place = StringName(str(context.get("place", context.get("hill_place", "gate"))))
	if place == &"":
		place = &"gate"
	title_label.text = Phase9Texts.LARGE_VILLAGE_TITLE if place == &"village" else HillTexts.PANEL_TITLE
	head_label.text = Phase9Texts.LARGE_VILLAGE_HEAD if place == &"village" else HillTexts.PANEL_HEAD
	_focus_id = &""
	_scroll.scroll_vertical = 0
	_inventory = _player_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


## Ids shown (the board, in pinning order) – the small requests only at the gate.
func ids() -> Array[StringName]:
	if place != &"gate":
		return [] as Array[StringName]
	return hill.board() if hill != null else ([] as Array[StringName])


## Phase 9: the large requests of this place (HillRequests.large_board), first.
func large_ids() -> Array[StringName]:
	return hill.large_board(place) if hill != null else ([] as Array[StringName])


func _refresh() -> void:
	for id: StringName in _order:
		var old := accept_button(id)
		if is_instance_valid(old) and old.has_focus():
			_focus_id = id
	UIKit.clear_children(_list)
	cards.clear()
	large_cards.clear()
	_order.clear()
	var shown := ids()
	var large := large_ids()
	for id: StringName in large:
		var lc := large_card_data(id)
		if not lc.is_empty():
			_list.add_child(_large_card(lc))
	if shown.is_empty() and large.is_empty():
		var empty := UIKit.label(HillTexts.BOARD_EMPTY + " " + HillTexts.PANEL_NEXT, &"DimLabel", true)
		empty.custom_minimum_size.x = panel_width - 60.0
		_list.add_child(empty)
	for id: StringName in shown:
		var c := card_data(id)
		if not c.is_empty():
			_list.add_child(_card(c))
	var cap := hill.max_active() if hill != null else 0
	count_label.text = HillTexts.PANEL_COUNT % [hill.active().size() if hill != null else 0, cap]
	if place == &"village" and hill != null:
		var cfg := hill.config if hill.config != null else HillRequestsConfig.new()
		count_label.text = HillTexts.PANEL_COUNT % [hill.large_active().size(), maxi(0, cfg.large_max_active)]
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
	if large_cards.has(id):
		return large_cards[id].accept as Button
	return cards[id].accept as Button if cards.has(id) else null


## After a rebuild the focus stays on the card used last (its button; accepted: the next card's, else the first enabled one).
func focus_default() -> void:
	var start := _order.find(_focus_id)
	if start >= 0:
		for i: int in range(start, _order.size()):
			var b := accept_button(_order[i])
			if b != null and b.visible and not b.disabled and b.is_visible_in_tree():
				b.grab_focus()
				reveal.call_deferred(b)
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
	_order.append(id)
	return card


func _on_request_changed(_id: StringName, _state: StringName) -> void:
	if is_open:
		refresh()


func _on_part_changed(_id: StringName, _part: int, _done: bool) -> void:
	if is_open:
		refresh()


# --- Phase 9: the large request (§2.3.4) ------------------------------------------------------------------------------

## HillRequests.large_card(id) + half (more than half done) and the deadline words ({} = unknown).
func large_card_data(id: StringName) -> Dictionary:
	if hill == null:
		return {}
	var c := hill.large_card(id)
	if c.is_empty():
		return c
	var st := StringName(str(c.get("state", "")))
	var left := int(c.get("days_left", -1)) if st == HillRequests.STATE_ACCEPTED else -1
	c["deadline"] = HillTexts.deadline(int(c.get("days_limit", 1)), left)
	c["hangs"] = HillTexts.PANEL_HANGS % HillTexts.days(maxi(1, int(c.get("hangs_left", 1)))) if st == HillRequests.STATE_OFFERED else ""
	c["half"] = st == HillRequests.STATE_ACCEPTED and hill.half_done(id) and not _all_done(c)
	return c


static func _all_done(c: Dictionary) -> bool:
	for p: Variant in c.get("parts", []):
		if p is Dictionary and not bool((p as Dictionary).get("done", false)):
			return false
	return true


## „✓ Zwei Zierstücke im Alten Hof" / „○ 10 Holz schlagen (4/10)".
static func part_line(part: Dictionary) -> String:
	var mark := Phase9Texts.PART_DONE if bool(part.get("done", false)) else Phase9Texts.PART_OPEN
	var need := int(part.get("need", 1))
	var count := Phase9Texts.LARGE_PART_COUNT % [mini(int(part.get("progress", 0)), need), need] if need > 1 and not bool(part.get("done", false)) else ""
	return "%s  %s%s" % [mark, str(part.get("title", "")), count]


func _large_card(c: Dictionary) -> Control:
	var id := StringName(str(c.id))
	var card := UIKit.panel(&"LedgerPagePanel")
	card.set_meta(&"request_id", id)
	card.set_meta(&"large", true)
	var box := UIKit.vbox(6)
	card.add_child(box)
	var width := panel_width - 110.0
	var head := UIKit.hbox(10)
	head.add_child(UIKit.label(Phase9Texts.LARGE_HEAD, &"InkStampLabel"))
	head.add_child(UIKit.spacer())
	var st := StringName(str(c.get("state", "")))
	var half := UIKit.label(Phase9Texts.HALF_STAMP, &"InkStampLabel")
	half.visible = bool(c.get("half", false))
	head.add_child(half)
	var stamp := UIKit.label(HillTexts.PANEL_ACCEPTED if st == HillRequests.STATE_ACCEPTED else "", &"InkStampLabel")
	stamp.visible = stamp.text != ""
	head.add_child(stamp)
	box.add_child(head)
	var title := UIKit.label(str(c.get("title", "")), &"InkHeaderLabel", true)
	title.custom_minimum_size.x = width
	box.add_child(title)
	box.add_child(UIKit.label(HillTexts.PANEL_FROM % str(c.get("giver_name", "")), &"InkDimLabel"))
	var text := UIKit.label(str(c.get("text", "")), &"InkLabel", true)
	text.custom_minimum_size.x = width
	box.add_child(text)
	var parts_head := Phase9Texts.LARGE_PARTS + ((" – " + Phase9Texts.LARGE_IN_ORDER) if bool(c.get("parts_in_order", false)) else "")
	box.add_child(UIKit.label(parts_head, &"LedgerHeadLabel"))
	var part_labels: Array[Label] = []
	for p: Variant in c.get("parts", []):
		if not p is Dictionary:
			continue
		var done := bool((p as Dictionary).get("done", false))
		var l := UIKit.label(part_line(p as Dictionary), &"InkLabel" if done else &"InkPencilLabel", true)
		l.custom_minimum_size.x = width
		box.add_child(l)
		part_labels.append(l)
	if bool(c.get("half", false)):
		var note := UIKit.label(Phase9Texts.LARGE_HALF_NOTE, &"InkDimLabel", true)
		note.custom_minimum_size.x = width
		box.add_child(note)
	var times := PackedStringArray([str(c.get("deadline", ""))])
	if str(c.get("hangs", "")) != "":
		times.append(str(c.hangs))
	box.add_child(UIKit.label(HillTexts.SEP.join(times), &"InkDimLabel", true))
	var reward := UIKit.label(HillTexts.PANEL_REWARD % str(c.get("reward", "")), &"InkLabel", true)
	reward.custom_minimum_size.x = width
	box.add_child(reward)
	var reason := str(c.get("accept_reason", ""))
	var open := st == HillRequests.STATE_OFFERED
	var reason_label := UIKit.label(reason if open else "", &"LedgerWarnLabel", true)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reason_label.visible = reason_label.text != ""
	box.add_child(reason_label)
	var button := UIKit.button(HillTexts.PANEL_ACCEPT, &"InkButton")
	button.visible = open
	button.disabled = reason != ""
	button.tooltip_text = reason
	button.pressed.connect(accept.bind(id))
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(button)
	row.visible = open
	box.add_child(row)
	large_cards[id] = {"card": card, "accept": button, "state": stamp, "reason": reason_label, "parts": part_labels, "half": half}
	_order.append(id)
	return card
