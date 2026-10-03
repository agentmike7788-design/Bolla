class_name DeductionRules
extends RefCounted
## Pure rules of the cause-of-death deduction (docs/PHASE7_DESIGN.md §2.6.5, §3.4): a deduction
## matches when its cause is chosen, every needs_all card and at least one needs_any card (if any) are
## among the chosen cards (more chosen cards do not hurt). A wrong deduction costs nothing.

const TEXT_NO_MATCH := "Das passt nicht zusammen."
const TEXT_MATCH := "Du hast es selbst gesehen."
## §2.6.5: two or three cards and one cause.
const MIN_CARDS := 2
const MAX_CARDS := 3
## The causes of the list besides the CorpseTables causes.
const EXTRA_CAUSES: Array[StringName] = [&"arsenic", &"dead_before_water", &"drink", &"unexplained"]


static func matches(d: DeductionData, cards: PackedStringArray, cause: StringName) -> bool:
	if d == null or cause == &"" or cause != d.cause_id:
		return false
	for id: StringName in d.needs_all:
		if not cards.has(String(id)):
			return false
	if d.needs_any.is_empty():
		return true
	for id: StringName in d.needs_any:
		if cards.has(String(id)):
			return true
	return false


## null = „Das passt nicht zusammen."
static func find(deductions: Array[DeductionData], cards: PackedStringArray, cause: StringName) -> DeductionData:
	for d: DeductionData in deductions:
		if matches(d, cards, cause):
			return d
	return null


## Like find, and a confirming deduction (reveals_cause false, e.g. d_moor) also accepts the cause
## the dead person was delivered with (W0-Notizen 12: „gezeigte Ursache").
static func find_for(deductions: Array[DeductionData], cards: PackedStringArray, cause: StringName, shown_cause: StringName) -> DeductionData:
	var d := find(deductions, cards, cause)
	if d != null or cause == &"" or cause != shown_cause:
		return d
	for other: DeductionData in deductions:
		if other != null and not other.reveals_cause and matches(other, cards, other.cause_id):
			return other
	return null


## The cause list of the panel: the CorpseTables causes + EXTRA_CAUSES (no duplicates).
static func cause_list(tables: CorpseTables) -> Array[StringName]:
	var out: Array[StringName] = []
	if tables != null:
		for c: Dictionary in tables.causes:
			var id := StringName(c.get("id", &""))
			if id != &"" and not id in out:
				out.append(id)
	for id: StringName in EXTRA_CAUSES:
		if not id in out:
			out.append(id)
	return out
