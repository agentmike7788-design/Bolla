class_name Ossuary
extends Node
## STUB (P3) – Systems/Ossuary (docs/PHASE6_DESIGN.md §2.3, §3.1, §3.4, §5.1), groups &"ossuary",
## &"saveable": lifted (waiting) and reinterred old graves in lifting order, the sealed passage /
## grille of the crypt and its clue. W1 (P3) fills the bodies; the signatures are the contract.

const GROUP := &"ossuary"
const PASSAGE_HIDDEN := &"hidden"
const PASSAGE_SEALED := &"sealed"
const PASSAGE_GRILLE := &"grille"

@export var save_id: String = "ossuary"
@export var save_order: int = 36

## Rules; null = data/config/crypt_config.tres (resolved lazily).
var config: CryptConfig


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## Ossuary places of the current crypt level.
func capacity() -> int:
	return 0


## Lifted (waiting) + reinterred.
func used() -> int:
	return 0


func lift_block_reason(_grave_id: String, _inv: Inventory) -> String:
	return ""


## After the TimedAction: bone_box → bone_box_full, Graveyard.lift_old, bones_lifted, stats.bones_lifted.
func lift(_grave_id: String, _inv: Inventory) -> bool:
	return false


## Lifted, not yet reinterred (lifting order).
func pending() -> PackedStringArray:
	return PackedStringArray()


func reinterred() -> PackedStringArray:
	return PackedStringArray()


## FIFO; takes a bone_box_full; fee (payment_received), reputation, piety, the line;
## bones_reinterred; Buildings.check_goal; grave_id | "".
func reinter(_inv: Inventory) -> String:
	return ""


## Unlocks the passage / grille (state only, no note).
func on_crypt_level(_level: int) -> void:
	pass


## &"hidden" | &"sealed" | &"grille".
func passage_state() -> StringName:
	return PASSAGE_HIDDEN


## The clue c_crypt_draft once (Journal.add_clue), texts §2.3.
func look_at_passage() -> void:
	pass


func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass
