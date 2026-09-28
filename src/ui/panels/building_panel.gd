class_name BuildingPanel
extends UIPanel
## &"building" – a building site of Phase 6 (docs/PHASE6_DESIGN.md §2.1, §2.5, §7): context
## {building (id), data: BuildingData, level, site: BuildingSite, inventory, player}. Parchment
## like the Phase-5 build-site panel: the name with the level pips („●○○ Stufe 1 von 3"), three
## level cards side by side (built bright with a tick · the next one amber · later ones dimmed; each
## with the picture of its level from the icon renderer and its „Neu:" list), below them what the
## next level needs with have / need (and „im Schuppen: n" from shed 2), the coin row („Kalk und
## Mörtel aus Hollerbrück · 20 Münzen"), the duration and „Stufe 2 bauen (210 Min)". Something
## missing → dimmed with „Es fehlt: …" (Buildings.upgrade_block_reason via the site). From shed 2
## „Fehlendes aus dem Schuppen holen (10 Min)" (site.request_fetch), from shed 3 „Überschuss
## einlagern". Building closes the panel and calls site.request_upgrade().

const COST_COLUMNS := 2
const STATE_STYLES: Dictionary[StringName, StringName] = {&"done": &"LevelCardDone", &"next": &"LevelCardNext", &"later": &"LevelCardLater"}
const STATE_LABELS: Dictionary[StringName, StringName] = {&"done": &"GoodLabel", &"next": &"AccentLabel", &"later": &"DimLabel"}

@export var panel_width: float = 1560.0
@export var card_icon_edge: float = 120.0
@export var cost_icon_edge: float = 34.0

var title_label: Label
var pips_label: Label
var cards_box: HBoxContainer
var next_box: VBoxContainer
var text_label: Label
var costs_caption: Label
var cost_grid: GridContainer
var duration_label: Label
var note_label: Label
var coins_label: Label
var reason_label: Label
var build_button: Button
var shed_bar: ShedFetchBar
## Cost rows of the next level as shown (Phase6Texts.cost_rows).
var rows: Array[Dictionary] = []
## Level cards as shown (Phase6Texts.level_cards).
var cards: Array[Dictionary] = []

var _inventory: Inventory
var _shed: Inventory


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(16)
	add_child(box)
	var head := UIKit.hbox(18)
	title_label = UIKit.label("", &"HeaderLabel")
	head.add_child(title_label)
	pips_label = UIKit.label("", &"AccentLabel")
	pips_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pips_label)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	cards_box = UIKit.hbox(18)
	box.add_child(cards_box)
	next_box = UIKit.vbox(10)
	box.add_child(next_box)
	text_label = UIKit.label("", &"WhisperLabel", true)
	text_label.custom_minimum_size.x = panel_width - 80.0
	next_box.add_child(text_label)
	var caption_row := UIKit.hbox(24)
	costs_caption = UIKit.label("", &"AccentLabel")
	costs_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_row.add_child(costs_caption)
	caption_row.add_child(UIKit.label(Phase6Texts.DURATION, &"DimLabel"))
	duration_label = UIKit.label("", &"SubheaderLabel")
	caption_row.add_child(duration_label)
	next_box.add_child(caption_row)
	cost_grid = GridContainer.new()
	cost_grid.columns = COST_COLUMNS
	cost_grid.add_theme_constant_override(&"h_separation", 48)
	cost_grid.add_theme_constant_override(&"v_separation", 6)
	next_box.add_child(cost_grid)
	note_label = UIKit.label("", &"DimLabel", true)
	note_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(note_label)
	_make_action_row(box)
	shed_bar = ShedFetchBar.new()
	shed_bar.fetch_pressed.connect(_on_fetch_pressed)
	shed_bar.store_pressed.connect(_on_store_pressed)
	box.add_child(shed_bar)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	coins_label = UIKit.label("", &"DimLabel")
	coins_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(coins_label)
	bottom.add_child(UIKit.spacer())
	reason_label = UIKit.label("", &"WarningLabel")
	reason_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(reason_label)
	var close_button := UIKit.button(TEXT_CLOSE)
	close_button.pressed.connect(request_close)
	bottom.add_child(close_button)
	build_button = UIKit.button("", &"AccentButton")
	build_button.pressed.connect(_on_build_pressed)
	bottom.add_child(build_button)
	box.add_child(bottom)


