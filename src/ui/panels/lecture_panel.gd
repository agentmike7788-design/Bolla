class_name LecturePanel
extends UIPanel
## &"lecture" – Quast's secret anatomy lecture at night (docs/PHASE7_DESIGN.md §2.6.4, §7): context
## {speaker, inventory, player, uid?} (dialogue action open_lecture, only on a lecture night; or from the
## anatomist's panel with the piece chosen). Choose a jar, a bone or a display specimen (Lectures'
## reason dims the rest – no bundle) with the fee preview and Quast's line about the night („Der
## Nachtwächter ist heute bei seiner Schwester."). „Vorlesung halten (60 Min)": the veil at 60 % with
## three calm lines of his talk (nothing about the inside), LectureSet.show_lecture(organ) when the room
## has one, a TimedAction of lecture.minutes, then Lectures.hold – the result card shows the fee and the
## new teaching. One lecture a night; the examination table stays under its cloth.

const SPECIMENS_GROUP := &"specimens"
const LECTURES_GROUP := &"lectures"
const MANAGER_GROUP := &"corpse_manager"
const LECTURE_SET_GROUP := &"lecture_set"
const ANIM := &"interact"
const DEFAULT_MINUTES := 60
const DEFAULT_VEIL := 0.6

@export var panel_width: float = 1180.0

var specimens: Specimens
var lectures: Lectures
var intro_label: Label
var night_label: Label
var list_box: VBoxContainer
var empty_label: Label
var chosen_label: Label
var reason_label: Label
var hold_button: Button
var result_card: PanelContainer
var result_fee: Label
var result_teaching: Label
## uid -> {row, fee}
var rows: Dictionary[String, Dictionary] = {}
var selected: String = ""
var result: Dictionary = {}

var _inventory: Inventory


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	_make_header(box, Phase7Texts.LECTURE_TITLE)
	intro_label = UIKit.label(Phase7Texts.LECTURE_INTRO, &"WhisperLabel", true)
	intro_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(intro_label)
	night_label = UIKit.label("", &"AccentLabel", true)
	box.add_child(night_label)
	box.add_child(UIKit.separator())
	list_box = UIKit.vbox(6)
	box.add_child(list_box)
	empty_label = UIKit.label(Phase7Texts.LECTURE_EMPTY, &"DimLabel", true)
	box.add_child(empty_label)
	result_card = UIKit.panel(&"CardPanel")
	var rbox := UIKit.vbox(4)
	rbox.add_child(UIKit.label(Phase7Texts.LECTURE_RESULT, &"InkHeaderLabel"))
	result_fee = UIKit.label("", &"InkLabel")
	rbox.add_child(result_fee)
	result_teaching = UIKit.label("", &"InkStampLabel", true)
	rbox.add_child(result_teaching)
	rbox.add_child(UIKit.label(Phase7Texts.LECTURE_RESULT_STAYS, &"InkDimLabel"))
	result_card.add_child(rbox)
	box.add_child(result_card)
	_make_action_row(box)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	chosen_label = UIKit.label("", &"SubheaderLabel")
	chosen_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(chosen_label)
	reason_label = UIKit.label("", &"WarningLabel", true)
	reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reason_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(reason_label)
	var back := UIKit.button(TEXT_CLOSE)
	back.pressed.connect(request_close)
	bottom.add_child(back)
	hold_button = UIKit.button("", &"AccentButton")
	hold_button.pressed.connect(request_hold)
	bottom.add_child(hold_button)
	box.add_child(bottom)


func _on_opened() -> void:
	specimens = get_tree().get_first_node_in_group(SPECIMENS_GROUP) as Specimens if is_inside_tree() else null
	lectures = get_tree().get_first_node_in_group(LECTURES_GROUP) as Lectures if is_inside_tree() else null
	result = {}
	_inventory = _player_inventory()
	if _inventory == null and is_inside_tree():
		var p := get_tree().get_first_node_in_group(&"player")
		_inventory = p.get(&"inventory") as Inventory if p != null else null
	selected = str(context.get("uid", ""))
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


## Held pieces in the pack that could stand on the lectern (no bundle).
func candidates() -> PackedStringArray:
	var out := PackedStringArray()
	if specimens == null or _inventory == null:
		return out
	for uid: String in specimens.held():
		var spec := specimens.get_record(uid)
		if _inventory.has_uid(uid) and spec.container != SpecimenRecord.CONTAINER_BUNDLE:
			out.append(uid)
	return out


