class_name ChapelRules
extends RefCounted
## Pure rules of the funeral service and the devotion (docs/PHASE6_DESIGN.md §2.4, §3.4). All
## values come from ChapelConfig (arrays by chapel level 0…3); the texts are the chapel's own.

const TEXT_DAYTIME := "Die Trauergäste kommen nur bei Tag."
const TEXT_DRESS := "Erst einkleiden – so legt man niemanden vor den Altar."
const TEXT_LATE := "Zu spät für eine offene Aussegnung."
const TEXT_NO_CANDLE := "Keine Altarkerze – Osric hat welche."
const TEXT_LIT := "Für dieses Grab brennt schon ein Licht."
const TEXT_NO_CHAPEL := "Die Kapelle hat noch kein Dach."
const TEXT_NO_CORPSE := "Auf dem Katafalk liegt niemand."
const TEXT_HELD := "Für diese Leiche ist die Aussegnung schon gehalten."
const TEXT_NO_GHOST := "In diesem Grab wartet noch keiner auf ein Licht."
## Minute value for `service_block_reason` that skips the time window and the freshness (the end of
## a service that began before 17:00 and fresh enough – ChapelRites.hold_service).
const ANY_MINUTE := -1


## "" or why the service cannot start, in this order: no chapel (level < 1) · no corpse on the
## catafalque · already held · outside service_start_min…service_start_max (skipped for
## ANY_MINUTE) · not dressed (shroud or gown) · freshness below service_min_freshness (skipped for
## ANY_MINUTE: the end of a service that began fresh enough) · no candle.
static func service_block_reason(record: CorpseRecord, inv: Inventory, minute: int, level: int, cfg: ChapelConfig) -> String:
	var c := _cfg(cfg)
	if level < 1:
		return TEXT_NO_CHAPEL
	if record == null or record.location != CorpseRecord.LOCATION_CATAFALQUE:
		return TEXT_NO_CORPSE
	if record.service_held:
		return TEXT_HELD
	if minute != ANY_MINUTE and (minute < c.service_start_min or minute > c.service_start_max):
		return TEXT_DAYTIME
	if c.service_needs_dress and not is_dressed(record):
		return TEXT_DRESS
	# The freshness counts at the start like the time window: a service that began fresh enough
	# ends even if the corpse lost a little during the 45 minutes (QA6-07).
	if minute != ANY_MINUTE and record.freshness < c.service_min_freshness:
		return TEXT_LATE
	if not has_candle(inv, c):
		return TEXT_NO_CANDLE
	return ""


## "" or why no devotion for this grave (`current` = the level already held for it, 0 = none):
## no chapel · no ghost (grave not MARKED) · a light at this level already burns · no candle.
## After an upgrade of the chapel the grave may be held for again (the higher value counts).
static func devotion_block_reason(grave: GraveRecord, current: int, inv: Inventory, level: int, cfg: ChapelConfig) -> String:
	var c := _cfg(cfg)
	if level < 1:
		return TEXT_NO_CHAPEL
	if grave == null or grave.state != GraveRecord.State.MARKED:
		return TEXT_NO_GHOST
	if current >= level:
		return TEXT_LIT
	if not has_candle(inv, c):
		return TEXT_NO_CANDLE
	return ""


## devotion_mood_by_level[level_held] (0 outside the table); for a robbed soul (robbed > 0) capped so
## that base_score + bonus ≤ devotion_robbed_cap. Never negative.
static func devotion_bonus(level_held: int, robbed: int, base_score: int, cfg: ChapelConfig) -> int:
	var c := _cfg(cfg)
	var bonus := at_level(c.devotion_mood_by_level, level_held)
	if robbed > 0:
		bonus = mini(bonus, c.devotion_robbed_cap - base_score)
	return maxi(bonus, 0)


## Fee of the family at `level` (service_fee_by_level; 0 outside the table).
static func fee(level: int, cfg: ChapelConfig) -> int:
	return at_level(_cfg(cfg).service_fee_by_level, level)


## Reputation of a service at `level` (service_rep_by_level).
static func reputation(level: int, cfg: ChapelConfig) -> int:
	return at_level(_cfg(cfg).service_rep_by_level, level)


## Silent mourners at `level` (mourners_by_level).
static func mourners(level: int, cfg: ChapelConfig) -> int:
	return at_level(_cfg(cfg).mourners_by_level, level)


## Shroud or gown (older records: shrouded).
static func is_dressed(record: CorpseRecord) -> bool:
	return record != null and (record.dress != CorpseRecord.DRESS_NONE or record.shrouded)


static func has_candle(inv: Inventory, cfg: ChapelConfig) -> bool:
	var c := _cfg(cfg)
	return c.candle_amount <= 0 or (inv != null and inv.has(c.candle_item, c.candle_amount))


## values[level], 0 outside the table.
static func at_level(values: PackedInt32Array, level: int) -> int:
	return values[level] if level >= 0 and level < values.size() else 0


static func _cfg(cfg: ChapelConfig) -> ChapelConfig:
	if cfg != null:
		return cfg
	var real := Database.config(&"chapel_config") as ChapelConfig
	return real if real != null else ChapelConfig.new()
