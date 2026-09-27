class_name Desk
extends Node3D
## The gravekeeper's desk with the grave register (docs §11). [E] opens &"grave_register" with
## {entries, total, rating}; one entry per grave holding a corpse (Graveyard records + the
## CorpseManager's CorpseRecords): {name, age, cause_label, day_buried, grave_id, quality,
## marker_label}. Old graves have no record and are not listed.

const PANEL := &"grave_register"
const PROMPT_READ := "[E] Grabregister lesen"
const GRAVEYARD_GROUP := &"graveyard"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const MINUTES_PER_DAY := 1440

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy()


func get_interaction_prompt(_player: Player) -> String:
	return PROMPT_READ


func interact(player: Player) -> void:
	if can_interact(player):
		EventBus.ui_panel_requested.emit(PANEL, register_context())


## {entries, total, rating} of the current world (empty register without the systems).
func register_context() -> Dictionary:
	var graveyard := _first(GRAVEYARD_GROUP) as Graveyard
	var corpses := _first(CORPSE_MANAGER_GROUP) as CorpseManager
	return {
		"entries": register_entries(graveyard, corpses),
		"total": graveyard.total_quality() if graveyard != null else 0,
		"rating": graveyard.rating() if graveyard != null else CemeteryRating.NEGLECTED,
	}


## Entries of every FILLED / MARKED grave whose corpse record is known, in grave order.
static func register_entries(graveyard: Graveyard, corpses: CorpseManager) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if graveyard == null or corpses == null:
		return out
	var tables := corpses.tables if corpses.tables != null else Database.corpse_tables() as CorpseTables
	for grave: GraveRecord in graveyard.graves():
		if grave.corpse_id == "" or not grave.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED]:
			continue
		var record := corpses.get_record(grave.corpse_id)
		if record == null:
			continue
		var cause: Dictionary = tables.get_cause(record.cause_id) if tables != null else {}
		out.append({
			"name": record.display_name,
			"age": record.age,
			"cause_label": str(cause.get("label", record.cause_id)),
			"day_buried": record.buried_day if record.buried_day > 0 else _arrival_day(record),
			"grave_id": grave.id,
			"quality": grave.quality if grave.state == GraveRecord.State.MARKED else 0,
			"marker_label": _marker_label(grave.marker_id),
		})
	return out


@warning_ignore("integer_division")
static func _arrival_day(record: CorpseRecord) -> int:
	return record.arrival_total_minutes / MINUTES_PER_DAY + 1


static func _marker_label(marker_id: StringName) -> String:
	if marker_id == &"":
		return ""
	var item := Database.item(marker_id) as ItemData if Database.has_item(marker_id) else null
	return item.display_name if item != null and item.display_name != "" else String(marker_id)


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null
