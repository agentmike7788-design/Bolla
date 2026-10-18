class_name StrangerPanel
extends UIPanel
## &"stranger" – the panel of the gentleman with the case (docs/PHASE9_DESIGN.md §7.4, §2.5.2 K2, W-UI): context
## {speaker, inventory, player} (dialogue action stranger_offers). Docked at the right edge below the HUD's resource
## panel like the work panels of rounds 4/5 (dock_right, no dim), mouse and keyboard. Head „C. Brenneisen,
## Commissionär" with his portrait, his offers as cards (Stranger.offers): the thing with its icon, the price, one line
## of what follows without a number („Lenz wird es erfahren."), „Verkaufen" (dimmed with Stranger's reason) and „Nein"
## (the card only says „Wie Sie meinen." – nothing changes in the game). No haggling. Only Stranger.sell changes
## anything.

const STRANGER_GROUP := &"stranger"
const PORTRAIT := &"villager_stranger"

@export var panel_width: float = 700.0
@export var max_list_height: float = 720.0
## W3 („Restbedarf“ 7): smaller portrait and icons, the compact cards (all offers on screen at 1280 × 720).
@export var portrait_edge: float = 60.0
@export var icon_edge: float = 40.0
@export var title_font_size: int = 30
@export var card_title_font_size: int = 22
## The note / reason under a card's name, his words and the keys at the bottom (DimLabel 20 → 18).
@export var small_font_size: int = 18
## Room of the price at the title and of „Nein" / „Verkaufen" beside the note (1920 × 1080 base).
@export var price_width: float = 110.0
@export var buttons_width: float = 240.0

var stranger: Stranger
var title_label: Label
var head_label: Label
var empty_label: Label
var hint_label: Label
## offer id → {card, sell, no, reason, note, price}
var cards: Dictionary[StringName, Dictionary] = {}
## Offers answered „Nein" while the panel is open (UI only).
var declined: Array[StringName] = []
## Offers sold while the panel is open (their card says so).
var sold_now: Array[StringName] = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _inventory: Inventory
var _focus: StringName = &""


func _init() -> void:
	super._init()
	dock_right = true


func _ready() -> void:
	super._ready()
	EventBus.stranger_event.connect(_on_stranger_event.unbind(2))
	get_viewport().size_changed.connect(_fit_scroll)


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	var head := UIKit.hbox(14)
	var portrait := UIKit.icon(Database.icon(PORTRAIT), portrait_edge)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(portrait)
	var titles := UIKit.vbox(4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label = UIKit.label(Phase9Texts.STRANGER_TITLE, &"HeaderLabel", true)
	# W3 („Restbedarf“ 7): the name on one line, his words under the head row over the whole width (room for the cards).
	title_label.add_theme_font_size_override(&"font_size", title_font_size)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_child(title_label)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(titles)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	head_label = UIKit.label(Phase9Texts.STRANGER_HEAD, &"DimLabel", true)
	head_label.custom_minimum_size.x = panel_width - 40.0
	box.add_child(head_label)
	box.add_child(UIKit.separator())
	var dock := make_dock_scroll(box, 8)
	_scroll = dock[0] as ScrollContainer
	_list = dock[1] as VBoxContainer
	empty_label = UIKit.label("", &"DimLabel", true)
	empty_label.custom_minimum_size.x = panel_width - 60.0
	box.add_child(empty_label)
	box.add_child(UIKit.separator())
	# W3: his rule and the keys in one column beside „Schließen" (one row less under the cards).
	var bottom := UIKit.hbox(12)
	var words := UIKit.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quote := UIKit.label(Phase9Texts.STRANGER_QUOTE, &"DimLabel", true)
	quote.add_theme_font_size_override(&"font_size", small_font_size)
	words.add_child(quote)
	hint_label = UIKit.label(Phase9Texts.STRANGER_HINT, &"DimLabel")
	hint_label.add_theme_font_size_override(&"font_size", small_font_size)
	words.add_child(hint_label)
	bottom.add_child(words)
	var close := UIKit.button(TEXT_CLOSE)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(request_close)
	bottom.add_child(close)
	box.add_child(bottom)


func _on_opened() -> void:
	stranger = get_tree().get_first_node_in_group(STRANGER_GROUP) as Stranger if is_inside_tree() else null
	_inventory = _player_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)
	declined.clear()
	sold_now.clear()
	_focus = &""
	_scroll.scroll_vertical = 0


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


## Stranger.offers(inventory) – {id, label, item, price, note, reason}.
func offers() -> Array[Dictionary]:
	if stranger == null:
		return [] as Array[Dictionary]
	return stranger.offers(_inventory)


