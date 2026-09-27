class_name MorgueTable
extends Node3D
## Examination table (group morgue_table). A corpse lies on the model's slot_corpse marker.
## Occupancy is derived from the CorpseManager records (location &"table") – nothing is saved
## here, and after a load the corpse node lives under the Corpses container at its saved spot.
## Carrying + free table: put down. Free hands + occupied: opens the corpse_exam panel, whose
## buttons call request_examine / request_shroud / decide_valuables / request_pick_up.

const GROUP := &"morgue_table"
const MANAGER_GROUP := &"corpse_manager"
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
		EventBus.ui_panel_requested.emit(EXAM_PANEL, {"corpse_id": corpse_id, "table": self, "player": player})


## Panel: examine the corpse on the table (timed examine_minutes, not cancellable).
func request_examine() -> void:
	var record := _table_record()
	var player := _acting_player()
	if record == null:
		_warn(TEXT_NO_CORPSE)
	elif record.examined:
		_warn(TEXT_EXAMINED)
	elif not _can_act(player):
		_warn(TEXT_BUSY)
	else:
		player.start_timed_action(LABEL_EXAMINE, _actions(player).examine_minutes, _finish_examine.bind(record.id), false, ANIM)


## Panel: wrap the corpse in a shroud (needs 1 shroud; locked while the valuables decision is open).
func request_shroud() -> void:
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


## The model's slot_corpse marker (the corpse is parented to it with identity transform).
func slot_node() -> Node3D:
	var slot := find_child(SLOT_NAME, true, false) as Node3D
	return slot if slot != null else self


func slot_transform() -> Transform3D:
	return slot_node().global_transform


func _finish_examine(id: String) -> void:
	var manager := _manager()
	if manager != null and _is_on_table(id):
		manager.examine(id)


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
