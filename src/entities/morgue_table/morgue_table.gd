class_name MorgueTable
extends Node3D
## Examination table (group morgue_table). A corpse lies on the model's slot_corpse marker.
## Occupancy is derived from the CorpseManager records (location &"table") – nothing is saved
## here, and after a load the corpse node lives under the Corpses container at its saved spot.
## Carrying + free table: put down. Free hands + occupied: opens the corpse_exam panel, whose
## buttons call request_exam_step / request_exam_all / request_wash / request_dress /
## request_lay_out / request_balm / request_harvest (Phase 4, via Systems/CorpseCare),
## decide_valuables and request_pick_up; request_examine / request_shroud stay for the
## Phase-2 panel. panel_state() is the read-only view model of the Phase-4 panel.

const GROUP := &"morgue_table"
const MANAGER_GROUP := &"corpse_manager"
const CARE_GROUP := &"corpse_care"
const SLOT_NAME := "slot_corpse"
const EXAM_PANEL := &"corpse_exam"
const SHROUD_ITEM := &"shroud"
const ANIM := &"interact"

const PROMPT_PUT_DOWN := "[E] Leiche ablegen"
const PROMPT_EXAMINE := "[E] Leiche untersuchen"
## After the examination the panel still offers shroud, valuables and pick up (UI-07).
const PROMPT_VIEW := "[E] Leiche ansehen"
const PROMPT_OCCUPIED := "Der Tisch ist belegt"
const LABEL_EXAMINE := "Untersuchen"
const LABEL_SHROUD := "Leichentuch anlegen"
const LABEL_GOWN := "Totenhemd anziehen"
const LABEL_EXAM_ALL := "Gründlich untersuchen"
const LABEL_WASH := "Waschen"
const LABEL_LAY_OUT := "Aufbahren"
const LABEL_BALM := "Mit Wacholder räuchern"
const TEXT_NO_CORPSE := "Auf dem Tisch liegt keine Leiche."
const TEXT_EXAMINED := "Die Leiche ist bereits untersucht."
const TEXT_SHROUDED := "Die Leiche ist bereits eingehüllt."
const TEXT_DECIDE_FIRST := "Erst über die Wertsachen entscheiden."
const TEXT_NO_SHROUD := "Kein Leichentuch – an der Werkbank herstellen."
const TEXT_NO_DECISION := "Hier gibt es nichts zu entscheiden."
const TEXT_BUSY := "Gerade nicht möglich."

## Id of the corpse on the table ("" = free), always derived from the CorpseManager records.
var corpse_id: String = "":
	get:
		return _table_corpse_id()

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

# Phase 6 (docs/PHASE6_DESIGN.md §2.2, §3.4; P2): the crypt table (room &"crypt", requires_level 1)
# and the old table in front of the hut (retire_at_level 1). Exactly one table is active.
@export var room: StringName = &""
@export var requires_level: int = 0
## 0 = never retires.
@export var retire_at_level: int = 0

## Player of the last interaction (the panel acts for them).
var _player: Player


func _init() -> void:
	add_to_group(GROUP, true)


func can_interact(player: Player) -> bool:
	if player == null or player.is_busy():
		return false
	if _is_carrying(player):
		return corpse_id == ""
	return corpse_id != ""


func get_interaction_prompt(player: Player) -> String:
	var record := _table_record()
	if player != null and _is_carrying(player):
		return PROMPT_OCCUPIED if record != null else PROMPT_PUT_DOWN
	if record == null:
		return ""
	return PROMPT_VIEW if record.examined else PROMPT_EXAMINE


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	_player = player
	var manager := _manager()
	if manager == null:
		return
	if _is_carrying(player):
		var slot := slot_node()
		manager.put_down(player.carried_id, CorpseRecord.LOCATION_TABLE, slot_transform(), slot)
	else:
		# The panel shows the freshness of now (the hourly decay may lag, QA4-01).
		manager.refresh_decay(corpse_id)
		EventBus.ui_panel_requested.emit(EXAM_PANEL, {"corpse_id": corpse_id, "table": self, "player": player})


## Panel (Phase 2, compatibility): examine the corpse on the table – examine_minutes, not
## cancellable. With a CorpseCare node every open step is resolved at the end (the Phase-2
## panel showed everything at once); without one the Phase-2 flag only.
func request_examine() -> void:
	var record := _table_record()
	var player := _acting_player()
	var care := _care()
	if record == null:
		_warn(TEXT_NO_CORPSE)
	elif (care == null and record.examined) or (care != null and care.open_steps(record.id).is_empty()):
		_warn(TEXT_EXAMINED)
	elif not _can_act(player):
		_warn(TEXT_BUSY)
	else:
		player.start_timed_action(LABEL_EXAMINE, _actions(player).examine_minutes, _finish_examine.bind(record.id), false, ANIM)