func _refresh() -> void:
	night_label.text = lectures.night_line() if lectures != null else ""
	night_label.visible = night_label.text != ""
	UIKit.clear_children(list_box)
	rows.clear()
	var list := candidates()
	if selected == "" or not list.has(selected):
		selected = _first_open(list)
	var now := TimeManager.total_minutes()
	var cfg := specimens.get_config() if specimens != null else AnatomyConfig.new()
	for uid: String in list:
		var spec := specimens.get_record(uid)
		var r := Phase7Texts.specimen_row(spec, _record(spec.corpse_id), now, cfg)
		var chosen := uid == selected
		var b := UIKit.button("", &"BuildSlotSelected" if chosen else &"SlotButton")
		b.custom_minimum_size = Vector2(panel_width - 80.0, 54.0)
		b.pressed.connect(select.bind(uid))
		var line := UIKit.hbox(18)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 18.0
		line.offset_right = -18.0
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name := UIKit.label("%s – %s – %s" % [str(r.organ_label), str(r.name), str(r.container_word)], &"SubheaderLabel")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(name)
		var fee := lectures.fee_for(uid) if lectures != null else 0
		var fee_label := UIKit.label(Phase7Texts.LECTURE_FEE % [fee, Phase7Texts.coins(fee)], &"AccentLabel")
		fee_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(fee_label)
		b.add_child(line)
		var reason := lectures.hold_block_reason(uid, _inventory) if lectures != null else Phase7Texts.LECTURE_NOT_TONIGHT
		b.tooltip_text = reason
		b.set_meta(&"uid", uid)
		list_box.add_child(b)
		rows[uid] = {"row": b, "fee": fee_label}
	empty_label.visible = list.is_empty()
	result_card.visible = not result.is_empty() and bool(result.get("ok", false))
	if result_card.visible:
		var fee_v := int(result.get("fee", 0))
		result_fee.text = Phase7Texts.LECTURE_RESULT_FEE % [fee_v, Phase7Texts.coins(fee_v)]
		var t := Database.teaching(StringName(str(result.get("teaching", "")))) as TeachingData
		result_teaching.text = Phase7Texts.LECTURE_RESULT_TEACHING % (t.title if t != null else str(result.get("teaching", ""))) \
				if bool(result.get("learned", false)) else Phase7Texts.LECTURE_RESULT_KNOWN
	var chosen_spec := specimens.get_record(selected) if specimens != null and selected != "" else null
	chosen_label.text = Phase7Texts.PULT_CHOSEN % Phase7Texts.organ_label(chosen_spec.organ, cfg) if chosen_spec != null else Phase7Texts.LECTURE_PICK
	var minutes := int(cfg.lecture.get("minutes", DEFAULT_MINUTES))
	hold_button.text = Phase7Texts.LECTURE_BUTTON % UIKit.minutes(minutes)
	var block := block_reason()
	hold_button.disabled = block != ""
	hold_button.tooltip_text = block
	reason_label.text = block if block != TEXT_BUSY and selected != "" else ""


func block_reason() -> String:
	if action_running:
		return TEXT_BUSY
	if lectures == null:
		return Phase7Texts.LECTURE_NOT_TONIGHT
	if selected == "":
		return Phase7Texts.LECTURE_PICK
	return lectures.hold_block_reason(selected, _inventory)


func select(uid: String) -> void:
	selected = uid
	refresh()


## Veil 60 % + talk, TimedAction, then finish_hold.
func request_hold() -> bool:
	if block_reason() != "":
		return false
	var spec := specimens.get_record(selected)
	var cfg := specimens.get_config()
	var minutes := int(cfg.lecture.get("minutes", DEFAULT_MINUTES))
	var uid := selected
	var inv := _inventory
	_show_scene(spec.organ, float(cfg.lecture.get("veil_alpha", DEFAULT_VEIL)))
	var p := _player_node()
	if p != null and p.has_method(&"start_timed_action"):
		if not EventBus.timed_action_finished.is_connected(_on_lecture_finished):
			EventBus.timed_action_finished.connect(_on_lecture_finished, CONNECT_ONE_SHOT)
		if bool(p.call(&"start_timed_action", Phase7Texts.LECTURE_ACTION, minutes, finish_hold.bind(uid, inv), false, ANIM)):
			return true
		if EventBus.timed_action_finished.is_connected(_on_lecture_finished):
			EventBus.timed_action_finished.disconnect(_on_lecture_finished)
		_hide_scene()
		return false
	finish_hold(uid, inv)
	_hide_scene()
	return true


func finish_hold(uid: String, inv: Inventory) -> void:
	if lectures == null:
		return
	result = lectures.hold(uid, inv)
	selected = ""
	if is_open:
		refresh()


func _on_lecture_finished(_completed: bool) -> void:
	_hide_scene()


func _show_scene(organ: StringName, alpha: float) -> void:
	var veil := _veil()
	if veil != null:
		veil.open(alpha, Phase7Texts.LECTURE_INTRO, Phase7Texts.lecture_lines(organ))
	var set_node := _lecture_set()
	if set_node != null and set_node.has_method(&"show_lecture"):
		set_node.call(&"show_lecture", organ)


func _hide_scene() -> void:
	var veil := _veil()
	if veil != null:
		veil.close()
	var set_node := _lecture_set()
	if set_node != null and set_node.has_method(&"hide_lecture"):
		set_node.call(&"hide_lecture")


func _first_open(list: PackedStringArray) -> String:
	for uid: String in list:
		if lectures != null and lectures.hold_block_reason(uid, _inventory) == "":
			return uid
	return list[0] if not list.is_empty() else ""


func _veil() -> ScreenVeil:
	return get_tree().get_first_node_in_group(ScreenVeil.GROUP) as ScreenVeil if is_inside_tree() else null


func _lecture_set() -> Node:
	return get_tree().get_first_node_in_group(LECTURE_SET_GROUP) if is_inside_tree() else null


func _record(corpse_id: String) -> CorpseRecord:
	var manager := get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager if is_inside_tree() else null
	return manager.get_record(corpse_id) if manager != null else null


func _player_node() -> Node:
	var p := _player()
	if p != null:
		return p
	return get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
