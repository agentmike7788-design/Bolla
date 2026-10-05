class_name GraveRecord
extends RefCounted
## State of one grave.
## to_dict() keeps native types for JSON.from_native saves; from_dict() also accepts
## plain JSON values (floats for ints, Strings for StringNames).

## LOCKED (Phase 3): plot of a section not yet unlocked – appended, saved ints unchanged.
enum State { EMPTY, DUG, FILLED, MARKED, OLD, LOCKED }

var id: String = ""
var state: State = State.EMPTY
var corpse_id: String = ""
var marker_id: StringName = &""
var quality: int = 0
## [{label: String, points: int}] from GraveQuality.breakdown (empty until MARKED).
var breakdown: Array = []
## Phase 3: TimeManager.day of place_marker (0 = migrated / unknown).
var completed_day: int = 0
## Phase 5 §3.4, §5.1: StoneDesign.to_dict of the designed stone ({} = none; marker_id is then
## the shape id). Saved always; from_dict normalises it through StoneDesign (tolerant).
var design: Dictionary = {}
## Phase 8 §2.3, §3.4, §5.1: the night digger was undisturbed until 05:00 (GraveCare.set_disturbed /
## close_disturbed, P2) and the lines chiselled on afterwards (Graveyard.append_inscription, wish line).
## Saved always; missing = default (tolerant).
var disturbed: bool = false
var extra_lines: PackedStringArray = []


func to_dict() -> Dictionary:
	return {
		"id": id,
		"state": int(state),
		"corpse_id": corpse_id,
		"marker_id": marker_id,
		"quality": quality,
		"breakdown": breakdown.duplicate(true),
		"completed_day": completed_day,
		"design": design.duplicate(true),
		"disturbed": disturbed,
		"extra_lines": Array(extra_lines),
	}


## Missing or malformed values fall back to the defaults of a new record.
static func from_dict(d: Dictionary) -> GraveRecord:
	var r := GraveRecord.new()
	r.id = _to_str(d.get("id"), r.id)
	r.state = _to_state(d.get("state"))
	r.corpse_id = _to_str(d.get("corpse_id"), r.corpse_id)
	r.marker_id = StringName(_to_str(d.get("marker_id"), ""))
	r.quality = _to_int(d.get("quality"), r.quality)
	r.completed_day = maxi(0, _to_int(d.get("completed_day"), r.completed_day))
	var raw_design: Variant = d.get("design", {})
	if raw_design is Dictionary:
		r.design = StoneDesign.from_dict(raw_design as Dictionary).to_dict()
	r.disturbed = typeof(d.get("disturbed")) == TYPE_BOOL and bool(d.get("disturbed"))
	var lines: Variant = d.get("extra_lines", [])
	if lines is Array or lines is PackedStringArray:
		for line: Variant in lines:
			if (line is String or line is StringName) and String(line) != "":
				r.extra_lines.append(String(line))
	var entries: Variant = d.get("breakdown", [])
	if entries is Array:
		for entry: Variant in entries:
			if entry is Dictionary:
				var e: Dictionary = entry
				r.breakdown.append({"label": _to_str(e.get("label"), ""), "points": _to_int(e.get("points"), 0)})
	return r


static func _to_state(v: Variant) -> State:
	var value := -1
	if v is int or v is float:
		value = roundi(float(v))
	elif v is String or v is StringName:
		var text := String(v)
		value = text.to_int() if text.is_valid_int() else State.keys().find(text.to_upper())
	if value < 0 or value >= State.size():
		if typeof(v) != TYPE_NIL:
			push_warning("[GraveRecord] invalid state %s – EMPTY" % str(v))
		return State.EMPTY
	return value as State


static func _to_str(v: Variant, fallback: String) -> String:
	if v is String or v is StringName:
		return String(v)
	if v is int or v is float:
		return str(v)
	return fallback


static func _to_int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float:
		return roundi(v)
	if v is String and (v as String).is_valid_float():
		return roundi((v as String).to_float())
	return fallback
