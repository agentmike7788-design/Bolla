class_name WhoKnows
extends Node
## STUB (P4) – Systems/WhoKnows (docs/PHASE9_DESIGN.md §2.2, §3.1, §3.3, §3.4, §5.1), groups &"who_knows",
## &"saveable", save_id who_knows / 82: the main chain „Wer weiß, wann?" – Lorenz' ledger (H1), the register and the
## five graves (H2), the witnesses (H3 → i_light_before), Johann Sieber's mark (H4), the nameless letter at the
## Siebers' door (ending A), the deadline (light + 17 → silent), Johann's departure with Hanne or Osric, the reserved
## plot of the fourth row.
## W0: matched / witnessed / letter_posted / depart_plan answer from load_state (§5.1 {light_day, matched, witnessed,
## marked_seen, letter_posted, depart, fallback_day}); everything else is inert. W1 (P4) fills the bodies; the
## signatures are the contract.

const GROUP := &"who_knows"
const WITH_PEDDLER := &"peddler"
const WITH_CARTER := &"carter"

@export var save_id: String = "who_knows"
@export var save_order: int = 82

## Rules; null = data/config/who_knows_config.tres (resolved lazily).
var config: WhoKnowsConfig

## W0 stub store (P4 may rename it – the fixtures use load_state only).
var _matched: Array[StringName] = []
var _witnessed: Array[StringName] = []
var _marked_seen: bool = false
var _letter_posted: bool = false
var _depart: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## H1 (Desk): why the ledger cannot be read now ("" = it can; TimedAction afterwards).
func read_block_reason(_inv: Inventory) -> String:
	return ""


func read_kladde() -> void:
	pass


## H2: the entries matched with a record.
func compare_register() -> PackedStringArray:
	return PackedStringArray()


func can_compare(_grave_id: String) -> bool:
	return false


func compare_grave(_grave_id: String) -> bool:
	return false


func matched(entry_id: StringName) -> bool:
	return _matched.has(entry_id)


## Dialogue action witness:<entry>.
func witness(_entry_id: StringName) -> bool:
	return false


func witnessed() -> Array[StringName]:
	return _witnessed.duplicate()


## H4 (Johann shows it).
func mark_seen() -> void:
	pass


func letter_posted() -> bool:
	return _letter_posted


## Ending A: the nameless letter at the door (at night).
func post_letter(_inv: Inventory) -> bool:
	return false


## Deadline → silent; departure (Hanne / Osric), runtime schedules.
func apply_morning(_day: int) -> void:
	pass


## {day, minute, with: &"peddler" | &"carter"} | {}
func depart_plan() -> Dictionary:
	return _depart.duplicate()


## §5.1 {light_day, matched, witnessed, marked_seen, letter_posted, depart, fallback_day}.
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_matched = _names(data.get("matched", []))
	_witnessed = _names(data.get("witnessed", []))
	_marked_seen = data.get("marked_seen", false) == true
	_letter_posted = data.get("letter_posted", false) == true
	var depart: Variant = data.get("depart", {})
	_depart = (depart as Dictionary).duplicate() if depart is Dictionary else {}


static func _names(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array or raw is PackedStringArray:
		for v: Variant in raw:
			out.append(StringName(str(v)))
	return out
