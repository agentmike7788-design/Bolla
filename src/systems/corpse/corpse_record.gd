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
# Phase 6 (docs/PHASE6_DESIGN.md §3.4, W0) – appended.
const LOCATION_NICHE := &"niche"
const LOCATION_CATAFALQUE := &"catafalque"
const LOCATIONS: Array[StringName] = [LOCATION_DROPOFF, LOCATION_CARRIED, LOCATION_TABLE, LOCATION_GROUND, LOCATION_BURIED,
		LOCATION_NICHE, LOCATION_CATAFALQUE]

const STAGE_FRESH := &"fresh"
const STAGE_WILTED := &"wilted"
const STAGE_DECAYING := &"decaying"

const TRAIT_VALUABLES := &"valuables"
const DECISION_NONE := &""
const DECISION_TAKEN := &"taken"
const DECISION_LEFT := &"left"
const DECISIONS: Array[StringName] = [DECISION_NONE, DECISION_TAKEN, DECISION_LEFT]
# Phase 4 (docs/PHASE4_DESIGN.md §3.4, W0) – examination steps, stage, dress, harvest kinds.
const STEP_CLOTHING := &"clothing"
const STEP_HANDS := &"hands"
const STEP_WOUNDS := &"wounds"
const STEP_POCKETS := &"pockets"
const STEPS: Array[StringName] = [STEP_CLOTHING, STEP_HANDS, STEP_WOUNDS, STEP_POCKETS]
const STAGE_ROTTEN := &"rotten"
const DRESS_NONE := &""
const DRESS_SHROUD := &"shroud"
const DRESS_GOWN := &"gown"
const HARVEST_HAIR := &"hair"
const HARVEST_TEETH := &"teeth"
const DRESSES: Array[StringName] = [DRESS_NONE, DRESS_SHROUD, DRESS_GOWN]
# Phase 7 (docs/PHASE7_DESIGN.md §2.6, §3.4, W0) – the seven organs appended (specimens).
const HARVEST_HEART := &"heart"
const HARVEST_LUNG := &"lung"
const HARVEST_STOMACH := &"stomach"
const HARVEST_LIVER := &"liver"
const HARVEST_KIDNEYS := &"kidneys"
const HARVEST_EYES := &"eyes"
const HARVEST_HAND := &"hand"
const ORGAN_KINDS: Array[StringName] = [HARVEST_HEART, HARVEST_LUNG, HARVEST_STOMACH, HARVEST_LIVER, HARVEST_KIDNEYS,
		HARVEST_EYES, HARVEST_HAND]
const HARVEST_KINDS: Array[StringName] = [HARVEST_HAIR, HARVEST_TEETH, HARVEST_HEART, HARVEST_LUNG, HARVEST_STOMACH,
		HARVEST_LIVER, HARVEST_KIDNEYS, HARVEST_EYES, HARVEST_HAND]

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
# Phase 4 (§3.4) – all in to_dict / from_dict (missing = default).
var story_id: StringName = &""
## Finished examination steps (STEPS).
var exam_done: Array[StringName] = []
## FindData ids in the order they were revealed / lost.
var finds_revealed: Array[StringName] = []
var finds_lost: Array[StringName] = []
## Traits whose find was revealed (set by CorpseCare).
var traits_revealed: Array[StringName] = []
var washed: bool = false
## DRESS_*; shrouded == (dress != DRESS_NONE) is kept in sync by whoever dresses (compatibility).
var dress: StringName = &""
var laid_out: bool = false
## HARVEST_* kinds taken.
var harvested: Array[StringName] = []
## Juniper windows [start, end, start, end …] in total minutes.
var balm_windows: PackedInt32Array = []
## "Es riecht streng." already shown for this corpse.
var stench_noted: bool = false
# Phase 6 (§3.4, §5.1) – all in to_dict / from_dict (missing = default).
## &"crypt" | &"chapel" | &"" (outside).
var room: StringName = &""
## niche_1…6 at LOCATION_NICHE ("" elsewhere).
var slot_id: String = ""
## Cold windows [start, end (-1 = open), factor‰, …] in total minutes.
var cold_windows: PackedInt32Array = []
## Funeral service held (ChapelRites → CorpseManager.mark_service) on game day service_day.
var service_held: bool = false
var service_day: int = 0
# Phase 7 (§3.4, §5.1) – all in to_dict / from_dict (missing = default).
## Hidden cause of a random corpse (CorpseTables.hidden_causes; &"" = none / story corpse).
var hidden_cause: StringName = &""
## Organs given back to the grave (Specimens.return_to_grave); always ⊆ harvested.
var returned: Array[StringName] = []
## The cause the player deduced (Deductions.deduce; &"" = not deduced).
var revealed_cause: StringName = &""


