class_name Lectures
extends Node
## STUB (P8) – Systems/Lectures (docs/PHASE7_DESIGN.md §2.6.4, §2.6.5, §3.1, §3.4, §5.1), groups
## &"lectures", &"saveable": the invitation, tonight's lecture (HouseDoor asks door_open), hold after the
## TimedAction (Specimens.consume(lectured), the fee, the teaching, piety, Quast +3, lecture_held), the
## known teachings, the rumour of the night on the next morning (once).
## W0: invited() / known_teachings() answer from load_state({"invited", "teachings", …}) so W1 tests can
## set them (Phase7Fixtures.lecture_night); everything else is inert.
## W1 (P8) fills the bodies; the signatures are the contract.

const GROUP := &"lectures"
const SURGERY_DOOR := &"door_surgery"

@export var save_id: String = "lectures"
@export var save_order: int = 55

## Rules; null = data/config/anatomy_config.tres (resolved lazily).
var config: AnatomyConfig

## W0 stub store (P8 may rename it – the fixtures use load_state only).
var _invited: bool = false
var _teachings: PackedStringArray = []


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func invited() -> bool:
	return _invited


## Today is a lecture night and the lecture window is open.
func tonight() -> bool:
	return false


## HouseDoor (P1) asks through the group lectures.
func door_open(_door_id: StringName) -> bool:
	return false


## After the TimedAction: Specimens.consume(lectured), fee (payment_received), teaching, piety, Quast +3, lecture_held.
func hold(_uid: String, _inv: Inventory) -> Dictionary:
	return {}


## false = already known.
func learn(_teaching_id: StringName) -> bool:
	return false


func known_teachings() -> PackedStringArray:
	return _teachings.duplicate()


## The rumour of the night: reputation, priest, washer (once).
func apply_morning(_day: int) -> void:
	pass


## {invited, last_day, attended, teachings, rumor_day} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_invited = data.get("invited") is bool and bool(data.get("invited"))
	_teachings = PackedStringArray()
	var list: Variant = data.get("teachings")
	if list is Array or list is PackedStringArray:
		for id: Variant in list:
			_teachings.append(str(id))
