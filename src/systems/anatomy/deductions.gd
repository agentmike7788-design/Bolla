class_name Deductions
extends Node
## STUB (P8) – Systems/Deductions (docs/PHASE7_DESIGN.md §2.6.5, §3.1, §3.4, §5.1), groups &"deductions",
## &"saveable": the cards per dead person (findings + revealed finds + teachings), the deduction
## (right: CorpseRecord.revealed_cause, JournalManager.add_clue, stats.deductions, cause_deduced;
## wrong: nothing, not counted).
## W0: cards() / deduced() answer from load_state({"cards": {…}, "done": {…}}) so W1 tests can set them
## (Phase7Fixtures.cards_for); everything else is inert.
## W1 (P8) fills the bodies; the signatures are the contract.

const GROUP := &"deductions"

@export var save_id: String = "deductions"
@export var save_order: int = 56

## W0 stub store (P8 may rename it – the fixtures use load_state only).
var _cards: Dictionary[String, PackedStringArray] = {}
var _done: Dictionary[String, PackedStringArray] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func add_card(_corpse_id: String, _card_id: StringName) -> void:
	pass


## Findings + revealed finds + teachings.
func cards(corpse_id: String) -> PackedStringArray:
	return _cards.get(corpse_id, PackedStringArray()).duplicate()


## At least one finding card.
func can_deduce(_corpse_id: String) -> bool:
	return false


## {ok, cause, clue, text}.
func deduce(_corpse_id: String, _cards_chosen: PackedStringArray, _cause: StringName) -> Dictionary:
	return {"ok": false, "cause": &"", "clue": &"", "text": DeductionRules.TEXT_NO_MATCH}


## Deduction ids done for this dead person.
func deduced(corpse_id: String) -> PackedStringArray:
	return _done.get(corpse_id, PackedStringArray()).duplicate()


## {cards: {corpse_id: [...]}, done: {corpse_id: [...]}} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_cards = _read(data.get("cards"))
	_done = _read(data.get("done"))


static func _read(v: Variant) -> Dictionary[String, PackedStringArray]:
	var out: Dictionary[String, PackedStringArray] = {}
	if v is Dictionary:
		for key: Variant in v:
			var list: Variant = (v as Dictionary)[key]
			if list is Array or list is PackedStringArray:
				var ids := PackedStringArray()
				for id: Variant in list:
					ids.append(str(id))
				out[str(key)] = ids
	return out
