class_name PultPanel
extends UIPanel
## &"pult" – the second card of the preparation desk in the crypt (docs/PHASE7_DESIGN.md §2.7, §3.4, §7):
## context {station, inventory, workbench, player} (the crafting panel's button „Präparate und Arzneien"
## at the station pult). Left the pieces in the pack and in the cold box (those in the box can be taken out
## first); right, for the chosen piece, the cards „Einlegen (5 Min)", „Schaupräparat (40 Min)",
## „Knochenpräparat (60 Min)", „Begutachten (20 Min)" (PultRules' reasons) and „Arzneien" – the recipe
## cards from Quast's book (MedicineData) with the needed organ, the ingredients (have / need, shed fetch
## from shed 2 through the workbench), the result and Quast's price. Every handgrip is a TimedAction of the
## player; at its end only Specimens.seal / make_display / make_bone / inspect or PultRules.make_medicine
## run – they take their ingredients themselves. The making of a medicine is never described.

const SPECIMENS_GROUP := &"specimens"
const MANAGER_GROUP := &"corpse_manager"
const SHOP_SURGEON := &"surgeon"
const ANIM := &"interact"
const ACTION_SEAL := &"seal"
const ACTION_DISPLAY := &"display"
const ACTION_BONE := &"bone"
const ACTION_INSPECT := &"inspect"
const ACTIONS: Array[StringName] = [ACTION_SEAL, ACTION_DISPLAY, ACTION_BONE, ACTION_INSPECT]

@export var panel_width: float = 1500.0
@export var column_width: float = 560.0

var specimens: Specimens
var pieces_box: VBoxContainer
var none_label: Label
var actions_box: VBoxContainer
var chosen_label: Label
var medicines_box: VBoxContainer
var book_label: Label
var reply_label: Label
## action -> {button, reason}
var action_rows: Dictionary[StringName, Dictionary] = {}
## medicine id -> {card, button, reason, fetch}
var medicine_rows: Dictionary[StringName, Dictionary] = {}
## uid -> piece button
var piece_buttons: Dictionary[String, Button] = {}
var selected: String = ""
var reply: String = ""

var _inventory: Inventory
var _cold: Inventory


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	_make_header(box, Phase7Texts.PULT_TITLE)
	box.add_child(UIKit.label(Phase7Texts.PULT_INTRO, &"WhisperLabel", true))
	var columns := UIKit.hbox(24)
	box.add_child(columns)
	var left := UIKit.vbox(8)
	left.custom_minimum_size.x = column_width
	columns.add_child(left)
	left.add_child(UIKit.label(Phase7Texts.PULT_PIECES, &"AccentLabel"))
	pieces_box = UIKit.vbox(6)
	left.add_child(pieces_box)
	none_label = UIKit.label(Phase7Texts.PULT_NONE, &"DimLabel", true)
	none_label.custom_minimum_size.x = column_width
	left.add_child(none_label)
	var right := UIKit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	chosen_label = UIKit.label("", &"SubheaderLabel")
	right.add_child(chosen_label)
	right.add_child(UIKit.label(Phase7Texts.PULT_ACTIONS, &"AccentLabel"))
	actions_box = UIKit.vbox(6)
	right.add_child(actions_box)
	for action: StringName in ACTIONS:
		var row := UIKit.hbox(12)
		var b := UIKit.button("")
		b.custom_minimum_size.x = 340.0
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(request_action.bind(action))
		row.add_child(b)
		var reason := UIKit.label("", &"DimLabel", true)
		reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reason.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(reason)
		actions_box.add_child(row)
		action_rows[action] = {"button": b, "reason": reason}
	right.add_child(UIKit.separator())
	right.add_child(UIKit.label(Phase7Texts.PULT_MEDICINES, &"AccentLabel"))
	book_label = UIKit.label(Phase7Texts.PULT_BOOK, &"DimLabel")
	right.add_child(book_label)
	medicines_box = UIKit.vbox(8)
	right.add_child(medicines_box)
	reply_label = UIKit.label("", &"WhisperLabel", true)
	box.add_child(reply_label)
	_make_action_row(box)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	bottom.add_child(UIKit.spacer())
	var back := UIKit.button(TEXT_CLOSE)
	back.pressed.connect(request_close)
	bottom.add_child(back)
	box.add_child(bottom)