func _ready() -> void:
	super._ready()
	EventBus.building_upgraded.connect(_on_building_upgraded)


func _on_opened() -> void:
	_inventory = _player_inventory()
	_shed = ShedSupply.shed_inventory(get_tree()) if is_inside_tree() else null
	for inv: Inventory in [_inventory, _shed]:
		if inv != null and not inv.changed.is_connected(refresh):
			inv.changed.connect(refresh)


func _on_closed() -> void:
	for inv: Inventory in [_inventory, _shed]:
		if is_instance_valid(inv) and inv.changed.is_connected(refresh):
			inv.changed.disconnect(refresh)
	_inventory = null
	_shed = null


func _refresh() -> void:
	var data := building_data()
	var lvl := level()
	var top := data.max_level() if data != null else 3
	title_label.text = data.display_name if data != null and data.display_name != "" else String(building_id())
	pips_label.text = "%s  %s" % [Phase6Texts.pips(lvl, top), Phase6Texts.level_text(lvl, top)]
	_fill_cards(data, lvl)
	var next := BuildingRules.next_level(data, lvl)
	next_box.visible = next != null
	UIKit.clear_children(cost_grid)
	rows = []
	var shed_state := {}
	if next != null:
		text_label.text = next.text
		text_label.visible = next.text != ""
		costs_caption.text = Phase6Texts.COSTS % next.level
		duration_label.text = Phase5Texts.duration(next.minutes)
		shed_state = Phase6Texts.shed_state_in(get_tree() if is_inside_tree() else null, BuildingRules.cost(next), _inventory)
		rows = Phase6Texts.cost_rows(next, _inventory, _shed if bool(shed_state.get("shown", false)) else null)
		for row: Dictionary in rows:
			cost_grid.add_child(_cost_row(row))
	note_label.text = Phase6Texts.BUILD_NOTE if next != null else Phase6Texts.MAXED_NOTE
	coins_label.text = Phase6Texts.COINS_HAVE % (_inventory.count(Phase6Texts.COIN) if is_instance_valid(_inventory) else 0)
	var reason := block_reason()
	build_button.visible = next != null
	build_button.text = Phase6Texts.build_button(next.level, next.minutes) if next != null else Phase6Texts.BUILD_MAXED
	build_button.disabled = reason != ""
	build_button.tooltip_text = reason
	reason_label.text = reason
	reason_label.visible = next != null and reason != "" and reason != TEXT_BUSY
	shed_bar.show_state(shed_state, action_running)


## "" = can be built; else the site's reason („Es fehlt: 2 Stein, 5 Münzen", „Voll ausgebaut.") or
## TEXT_BUSY while an action runs. Without a site the pure rule (BuildingRules) decides.
func block_reason() -> String:
	if action_running:
		return TEXT_BUSY
	var site: Variant = context.get("site")
	if is_instance_valid(site) and (site as Object).has_method(&"block_reason"):
		return str((site as Object).call(&"block_reason", _inventory))
	return BuildingRules.upgrade_block_reason(building_data(), level(), _inventory, true)


func building_id() -> StringName:
	var id: Variant = context.get("building", &"")
	if (id is String or id is StringName) and String(id) != "":
		return StringName(id)
	var data := context.get("data") as BuildingData
	return data.id if data != null else &""


func building_data() -> BuildingData:
	var data: Variant = context.get("data")
	if data is BuildingData:
		return data
	var id := building_id()
	return Database.building(id) as BuildingData if id != &"" else null


## The current level: the site's (live), else the context's.
func level() -> int:
	var site: Variant = context.get("site")
	if is_instance_valid(site) and (site as Object).has_method(&"level"):
		return int((site as Object).call(&"level"))
	return int(context.get("level", 0))


## Text of a cost row by item id (coins: &"coin") – tests.
func row_text(id: StringName) -> String:
	for node: Node in cost_grid.get_children():
		if node.get_meta(&"id", &"") == id and not node.is_queued_for_deletion():
			return (node.get_meta(&"text", "") as String)
	return ""


## State of the card of `lvl` (&"done" / &"next" / &"later", &"" unknown) – tests.
func card_state(lvl: int) -> StringName:
	for card: Dictionary in cards:
		if int(card.level) == lvl:
			return card.state
	return &""


