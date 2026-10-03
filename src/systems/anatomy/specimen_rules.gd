class_name SpecimenRules
extends RefCounted
## Pure specimen rules (docs/PHASE7_DESIGN.md §2.6, §2.6.1, §2.6.3, §3.4): harvest block reasons
## ("-" = no card at all: anatomy unknown / not the crypt table), clarity (a jar keeps it; a bundle
## falls linearly from its harvest clarity to 0 over bundle_minutes of effective time – cold windows ×
## pult_cold_factor), spoiled, the clarity word, Quast's price, the finding of a specimen.
## The depiction stays implied: the rules only know sealed jars and linen bundles.

const REASON_NO_CARD := "-"
const TEXT_TOO_LATE := "Zu spät. Daran lässt sich nichts mehr zeigen."
const TEXT_NO_TOOL := "Werkzeug fehlt – Quast hat es."
const TEXT_DRESSED := "Nach dem Einkleiden nicht mehr zugänglich."
const TEXT_MAX := "Mehr nimmst du ihr nicht."
const TEXT_TAKEN := "Das ist schon genommen."
const TEXT_UNKNOWN := "Das geht hier nicht."
const TEXT_ONLY_JAR := "Nur im dunklen, versiegelten Glas."
const TEXT_ONLY_BUNDLE := "Nur in Leinen geschlagen."
const TEXT_MISSING := "Es fehlt: %s"
const TEXT_FULL := "Kein Platz im Inventar."
const CLARITY_WORDS: Array[String] = ["sehr gut", "gut", "trüb", "kaum lesbar"]
const WORD_SPOILED := "verdorben"
## Grid of the clarity (like the corpse freshness, 1e-6).
const RESOLUTION := 1000000.0
## §2.6.3 „Seed 1 von 4": a finding without a data condition, rolled from the corpse seed.
const SEED_FINDING := &"b_stones"
const SEED_FINDING_ONE_IN := 4
const ITEM_JAR := &"specimen_jar"
const ITEM_BUNDLE := &"specimen_bundle"


## "" = possible. Order: no card (unknown / not the crypt / not on the table) · unknown organ ·
## dressed · taken · at most max_per_corpse organs · container of the organ · freshness · tool ·
## inputs · room for the piece.
static func harvest_block_reason(record: CorpseRecord, organ: StringName, container: StringName, inv: Inventory,
		room: StringName, known: bool, cfg: AnatomyConfig) -> String:
	var c := _cfg(cfg)
	if not known or record == null or room != c.room_id or record.location != CorpseRecord.LOCATION_TABLE:
		return REASON_NO_CARD
	var row := c.organ(organ)
	if row.is_empty():
		return TEXT_UNKNOWN
	if record.is_dressed() or record.shrouded:
		return TEXT_DRESSED
	if record.is_harvested(organ):
		return TEXT_TAKEN
	if organs_taken(record) >= c.max_per_corpse:
		return TEXT_MAX
	if not allows(organ, container, c):
		var allowed: Array = row.get("containers", [])
		return TEXT_ONLY_JAR if allowed == [SpecimenRecord.CONTAINER_JAR] else (TEXT_ONLY_BUNDLE if allowed == [SpecimenRecord.CONTAINER_BUNDLE] else TEXT_UNKNOWN)
	if record.freshness < c.min_freshness:
		return TEXT_TOO_LATE
	if inv == null or not inv.has(c.tool_item):
		return TEXT_NO_TOOL
	var missing := PackedStringArray()
	var inputs := harvest_inputs(organ, container, c)
	for id: StringName in inputs:
		if not inv.has(id, inputs[id]):
			missing.append(_item_name(id))
	if not missing.is_empty():
		return TEXT_MISSING % ", ".join(missing)
	if not inv.can_add(item_for(container), 1):
		return TEXT_FULL
	return ""


## Organs (not hair / teeth) of `record` taken so far.
static func organs_taken(record: CorpseRecord) -> int:
	var n := 0
	if record == null:
		return 0
	for kind: StringName in record.harvested:
		if kind in AnatomyConfig.ORGANS:
			n += 1
	return n


