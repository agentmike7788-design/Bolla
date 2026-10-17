class_name Stranger
extends Node
## STUB (P5) – Systems/Stranger (docs/PHASE9_DESIGN.md §2.5, §3.1, §3.3, §3.4, §5.1), groups &"stranger", &"saveable",
## save_id stranger / 84: Cornelius Brenneisen, the gentleman with the case – his visits (p9_open_day + 2, every 5 days
## for 3 days; over the Holderbrücke on foot, the Holderkrug, outside the cemetery gate 14:10–15:30 – he never enters
## the cemetery), the questions (K1), what he wants to buy (K2: soil, the register extract, specimens – never a
## corpse), the bribe (K3), the case (K4), the three endings Fenner / deal / Ilse (K5).
## W0: gone() and case_holder() answer from load_state (§5.1 {visits, answers, sold, bribe, case, ending, rumors});
## everything else is inert. W1 (P5) fills the bodies; the signatures are the contract.

const GROUP := &"stranger"
const ANSWERS: Array[StringName] = [&"frank", &"evade", &"refuse"]
const ENDINGS: Array[StringName] = [&"fenner", &"deal", &"ilse"]
const CASE_HOLDERS: Array[StringName] = [&"inn", &"player", &"fenner", &"stranger"]

@export var save_id: String = "stranger"
@export var save_order: int = 84

## Rules; null = data/config/stranger_config.tres (resolved lazily).
var config: StrangerConfig

## W0 stub store (P5 may rename it – the fixtures use load_state only).
var _ending: StringName = &""
var _case: StringName = &""


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func present(_region: StringName) -> bool:
	return false


## His chain has ended (K5) – he never comes again.
func gone() -> bool:
	return _ending != &""


## &"frank" | &"evade" | &"refuse"
func answer(_kind: StringName) -> void:
	pass


func offers(_inv: Inventory) -> Array[Dictionary]:
	return []


func sell(_offer_id: StringName, _inv: Inventory) -> bool:
	return false


func take_soil(_grave_id: String, _inv: Inventory) -> bool:
	return false


func bribe(_accept: bool, _inv: Inventory) -> void:
	pass


## &"inn" | &"player" | &"fenner" | &"stranger" (&"" = no case yet).
func case_holder() -> StringName:
	return _case


## &"fenner" | &"deal" | &"ilse"
func resolve(_choice: StringName) -> void:
	pass


func apply_morning(_day: int) -> void:
	pass


func apply_minute(_day: int, _minute: int) -> void:
	pass


## §5.1 {visits, answers, sold, bribe, case, ending, rumors}.
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	var e := StringName(str(data.get("ending", "")))
	_ending = e if e in ENDINGS else &""
	var c := StringName(str(data.get("case", "")))
	_case = c if c in CASE_HOLDERS else &""
