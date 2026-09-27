class_name JournalManager
extends Node
## STUB (P6) – docs/PHASE4_DESIGN.md §2.12, §3.4, §5.1. Systems/Journal (groups &"journal",
## &"saveable"): clues, insights, unread marks; the death notes are derived from the records.
## add_clue also sets the flag clue_<id> (dialogue conditions).

const GROUP := &"journal"

@export var save_id: String = "journal"
@export var save_order: int = 40


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func has_clue(_id: StringName) -> bool:
	return false


## false = already there (then only the counter); clue_found; notification "Ins Merkbuch: <Titel>".
func add_clue(_id: StringName, _corpse_id: String = "", _silent: bool = false) -> bool:
	return false


## How many dead carry the generic clue.
func clue_count(_id: StringName) -> int:
	return 0


func clues() -> Array[StringName]:
	return []


## insight_unlocked, flag, renaming via CorpseManager; &"" without consequences.
func try_link(_ids: Array[StringName]) -> StringName:
	return &""


func insights() -> Array[StringName]:
	return []


func has_insight(_id: StringName) -> bool:
	return false


## Derived: {corpse_id, name, age, cause, day, grave_id, story_id, finds, lost, washed, dress,
## laid_out, harvested, heard}.
func people() -> Array[Dictionary]:
	return []


func unread() -> Array[StringName]:
	return []


func mark_read(_ids: Array[StringName]) -> void:
	pass


## Silently: clues from finds_revealed of all records (migration, load). Returns the number added.
func sync_from_records() -> int:
	return 0


## {"clues": {id: {"day", "corpse", "count"}}, "insights": {id: day}, "unread": [ids]} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass


## → sync_from_records
func post_load() -> void:
	pass
