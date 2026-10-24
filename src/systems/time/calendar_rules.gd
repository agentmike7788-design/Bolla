class_name CalendarRules
extends RefCounted
## Weekdays and calendar months of the game days (docs/PHASE10_DESIGN.md §2.7.1, §3.4; Lead, complete in W0).
## Game day 1 = Friday, 3. Gilbhart 1834 (historically right): weekday = (day − 1 + DAY1_WEEKDAY) mod 7, 0 = Monday.
## Saturdays are days 2, 9, … 79, 86; Sundays 3, 10, … 80, 87; the month's firsts days 30 (1. Nebelung, Sa),
## 60 (1. Julmond, Mo), 91 (1. Hartung 1835, Do), 122 (1. Hornung).
## Pure functions over StoneCalendar.date_of (StoneCalendar stays unchanged – PHASE9 W0 Nr. 11). Unlike StoneCalendar
## (which clamps days < 1 to day 1 for the inscriptions) weekday/week_of count on through days ≤ 0, and
## first_day_of_month may return a day ≤ 0 (1. Gilbhart 1834 = day −1).
## Month keys are "YYYY-MM" ("1834-12"); cfg null = the class defaults of StoneConfig (= data/config/stone_config.tres).

const WEEKDAY_NAMES: PackedStringArray = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
const WEEKDAY_SHORT: PackedStringArray = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
const DAY1_WEEKDAY := 4                               # Tag 1 = Freitag, 3. Gilbhart 1834
const MONDAY := 0
const SATURDAY := 5
const SUNDAY := 6


## 0 = Montag … 6 = Sonntag
static func weekday(day: int) -> int:
	return posmod(day - 1 + DAY1_WEEKDAY, 7)


## "Samstag" | "Sa"
static func weekday_name(day: int, short: bool = false) -> String:
	return WEEKDAY_SHORT[weekday(day)] if short else WEEKDAY_NAMES[weekday(day)]


## Week Monday–Sunday; days 1–3 (Fr–So) = week 0, day 4 (the first Monday) = week 1.
static func week_of(day: int) -> int:
	return floori(float(day - 1 + DAY1_WEEKDAY) / 7.0)


## "1834-12" for game day `day` (days < 1 = day 1, as StoneCalendar).
static func month_key(day: int, cfg: StoneConfig = null) -> String:
	var d := StoneCalendar.date_of(day, cfg)
	return _key(int(d.year), int(d.month))


## "Julmond 1834" ("" for a malformed key).
static func month_title(key: String, cfg: StoneConfig = null) -> String:
	var ym := _parse(key)
	if ym.is_empty():
		return ""
	return "%s %d" % [StoneCalendar._month_names(cfg)[ym[1] - 1], ym[0]]


static func is_first_of_month(day: int, cfg: StoneConfig = null) -> bool:
	return day >= 1 and int(StoneCalendar.date_of(day, cfg).day) == 1


## The game day of the 1st of month `key` (≤ 0 before the game's start: 1. Gilbhart 1834 = −1). A malformed key → 0.
static func first_day_of_month(key: String, cfg: StoneConfig = null) -> int:
	var ym := _parse(key)
	if ym.is_empty():
		return 0
	var start := _start(cfg)
	var lengths := StoneCalendar._month_days(cfg)
	# Days from the 1st of the start month to the 1st of the target month (negative before it).
	var offset := 0
	var y: int = start[0]
	var m: int = start[1]
	var target := ym[0] * 12 + ym[1]
	while y * 12 + m < target:
		offset += lengths[m - 1]
		m += 1
		if m > 12:
			m = 1
			y += 1
	while y * 12 + m > target:
		m -= 1
		if m < 1:
			m = 12
			y -= 1
		offset -= lengths[m - 1]
	# Game day 1 is the start_day of the start month.
	return offset - (start[2] - 1) + 1


## Length of month `key` in days (no leap years, as StoneCalendar); a malformed key → 0.
static func days_in_month(key: String, cfg: StoneConfig = null) -> int:
	var ym := _parse(key)
	if ym.is_empty():
		return 0
	return StoneCalendar._month_days(cfg)[ym[1] - 1]


## The next day ≥ day with this weekday (0 = Montag … 6 = Sonntag).
static func next_weekday(day: int, p_weekday: int) -> int:
	return day + posmod(p_weekday - weekday(day), 7)


# --- helpers ------------------------------------------------------------------------------------

static func _key(year: int, month: int) -> String:
	return "%04d-%02d" % [year, month]


## [year, month] of "YYYY-MM", [] if malformed.
static func _parse(key: String) -> Array[int]:
	var parts := key.split("-")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return []
	var month := parts[1].to_int()
	if month < 1 or month > 12:
		return []
	return [parts[0].to_int(), month]


## [start_year, start_month, start_day] of the calendar (StoneConfig.calendar, clamped like StoneCalendar.date_of).
static func _start(cfg: StoneConfig) -> Array[int]:
	var cal: Dictionary = cfg.calendar if cfg != null else StoneConfig.new().calendar
	var month := clampi(int(cal.get("start_month", 1)), 1, 12)
	var day := clampi(int(cal.get("start_day", 1)), 1, StoneCalendar._month_days(cfg)[month - 1])
	return [int(cal.get("start_year", 1834)), month, day]
