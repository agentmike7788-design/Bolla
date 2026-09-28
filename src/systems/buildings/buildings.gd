class_name Buildings
extends Node
## STUB (P1) – Systems/Buildings (docs/PHASE6_DESIGN.md §1.2, §1.5, §2.1, §3.1, §3.3, §3.4, §5.1,
## §5.2), groups &"buildings", &"saveable": the levels of crypt, chapel and shed, buildings_open,
## the chapter „Unter Dach und Erde" and the one-time clearing of decor on the site rects.
## W1 (P1) fills the bodies; the signatures are the contract.
## W0: level() answers from load_state({"levels": {…}}) so W1 tests can set levels
## (Phase6Fixtures.crypt_at / buildings_at) before P1 is merged; everything else is inert.

const GROUP := &"buildings"
const CRYPT := &"crypt"
const CHAPEL := &"chapel"
const SHED := &"shed"

@export var save_id: String = "buildings"
@export var save_order: int = 32
## Footprint + margin + access of the building sites (the builder fills them from
## layout.buildings.site_rects); decor in them is cleared once (post_load, §5.2 step 5).
@export var site_rects: Array[Rect2] = []

## Rules; null = data/config/buildings_config.tres (resolved lazily).
var config: BuildingsConfig

## W0 stub store of the levels (P1 may rename it – the fixtures use load_state only).
var _levels: Dictionary[StringName, int] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## Flag buildings_open.
func is_open() -> bool:
	return false


## 0 (site) … 3.
func level(building_id: StringName) -> int:
	return int(_levels.get(building_id, 0))


func levels() -> Dictionary[StringName, int]:
	return _levels.duplicate()


func upgrade_block_reason(_building_id: StringName, _inv: Inventory) -> String:
	return ""


## Atomic (items + coins at the end); building_upgraded; note_coins_spent(&"building");
## apply_levels; crypt 1: CorpseManager.relocate_table_corpse; check_goal.
func upgrade(_building_id: StringName, _inv: Inventory) -> bool:
	return false


## Rooms, tables, niches, shed, cold windows to the current levels (also post_load).
func apply_levels() -> void:
	pass


func goal_progress() -> Dictionary:
	return {"done": 0, "total": 0, "missing": PackedStringArray()}


## Chapter §1.5 once.
func check_goal() -> void:
	pass


## Idempotent: buildings_open from unlock_flag at the first minute ≥ intro_minute.
func apply_morning(_day: int) -> void:
	pass


func save_state() -> Dictionary:
	return {}


## W0: only reads "levels" (§5.1) so tests can set levels.
func load_state(data: Dictionary) -> void:
	_levels.clear()
	var saved: Variant = data.get("levels")
	if saved is Dictionary:
		for key: Variant in saved:
			_levels[StringName(str(key))] = int(saved[key])


## v4 → buildings_open at once; site_rects cleared (§5.2).
func post_load() -> void:
	pass