## `container` is one of the organ's containers (eyes: jar only, hand: bundle only).
static func allows(organ: StringName, container: StringName, cfg: AnatomyConfig) -> bool:
	var allowed: Array = _cfg(cfg).organ(organ).get("containers", [])
	return allowed.has(container) or allowed.has(String(container))


## The inputs of one harvest: jar (eyes: the small dark jar) or bundle (hand: linen + wax).
static func harvest_inputs(organ: StringName, container: StringName, cfg: AnatomyConfig) -> Dictionary[StringName, int]:
	var c := _cfg(cfg)
	if container == SpecimenRecord.CONTAINER_JAR:
		return c.small_jar_inputs if organ == CorpseRecord.HARVEST_EYES else c.jar_inputs
	return c.hand_inputs if organ == CorpseRecord.HARVEST_HAND else c.bundle_inputs


## Item id of a fresh specimen in `container`.
static func item_for(container: StringName) -> StringName:
	match container:
		SpecimenRecord.CONTAINER_BUNDLE:
			return ITEM_BUNDLE
		SpecimenRecord.CONTAINER_DISPLAY:
			return &"display_specimen"
		SpecimenRecord.CONTAINER_BONE:
			return &"bone_specimen"
	return ITEM_JAR


## A jar / display / bone keeps its clarity (sealed_clarity once sealed from a bundle); a bundle falls
## linearly from clarity_at_harvest to 0 over bundle_minutes of effective minutes since the harvest.
static func clarity(spec: SpecimenRecord, now_total: int, cfg: AnatomyConfig) -> float:
	if spec == null:
		return 0.0
	if spec.container != SpecimenRecord.CONTAINER_BUNDLE:
		return spec.sealed_clarity if spec.sealed_clarity >= 0.0 else spec.clarity_at_harvest
	var c := _cfg(cfg)
	var total := float(maxi(c.bundle_minutes, 1))
	var value := maxf(0.0, spec.clarity_at_harvest * (1.0 - effective_minutes(spec, now_total) / total))
	return roundf(value * RESOLUTION) / RESOLUTION


## Minutes since the harvest, those inside a cold window × its factor‰ (purely from the total-minute
## difference; overlapping windows: the smallest factor counts).
static func effective_minutes(spec: SpecimenRecord, now_total: int) -> float:
	var from := spec.harvest_total
	var minutes := maxi(0, now_total - from)
	var w := spec.cold_windows
	if minutes == 0 or w.size() < 3:
		return float(minutes)
	var borders: Array[int] = [from, now_total]
	for i: int in range(0, w.size() - 2, 3):
		for b: int in [w[i], w[i + 1]]:
			if b > from and b < now_total and not b in borders:
				borders.append(b)
	borders.sort()
	var out := 0.0
	for i: int in borders.size() - 1:
		out += float(borders[i + 1] - borders[i]) * cold_factor_at(spec, borders[i])
	return out


## The factor of the cold windows covering minute `total` (1.0 outside).
static func cold_factor_at(spec: SpecimenRecord, total: int) -> float:
	var factor := 1.0
	var w := spec.cold_windows
	for i: int in range(0, w.size() - 2, 3):
		if w[i] <= total and (w[i + 1] < 0 or total < w[i + 1]):
			factor = minf(factor, clampf(float(w[i + 2]) / 1000.0, 0.0, 1.0))
	return factor


## Only a bundle spoils: clarity 0.
static func is_spoiled(spec: SpecimenRecord, now_total: int, cfg: AnatomyConfig) -> bool:
	return spec != null and spec.container == SpecimenRecord.CONTAINER_BUNDLE and clarity(spec, now_total, cfg) <= 0.0


## ≥ 0.8 „sehr gut" · ≥ 0.6 „gut" · ≥ 0.45 „trüb" · below „kaum lesbar".
static func clarity_word(c: float, cfg: AnatomyConfig) -> String:
	var t := _cfg(cfg).clarity_words
	for i: int in mini(t.size(), CLARITY_WORDS.size() - 1):
		if c >= t[i] - 1e-6:
			return CLARITY_WORDS[i]
	return CLARITY_WORDS[CLARITY_WORDS.size() - 1]


