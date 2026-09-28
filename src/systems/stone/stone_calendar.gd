class_name StoneCalendar
extends RefCounted
## STUB (P4) – docs/PHASE5_DESIGN.md §2.5, §14.3: game day → calendar date of the inscriptions
## (day 1 = 3. Gilbhart 1834, old German month names, real month lengths; StoneConfig.calendar).
## W1 (P4) fills the bodies.


## "8. Nebelung 1834"
static func date_text(_day: int, _cfg: StoneConfig) -> String:
	return ""


static func year_of(_day: int, cfg: StoneConfig) -> int:
	return int(cfg.calendar.get("start_year", 0)) if cfg != null else 0
