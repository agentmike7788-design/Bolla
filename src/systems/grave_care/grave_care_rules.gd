class_name GraveCareRules
extends RefCounted
## Pure grave-care rules (docs/PHASE8_DESIGN.md §2.3, §3.2.1): flowers fresh / wilted / gone by the minutes
## since the last watering, the candle window 15:00–07:00, the night a candle burns in, the mortsafe minimum
## of 10 days, the care bonus (flowers or bouquet +1, candle +1 – +2 on the night of the lights – capped by
## care_cap; a disturbed grave disturbed_mood on top). Deterministic, no tree.

const MINUTES_PER_DAY := 1440
## Minutes before noon belong to the night that began the evening before (GhostManager.night_index).
const NIGHT_SPLIT_MINUTE := 720
const FRESH := &"fresh"
const WILTED := &"wilted"
const WREATH := &"wreath"


## &"" | &"fresh" | &"wilted" | &"wreath" of a flowers entry {planted, watered, wreath} at `now` (total
## minutes). A wax wreath never wilts; grave flowers are fresh flower_fresh_minutes after the last watering,
## wilted until flower_wilt_minutes, then gone.
static func flowers_state(entry: Dictionary, now: int, cfg: GraveCareConfig) -> StringName:
	if entry.is_empty():
		return &""
	if bool(entry.get("wreath", false)):
		return WREATH
	var since := now - last_watered(entry)
	if since < 0:
		return FRESH
	if since < cfg.flower_fresh_minutes:
		return FRESH
	if since < cfg.flower_wilt_minutes:
		return WILTED
	return &""


## Total minute of the last watering (planting counts as one).
static func last_watered(entry: Dictionary) -> int:
	return _int(entry.get("watered", entry.get("planted", 0)))


## The grave flowers are gone (withered away) at `now` – a wreath never.
static func flowers_gone(entry: Dictionary, now: int, cfg: GraveCareConfig) -> bool:
	return not entry.is_empty() and flowers_state(entry, now, cfg) == &""


## A candle may be lit at this minute of day: from candle_from_minute (15:00) through the night until
## candle_until_minute (07:00).
static func may_light_at(minute_of_day: int, cfg: GraveCareConfig) -> bool:
	var m := posmod(minute_of_day, MINUTES_PER_DAY)
	return m >= cfg.candle_from_minute or m < cfg.candle_until_minute


## Total minute a candle lit at `lit_total` goes out: the next candle_until_minute (07:00).
static func candle_out_total(lit_total: int, cfg: GraveCareConfig) -> int:
	var day_start := floori(float(lit_total) / MINUTES_PER_DAY) * MINUTES_PER_DAY
	var m := lit_total - day_start
	if m < cfg.candle_until_minute:
		return day_start + cfg.candle_until_minute
	return day_start + MINUTES_PER_DAY + cfg.candle_until_minute


## The candle lit at `lit_total` still burns at `now`.
static func candle_burning(lit_total: int, now: int, cfg: GraveCareConfig) -> bool:
	return now >= lit_total and now < candle_out_total(lit_total, cfg)


## The night (= the day whose evening it began on) of a total minute: before noon the night before.
static func night_of(total: int) -> int:
	var day := floori(float(total) / MINUTES_PER_DAY) + 1
	var minute := total - (day - 1) * MINUTES_PER_DAY
	return day if minute >= NIGHT_SPLIT_MINUTE else day - 1


## The mortsafe set at `set_total` may come off at `now` (mortsafe_min_days: "bis die Erde sich gesetzt hat").
static func mortsafe_removable(set_total: int, now: int, cfg: GraveCareConfig) -> bool:
	return now - set_total >= cfg.mortsafe_min_days * MINUTES_PER_DAY


## Days left until the mortsafe may come off (0 = now).
static func mortsafe_days_left(set_total: int, now: int, cfg: GraveCareConfig) -> int:
	var left := cfg.mortsafe_min_days * MINUTES_PER_DAY - (now - set_total)
	return maxi(0, ceili(float(left) / MINUTES_PER_DAY))


## The visitor's bouquet laid at `laid_total` is still fresh at `now` (bouquet_minutes).
static func bouquet_fresh(laid_total: int, now: int, cfg: GraveCareConfig) -> bool:
	return now >= laid_total and now - laid_total < cfg.bouquet_minutes


## Care bonus of the ghost mood (§2.3, §2.11): fresh grave flowers or a fresh bouquet +1 (not both; the wax
## wreath +0), a burning candle +1 (+lights_candle_mood on the night of the lights), capped by care_cap; a
## disturbed grave adds disturbed_mood (not capped).
static func care_bonus(flowers: StringName, bouquet: bool, candle: bool, lights_night: bool, disturbed: bool,
		cfg: GraveCareConfig) -> int:
	var plus := 0
	if flowers == FRESH or bouquet:
		plus += 1
	if candle:
		plus += cfg.lights_candle_mood if lights_night else 1
	var out := clampi(plus, 0, maxi(cfg.care_cap, 0))
	if disturbed:
		out += cfg.disturbed_mood
	return out


static func _int(v: Variant) -> int:
	if v is int:
		return v
	if v is float:
		return roundi(v)
	if v is String and (v as String).is_valid_float():
		return roundi((v as String).to_float())
	return 0
