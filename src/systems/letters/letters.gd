class_name Letters
extends Node
## STUB (P3) – Systems/Letters (docs/PHASE9_DESIGN.md §2.4, §3.1, §3.3, §3.4, §5.1), groups &"letters", &"saveable",
## save_id letters / 83: letters in the pockets of the dead (assigned at the delivery from p9_open on – the first three
## L1–L3 for sure, then the pool for corpses with the trait letter), the post for the dead (Osric p9_open_day + 3/6/9,
## Hanne), the choices (deliver, read, read at the grave, answer, burn, lay into the grave), postage, counter-letters.
## W0: letter / state / corpse_of / decided_count / delivered_count answer from load_state (§5.1 {next_uid, records:
## {uid: {id, corpse, state, day}}, forced_used, post_done, replies, rep_day}); everything else is inert.
## W1 (P3) fills the bodies; the signatures are the contract.

const GROUP := &"letters"
const UID_PREFIX := "lt_"
const CARRIER_PEDDLER := &"peddler"
const CARRIER_CARTER := &"carter"
## letter_changed states that are a decision (§2.4.2 „entschieden") – W0 reading, P3 decides.
const DECIDED_STATES: Array[StringName] = [&"posted", &"delivered", &"read", &"read_grave", &"answered", &"burned", &"buried"]
const DELIVERED_STATES: Array[StringName] = [&"posted", &"delivered"]

@export var save_id: String = "letters"
@export var save_order: int = 83

## Rules; null = data/config/letters_config.tres (resolved lazily).
var config: LettersConfig
## Letters by id; empty = Database.letters() (tests inject fixtures).
var letter_table: Dictionary[StringName, LetterData] = {}

## W0 stub store (P3 may rename it – the fixtures use load_state only): uid → {id, corpse, state, day}.
var _records: Dictionary[String, Dictionary] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## At the delivery (forced / pool).
func assign(_record: CorpseRecord) -> void:
	pass


## Pockets → uid ("" = no letter).
func on_found(_corpse_id: String, _inv: Inventory) -> String:
	return ""


func letter(uid: String) -> LetterData:
	if not _records.has(uid):
		return null
	var id := StringName(str(_records[uid].get("id", "")))
	if letter_table.has(id):
		return letter_table[id]
	return Database.letter(id) as LetterData


func state(uid: String) -> StringName:
	return StringName(str(_records[uid].get("state", ""))) if _records.has(uid) else &""


func corpse_of(uid: String) -> String:
	return str(_records[uid].get("corpse", "")) if _records.has(uid) else ""


## {id, label, reason}
func choices(_uid: String, _context: Dictionary) -> Array[Dictionary]:
	return []


func decide(_uid: String, _choice: StringName, _context: Dictionary) -> bool:
	return false


## Post for the dead (Osric 07:40, Hanne).
func post_today(_day: int) -> Array[String]:
	return []


## 1 coin, &"peddler" | &"carter".
func give_to_carrier(_uid: String, _carrier: StringName, _inv: Inventory) -> bool:
	return false


func decided_count() -> int:
	return _count(DECIDED_STATES)


func delivered_count() -> int:
	return _count(DELIVERED_STATES)


## Post, counter-letters.
func apply_morning(_day: int) -> void:
	pass


## §5.1 {next_uid, records, forced_used, post_done, replies, rep_day}.
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_records.clear()
	var records: Variant = data.get("records", {})
	if records is Dictionary:
		for uid: Variant in records:
			if records[uid] is Dictionary:
				_records[str(uid)] = (records[uid] as Dictionary).duplicate()


func _count(states: Array[StringName]) -> int:
	var n := 0
	for uid: String in _records:
		if StringName(str(_records[uid].get("state", ""))) in states:
			n += 1
	return n