func _fill_cards(data: BuildingData, lvl: int) -> void:
	UIKit.clear_children(cards_box)
	cards = Phase6Texts.level_cards(data, lvl)
	var count := maxi(cards.size(), 1)
	var width := (panel_width - 80.0 - 18.0 * float(count - 1)) / float(count)
	for card: Dictionary in cards:
		cards_box.add_child(_card(card, width))


func _card(card: Dictionary, width: float) -> Control:
	var state: StringName = card.state
	var frame := UIKit.panel(STATE_STYLES.get(state, &"SectionPanel"))
	frame.custom_minimum_size.x = width
	frame.size_flags_vertical = Control.SIZE_FILL
	var box := UIKit.vbox(8)
	frame.add_child(box)
	var head := UIKit.hbox(14)
	var pic := UIKit.icon(Database.icon(card.icon), card_icon_edge)
	if state == &"later":
		pic.self_modulate.a = 0.45
	head.add_child(pic)
	var titles := UIKit.vbox(4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var caption := UIKit.hbox(12)
	caption.add_child(UIKit.label(Phase6Texts.CARD_LEVEL % int(card.level), &"DimLabel"))
	caption.add_child(UIKit.label(card.state_text, STATE_LABELS.get(state, &"DimLabel")))
	titles.add_child(caption)
	var title := UIKit.label(card.title, &"SubheaderLabel" if state != &"later" else &"DimLabel", true)
	title.custom_minimum_size.x = width - card_icon_edge - 70.0
	titles.add_child(title)
	head.add_child(titles)
	box.add_child(head)
	box.add_child(UIKit.label(Phase6Texts.CARD_NEW, &"DimLabel"))
	for line: String in (card.adds as PackedStringArray):
		var l := UIKit.label(Phase6Texts.CARD_BULLET % line, &"" if state != &"later" else &"DimLabel", true)
		l.custom_minimum_size.x = width - 40.0
		box.add_child(l)
	frame.set_meta(&"level", int(card.level))
	return frame


func _cost_row(row: Dictionary) -> Control:
	var line := UIKit.hbox(10)
	line.custom_minimum_size.x = (panel_width - 140.0) / float(COST_COLUMNS)
	var icon_id: StringName = row.id
	line.add_child(UIKit.icon(Database.icon(icon_id), cost_icon_edge))
	var text := "%s" % row.name if bool(row.coin) else "%d× %s" % [int(row.need), row.name]
	var name := UIKit.label(text, &"")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	var shed_text := ""
	if int(row.shed) >= 0:
		shed_text = Phase6Texts.SHED_HAVE % int(row.shed)
		line.add_child(UIKit.label(shed_text, &"DimLabel"))
	var have := UIKit.label(Phase6Texts.HAVE % [int(row.have), int(row.need)], &"GoodLabel" if bool(row.ok) else &"WarningLabel")
	line.add_child(have)
	var mark := UIKit.label("✓" if bool(row.ok) else "✗", &"GoodLabel" if bool(row.ok) else &"WarningLabel")
	mark.custom_minimum_size.x = 22.0
	line.add_child(mark)
	line.set_meta(&"id", icon_id)
	var parts := PackedStringArray([text])
	if shed_text != "":
		parts.append(shed_text)
	parts.append(have.text)
	line.set_meta(&"text", " ".join(parts))
	return line


func _on_build_pressed() -> void:
	if block_reason() != "":
		return
	var site: Variant = context.get("site")
	if not is_instance_valid(site) or not (site as Object).has_method(&"request_upgrade"):
		push_warning("[BuildingPanel] site has no request_upgrade()")
		return
	request_close()
	(site as Object).call(&"request_upgrade")


func _on_fetch_pressed() -> void:
	var site: Variant = context.get("site")
	if is_instance_valid(site) and (site as Object).has_method(&"request_fetch"):
		(site as Object).call(&"request_fetch")


func _on_store_pressed() -> void:
	var player := _player() as Player
	if player != null and is_inside_tree():
		ShedSupply.run_store(get_tree(), player)


func _on_building_upgraded(id: StringName, _level: int) -> void:
	if is_open and id == building_id():
		refresh()