## Panel (Phase 2, compatibility) = request_dress(&"shroud").
func request_shroud() -> void:
	request_dress(CorpseRecord.DRESS_SHROUD)


## Panel: final valuables decision (take = coins now, quality and reputation suffer).
func decide_valuables(take: bool) -> void:
	var record := _table_record()
	var player := _acting_player()
	if record == null:
		_warn(TEXT_NO_CORPSE)
	elif not record.needs_valuables_decision():
		_warn(TEXT_NO_DECISION)
	elif player == null or player.is_busy():
		_warn(TEXT_BUSY)
	else:
		_manager().decide_valuables(record.id, take, player.inventory)


## Panel: carry the corpse again.
func request_pick_up() -> void:
	var record := _table_record()
	var player := _acting_player()
	if record == null:
		_warn(TEXT_NO_CORPSE)
	elif not _can_act(player):
		_warn(TEXT_BUSY)
	else:
		_manager().pick_up(record.id, player)


# --- Phase 4 panel calls (docs/PHASE4_DESIGN.md §3.4) ---------------------------------------
# Every call checks the CorpseCare reason first (a warning note otherwise), runs its minutes as
# a timed action that cannot be cancelled and applies the result at the end (CorpseCare re-checks).

## One examination step (ExamConfig minutes).
func request_exam_step(step: StringName) -> void:
	var record := _table_record()
	var care := _care()
	var player := _acting_player()
	if not _ready_to_act(record, care, player):
		return
	var reason := care.step_block_reason(record.id, step)
	if reason != "":
		_warn(reason)
		return
	var cfg := care.get_exam_config()
	var label := String(cfg.step(step).get("verb", LABEL_EXAMINE))
	player.start_timed_action(label, cfg.step_minutes(step), _finish_exam_step.bind(record.id, step), false, ANIM)


## "Gründlich untersuchen": all open steps as one timed action, then CorpseCare.exam_all.
func request_exam_all() -> void:
	var record := _table_record()
	var care := _care()
	var player := _acting_player()
	if not _ready_to_act(record, care, player):
		return
	if care.open_steps(record.id).is_empty():
		_warn(TEXT_EXAMINED)
		return
	player.start_timed_action(LABEL_EXAM_ALL, care.exam_all_minutes(record.id), _finish_exam_all.bind(record.id), false, ANIM)


func request_wash() -> void:
	_request_prep(CorpsePrep.ACTION_WASH, &"", LABEL_WASH)


## kind: CorpseRecord.DRESS_SHROUD / DRESS_GOWN. Without a CorpseCare node the Phase-2 shroud.
func request_dress(kind: StringName) -> void:
	if _care() == null and kind == CorpseRecord.DRESS_SHROUD:
		_request_shroud_phase2()
		return
	_request_prep(CorpsePrep.ACTION_DRESS, kind, LABEL_GOWN if kind == CorpseRecord.DRESS_GOWN else LABEL_SHROUD)


func request_lay_out() -> void:
	_request_prep(CorpsePrep.ACTION_LAY_OUT, &"", LABEL_LAY_OUT)


func request_balm() -> void:
	_request_prep(CorpsePrep.ACTION_BALM, &"", LABEL_BALM)


## kind: CorpseRecord.HARVEST_HAIR / HARVEST_TEETH (UtilizationConfig minutes and verb). No
## note while the button is hidden (trader not known).
func request_harvest(kind: StringName) -> void:
	var record := _table_record()
	var care := _care()
	var player := _acting_player()
	if not _ready_to_act(record, care, player):
		return
	var reason := care.harvest_block_reason(record.id, kind, player.inventory)
	if reason == UtilizationRules.HIDDEN:
		return
	if reason != "":
		_warn(reason)
		return
	var entry := care.get_utilization_config().kind(kind)
	player.start_timed_action(String(entry.get("verb", String(kind))), int(entry.get("minutes", 0)),
			_finish_harvest.bind(record.id, kind, player.inventory), false, ANIM)


## Everything the Phase-4 panel needs about the corpse on the table ({} = none): steps with
## label / minutes / done / reason, open steps + minutes, finds per step (revealed / lost /
## pending with text and clue), preparation lines with minutes / reason, harvest kinds with
## reason (hidden = "-"), the loss forecast and the running juniper window.
func panel_state() -> Dictionary:
	var record := _table_record()
	var care := _care()
	var player := _acting_player()
	if record == null or care == null:
		return {}
	var inv: Inventory = player.inventory if player != null else null
	return MorgueTablePanelState.build(record, care, inv)


## The model's slot_corpse marker (the corpse is parented to it with identity transform).
func slot_node() -> Node3D:
	var slot := find_child(SLOT_NAME, true, false) as Node3D
	return slot if slot != null else self


func slot_transform() -> Transform3D:
	return slot_node().global_transform


