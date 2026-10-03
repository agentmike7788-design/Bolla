class_name Specimens
extends Node
## STUB (P4) – Systems/Specimens (docs/PHASE7_DESIGN.md §2.6, §3.1, §3.3, §3.4, §5.1), groups
## &"specimens", &"saveable": the records of every specimen (uid → SpecimenRecord); the inventory slots
## carry the uid (Inventory.add_unique). harvest / sell / expertise / inspect / consume / seal /
## make_display / make_bone / return_to_grave; bundles spoil (check_spoiled on hour_changed).
## W0: get_record / held / of_corpse answer from load_state({"next", "records": [...]}) so W1 tests can
## install records before P4 is merged; everything else is inert.
## W1 (P4) fills the bodies; the signatures are the contract.

const GROUP := &"specimens"
## The four item ids every specimen shares (the organ is in the record).
const ITEM_JAR := &"specimen_jar"
const ITEM_BUNDLE := &"specimen_bundle"
const ITEM_DISPLAY := &"display_specimen"
const ITEM_BONE := &"bone_specimen"
const ITEMS: Array[StringName] = [ITEM_JAR, ITEM_BUNDLE, ITEM_DISPLAY, ITEM_BONE]
const UID_FORMAT := "sp_%04d"

@export var save_id: String = "specimens"
@export var save_order: int = 54

## Rules; null = data/config/anatomy_config.tres (resolved lazily).
var config: AnatomyConfig

## W0 stub store (P4 may rename it – the fixtures use load_state only).
var _records: Dictionary[String, SpecimenRecord] = {}
var _next: int = 1


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func get_record(uid: String) -> SpecimenRecord:
	return _records.get(uid)


## uids in state held.
func held() -> PackedStringArray:
	var out := PackedStringArray()
	for uid: String in _records:
		if _records[uid].state == SpecimenRecord.STATE_HELD:
			out.append(uid)
	return out


func of_corpse(corpse_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for uid: String in _records:
		if _records[uid].corpse_id == corpse_id:
			out.append(uid)
	return out


## „Herz – Hedwig Lamprecht, 58 – Klarheit gut".
func label(_uid: String) -> String:
	return ""


## uid | ""; takes the inputs, add_unique; specimen_changed(taken).
func harvest(_corpse_id: String, _organ: StringName, _container: StringName, _inv: Inventory) -> String:
	return ""


## Quast present; remove_uid; coins; Relationships.on_specimen_sold; stats.specimens_sold.
func sell(_uid: String, _inv: Inventory) -> int:
	return 0


## Quast's expertise after the TimedAction: finding card (Deductions.add_card) + the organ's teaching
## (Lectures.learn); state researched; Quast +3.
func expertise(_uid: String, _inv: Inventory) -> Dictionary:
	return {}


## Inspect at the pult: the finding id (finding_for), the piece stays; Deductions.add_card.
func inspect(_uid: String) -> StringName:
	return &""


## Lecture (lectured) and medicine (used): remove_uid, state, specimen_changed.
func consume(_uid: String, _inv: Inventory, _state: StringName) -> bool:
	return false


## Hand bundle → bone_specimen (new item id, same uid).
func make_bone(_uid: String, _inv: Inventory) -> bool:
	return false


## Bundle → jar (container jar, sealed_*; same uid).
func seal(_uid: String, _inv: Inventory) -> bool:
	return false


func make_display(_uid: String, _inv: Inventory) -> bool:
	return false


func return_block_reason(_uid: String, _grave_id: String) -> String:
	return ""


func return_to_grave(_uid: String, _grave_id: String, _inv: Inventory) -> bool:
	return false


## PultStore on in / out: open / close a cold window.
func note_cold(_uid: String, _entering: bool) -> void:
	pass


## hour_changed: a note once per bundle, specimen_changed(spoiled).
func check_spoiled(_now_total: int) -> void:
	pass


## Phase-13 hook (only counted): held, not spoiled specimens of `organ`, the collection included.
func kept(_organ: StringName) -> int:
	return 0


## {next, records: [SpecimenRecord.to_dict()]} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_records.clear()
	_next = maxi(int(data.get("next", 1)) if (data.get("next") is int or data.get("next") is float) else 1, 1)
	var list: Variant = data.get("records")
	if list is Array:
		for d: Variant in list:
			if d is Dictionary:
				var r := SpecimenRecord.from_dict(d)
				if r.uid != "":
					_records[r.uid] = r


## A uid without an inventory slot → a warning, the state stays (fuzzer).
func post_load() -> void:
	pass