func _on_opened() -> void:
	specimens = get_tree().get_first_node_in_group(SPECIMENS_GROUP) as Specimens if is_inside_tree() else null
	var store := find_store(get_tree() if is_inside_tree() else null)
	_cold = store.store() if store != null else null
	reply = ""
	_inventory = _player_inventory()
	for inv: Inventory in [_inventory, _cold]:
		if inv != null and not inv.changed.is_connected(refresh):
			inv.changed.connect(refresh)


func _on_closed() -> void:
	for inv: Inventory in [_inventory, _cold]:
		if is_instance_valid(inv) and inv.changed.is_connected(refresh):
			inv.changed.disconnect(refresh)
	_inventory = null
	_cold = null


## The cold box of the pult (PultStore has no group of its own: the saveables are searched).
static func find_store(tree: SceneTree) -> PultStore:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(&"saveable"):
		if node is PultStore:
			return node as PultStore
	return null


## Held uids in the pack, then those in the cold box: [{uid, cold}].
func pieces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if specimens == null:
		return out
	for uid: String in specimens.held():
		if _inventory != null and _inventory.has_uid(uid):
			out.append({"uid": uid, "cold": false})
	for uid: String in specimens.held():
		if _cold != null and _cold.has_uid(uid):
			out.append({"uid": uid, "cold": true})
	return out


func _refresh() -> void:
	var list := pieces()
	var in_pack := list.filter(func(p: Dictionary) -> bool: return not bool(p.cold)).map(func(p: Dictionary) -> String: return str(p.uid))
	if selected == "" or not in_pack.has(selected):
		selected = str(in_pack[0]) if not in_pack.is_empty() else ""
	UIKit.clear_children(pieces_box)
	piece_buttons.clear()
	var now := TimeManager.total_minutes()
	var cfg := _cfg()
	for p: Dictionary in list:
		var uid := str(p.uid)
		var spec := specimens.get_record(uid)
		var r := Phase7Texts.specimen_row(spec, _record(spec.corpse_id), now, cfg)
		var row := UIKit.hbox(8)
		var b := UIKit.button("%s – %s" % [str(r.organ_label), str(r.name)], &"BuildSlotSelected" if uid == selected else &"SlotButton")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%s · Klarheit %s%s" % [str(r.container_word), str(r.clarity_word), (" · " + str(r.eta)) if str(r.eta) != "" else ""]
		b.disabled = bool(p.cold)
		b.pressed.connect(select.bind(uid))
		row.add_child(b)
		var info := UIKit.label(Phase7Texts.PULT_IN_COLD if bool(p.cold) else str(r.container_word), &"DimLabel")
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(info)
		if bool(p.cold):
			var take := UIKit.button(Phase7Texts.PULT_TAKE_OUT)
			take.disabled = action_running
			take.pressed.connect(take_from_cold.bind(uid))
			row.add_child(take)
		pieces_box.add_child(row)
		piece_buttons[uid] = b
	none_label.visible = list.is_empty()
	var spec_sel := specimens.get_record(selected) if specimens != null and selected != "" else null
	chosen_label.text = Phase7Texts.PULT_CHOSEN % Phase7Texts.specimen_row(spec_sel, _record(spec_sel.corpse_id), now, cfg).label \
			if spec_sel != null else Phase7Texts.PULT_PICK
	for action: StringName in ACTIONS:
		var row: Dictionary = action_rows[action]
		var b := row.button as Button
		b.text = action_text(action, cfg)
		var reason := action_reason(action)
		b.disabled = action_running or reason != ""
		b.tooltip_text = reason
		(row.reason as Label).text = reason if spec_sel != null else ""
	_refresh_medicines(spec_sel, now, cfg)
	reply_label.text = reply
	reply_label.visible = reply != ""