## §2.6.1 without the university standing (Specimens adds it): round(base × (0.5 + 0.5 × clarity)) –
## bundle × bundle_price_factor; display × display_price_factor + display_price_bonus; bone = base –
## + friend_price_bonus with Quast „Befreundet". Never below 1; 0 for a spoiled or unknown piece.
static func price(spec: SpecimenRecord, now_total: int, friend: bool, cfg: AnatomyConfig) -> int:
	var c := _cfg(cfg)
	if spec == null or c.organ(spec.organ).is_empty() or is_spoiled(spec, now_total, c):
		return 0
	var base := float(int(c.organ(spec.organ).get("base_price", 0)))
	var value := base
	match spec.container:
		SpecimenRecord.CONTAINER_BONE:
			value = base
		SpecimenRecord.CONTAINER_DISPLAY:
			value = base * (0.5 + 0.5 * clarity(spec, now_total, c)) * c.display_price_factor + float(c.display_price_bonus)
		SpecimenRecord.CONTAINER_BUNDLE:
			value = base * (0.5 + 0.5 * clarity(spec, now_total, c)) * c.bundle_price_factor
		_:
			value = base * (0.5 + 0.5 * clarity(spec, now_total, c))
	return maxi(1, roundi(value + 1e-9) + (c.friend_price_bonus if friend else 0))


## Priority first (higher wins), then the order of `findings` (§2.6.3); null = none. Conditions: the
## organ (&"" = every organ), story_id, a cause condition (the effective cause – hidden_cause, else
## cause_id – equals one of the two non-empty fields, W0-Notizen 12), requires_trait; b_stones rolls
## „1 of 4" from the corpse seed.
static func finding_for(spec: SpecimenRecord, record: CorpseRecord, findings: Array[SpecimenFindingData]) -> SpecimenFindingData:
	if spec == null:
		return null
	var ordered: Array[SpecimenFindingData] = []
	for f: SpecimenFindingData in findings:
		if f != null:
			ordered.append(f)
	var indexed: Array = []
	for i: int in ordered.size():
		indexed.append([ordered[i].priority, i])
	indexed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	for entry: Array in indexed:
		var f: SpecimenFindingData = ordered[entry[1]]
		if _finding_matches(f, spec, record):
			return f
	return null


static func _finding_matches(f: SpecimenFindingData, spec: SpecimenRecord, record: CorpseRecord) -> bool:
	if f.organ != &"" and f.organ != spec.organ:
		return false
	if f.story_id != &"" and (record == null or record.story_id != f.story_id):
		return false
	if f.hidden_cause != &"" or f.cause_id != &"":
		if record == null:
			return false
		var cause := effective_cause(record)
		if cause != f.hidden_cause and cause != f.cause_id:
			return false
	if f.requires_trait != &"" and (record == null or not record.has_trait(f.requires_trait)):
		return false
	if f.id == SEED_FINDING and not seed_roll(record):
		return false
	return true


## The cause that really killed: hidden_cause, else the shown cause_id.
static func effective_cause(record: CorpseRecord) -> StringName:
	if record == null:
		return &""
	return record.hidden_cause if record.hidden_cause != &"" else record.cause_id


## b_stones: one corpse in four, deterministic from the seed.
static func seed_roll(record: CorpseRecord) -> bool:
	if record == null:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([record.seed, "b_stones"])
	return rng.randi_range(0, SEED_FINDING_ONE_IN - 1) == 0


static func _item_name(id: StringName) -> String:
	if Database.has_item(id):
		var item := Database.item(id) as ItemData
		if item != null and item.display_name != "":
			return item.display_name
	return String(id)


static func _cfg(cfg: AnatomyConfig) -> AnatomyConfig:
	if cfg != null:
		return cfg
	var real := Database.config(&"anatomy_config") as AnatomyConfig
	return real if real != null else AnatomyConfig.new()