func _refresh() -> void:
	for id: StringName in cards:
		for key: String in ["sell", "no"]:
			var b: Button = cards[id][key]
			if is_instance_valid(b) and b.has_focus():
				_focus = id
	UIKit.clear_children(_list)
	cards.clear()
	var shown := offers()
	if stranger == null or stranger.gone():
		empty_label.text = Phase9Texts.STRANGER_GONE
	elif shown.is_empty():
		empty_label.text = Phase9Texts.STRANGER_NONE
	else:
		empty_label.text = ""
	empty_label.visible = empty_label.text != ""
	for o: Dictionary in shown:
		_list.add_child(_card(o))
	_fit_scroll.call_deferred()


func _card(o: Dictionary) -> Control:
	var id := StringName(str(o.get("id", "")))
	var card := UIKit.panel(&"SectionPanel")
	card.set_meta(&"offer_id", id)
	# W3 („Restbedarf“ 7): compact – the thing, its name and price on one row, below it what follows (and why not) beside
	# „Nein" / „Verkaufen"; all four offers fit the dock at 1280 × 720 (before: a row of their own for the buttons, two
	# cards and a half visible).
	var col := UIKit.vbox(4)
	card.add_child(col)
	var head := UIKit.hbox(10)
	var item := StringName(str(o.get("item", "")))
	var icon := UIKit.icon(Database.icon(item if item != &"" else &"specimen_jar"), icon_edge)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(icon)
	var title := UIKit.label(str(o.get("label", "")), &"SubheaderLabel", true)
	title.add_theme_font_size_override(&"font_size", card_title_font_size)
	title.custom_minimum_size.x = panel_width - icon_edge - price_width - 70.0
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var price := int(o.get("price", 0))
	var price_label := UIKit.label(Phase9Texts.STRANGER_PRICE % [price, Phase8Texts.coins(price)], &"AccentLabel")
	price_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(price_label)
	col.add_child(head)
	var foot := UIKit.hbox(10)
	col.add_child(foot)
	var texts := UIKit.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(texts)
	var width := panel_width - buttons_width - 60.0
	var note := UIKit.label(str(o.get("note", "")), &"DimLabel", true)
	note.custom_minimum_size.x = width
	note.add_theme_font_size_override(&"font_size", small_font_size)
	note.visible = note.text != ""
	texts.add_child(note)
	var reason := str(o.get("reason", ""))
	var said := ""
	if id in sold_now:
		said = Phase9Texts.STRANGER_SOLD
	elif id in declined:
		said = Phase9Texts.STRANGER_DECLINED
	var reason_label := UIKit.label(said if said != "" else reason, &"GoodLabel" if id in sold_now else (&"DimLabel" if said != "" else &"WarningLabel"), true)
	reason_label.custom_minimum_size.x = width
	reason_label.add_theme_font_size_override(&"font_size", small_font_size)
	reason_label.visible = reason_label.text != ""
	texts.add_child(reason_label)
	var buttons := UIKit.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.size_flags_vertical = Control.SIZE_SHRINK_END
	var no := UIKit.button(Phase9Texts.STRANGER_NO)
	no.disabled = id in declined
	no.pressed.connect(decline.bind(id))
	buttons.add_child(no)
	var sell_b := UIKit.button(Phase9Texts.STRANGER_SELL, &"AccentButton")
	sell_b.disabled = reason != "" or id in declined
	sell_b.tooltip_text = reason
	sell_b.pressed.connect(sell.bind(id))
	buttons.add_child(sell_b)
	foot.add_child(buttons)
	cards[id] = {"card": card, "sell": sell_b, "no": no, "reason": reason_label, "note": note, "price": price_label}
	return card


## „Verkaufen": Stranger.sell(offer, inventory) – refreshes; returns success.
func sell(id: StringName) -> bool:
	if stranger == null:
		return false
	_focus = id
	var ok := stranger.sell(id, _inventory)
	if ok and not id in sold_now:
		sold_now.append(id)
	refresh()
	return ok


## „Nein": the card says „Wie Sie meinen." – nothing else happens.
func decline(id: StringName) -> void:
	_focus = id
	if not id in declined:
		declined.append(id)
	refresh()


func sell_button(id: StringName) -> Button:
	return cards[id].sell as Button if cards.has(id) else null


func focus_default() -> void:
	if cards.has(_focus):
		for key: String in ["sell", "no"]:
			var b: Button = cards[_focus][key]
			if is_instance_valid(b) and not b.disabled and b.is_visible_in_tree():
				b.grab_focus()
				reveal.call_deferred(b)
				return
	super.focus_default()


func _fit_scroll() -> void:
	fit_dock_scroll(_scroll, _list, max_list_height)


func _fit_dock() -> void:
	_fit_scroll()


func _on_stranger_event() -> void:
	if is_open:
		refresh()
