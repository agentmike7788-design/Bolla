class_name LightRules
extends RefCounted
## STUB (P4) – pure rules of the list (docs/PHASE9_DESIGN.md §2.2.1, §2.2.2, §3.4): the light day of an entry from the
## saved records (death = arrival day − 1, D2 from night_paths.deaths.np_ott; light = death − 21), the date text over
## StoneCalendar.date_text, the open light (p9_open_day − 12), Johann's death (light + 21) and the deadline (light + 17).
## Fixed (e_dorn) or missing dead → NO_DAY.
## W1 (P4) fills the bodies; the signatures are the contract.

## „INT_MIN" of §3.4.
const NO_DAY := -9223372036854775807 - 1


## Death − 21; fixed / missing → NO_DAY.
static func light_day(_entry: LightEntryData, _tree: SceneTree, _cfg: WhoKnowsConfig) -> int:
	return NO_DAY


## Over StoneCalendar.date_text.
static func entry_text(_entry: LightEntryData, _tree: SceneTree, _cfg: WhoKnowsConfig) -> String:
	return ""


static func open_light_day(_open_day: int, _cfg: WhoKnowsConfig) -> int:
	return NO_DAY


static func death_day(_light_day: int, _cfg: WhoKnowsConfig) -> int:
	return NO_DAY


static func decide_day(_light_day: int, _cfg: WhoKnowsConfig) -> int:
	return NO_DAY