func _finish_examine(id: String) -> void:
	var manager := _manager()
	if manager == null or not _is_on_table(id):
		return
	var care := _care()
	if care != null:
		care.exam_all_instant(id)
	else:
		manager.examine(id)


func _finish_exam_step(id: String, step: StringName) -> void:
	var care := _care()
	if care != null and _is_on_table(id):
		care.exam_step(id, step)


func _finish_exam_all(id: String) -> void:
	var care := _care()
	if care != null and _is_on_table(id):
		care.exam_all(id)


func _finish_prep(id: String, action: StringName, kind: StringName, inv: Inventory) -> void:
	var care := _care()
	if care == null or not _is_on_table(id):
		return
	var ok := false
	match action:
		CorpsePrep.ACTION_WASH:
			ok = care.wash(id, inv)
		CorpsePrep.ACTION_DRESS:
			ok = care.dress(id, kind, inv)
		CorpsePrep.ACTION_LAY_OUT:
			ok = care.lay_out(id, inv)
		CorpsePrep.ACTION_BALM:
			ok = care.apply_balm(id, inv)
	if not ok:
		_warn(TEXT_BUSY)


func _finish_harvest(id: String, kind: StringName, inv: Inventory) -> void:
	var care := _care()
	if care != null and _is_on_table(id) and not care.harvest(id, kind, inv):
		var reason := care.harvest_block_reason(id, kind, inv)
		_warn(reason if reason != "" and reason != UtilizationRules.HIDDEN else TEXT_BUSY)


func _request_prep(action: StringName, kind: StringName, label: String) -> void:
	var record := _table_record()
	var care := _care()
	var player := _acting_player()
	if not _ready_to_act(record, care, player):
		return
	var reason := care.prep_block_reason(record.id, action, player.inventory, kind)
	if reason != "":
		_warn(reason)
		return
	player.start_timed_action(label, CorpsePrep.minutes(action, care.get_prep_config(), kind),
			_finish_prep.bind(record.id, action, kind, player.inventory), false, ANIM)


## Phase-2 shroud (no CorpseCare in the world): needs 1 shroud, locked while the valuables
## decision is open.
func _request_shroud_phase2() -> void:
	var record := _table_record()
	var player := _acting_player()
	if record == null:
		_warn(TEXT_NO_CORPSE)
	elif record.shrouded:
		_warn(TEXT_SHROUDED)
	elif record.needs_valuables_decision():
		_warn(TEXT_DECIDE_FIRST)
	elif not _can_act(player):
		_warn(TEXT_BUSY)
	elif not player.inventory.has(SHROUD_ITEM):
		_warn(TEXT_NO_SHROUD)
	else:
		player.start_timed_action(LABEL_SHROUD, _actions(player).shroud_minutes, _finish_shroud.bind(record.id, player.inventory), false, ANIM)


## Table corpse, CorpseCare node and a free player – warns otherwise.
func _ready_to_act(record: CorpseRecord, care: CorpseCare, player: Player) -> bool:
	if record == null:
		_warn(TEXT_NO_CORPSE)
		return false
	if care == null or not _can_act(player):
		_warn(TEXT_BUSY)
		return false
	return true


func _care() -> CorpseCare:
	return get_tree().get_first_node_in_group(CARE_GROUP) as CorpseCare if is_inside_tree() else null


func _finish_shroud(id: String, inv: Inventory) -> void:
	var manager := _manager()
	if manager != null and _is_on_table(id) and not manager.apply_shroud(id, inv):
		_warn(TEXT_NO_SHROUD)


func _table_record() -> CorpseRecord:
	var manager := _manager()
	var id := corpse_id
	return manager.get_record(id) if manager != null and id != "" else null


func _table_corpse_id() -> String:
	var manager := _manager()
	if manager == null:
		return ""
	for record: CorpseRecord in manager.records():
		if record.location == CorpseRecord.LOCATION_TABLE:
			return record.id
	return ""


func _is_on_table(id: String) -> bool:
	var record := _manager().get_record(id)
	return record != null and record.location == CorpseRecord.LOCATION_TABLE


func _acting_player() -> Player:
	if is_instance_valid(_player):
		return _player
	return get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null


func _can_act(player: Player) -> bool:
	return player != null and not player.is_busy() and not _is_carrying(player)


func _manager() -> CorpseManager:
	return get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager if is_inside_tree() else null


func _warn(text: String) -> void:
	EventBus.notification_requested.emit(text, &"warning")


static func _actions(player: Player) -> ActionConfig:
	if player != null and player.actions != null:
		return player.actions
	var cfg := Database.config(&"action_config") as ActionConfig
	return cfg if cfg != null else ActionConfig.new()


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)


## STUB (P2) – Buildings.level(&"crypt") in [requires_level, retire_at_level) (retire 0 = never).
## W0: always true (the old table stays active).
func is_active() -> bool:
	return true
