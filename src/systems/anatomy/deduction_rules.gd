class_name DeductionRules
extends RefCounted
## STUB (P8) – pure rules of the cause-of-death deduction (docs/PHASE7_DESIGN.md §2.6.5, §3.4): a
## deduction matches when its cause is chosen, every needs_all card and at least one needs_any card
## (if any) are among the chosen cards. W1 (P8) fills the bodies; the signatures are the contract.

const TEXT_NO_MATCH := "Das passt nicht zusammen."
const TEXT_MATCH := "Du hast es selbst gesehen."


static func matches(_d: DeductionData, _cards: PackedStringArray, _cause: StringName) -> bool:
	return false


## null = „Das passt nicht zusammen."
static func find(_deductions: Array[DeductionData], _cards: PackedStringArray, _cause: StringName) -> DeductionData:
	return null