func _refresh_medicines(spec: SpecimenRecord, now: int, cfg: AnatomyConfig) -> void:
	UIKit.clear_children(medicines_box)
	medicine_rows.clear()
	var known := PultRules.book_known(cfg)
	book_label.text = Phase7Texts.PULT_BOOK if known else Phase7Texts.PULT_NO_BOOK
	if not known:
		return
	for med: MedicineData in medicines():
		var card := UIKit.panel(&"SectionPanel")
		var col := UIKit.vbox(4)
		var head := UIKit.hbox(12)
		var title := UIKit.label(UIKit.item_name(med.output), &"SubheaderLabel")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var price := medicine_price(med.output)
		if price > 0:
			head.add_child(UIKit.label(Phase7Texts.PULT_MED_PRICE % price, &"DimLabel"))
		col.add_child(head)
		var organs := PackedStringArray()
		for o: StringName in med.organs:
			organs.append(Phase7Texts.organ_label(o, cfg))
		col.add_child(UIKit.label(Phase7Texts.PULT_MED_NEEDS % [" oder ".join(organs), _percent(med.min_clarity)], &"DimLabel"))
		var parts := PackedStringArray()
		for id: StringName in med.inputs:
			parts.append(Phase7Texts.INPUT_ROW % [int(med.inputs[id]), UIKit.item_name(id), _inventory.count(id) if _inventory != null else 0, int(med.inputs[id])])
		col.add_child(UIKit.label(Phase7Texts.SEP.join(parts), &""))
		col.add_child(UIKit.label(Phase7Texts.PULT_MED_RESULT % [maxi(med.amount, 1), UIKit.item_name(med.output)], &"GoodLabel"))
		var row := UIKit.hbox(12)
		var reason := medicine_reason(med)
		var reason_label := UIKit.label(reason if spec != null else "", &"DimLabel", true)
		reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(reason_label)
		var fetch := _fetch_button(med)
		if fetch != null:
			row.add_child(fetch)
		var b := UIKit.button(Phase7Texts.PULT_MED_BUTTON % UIKit.minutes(med.minutes), &"AccentButton")
		b.disabled = action_running or reason != ""
		b.tooltip_text = reason
		b.pressed.connect(request_medicine.bind(med.id))
		row.add_child(b)
		col.add_child(row)
		card.add_child(col)
		medicines_box.add_child(card)
		medicine_rows[med.id] = {"card": card, "button": b, "reason": reason_label, "fetch": fetch}


func _fetch_button(med: MedicineData) -> Button:
	var shed := Phase6Texts.shed_state_in(get_tree() if is_inside_tree() else null, med.inputs, _inventory)
	if not bool(shed.get("shown", false)) or str(shed.get("reason", "")) == ShedSupply.TEXT_NOTHING_MISSING:
		return null
	var b := UIKit.button(Phase6Texts.fetch_button(int(shed.get("minutes", 0)), true))
	b.disabled = action_running or str(shed.get("reason", "")) != ""
	b.tooltip_text = str(shed.get("reason", ""))
	b.pressed.connect(_on_fetch.bind(med))
	return b


# --- queries -----------------------------------------------------------------------------------------

func select(uid: String) -> void:
	selected = uid
	reply = ""
	refresh()


func action_text(action: StringName, cfg: AnatomyConfig) -> String:
	match action:
		ACTION_SEAL:
			return Phase7Texts.PULT_SEAL % UIKit.minutes(cfg.seal_minutes)
		ACTION_DISPLAY:
			return Phase7Texts.PULT_DISPLAY % UIKit.minutes(cfg.display_minutes)
		ACTION_BONE:
			return Phase7Texts.PULT_BONE % UIKit.minutes(cfg.bone_minutes)
	return Phase7Texts.PULT_INSPECT % UIKit.minutes(cfg.inspect_minutes)


func action_minutes(action: StringName, cfg: AnatomyConfig) -> int:
	match action:
		ACTION_SEAL:
			return cfg.seal_minutes
		ACTION_DISPLAY:
			return cfg.display_minutes
		ACTION_BONE:
			return cfg.bone_minutes
	return cfg.inspect_minutes


## "" = the handgrip is possible for the chosen piece (PultRules).
func action_reason(action: StringName) -> String:
	var spec := specimens.get_record(selected) if specimens != null and selected != "" else null
	if spec == null:
		return PultRules.TEXT_NO_PIECE
	var now := TimeManager.total_minutes()
	var cfg := _cfg()
	match action:
		ACTION_SEAL:
			return PultRules.seal_block_reason(spec, _inventory, now, cfg)
		ACTION_DISPLAY:
			return PultRules.display_block_reason(spec, _inventory, cfg)
		ACTION_BONE:
			return PultRules.bone_block_reason(spec, _inventory, now, cfg)
	var reason := PultRules.inspect_block_reason(spec, now, cfg)
	if reason == "" and (_inventory == null or not _inventory.has_uid(spec.uid)):
		return PultRules.TEXT_NOT_HELD
	return reason


func medicine_reason(med: MedicineData) -> String:
	var spec := specimens.get_record(selected) if specimens != null and selected != "" else null
	if not PultRules.book_known(_cfg()):
		return PultRules.TEXT_NO_BOOK
	return PultRules.medicine_block_reason(med, spec, _inventory, TimeManager.total_minutes(), _cfg())


