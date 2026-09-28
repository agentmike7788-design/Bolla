class_name BuildSitePanel
extends UIPanel
## &"build_site" – a build site of the workyard (docs/PHASE5_DESIGN.md §2.1, §7): context
## {station (id), station_data: StationData, site: BuildSite, inventory, player}. Picture of the
## station (icon renderer: station_<id>), its description, the cost list with have / need (the
## coins as their own row „Meißelsatz aus Hollerbrück · 15 Münzen"), the duration and „Bauen
## (90 Min)". Something missing → the button is dimmed with „Es fehlt: 2 Stein, 5 Münzen"
## (WorkshopRules / BuildSite.block_reason). Pressing it closes the panel and calls
## site.request_build() (timed action, the site takes items + coins at the end).
## Phase 6 (docs/PHASE6_DESIGN.md §2.5, §7): from shed 2 the cost rows say „im Schuppen: n" and
## „Fehlendes aus dem Schuppen holen (10 Min)" calls site.request_fetch(build_inputs); from shed 3
## „Überschuss einlagern" calls site.request_store().

const ICON_PREFIX := "station_"

@export var panel_width: float = 860.0
@export var picture_edge: float = 220.0
@export var icon_edge: float = 38.0

var title_label: Label
var text_label: Label
var picture: TextureRect
var cost_box: VBoxContainer
var duration_label: Label
var coins_label: Label
var build_button: Button
var reason_label: Label
var shed_bar: ShedFetchBar
## Cost rows as shown ({id, name, need, have, ok, coin}).
var rows: Array[Dictionary] = []

var _inventory: Inventory


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(14)
	add_child(box)
	title_label = _make_header(box, "")
	var body := UIKit.hbox(24)
	box.add_child(body)
	var frame := UIKit.panel(&"SectionPanel")
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picture = UIKit.icon(null, picture_edge)
	frame.add_child(picture)
	body.add_child(frame)
	var info := UIKit.vbox(10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	text_label = UIKit.label("", &"WhisperLabel", true)
	text_label.custom_minimum_size.x = panel_width - picture_edge - 120.0
	info.add_child(text_label)
	info.add_child(UIKit.label(Phase5Texts.BUILD_COSTS, &"AccentLabel"))
	cost_box = UIKit.vbox(6)
	info.add_child(cost_box)
	var dur := UIKit.hbox(10)
	dur.add_child(UIKit.label(Phase5Texts.BUILD_DURATION, &"DimLabel"))
	duration_label = UIKit.label("", &"SubheaderLabel")
	dur.add_child(duration_label)
	info.add_child(dur)
	box.add_child(UIKit.label(Phase5Texts.BUILD_NOTE, &"DimLabel", true))
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


func _on_opened() -> void:
	_inventory = _player_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


func _refresh() -> void:
	var data := station_data()
	var name := data.display_name if data != null and data.display_name != "" else String(station_id())
	title_label.text = Phase5Texts.BUILD_TITLE % name
	text_label.text = data.build_text if data != null else ""
	text_label.visible = text_label.text != ""
	picture.texture = Database.icon(StringName(ICON_PREFIX + String(station_id())))
	UIKit.clear_children(cost_box)
	rows = Phase5Texts.build_rows(data, _inventory)
	var shed := Phase6Texts.shed_state_in(get_tree() if is_inside_tree() else null, needs(), _inventory)
	var in_shed: Dictionary = shed.get("available", {})
	for row: Dictionary in rows:
		row["shed"] = int(in_shed.get(row.id, 0)) if bool(shed.get("shown", false)) and not bool(row.coin) else -1
		cost_box.add_child(_cost_row(row))
	var minutes := data.build_minutes if data != null else 0
	duration_label.text = Phase5Texts.duration(minutes)
	coins_label.text = Phase5Texts.BUILD_COINS_HAVE % (_inventory.count(WorkshopRules.COIN) if is_instance_valid(_inventory) else 0)
	build_button.text = Phase5Texts.BUILD_BUTTON % UIKit.minutes(minutes)
	var reason := block_reason()
	build_button.disabled = reason != ""
	build_button.tooltip_text = reason
	reason_label.text = reason
	reason_label.visible = reason != "" and reason != TEXT_BUSY
	reason_label.theme_type_variation = &"WarningLabel"
	shed_bar.show_state(shed, action_running)


## "" = can be built; else the site's reason ("Es fehlt: 2 Stein, 5 Münzen", "Schon gebaut.") or
## TEXT_BUSY while an action runs. Without a site the pure rule (WorkshopRules) decides.
func block_reason() -> String:
	if action_running:
		return TEXT_BUSY
	var site: Variant = context.get("site")
	if is_instance_valid(site) and (site as Object).has_method(&"block_reason"):
		return str((site as Object).call(&"block_reason", _inventory))
	return WorkshopRules.build_block_reason(station_data(), _inventory, false, true)


func station_id() -> StringName:
	var id: Variant = context.get("station", &"")
	if (id is String or id is StringName) and String(id) != "":
		return StringName(id)
	var data := context.get("station_data") as StationData
	return data.id if data != null else &""


func station_data() -> StationData:
	var data: Variant = context.get("station_data")
	if data is StationData:
		return data
	var id := station_id()
	return Database.station(id) as StationData if id != &"" else null


## Text of a cost row by item id (coins: &"coin") – tests.
func row_text(id: StringName) -> String:
	for node: Node in cost_box.get_children():
		if node.get_meta(&"id", &"") == id and not node.is_queued_for_deletion():
			return (node.get_meta(&"text", "") as String)
	return ""


func _cost_row(row: Dictionary) -> Control:
	var line := UIKit.hbox(10)
	var icon_id: StringName = row.id
	line.add_child(UIKit.icon(Database.icon(icon_id), icon_edge))
	var text := "%s" % row.name if bool(row.coin) else "%d× %s" % [int(row.need), row.name]
	var name := UIKit.label(text, &"")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	if int(row.get("shed", -1)) >= 0:
		line.add_child(UIKit.label(Phase6Texts.SHED_HAVE % int(row.shed), &"DimLabel"))
	var have := UIKit.label(Phase5Texts.BUILD_HAVE % [int(row.have), int(row.need)], &"GoodLabel" if bool(row.ok) else &"WarningLabel")
	line.add_child(have)
	var mark := UIKit.label("✓" if bool(row.ok) else "✗", &"GoodLabel" if bool(row.ok) else &"WarningLabel")
	mark.custom_minimum_size.x = 22.0
	line.add_child(mark)
	line.set_meta(&"id", icon_id)
	line.set_meta(&"text", "%s %s" % [text, have.text])
	return line


func _on_build_pressed() -> void:
	if block_reason() != "":
		return
	var site: Variant = context.get("site")
	if not is_instance_valid(site) or not (site as Object).has_method(&"request_build"):
		push_warning("[BuildSitePanel] site has no request_build()")
		return
	request_close()
	(site as Object).call(&"request_build")


## The station's build inputs ({item_id: amount}; coins are never fetched).
func needs() -> Dictionary:
	var data := station_data()
	return data.build_inputs.duplicate() if data != null else {}


func _on_fetch_pressed() -> void:
	var site: Variant = context.get("site")
	if is_instance_valid(site) and (site as Object).has_method(&"request_fetch"):
		(site as Object).call(&"request_fetch", needs())


func _on_store_pressed() -> void:
	var site: Variant = context.get("site")
	if is_instance_valid(site) and (site as Object).has_method(&"request_store"):
		(site as Object).call(&"request_store")
