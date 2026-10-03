class_name RegionTravel
extends RefCounted
## The way between the regions (docs/PHASE7_DESIGN.md §1.3, §3.4, §4.1): screen_fade_requested(fade);
## in the middle TimeManager.advance(minutes) (like sleeping, without the day-change special case),
## the teleport (HutPortal.arrive, outside – interior_changed / interior_room_changed first), then
## Player.set_region(target) (region_changed last), stats.village_trips +1 on the way into the
## village. HutPortal.is_travelling holds while it runs (the same meta), so no second trip, door or
## portal starts during the fade.

const TEXT_CORPSE := "Eine Leiche nimmst du nicht mit ins Dorf. Osric holt und bringt."
const TEXT_BUSY := "Erst fertig machen."
## The village is closed before Village.FLAG_VILLAGE_OPEN (the portals show no prompt then).
const TEXT_CLOSED := "Im Dorf hast du noch nichts verloren."
const FLAG_VILLAGE_OPEN := &"village_open"
const STAT_VILLAGE_TRIPS := &"village_trips"


## "" | TEXT_CORPSE | TEXT_BUSY | TEXT_CLOSED (the flag is missing); "-" without a player.
static func block_reason(player: Player, target: StringName) -> String:
	if player == null:
		return "-"
	if is_instance_valid(player.carried):
		return TEXT_CORPSE
	if player.is_busy() or HutPortal.is_travelling(player):
		return TEXT_BUSY
	if target == RegionRoot.VILLAGE and not GameState.flag_on(FLAG_VILLAGE_OPEN):
		return TEXT_CLOSED
	return ""


## Starts the trip (false when blocked). fade <= 0 or outside the tree: at once.
static func travel(player: Player, target: StringName, spawn: Transform3D, minutes: int, fade: float) -> bool:
	if block_reason(player, target) != "":
		return false
	if fade <= 0.0 or not player.is_inside_tree():
		arrive(player, target, spawn, minutes)
		return true
	player.set_meta(HutPortal.META_TRAVELLING, true)
	EventBus.screen_fade_requested.emit(fade)
	_arrive_later(player, target, spawn, minutes, fade * 0.5)
	return true


## The middle of the fade: the clock jumps, the gravekeeper stands at `spawn` outside, region last.
static func arrive(player: Player, target: StringName, spawn: Transform3D, minutes: int) -> void:
	if minutes > 0:
		TimeManager.advance(minutes)
	HutPortal.arrive(player, spawn, false)
	player.set_region(target)
	if target == RegionRoot.VILLAGE:
		GameState.add_stat(STAT_VILLAGE_TRIPS, 1)


static func _arrive_later(player: Player, target: StringName, spawn: Transform3D, minutes: int, delay: float) -> void:
	await player.get_tree().create_timer(delay).timeout
	if not is_instance_valid(player):
		return
	player.remove_meta(HutPortal.META_TRAVELLING)
	if player.is_inside_tree():
		arrive(player, target, spawn, minutes)