func medicines() -> Array[MedicineData]:
	var out: Array[MedicineData] = []
	for res: Resource in Database.medicines():
		if res is MedicineData:
			out.append(res as MedicineData)
	return out


## Quast's price for a medicine (the surgeon shop's buy row; 0 = unknown).
func medicine_price(item: StringName) -> int:
	var shops := get_tree().get_first_node_in_group(&"village_shops") as VillageShops if is_inside_tree() else null
	var data := shops.shop(SHOP_SURGEON) if shops != null else Database.shop(SHOP_SURGEON) as ShopData
	if data == null or not data.buys.has(item):
		return 0
	return ShopRules.row_price(data.buys[item])


# --- actions ---------------------------------------------------------------------------------------

## A handgrip on the chosen piece: TimedAction, then finish_action.
func request_action(action: StringName) -> bool:
	if action_running or action_reason(action) != "":
		return false
	var cfg := _cfg()
	var label := {ACTION_SEAL: Phase7Texts.LABEL_SEAL, ACTION_DISPLAY: Phase7Texts.LABEL_DISPLAY, ACTION_BONE: Phase7Texts.LABEL_BONE,
			ACTION_INSPECT: Phase7Texts.LABEL_INSPECT}[action] as String
	return _start(label, action_minutes(action, cfg), finish_action.bind(action, selected, _inventory), action == ACTION_INSPECT)


func finish_action(action: StringName, uid: String, inv: Inventory) -> void:
	if specimens == null:
		return
	match action:
		ACTION_SEAL:
			specimens.seal(uid, inv)
		ACTION_DISPLAY:
			specimens.make_display(uid, inv)
		ACTION_BONE:
			specimens.make_bone(uid, inv)
		ACTION_INSPECT:
			var finding := specimens.inspect(uid)
			var data := Database.finding(finding) as SpecimenFindingData
			reply = Phase7Texts.PULT_INSPECTED % data.text if data != null else ""
	if is_open:
		refresh()


## A medicine from the chosen piece: TimedAction of its minutes, then PultRules.make_medicine.
func request_medicine(med_id: StringName) -> bool:
	var med := Database.medicine(med_id) as MedicineData
	if med == null or action_running or medicine_reason(med) != "":
		return false
	return _start(Phase7Texts.LABEL_MEDICINE % UIKit.item_name(med.output), med.minutes, finish_medicine.bind(med, selected, _inventory), false)


func finish_medicine(med: MedicineData, uid: String, inv: Inventory) -> void:
	if PultRules.make_medicine(med, uid, inv, specimens, TimeManager.total_minutes(), _cfg()):
		reply = PultRules.FORMAT_MADE % [maxi(med.amount, 1), UIKit.item_name(med.output)]
	selected = ""
	if is_open:
		refresh()


## Out of the cold box into the pack (the piece keeps its uid; PultStore closes its cold window).
func take_from_cold(uid: String) -> bool:
	if _cold == null or _inventory == null or not _cold.has_uid(uid):
		return false
	var item := _cold.uid_item(uid)
	if item == &"" or not _inventory.can_add(item, 1):
		reply = PultRules.TEXT_NO_ROOM
		refresh()
		return false
	if not _cold.remove_uid(uid):
		return false
	if not _inventory.add_unique(item, uid):
		_cold.add_unique(item, uid)
		return false
	selected = uid
	refresh()
	return true


func _start(label: String, minutes: int, done: Callable, cancellable: bool) -> bool:
	var p := _player()
	if p == null and is_inside_tree():
		p = get_tree().get_first_node_in_group(&"player")
	if p != null and p.has_method(&"start_timed_action"):
		return bool(p.call(&"start_timed_action", label, minutes, done, cancellable, ANIM))
	done.call()
	return true


func _on_fetch(med: MedicineData) -> void:
	var bench: Variant = context.get("workbench")
	if is_instance_valid(bench) and (bench as Object).has_method(&"request_fetch"):
		(bench as Object).call(&"request_fetch", PultRules.missing(med.inputs, _inventory))


func _record(corpse_id: String) -> CorpseRecord:
	var manager := get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager if is_inside_tree() else null
	return manager.get_record(corpse_id) if manager != null else null


func _cfg() -> AnatomyConfig:
	return specimens.get_config() if specimens != null else PultRules._cfg(null)


static func _percent(v: float) -> String:
	return "%d %%" % roundi(v * 100.0)
