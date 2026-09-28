class_name OssuaryRules
extends RefCounted
## Pure rules of lifting old graves and the ossuary places (docs/PHASE6_DESIGN.md §2.3, §3.4):
## the rest period (year − died_year ≥ min_rest_years), the ossuary places per crypt level
## (ossuary_by_level; lifted + reinterred occupy a place), the bone box and the block texts.

const TEXT_REST := "Die Ruhezeit ist nicht um. Hier liegt noch keiner lange genug."
const TEXT_NO_BOX := "Keine Gebeinkiste – an der Werkbank zimmern."
const TEXT_FULL := "Das Beinhaus ist voll – erst die Gruft ausbauen."
const TEXT_BURIED := "Die Gruft ist noch verschüttet."
## The grave is no (longer an) old grave – already lifted or never one.
const TEXT_NOT_OLD := "Hier liegt kein altes Grab mehr."
## The filled box does not fit into the inventory.
const TEXT_NO_ROOM := "Kein Platz im Inventar für die belegte Kiste."
## Lifting is a dig action: the shovel tier shortens it like digging (60 / 50 / 35).
const ACTION_DIG := &"dig"


## year − died_year ≥ min_rest_years.
static func liftable(data: OldGraveData, year: int, cfg: CryptConfig) -> bool:
	if data == null or cfg == null:
		return false
	return year - data.died_year >= cfg.min_rest_years


## "" or the reason (§2.3 texts). Order: not open (the crypt is still buried) → no old grave →
## rest period → crypt level 0 → ossuary full → no bone box → no room for the filled box.
static func lift_block_reason(grave: GraveRecord, data: OldGraveData, crypt_level: int, used: int, inv: Inventory,
		year: int, cfg: CryptConfig, open: bool) -> String:
	if cfg == null:
		cfg = CryptConfig.new()
	if not open:
		return TEXT_BURIED
	if grave == null or grave.state != GraveRecord.State.OLD or data == null:
		return TEXT_NOT_OLD
	if not liftable(data, year, cfg):
		return TEXT_REST
	if crypt_level < 1:
		return TEXT_BURIED
	if used >= capacity(crypt_level, cfg):
		return TEXT_FULL
	if inv == null or not inv.has(cfg.box_item):
		return TEXT_NO_BOX
	if not inv.can_add(cfg.full_item, 1) and inv.count(cfg.box_item) > 1:
		return TEXT_NO_ROOM
	return ""


## ossuary_by_level[crypt_level] (clamped).
static func capacity(crypt_level: int, cfg: CryptConfig) -> int:
	if cfg == null or cfg.ossuary_by_level.is_empty():
		return 0
	return maxi(cfg.ossuary_by_level[clampi(crypt_level, 0, cfg.ossuary_by_level.size() - 1)], 0)


## „Agnes Hollweg (1741–1789)".
static func label(data: OldGraveData) -> String:
	if data == null:
		return ""
	return "%s (%d–%d)" % [data.display_name, data.born_year, data.died_year]


## Minutes of lifting with the shovel on the player's belt (lift_minutes through the dig factors).
static func lift_minutes(cfg: CryptConfig, actions: ActionConfig, inv: Inventory) -> int:
	var base := cfg.lift_minutes if cfg != null else CryptConfig.new().lift_minutes
	return ToolRules.action_minutes(actions, ACTION_DIG, base, inv)
