class_name CollectionPanel
extends UIPanel
## &"collection" – the collection shelf next to the pult (docs/PHASE7_DESIGN.md §2.7, §7): context {shelf:
## CollectionShelf, storage, inventory, player}. Seven compartments behind cloth, one per organ, each with
## its label (empty: the organ's name in grey) and „Herausnehmen"; the sets as a bar with a tick and Quast's
## one-time payment; „Ansehen bei der Universität: 2"; the pieces in the pack that fit („Aufstellen", dimmed
## with the shelf's reason – no bundle). The hint stays: „Was im Regal steht, fehlt im Grab." Only
## CollectionShelf.place / take change anything.

const SPECIMENS_GROUP := &"specimens"
const MANAGER_GROUP := &"corpse_manager"

@export var panel_width: float = 1380.0

var shelf: CollectionShelf
var specimens: Specimens
var standing_label: Label
var slots_grid: GridContainer
var sets_box: HBoxContainer
var held_box: VBoxContainer
var held_empty: Label
## organ -> {panel, label, take}
var slot_rows: Dictionary[StringName, Dictionary] = {}
## set id -> label
var set_labels: Dictionary[StringName, Label] = {}
## uid -> place button
var place_buttons: Dictionary[String, Button] = {}

var _inventory: Inventory
var _storage: Inventory


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	var head := UIKit.hbox(16)
	var title := UIKit.label(Phase7Texts.COLLECTION_TITLE, &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	standing_label = UIKit.label("", &"AccentLabel")
	standing_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(standing_label)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	box.add_child(UIKit.label(Phase7Texts.COLLECTION_HINT, &"WhisperLabel"))
	slots_grid = GridContainer.new()
	slots_grid.columns = 4
	slots_grid.add_theme_constant_override(&"h_separation", 12)
	slots_grid.add_theme_constant_override(&"v_separation", 12)
	box.add_child(slots_grid)
	for organ: StringName in AnatomyConfig.ORGANS:
		var panel := UIKit.panel(&"CardPanel")
		panel.custom_minimum_size = Vector2((panel_width - 120.0) / 4.0, 96.0)
		var col := UIKit.vbox(4)
		var label := UIKit.label("", &"InkLabel", true)
		label.custom_minimum_size.x = panel.custom_minimum_size.x - 40.0
		col.add_child(label)
		var take := UIKit.button(Phase7Texts.COLLECTION_TAKE, &"InkButton")
		take.size_flags_horizontal = Control.SIZE_SHRINK_END
		take.pressed.connect(take_out.bind(organ))
		col.add_child(take)
		panel.add_child(col)
		slots_grid.add_child(panel)
		slot_rows[organ] = {"panel": panel, "label": label, "take": take}
	box.add_child(UIKit.label(Phase7Texts.COLLECTION_SETS, &"AccentLabel"))
	sets_box = UIKit.hbox(18)
	box.add_child(sets_box)
	box.add_child(UIKit.separator())
	box.add_child(UIKit.label(Phase7Texts.COLLECTION_HELD, &"AccentLabel"))
	held_box = UIKit.vbox(6)
	box.add_child(held_box)
	held_empty = UIKit.label(Phase7Texts.COLLECTION_NOTHING, &"DimLabel")
	box.add_child(held_empty)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	bottom.add_child(UIKit.spacer())
	var back := UIKit.button(TEXT_CLOSE)
	back.pressed.connect(request_close)
	bottom.add_child(back)
	box.add_child(bottom)


func _on_opened() -> void:
	var s: Variant = context.get("shelf")
	shelf = s as CollectionShelf if is_instance_valid(s) else null
	specimens = get_tree().get_first_node_in_group(SPECIMENS_GROUP) as Specimens if is_inside_tree() else null
	_inventory = _player_inventory()
	_storage = shelf.storage if shelf != null else null
	for inv: Inventory in [_inventory, _storage]:
		if inv != null and not inv.changed.is_connected(refresh):
			inv.changed.connect(refresh)


func _on_closed() -> void:
	for inv: Inventory in [_inventory, _storage]:
		if is_instance_valid(inv) and inv.changed.is_connected(refresh):
			inv.changed.disconnect(refresh)
	_inventory = null
	_storage = null


func _refresh() -> void:
	var cfg := specimens.get_config() if specimens != null else AnatomyConfig.new()
	var organs: Dictionary = shelf.shelf_organs() if shelf != null else {}
	standing_label.text = Phase7Texts.COLLECTION_STANDING % (shelf.standing() if shelf != null else 0)
	var now := TimeManager.total_minutes()
	for organ: StringName in slot_rows:
		var row: Dictionary = slot_rows[organ]
		var spec: SpecimenRecord = organs.get(organ)
		var label := row.label as Label
		if spec != null:
			label.text = Phase7Texts.specimen_row(spec, _record(spec.corpse_id), now, cfg).label
			label.theme_type_variation = &"InkLabel"
		else:
			label.text = Phase7Texts.COLLECTION_EMPTY_SLOT % Phase7Texts.organ_label(organ, cfg)
			label.theme_type_variation = &"InkDimLabel"
		(row.take as Button).visible = spec != null
		(row.take as Button).disabled = action_running
	UIKit.clear_children(sets_box)
	set_labels.clear()
	var done := shelf.sets_done() if shelf != null else PackedStringArray()
	for data: CollectionSetData in sets():
		var col := UIKit.vbox(0)
		var ok := done.has(String(data.id))
		var l := UIKit.label((Phase7Texts.COLLECTION_SET_DONE if ok else Phase7Texts.COLLECTION_SET_OPEN) % data.title,
				&"GoodLabel" if ok else &"SubheaderLabel")
		col.add_child(l)
		var names := PackedStringArray()
		for o: StringName in data.organs:
			names.append(Phase7Texts.organ_label(o, cfg))
		var info := Phase7Texts.SEP.join(names)
		if data.needs_display:
			info += Phase7Texts.SEP + Phase7Texts.COLLECTION_SET_DISPLAY
		col.add_child(UIKit.label(info, &"DimLabel"))
		col.add_child(UIKit.label(Phase7Texts.COLLECTION_SET_REWARD % [data.reward_coins, Phase7Texts.coins(data.reward_coins)], &"DimLabel"))
		sets_box.add_child(col)
		set_labels[data.id] = l
	UIKit.clear_children(held_box)
	place_buttons.clear()
	for uid: String in held_pieces():
		var spec := specimens.get_record(uid)
		var line := UIKit.hbox(12)
		var name := UIKit.label(Phase7Texts.specimen_row(spec, _record(spec.corpse_id), now, cfg).label, &"")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(name)
		var reason := shelf.place_block_reason(uid, _inventory) if shelf != null else CollectionShelf.TEXT_NOT_ACCEPTED
		var reason_label := UIKit.label(reason, &"DimLabel")
		reason_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(reason_label)
		var b := UIKit.button(Phase7Texts.COLLECTION_PLACE, &"AccentButton")
		b.disabled = action_running or reason != ""
		b.tooltip_text = reason
		b.pressed.connect(place.bind(uid))
		line.add_child(b)
		held_box.add_child(line)
		place_buttons[uid] = b
	held_empty.visible = place_buttons.is_empty()


## Held pieces in the pack (Specimens order).
func held_pieces() -> PackedStringArray:
	var out := PackedStringArray()
	if specimens == null or _inventory == null:
		return out
	for uid: String in specimens.held():
		if _inventory.has_uid(uid):
			out.append(uid)
	return out


func sets() -> Array[CollectionSetData]:
	var out: Array[CollectionSetData] = []
	if shelf != null and not shelf.sets.is_empty():
		return shelf.sets
	for res: Resource in Database.collection_sets():
		if res is CollectionSetData:
			out.append(res as CollectionSetData)
	return out


func place(uid: String) -> bool:
	if shelf == null or _inventory == null:
		return false
	var ok := shelf.place(uid, _inventory)
	refresh()
	return ok


func take_out(organ: StringName) -> bool:
	if shelf == null or _inventory == null:
		return false
	var uid := shelf.uid_at(organ)
	var ok := uid != "" and shelf.take(uid, _inventory)
	refresh()
	return ok


func _record(corpse_id: String) -> CorpseRecord:
	var manager := get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager if is_inside_tree() else null
	return manager.get_record(corpse_id) if manager != null else null
