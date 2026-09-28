class_name CorpseSaveCodec
extends RefCounted
## Save data of CorpseManager: builds the corpse_manager save entry (save_state) and parses
## its plain JSON values tolerantly (load_state). Stateless.


## The save entry: corpses in spawn order plus the delivery bookkeeping.
static func write(records: Dictionary[String, CorpseRecord], next_serial: int, last_delivery_day: int,
		last_delivery_ids: Array[String], spawn_counts: Dictionary[int, int]) -> Dictionary:
	var corpses: Array = []
	for record: CorpseRecord in records.values():
		corpses.append(record.to_dict())
	var counts := {}
	for day: int in spawn_counts:
		counts[day] = spawn_counts[day]
	return {
		"corpses": corpses,
		"next_serial": next_serial,
		"last_delivery_day": last_delivery_day,
		"last_delivery_ids": last_delivery_ids.duplicate(),
		"spawn_counts": counts,
	}


## Adds the valid saved corpses of data.corpses to `into` (id -> record, in saved order);
## entries without a unique id are skipped with a warning.
static func read_records(data: Dictionary, into: Dictionary[String, CorpseRecord]) -> void:
	var corpses: Variant = data.get("corpses", [])
	if not corpses is Array:
		return
	for entry: Variant in corpses:
		if not entry is Dictionary:
			continue
		var record := CorpseRecord.from_dict(entry as Dictionary)
		if record.id == "" or into.has(record.id):
			push_warning("[CorpseManager] saved corpse without unique id skipped")
			continue
		into[record.id] = record


## Adds the valid entries of data.spawn_counts (day >= 0, count > 0) to `into`.
static func read_spawn_counts(data: Dictionary, into: Dictionary[int, int]) -> void:
	var counts: Variant = data.get("spawn_counts", {})
	if not counts is Dictionary:
		return
	for key: Variant in counts:
		var day := to_int(key, -1)
		var count := to_int((counts as Dictionary)[key], 0)
		if day >= 0 and count > 0:
			into[day] = count


## Corpse ids of the last delivery day: data.last_delivery_ids (format v2), else the v1 field
## last_delivery_id ("" = none). Empty and duplicate ids are dropped.
static func read_delivery_ids(data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var list: Variant = data.get("last_delivery_ids")
	if list is Array:
		for entry: Variant in list:
			if (entry is String or entry is StringName) and String(entry) != "" and not String(entry) in out:
				out.append(String(entry))
		return out
	var single := read_string(data, "last_delivery_id")
	if single != "":
		out.append(single)
	return out


## String value of data[key]; "" when missing or no String / StringName.
static func read_string(data: Dictionary, key: String) -> String:
	var value: Variant = data.get(key, "")
	return String(value) if value is String or value is StringName else ""


## int from int / float / numeric String (plain JSON values), else fallback.
static func to_int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float:
		return roundi(v)
	if v is String and (v as String).is_valid_float():
		return roundi((v as String).to_float())
	return fallback


## Phase 4 (§5.1): the story bookkeeping of the save entry.
static func write_story(delivered: PackedStringArray, last_day: int, stench_day: int) -> Dictionary:
	var list: Array = []
	for id: String in delivered:
		list.append(id)
	return {"story_delivered": list, "story_last_day": last_day, "stench_day": stench_day}


## data.story_delivered as unique non-empty ids in saved order (missing = none).
static func read_story_delivered(data: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var list: Variant = data.get("story_delivered", [])
	if not (list is Array or list is PackedStringArray):
		return out
	for entry: Variant in list:
		if (entry is String or entry is StringName) and String(entry) != "" and not out.has(String(entry)):
			out.append(String(entry))
	return out


## Phase 6: a saved list of unique non-empty ids (e.g. "niche_waited"; missing / invalid = none).
static func read_id_list(list: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if not (list is Array or list is PackedStringArray):
		return out
	for entry: Variant in list:
		if (entry is String or entry is StringName) and String(entry) != "" and not out.has(String(entry)):
			out.append(String(entry))
	return out
