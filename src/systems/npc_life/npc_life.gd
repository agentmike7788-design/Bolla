class_name NpcLife
extends Node
## STUB (P1) – Systems/NpcLife (docs/PHASE8_DESIGN.md §1.2, §1.5, §2.1, §3.1, §3.4, §5.1), groups
## &"npc_life", &"saveable": the opening of Phase 8 (p8_open at the first morning after
## name_in_village_complete, at once for a migrated v6 save), the daily moods (derived, not saved),
## the events the moods and remarks read (note_event), „[Zuhören]", the chapter „Wer heraufkommt".
## W0: is_open() / open_day() answer from the GameState flags p8_open / p8_open_day (Phase8Fixtures.p8_open);
## mood() is &"plain", everything else inert.
## W1 (P1) fills the bodies; the signatures are the contract.

const GROUP := &"npc_life"
const FLAG_OPEN := &"p8_open"
const FLAG_OPEN_DAY := &"p8_open_day"
const MOOD_PLAIN := &"plain"
const MOOD_CHEERFUL := &"cheerful"
const MOOD_LOW := &"low"
const MOOD_CROSS := &"cross"

@export var save_id: String = "npc_life"
@export var save_order: int = 70

## Rules; null = data/config/npc_life_config.tres (resolved lazily).
var config: NpcLifeConfig


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## Flag p8_open.
func is_open() -> bool:
	return GameState.flag_on(FLAG_OPEN)


## Flag p8_open_day (0 = not open).
func open_day() -> int:
	var v: Variant = GameState.get_flag(FLAG_OPEN_DAY, 0)
	return int(v) if v is int or v is float else 0


## 06:00: p8_open (idempotent), roll the moods, moods_rolled.
func apply_morning(_day: int) -> void:
	pass


## v6 with name_in_village_complete → p8_open at once (§1.2).
func post_load() -> void:
	pass


## Today's mood (derived from day + saved events, not saved).
func mood(_npc_id: StringName) -> StringName:
	return MOOD_PLAIN


## Remembers day + event (moods, remarks).
func note_event(_event: StringName, _npcs: Array[StringName] = []) -> void:
	pass


## The newest valid event for the remark or &"".
func reaction_for(_npc_id: StringName) -> StringName:
	return &""


## "" = „[Zuhören]" possible (mood low, once per day and person).
func listen_block_reason(_npc_id: StringName) -> String:
	return "-"


## 10 minutes, relationship +3 (listen), piety +1.
func listen(_npc_id: StringName) -> bool:
	return false


## §1.5 – exactly once: who_comes_up_complete, chapter_completed(&"who_comes_up").
func check_goal() -> bool:
	return false


## {levels, wishes, kin, steps, full, insight} for the objective line.
func goal_progress() -> Dictionary:
	return {}


## {open_day, events, event_npcs, listened, chatter_day, goal_done} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass
