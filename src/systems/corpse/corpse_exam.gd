class_name CorpseExam
extends RefCounted
## Pure examination rules (docs/PHASE4_DESIGN.md §2.1, §2.2, §3.4), testable without a scene
## tree. Which finds a step can reveal, revealed vs. lost by freshness, step locks and the
## loss forecast for the panel.

const REASON_DONE := "Schon untersucht."
const REASON_DRESSED := "Nach dem Einkleiden nicht mehr zugänglich."
const REASON_UNKNOWN_STEP := "Diesen Schritt gibt es nicht."
## Labels of the find freshness classes (§2.2) for the loss forecast ("Hautzeichen noch ≈ 3 Std.").
const CLASS_LABELS: Dictionary[String, String] = {"0.3": "Hautzeichen", "0.6": "Feine Spuren"}
const CLASS_LABEL_FALLBACK := "Spuren"
const STAGE_LABELS: Dictionary[StringName, String] = {&"fresh": "Frisch", &"wilted": "Welk", &"decaying": "Verwesend", &"rotten": "Verfallen"}
## Search horizon of next_loss (minutes).
const LOSS_HORIZON := 60 * 24 * 60


## Finds `step` can reveal, in the order of `finds` (generic trait finds, cause details), then
## the story finds in the order of story.finds. Generic: trait present and the trait's step
## (cfg.trait_steps, else the find's step) is `step`; cause detail of record.cause_id. Story
## finds come from story.finds only; one with trait_id replaces the generic find of that trait.
static func candidates(record: CorpseRecord, step: StringName, finds: Array[FindData], story: StoryCorpseData, cfg: ExamConfig) -> Array[FindData]:
	var out: Array[FindData] = []
	if record == null:
		return out
	var story_finds: Array[FindData] = []
	var replaced := {}
	if story != null:
		for fid: StringName in story.finds:
			var f := _find_by_id(finds, fid)
			if f == null:
				continue
			story_finds.append(f)
			if f.trait_id != &"":
				replaced[f.trait_id] = true
	for f: FindData in finds:
		if f == null or f.story_only:
			continue
		if f.trait_id != &"":
			if not record.has_trait(f.trait_id) or replaced.has(f.trait_id):
				continue
			var trait_step: StringName = f.step
			if cfg != null:
				trait_step = cfg.trait_steps.get(f.trait_id, f.step)
			if trait_step == step:
				out.append(f)
		elif f.cause_id != &"":
			if f.cause_id == record.cause_id and f.step == step:
				out.append(f)
	for f: FindData in story_finds:
		if f.step == step:
			out.append(f)
	return out


## {revealed: Array[StringName], lost: Array[StringName]} by record.freshness – revealed at
## freshness ≥ min_freshness, else lost. Finds the record already knows are skipped.
static func resolve(record: CorpseRecord, candidates: Array[FindData]) -> Dictionary:
	var revealed: Array[StringName] = []
	var lost: Array[StringName] = []
	if record != null:
		for f: FindData in candidates:
			if f == null or record.finds_revealed.has(f.id) or record.finds_lost.has(f.id):
				continue
			if f.is_lost_at(record.freshness):
				lost.append(f.id)
			else:
				revealed.append(f.id)
	return {"revealed": revealed, "lost": lost}


## "" | "Schon untersucht." | "Nach dem Einkleiden nicht mehr zugänglich."
static func block_reason(record: CorpseRecord, step: StringName, cfg: ExamConfig) -> String:
	if record == null:
		return REASON_UNKNOWN_STEP
	if cfg != null and not cfg.step_ids().has(step):
		return REASON_UNKNOWN_STEP
	if cfg == null and not CorpseRecord.STEPS.has(step):
		return REASON_UNKNOWN_STEP
	if record.is_step_done(step):
		return REASON_DONE
	var locked: Array[StringName] = cfg.locked_by_dress if cfg != null else ([CorpseRecord.STEP_CLOTHING, CorpseRecord.STEP_POCKETS] as Array[StringName])
	if record.is_dressed() and locked.has(step):
		return REASON_DRESSED
	return ""


## Steps that can still be done, in config order.
static func open_steps(record: CorpseRecord, cfg: ExamConfig) -> Array[StringName]:
	var out: Array[StringName] = []
	var ids: Array[StringName] = cfg.step_ids() if cfg != null else CorpseRecord.STEPS
	for step: StringName in ids:
		if block_reason(record, step, cfg) == "":
			out.append(step)
	return out


static func minutes_for(steps: Array[StringName], cfg: ExamConfig) -> int:
	var total := 0
	if cfg == null:
		return total
	for step: StringName in steps:
		total += cfg.step_minutes(step)
	return total


## The next of `pending` that decay would take: {minutes (until it is lost), stage_label (stage
## the corpse is in then), find_id, label (freshness class), min_freshness} | {} (nothing at
## risk). Finds already below their threshold now and finds without threshold are ignored.
static func next_loss(record: CorpseRecord, pending: Array[FindData], now_total: int, decay_per_hour: float, balm_factor: float) -> Dictionary:
	if record == null or decay_per_hour <= 0.0:
		return {}
	var now_fresh := CorpseDecay.freshness_at(record, now_total, decay_per_hour, balm_factor)
	var best := {}
	for f: FindData in pending:
		if f == null or f.min_freshness <= 0.0 or f.is_lost_at(now_fresh):
			continue
		if record.finds_revealed.has(f.id) or record.finds_lost.has(f.id):
			continue
		var minutes := _minutes_until_below(record, now_total, decay_per_hour, balm_factor, f.min_freshness)
		if minutes < 0:
			continue
		if best.is_empty() or minutes < int(best.minutes):
			best = {"minutes": minutes, "stage_label": _stage_label_below(f.min_freshness), "find_id": f.id,
					"label": class_label(f.min_freshness), "min_freshness": f.min_freshness}
	return best


## "Hautzeichen" (0.3) / "Feine Spuren" (0.6).
static func class_label(min_freshness: float) -> String:
	return CLASS_LABELS.get("%.1f" % min_freshness, CLASS_LABEL_FALLBACK)


## Smallest minute offset at which the freshness is below `threshold` (freshness_at is
## monotonically falling); −1 = not within LOSS_HORIZON.
static func _minutes_until_below(record: CorpseRecord, now_total: int, decay_per_hour: float, balm_factor: float, threshold: float) -> int:
	if CorpseDecay.freshness_at(record, now_total + LOSS_HORIZON, decay_per_hour, balm_factor) >= threshold:
		return -1
	var lo := 0
	var hi := LOSS_HORIZON
	while lo < hi:
		var mid := (lo + hi) / 2
		if CorpseDecay.freshness_at(record, now_total + mid, decay_per_hour, balm_factor) < threshold:
			hi = mid
		else:
			lo = mid + 1
	return lo


static func _stage_label_below(threshold: float) -> String:
	var stage := CorpseRecord.stage_for(threshold - 1.0 / CorpseDecay.FRESHNESS_RESOLUTION, EconomyConfig.resolve())
	return STAGE_LABELS.get(stage, String(stage))


static func _find_by_id(finds: Array[FindData], id: StringName) -> FindData:
	for f: FindData in finds:
		if f != null and f.id == id:
			return f
	return null
