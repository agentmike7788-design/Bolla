class_name CorpseGenerator
extends RefCounted
## Deterministic corpse generation (local RNG only, no autoloads).
## Draw order (fixed): first name, last name, age, cause, traits, valuables coins.

## seed_for(day, index) = day * DAY_FACTOR + OFFSET + INDEX_FACTOR * index (docs §2.5).
const DAY_FACTOR := 7919
const OFFSET := 17
const INDEX_FACTOR := 104729
## Shown when a name table is empty (broken data).
const FALLBACK_NAME := "Unbekannt"


## Sets name, age, cause, traits, valuables_coins, freshness = 1 and seed. id stays "".
static func generate(seed: int, tables: CorpseTables, day: int) -> CorpseRecord:
	if tables == null:
		push_warning("[CorpseGenerator] no CorpseTables – nothing generated")
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var record := CorpseRecord.new()
	record.seed = seed
	var first := _pick_name(rng, tables.first_names)
	var last := _pick_name(rng, tables.last_names)
	record.display_name = ("%s %s" % [first, last]).strip_edges()
	record.age = rng.randi_range(mini(tables.age_min, tables.age_max), maxi(tables.age_min, tables.age_max))
	record.cause_id = _pick_cause(rng, tables.causes)
	record.traits = _pick_traits(rng, tables, day)
	if record.has_trait(CorpseRecord.TRAIT_VALUABLES):
		var low := mini(tables.valuables_coins_min, tables.valuables_coins_max)
		var high := maxi(tables.valuables_coins_min, tables.valuables_coins_max)
		record.valuables_coins = rng.randi_range(low, high)
	record.freshness = 1.0
	return record


static func seed_for(day: int, spawn_index: int) -> int:
	return day * DAY_FACTOR + OFFSET + INDEX_FACTOR * spawn_index


static func _pick_name(rng: RandomNumberGenerator, names: PackedStringArray) -> String:
	if names.is_empty():
		return FALLBACK_NAME
	return names[rng.randi_range(0, names.size() - 1)]


## Weighted choice; causes with weight <= 0 are never picked. Always draws exactly one value.
static func _pick_cause(rng: RandomNumberGenerator, causes: Array[Dictionary]) -> StringName:
	var total := 0.0
	for cause: Dictionary in causes:
		total += maxf(0.0, float(cause.get("weight", 0.0)))
	var roll := rng.randf() * total
	var picked := &""
	for cause: Dictionary in causes:
		var weight := maxf(0.0, float(cause.get("weight", 0.0)))
		if weight <= 0.0:
			continue
		picked = StringName(cause.get("id", &""))
		if roll < weight:
			return picked
		roll -= weight
	# Rounding at the upper end: the last cause with a positive weight.
	if picked == &"" and not causes.is_empty():
		push_warning("[CorpseGenerator] no cause has a positive weight – using the first")
		picked = StringName(causes[0].get("id", &""))
	return picked


## forced_traits_by_day[day] (if present) is used exactly; otherwise one roll per trait in table order.
static func _pick_traits(rng: RandomNumberGenerator, tables: CorpseTables, day: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if tables.forced_traits_by_day.has(day):
		for trait_id: String in tables.forced_traits_by_day[day]:
			if not StringName(trait_id) in out:
				out.append(StringName(trait_id))
		return out
	for entry: Dictionary in tables.traits:
		var chance := clampf(float(entry.get("chance", 0.0)), 0.0, 1.0)
		var trait_id := StringName(entry.get("id", &""))
		# randf() is inclusive of 1.0 – chance 1.0 must always hit.
		var roll := rng.randf()
		if (roll < chance or chance >= 1.0) and trait_id != &"" and not trait_id in out:
			out.append(trait_id)
	return out
