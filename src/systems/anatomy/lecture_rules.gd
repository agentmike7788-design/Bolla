class_name LectureRules
extends RefCounted
## Pure rules of Quast's night lecture (docs/PHASE7_DESIGN.md §2.6.4, §3.4): every third night
## (day % every_days == 0) from 23:00 to 00:30 (lecture.start, lecture.window); a jar / bone / display
## specimen with clarity ≥ 0.5, not spoiled, no bundle; one lecture per evening; the fee (4 + organ
## bonus + standing); the deterministic rumour (25 %, 10 % from „Geschätzt").

const TEXT_BUNDLE := "Kein Bündel. Quast will ein Glas."
const TEXT_NOT_INVITED := "Quast hat dich nicht eingeladen."
const TEXT_HELD := "Heute Abend war schon Vorlesung."
const TEXT_GONE := "Das Präparat ist nicht mehr da."
const TEXT_CLOUDY := "Zu trüb. Daran sieht die Bank nichts."
const TEXT_NOT_TONIGHT := "Heute Abend ist keine Vorlesung."
const MINUTES_PER_DAY := 1440
const ESTEEMED := &"esteemed"
## Minimum clarity (§2.6.4: Klarheit ≥ 0,5 – the pult's inspect minimum).
const DEFAULT_MIN_CLARITY := 0.5


## day % every_days == 0 and start ≤ minute < start + window; minutes after midnight (< start + window
## − 1440) belong to the night of the day before. `minute` may also run past 1440 on the same day.
static func is_lecture_night(day: int, minute: int, cfg: AnatomyConfig) -> bool:
	return night_of(day, minute, cfg) > 0


## The lecture night (its day) that the minute belongs to; 0 = none.
static func night_of(day: int, minute: int, cfg: AnatomyConfig) -> int:
	var l := _lecture(cfg)
	var every := maxi(int(l.get("every_days", 3)), 1)
	var start := int(l.get("start", 1380))
	var window := int(l.get("window", 90))
	var night := -1
	if minute >= start and minute < start + window:
		night = day
	elif minute < start + window - MINUTES_PER_DAY and minute >= 0:
		night = day - 1
	if night <= 0 or posmod(night, every) != 0:
		return 0
	return night


## "" = this specimen can go on the lectern tonight.
static func block_reason(spec: SpecimenRecord, now_total: int, invited: bool, held_today: bool, cfg: AnatomyConfig) -> String:
	if not invited:
		return TEXT_NOT_INVITED
	if held_today:
		return TEXT_HELD
	if spec == null or spec.state != SpecimenRecord.STATE_HELD:
		return TEXT_GONE
	if spec.container == SpecimenRecord.CONTAINER_BUNDLE:
		return TEXT_BUNDLE
	var c := _cfg(cfg)
	if SpecimenRules.is_spoiled(spec, now_total, c) or SpecimenRules.clarity(spec, now_total, c) < c.inspect_min_clarity - 1e-6:
		return TEXT_CLOUDY
	return ""


## fee + the organ's lecture_bonus (heart 2, eyes 3, hand 4, else 1) + standing × standing_bonus.
static func fee(organ: StringName, standing: int, cfg: AnatomyConfig) -> int:
	var c := _cfg(cfg)
	var l := c.lecture
	return int(l.get("fee", 4)) + int(c.organ(organ).get("lecture_bonus", 0)) + maxi(standing, 0) * int(l.get("standing_bonus", 1))


## Somebody saw the light: rumor_chance (rumor_chance_esteemed from „Geschätzt" on), deterministic
## from day and seed.
static func rumor(day: int, seed: int, rep_tier: StringName, cfg: AnatomyConfig) -> bool:
	var l := _lecture(cfg)
	var esteemed := ReputationRules.tier_index(rep_tier) >= ReputationRules.tier_index(ESTEEMED)
	var chance := float(l.get("rumor_chance_esteemed", 0.10)) if esteemed else float(l.get("rumor_chance", 0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([day, seed, "lecture_rumor"])
	return rng.randf() < chance


static func _lecture(cfg: AnatomyConfig) -> Dictionary:
	return _cfg(cfg).lecture


static func _cfg(cfg: AnatomyConfig) -> AnatomyConfig:
	if cfg != null:
		return cfg
	var real := Database.config(&"anatomy_config") as AnatomyConfig
	return real if real != null else AnatomyConfig.new()