func has_trait(t: StringName) -> bool:
	return traits.has(t)


# --- Phase 4 helpers ---------------------------------------------------------------------------

func is_step_done(step: StringName) -> bool:
	return exam_done.has(step)


## All four STEPS done.
func is_fully_examined() -> bool:
	for step: StringName in STEPS:
		if not exam_done.has(step):
			return false
	return true


func is_dressed() -> bool:
	return dress != DRESS_NONE


## washed ∧ dressed ∧ laid out.
func is_fully_prepared() -> bool:
	return washed and is_dressed() and laid_out


func is_harvested(kind: StringName) -> bool:
	return harvested.has(kind)


## Phase 4 (§2.1): the traits whose find was revealed (traits_revealed, set by CorpseCare; the
## Phase-2 path CorpseManager.examine without CorpseCare reveals all traits). Legacy fallback: a
## record marked examined without any step bookkeeping (Phase-2/3 code and older records) shows
## all its traits, as before. Always a copy.
func revealed_traits() -> Array[StringName]:
	if _is_legacy_examined():
		return traits.duplicate()
	return traits_revealed.duplicate()


## stage_for(freshness) with the game's config (data/config/economy_config.tres, else defaults).
func freshness_stage() -> StringName:
	return stage_for(freshness, EconomyConfig.resolve())


## &"fresh" (>= fresh_good_threshold), &"rotten" (< rot_threshold, Phase 4 §2.5), &"decaying"
## (< fresh_bad_threshold), else &"wilted". The one threshold rule – GraveQuality's freshness
## points use it too.
static func stage_for(value: float, config: EconomyConfig) -> StringName:
	var cfg := EconomyConfig.resolve(config)
	if value >= cfg.fresh_good_threshold:
		return STAGE_FRESH
	if value < cfg.rot_threshold:
		return STAGE_ROTTEN
	if value < cfg.fresh_bad_threshold:
		return STAGE_DECAYING
	return STAGE_WILTED


## Phase 4 (§2.1): the pockets step is done, the corpse carries valuables and they are still
## undecided. Legacy fallback (examined without step bookkeeping): examined is enough.
func needs_valuables_decision() -> bool:
	if not has_trait(TRAIT_VALUABLES) or valuables_decision != DECISION_NONE:
		return false
	return _is_legacy_examined() or is_step_done(STEP_POCKETS)


## examined set without any Phase-4 step bookkeeping (Phase-2/3 code paths, unmigrated records).
func _is_legacy_examined() -> bool:
	return examined and exam_done.is_empty() and traits_revealed.is_empty()


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
		"story_id": story_id,
		"exam_done": exam_done.duplicate(),
		"finds_revealed": finds_revealed.duplicate(),
		"finds_lost": finds_lost.duplicate(),
		"traits_revealed": traits_revealed.duplicate(),
		"washed": washed,
		"dress": dress,
		"laid_out": laid_out,
		"harvested": harvested.duplicate(),
		"balm_windows": Array(balm_windows),
		"stench_noted": stench_noted,
		"room": room,
		"slot_id": slot_id,
		"cold_windows": Array(cold_windows),
		"service_held": service_held,
		"service_day": service_day,
		"hidden_cause": hidden_cause,
		"returned": returned.duplicate(),
		"revealed_cause": revealed_cause,
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
	# Phase 4 (§3.4, §5.1) – missing fields keep their defaults.
	r.story_id = StringName(_to_str(d.get("story_id"), ""))
	r.exam_done = _only(_to_name_array(d.get("exam_done")), STEPS)
	r.finds_revealed = _unique(_to_name_array(d.get("finds_revealed")))
	r.finds_lost = _unique(_to_name_array(d.get("finds_lost")))
	r.traits_revealed = _unique(_to_name_array(d.get("traits_revealed")))
	r.washed = _to_bool(d.get("washed"), r.washed)
	var dress_id := StringName(_to_str(d.get("dress"), ""))
	if dress_id in DRESSES:
		r.dress = dress_id
	# shrouded == (dress != "") – a record saved before the dress field was dressed in a shroud.
	if r.dress == DRESS_NONE and r.shrouded and not d.has("dress"):
		r.dress = DRESS_SHROUD
	r.shrouded = r.shrouded or r.dress != DRESS_NONE
	r.laid_out = _to_bool(d.get("laid_out"), r.laid_out)
	r.harvested = _only(_to_name_array(d.get("harvested")), HARVEST_KINDS)
	r.balm_windows = _to_windows(d.get("balm_windows"))
	r.stench_noted = _to_bool(d.get("stench_noted"), r.stench_noted)
	# Phase 6 (§3.4, §5.1) – missing fields keep their defaults.
	r.room = StringName(_to_str(d.get("room"), ""))
	r.slot_id = _to_str(d.get("slot_id"), r.slot_id)
	r.cold_windows = _to_cold_windows(d.get("cold_windows"))
	r.service_held = _to_bool(d.get("service_held"), r.service_held)
	r.service_day = _to_int(d.get("service_day"), r.service_day)
	# Phase 7 (§3.4, §5.1) – missing fields keep their defaults; returned ⊆ harvested.
	r.hidden_cause = StringName(_to_str(d.get("hidden_cause"), ""))
	r.returned = _only(_to_name_array(d.get("returned")), r.harvested)
	r.revealed_cause = StringName(_to_str(d.get("revealed_cause"), ""))
	return r


## Unique entries of `list` that are in `allowed`, in order.
static func _only(list: Array[StringName], allowed: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for item: StringName in list:
		if item in allowed and not item in out:
			out.append(item)
	return out


static func _unique(list: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for item: StringName in list:
		if item != &"" and not item in out:
			out.append(item)
	return out


## [start, end, …] pairs with end > start (JSON floats accepted); a malformed pair is dropped.
static func _to_windows(v: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not (v is Array or v is PackedInt32Array or v is PackedInt64Array or v is PackedFloat32Array or v is PackedFloat64Array):
		return out
	var list := Array(v)
	for i: int in range(0, list.size() - 1, 2):
		var start := _to_int(list[i], -1)
		var end := _to_int(list[i + 1], -1)
		if start >= 0 and end > start:
			out.append(start)
			out.append(end)
	return out


## [start, end, factor‰, …] triples: start ≥ 0, end -1 (open) or > start, factor 1…1000 (JSON
## floats accepted); a malformed triple is dropped.
static func _to_cold_windows(v: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not (v is Array or v is PackedInt32Array or v is PackedInt64Array or v is PackedFloat32Array or v is PackedFloat64Array):
		return out
	var list := Array(v)
	for i: int in range(0, list.size() - 2, 3):
		var start := _to_int(list[i], -1)
		var end := _to_int(list[i + 1], -2)
		var factor := _to_int(list[i + 2], 0)
		if start >= 0 and (end == -1 or end > start) and factor >= 1 and factor <= 1000:
			out.append(start)
			out.append(end)
			out.append(factor)
	return out


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
