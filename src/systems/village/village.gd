class_name Village
extends Node
## STUB (P3) – Systems/Village (docs/PHASE7_DESIGN.md §1.2, §1.5, §2.9, §3.1, §3.4, §5.1), groups
## &"village", &"saveable": village_open (morning rule; a migrated v5 save with roof_and_earth_complete
## opens at once in post_load), the consecration of the Lindenacker (price, day, Village.consecrate at
## 10:30 → linden_consecrated, ground_consecrated, ExpansionManager.try_unlock), the round in the
## Holderkrug, the poor box, the mourning ribbon and the chapter „Ein Name im Dorf".
## W1 (P3) fills the bodies; the signatures are the contract.

const GROUP := &"village"
const FLAG_OPEN := &"village_open"
const FLAG_OPEN_DAY := &"village_open_day"
const FLAG_LINDEN_GRANTED := &"linden_granted"
const FLAG_CONSECRATION_DAY := &"linden_consecration_day"
const FLAG_CONSECRATED := &"linden_consecrated"

@export var save_id: String = "village"
@export var save_order: int = 50

## Rules; null = data/config/village_config.tres (resolved lazily).
var config: VillageConfig


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## Flag village_open.
func is_open() -> bool:
	return false


func apply_morning(_day: int) -> void:
	pass


## v5 → open at once (§1.2).
func post_load() -> void:
	pass


## time_tick: end of the consecration, the mourning ribbon.
func apply_minute(_day: int, _minute: int) -> void:
	pass


func consecration_price() -> int:
	return 0


## linden_consecration_day = tomorrow.
func pay_consecration(_inv: Inventory) -> bool:
	return false


## linden_consecrated, ground_consecrated, ExpansionManager.try_unlock.
func consecrate() -> void:
	pass


## The innkeeper present, once per day; Relationships.add(round) for everyone in the inn.
func buy_round(_inv: Inventory) -> bool:
	return false


## One step; reputation +1, Fenner +1.
func donate(_inv: Inventory) -> bool:
	return false


## The house with the mourning ribbon ("" = none).
func mourning_house(_day: int) -> StringName:
	return &""


func goal_progress() -> Dictionary:
	return {}


func check_goal() -> void:
	pass


## {open_day, consecration_paid_day, round_day, donation_day, donation_steps, goal_done, ribbon_seen} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass
