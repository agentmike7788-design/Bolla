class_name RegionTravel
extends RefCounted
## STUB (P1) – the way between the regions (docs/PHASE7_DESIGN.md §1.3, §3.4, §4.1): screen_fade_requested
## (fade); in the middle TimeManager.advance(minutes) (like sleeping, without the day-change special
## case), the teleport, Player.set_region(target), stats.village_trips +1 on the way into the village;
## HutPortal.is_travelling holds while it runs. W1 (P1) fills the bodies; the signatures are the contract.

const TEXT_CORPSE := "Eine Leiche nimmst du nicht mit ins Dorf. Osric holt und bringt."
const TEXT_BUSY := "Erst fertig machen."


## "" | TEXT_CORPSE | TEXT_BUSY | the flag is missing.
static func block_reason(_player: Player, _target: StringName) -> String:
	return ""


static func travel(_player: Player, _target: StringName, _spawn: Transform3D, _minutes: int, _fade: float) -> bool:
	return false
