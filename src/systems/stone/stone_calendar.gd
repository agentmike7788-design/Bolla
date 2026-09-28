class_name StoneCalendar
extends RefCounted
## Game day → calendar date of the inscriptions (docs/PHASE5_DESIGN.md §2.5, §14.3): game day 1 =
## StoneConfig.calendar start (3. Gilbhart 1834), old German month names, real month lengths
## (month_days; no leap years – the game never runs a whole year). Days < 1 count as day 1.

const FALLBACK_NAMES: PackedStringArray = ["Hartung", "Hornung", "Lenzing", "Ostermond", "Wonnemond", "Brachet",
		"Heuet", "Ernting", "Scheiding", "Gilbhart", "Nebelung", "Julmond"]
const FALLBACK_DAYS: PackedInt32Array = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


## "8. Nebelung 1834"
static func date_text(day: int, cfg: StoneConfig) -> String:
	var d := date_of(day, cfg)
	return "%d. %s %d" % [d.day, _month_names(cfg)[int(d.month) - 1], d.year]


static func year_of(day: int, cfg: StoneConfig) -> int:
	return int(date_of(day, cfg).year)


## {year, month (1…12), day} of game day `day`.
static func date_of(day: int, cfg: StoneConfig) -> Dictionary:
	var cal: Dictionary = cfg.calendar if cfg != null else StoneConfig.new().calendar
	var lengths := _month_days(cfg)
	var year := int(cal.get("start_year", 1834))
	var month := clampi(int(cal.get("start_month", 1)), 1, 12)
	var d := clampi(int(cal.get("start_day", 1)), 1, lengths[month - 1])
	var left := maxi(day, 1) - 1
	while left > 0:
		var rest := lengths[month - 1] - d
		if left <= rest:
			d += left
			break
		left -= rest + 1
		d = 1
		month += 1
		if month > 12:
			month = 1
			year += 1
	return {"year": year, "month": month, "day": d}


static func _month_names(cfg: StoneConfig) -> PackedStringArray:
	var raw: Variant = cfg.calendar.get("month_names", []) if cfg != null else []
	var out := PackedStringArray()
	if raw is Array or raw is PackedStringArray:
		for n: Variant in raw:
			out.append(str(n))
	return out if out.size() == 12 else FALLBACK_NAMES


static func _month_days(cfg: StoneConfig) -> PackedInt32Array:
	var raw: Variant = cfg.calendar.get("month_days", []) if cfg != null else []
	var out := PackedInt32Array()
	if raw is Array or raw is PackedInt32Array:
		for n: Variant in raw:
			out.append(maxi(1, int(n)))
	return out if out.size() == 12 else FALLBACK_DAYS
