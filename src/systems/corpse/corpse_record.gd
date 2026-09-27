class_name CorpseRecord
extends RefCounted
## State of one corpse (pure data + helpers).
## to_dict() keeps native types (int, StringName, Vector3) for JSON.from_native saves;
## from_dict() also accepts plain JSON values (floats, Strings, arrays for vectors).

const LOCATION_DROPOFF := &"dropoff"
const LOCATION_CARRIED := &"carried"
const LOCATION_TABLE := &"table"
const LOCATION_GROUND := &"ground"
const LOCATION_BURIED := &"buried"
const LOCATIONS: Array[StringName] = [LOCATION_DROPOFF, LOCATION_CARRIED, LOCATION_TABLE, LOCATION_GROUND, LOCATION_BURIED]

const STAGE_FRESH := &"fresh"
const STAGE_WILTED := &"wilted"
const STAGE_DECAYING := &"decaying"

const TRAIT_VALUABLES := &"valuables"
const DECISION_NONE := &""
const DECISION_TAKEN := &"taken"
const DECISION_LEFT := &"left"
const DECISIONS: Array[StringName] = [DECISION_NONE, DECISION_TAKEN, DECISION_LEFT]

var id: String = ""
var seed: int = 0
var display_name: String = ""
var age: int = 0
var cause_id: StringName = &""
var traits: Array[StringName] = []
var examined: bool = false
var shrouded: bool = false
var valuables_coins: int = 0
var valuables_decision: StringName = &""
var freshness: float = 1.0
var freshness_at_burial: float = -1.0
var last_decay_total: int = 0
var location: StringName = &"dropoff"
var position: Vector3 = Vector3.ZERO
var rot_y: float = 0.0
var grave_id: String = ""
var arrival_total_minutes: int = 0
## Game day of the burial (CorpseManager.mark_buried; 0 = not buried / older save).
var buried_day: int = 0


func has_trait(t: StringName) -> bool:
	return traits.has(t)


## Empty until the corpse has been examined.
func revealed_traits() -> Array[StringName]:
	if not examined:
		return []
	return traits.duplicate()


## stage_for(freshness) with the game's config (data/config/economy_config.tres, else defaults).
func freshness_stage() -> StringName:
	return stage_for(freshness, EconomyConfig.resolve())


## &"fresh" (>= fresh_good_threshold), &"decaying" (< fresh_bad_threshold), else &"wilted".
## The one threshold rule – GraveQuality's freshness points use it too.
static func stage_for(value: float, config: EconomyConfig) -> StringName:
	var cfg := EconomyConfig.resolve(config)
	if value >= cfg.fresh_good_threshold:
		return STAGE_FRESH
	if value < cfg.fresh_bad_threshold:
		return STAGE_DECAYING
	return STAGE_WILTED


## True while examined valuables still wait for the take/leave decision.
func needs_valuables_decision() -> bool:
	return examined and has_trait(TRAIT_VALUABLES) and valuables_decision == DECISION_NONE


func to_dict() -> Dictionary:
	return {
		"id": id,
		"seed": seed,
		"display_name": display_name,
		"age": age,
		"cause_id": cause_id,
		"traits": traits.duplicate(),
		"examined": examined,
		"shrouded": shrouded,
		"valuables_coins": valuables_coins,
		"valuables_decision": valuables_decision,
		"freshness": freshness,
		"freshness_at_burial": freshness_at_burial,
		"last_decay_total": last_decay_total,
		"location": location,
		"position": position,
		"rot_y": rot_y,
		"grave_id": grave_id,
		"arrival_total_minutes": arrival_total_minutes,
		"buried_day": buried_day,
	}


## Missing or malformed values fall back to the defaults of a new record.
static func from_dict(d: Dictionary) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.id = _to_str(d.get("id"), r.id)
	r.seed = _to_int(d.get("seed"), r.seed)
	r.display_name = _to_str(d.get("display_name"), r.display_name)
	r.age = _to_int(d.get("age"), r.age)
	r.cause_id = StringName(_to_str(d.get("cause_id"), String(r.cause_id)))
	r.traits = _to_name_array(d.get("traits"))
	r.examined = _to_bool(d.get("examined"), r.examined)
	r.shrouded = _to_bool(d.get("shrouded"), r.shrouded)
	r.valuables_coins = _to_int(d.get("valuables_coins"), r.valuables_coins)
	var decision := StringName(_to_str(d.get("valuables_decision"), ""))
	r.valuables_decision = decision if decision in DECISIONS else DECISION_NONE
	r.freshness = _to_float(d.get("freshness"), r.freshness)
	r.freshness_at_burial = _to_float(d.get("freshness_at_burial"), r.freshness_at_burial)
	r.last_decay_total = _to_int(d.get("last_decay_total"), r.last_decay_total)
	var loc := StringName(_to_str(d.get("location"), String(r.location)))
	r.location = loc if loc in LOCATIONS else r.location
	r.position = _to_vector3(d.get("position"), r.position)
	r.rot_y = _to_float(d.get("rot_y"), r.rot_y)
	r.grave_id = _to_str(d.get("grave_id"), r.grave_id)
	r.arrival_total_minutes = _to_int(d.get("arrival_total_minutes"), r.arrival_total_minutes)
	r.buried_day = _to_int(d.get("buried_day"), r.buried_day)
	return r


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


static func _to_float(v: Variant, fallback: float) -> float:
	if v is float or v is int:
		return float(v)
	if v is String and (v as String).is_valid_float():
		return (v as String).to_float()
	return fallback


static func _to_bool(v: Variant, fallback: bool) -> bool:
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	if v is String:
		return (v as String).to_lower() == "true"
	return fallback


static func _to_name_array(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if v is Array or v is PackedStringArray:
		for item: Variant in v:
			if item is String or item is StringName:
				out.append(StringName(item))
	return out


## Vector3, [x, y, z], {x, y, z} or the JSON.stringify form "(x, y, z)".
static func _to_vector3(v: Variant, fallback: Vector3) -> Vector3:
	if v is Vector3:
		return v
	if v is Vector3i:
		return Vector3(v)
	var parts: Array = []
	if v is Array or v is PackedFloat32Array or v is PackedFloat64Array or v is PackedInt32Array:
		parts = Array(v)
	elif v is Dictionary:
		var dict: Dictionary = v
		parts = [dict.get("x"), dict.get("y"), dict.get("z")]
	elif v is String:
		parts = Array((v as String).strip_edges().trim_prefix("(").trim_suffix(")").split(","))
	if parts.size() != 3:
		return fallback
	var out := Vector3.ZERO
	for i: int in 3:
		var part: Variant = parts[i]
		if part is String:
			part = (part as String).strip_edges()
		if not (part is float or part is int or (part is String and (part as String).is_valid_float())):
			return fallback
		out[i] = _to_float(part, 0.0)
	return out
