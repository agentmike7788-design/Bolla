class_name DebugCommandParser
extends RefCounted
## Pure argument parsing & lookups for the debug commands (DebugCommands): clock and slot
## arguments, the item id list, the wait until an NPC's next appearance.
## Reads only its arguments plus static game data and the clock – never changes state.


## "HH:MM" / "H:MM" → minute of day, -1 when invalid.
static func parse_clock(text: String) -> int:
	var parts := text.strip_edges().split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or parts[1].length() != 2 or parts[0].length() > 2:
		return -1
	var hour := parts[0].to_int()
	var minute := parts[1].to_int()
	if hour < 0 or hour > 23 or minute < 0 or minute > 59 or parts[0].begins_with("-") or parts[1].begins_with("-"):
		return -1
	return hour * TimeManager.MINUTES_PER_HOUR + minute


## Optional slot argument → slot number (`default_slot` without argument), -1 when invalid.
static func parse_slot(args: PackedStringArray, default_slot: int) -> int:
	if args.is_empty():
		return default_slot
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() < 0:
		return -1
	return args[0].to_int()


## Minutes from now until the NPC next arrives at a visible phase with a dialogue
## (any visible phase if none has one); -1 if it never shows up.
static func minutes_to_next_presence(schedule: NpcSchedule) -> int:
	var best := -1
	for with_dialogue: bool in [true, false]:
		for entry: ScheduleEntry in schedule.entries:
			if entry == null or not entry.visible or (with_dialogue and entry.dialogue_id == &""):
				continue
			var wait := TimeManager.minutes_until(ScheduleResolver.arrival_minute(entry))
			if wait == 0:
				wait = TimeManager.MINUTES_PER_DAY
			if best < 0 or wait < best:
				best = wait
		if best >= 0:
			return best
	return best


## All item ids, sorted, comma separated.
static func item_ids() -> String:
	var ids: PackedStringArray = []
	for item: Resource in Database.items():
		ids.append(String(item.get("id")))
	ids.sort()
	return ", ".join(ids)
