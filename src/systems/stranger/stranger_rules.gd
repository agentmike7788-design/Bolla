class_name StrangerRules
extends RefCounted
## Pure rules of Brenneisen (docs/PHASE9_DESIGN.md §2.5, §3.4; P5): the visit days relative to p9_open_day
## (arrive_offset 2, every return_every days for stay_days days, at most MAX_VISITS visits), present in a region at a
## minute (outside the cemetery gate / in the village / in the Holderkrug – never inside the cemetery), why an offer
## cannot be sold (a fresh grave ≤ n days, the register extract, specimens × 1.5, the ledger after the main chain).
##
## state of present(): {open_day, ending, ending_day, left} (Stranger.rule_state()).
## context of offer_block_reason(): {soil_ready (a fresh grave offers soil today), specimen_uid, quest_ended
## (Array of quest ids), sold (Dictionary offer key → n)}.

## He comes at most this often; after the last day of the last visit without an ending he leaves for good.
const MAX_VISITS := 4
## Over the Holderbrücke at 09:30, at the Holderkrug until he walks up at 13:30; back in the village from 16:00.
const VILLAGE_MORNING := Vector2i(570, 810)
const VILLAGE_EVENING_FROM := 960
const REGION_GRAVEYARD := &"graveyard"
const REGION_VILLAGE := &"village"
const REGION_INN := &"inn"
## His place outside the gate – the only graveyard spot he ever stands on (§4.4: never inside the cemetery).
const GATE_SPOT := &"stranger_gate"
const SOIL_ITEM := &"soil_pouch"
const LEDGER_ITEM := &"lorenz_ledger_2"
const COND_FRESH := "fresh_grave_days"
const COND_HAS_ITEM := "has_item"
const COND_FLAG := "flag"
const COND_QUEST_ENDED := "quest_ended"

const TEXT_SOIL := "Erst eine Handvoll Erde von einem frischen Grab."
const TEXT_NO_FRESH := "Kein Grab ist frisch genug."
const TEXT_NOT_WITH_YOU := "Das hast du nicht dabei."
const TEXT_UNKNOWN := "Davon weißt du nichts."
const TEXT_NOT_YET := "Noch nicht."
const TEXT_NO_SPECIMEN := "Du hast kein Präparat dabei."
const TEXT_NO_INVENTORY := "Du hast nichts dabei."


## Every day he is in Hollerbrück (first days of the visits: open_day + arrive_offset + k × return_every), sorted.
## open_day < 0 → none.
static func visit_days(open_day: int, cfg: StrangerConfig) -> PackedInt32Array:
	var out := PackedInt32Array()
	if open_day < 0 or cfg == null:
		return out
	for k: int in MAX_VISITS:
		var start := visit_start(open_day, k + 1, cfg)
		for d: int in maxi(cfg.stay_days, 1):
			out.append(start + d)
	return out


## The first day of the `k`-th visit (1, 2, …).
static func visit_start(open_day: int, k: int, cfg: StrangerConfig) -> int:
	return open_day + cfg.arrive_offset + maxi(k - 1, 0) * cfg.return_every


## The number of the visit `day` belongs to (1…MAX_VISITS), 0 = none.
static func visit_of(day: int, open_day: int, cfg: StrangerConfig) -> int:
	if open_day < 0 or cfg == null:
		return 0
	for k: int in range(1, MAX_VISITS + 1):
		var start := visit_start(open_day, k, cfg)
		if day >= start and day < start + maxi(cfg.stay_days, 1):
			return k
	return 0


## The last day he can be here (the last day of the last visit).
static func last_day(open_day: int, cfg: StrangerConfig) -> int:
	return visit_start(open_day, MAX_VISITS, cfg) + maxi(cfg.stay_days, 1) - 1


## Is he in `region` at `minute` of `day`? graveyard = outside the gate in gate_window; village = 09:30–13:30 and from
## 16:00 to the end of inn_window; inn = inn_window. Not before p9_open, not after the day of his ending, not after he left.
static func present(day: int, minute: int, region: StringName, state: Dictionary, cfg: StrangerConfig) -> bool:
	if cfg == null:
		return false
	var open_day := _int(state.get("open_day"), -1)
	if open_day < 0 or state.get("left", false) == true:
		return false
	var ending := StringName(str(state.get("ending", "")))
	if ending != &"" and day > _int(state.get("ending_day"), day):
		return false
	if visit_of(day, open_day, cfg) == 0:
		return false
	match region:
		REGION_GRAVEYARD:
			return minute >= cfg.gate_window.x and minute < cfg.gate_window.y
		REGION_INN:
			return minute >= cfg.inn_window.x and minute < cfg.inn_window.y
		REGION_VILLAGE:
			return (minute >= VILLAGE_MORNING.x and minute < VILLAGE_MORNING.y) \
					or (minute >= VILLAGE_EVENING_FROM and minute < cfg.inn_window.y)
	return false


## Where he stands in `region` (the graveyard: only outside the gate).
static func spot(region: StringName) -> StringName:
	return GATE_SPOT if region == REGION_GRAVEYARD else &""


## Whether the offer is shown at all (flag / quest_ended conditions; the others only dim it).
static func offer_visible(offer: StrangerOfferData, context: Dictionary) -> bool:
	if offer == null:
		return false
	for c: String in offer.conditions:
		var key := c.get_slice(":", 0)
		var arg := c.substr(key.length() + 1) if c.contains(":") else ""
		match key:
			COND_FLAG:
				if not GameState.flag_on(StringName(arg)):
					return false
			COND_QUEST_ENDED:
				var ended: Variant = context.get("quest_ended", [])
				if not (ended is Array or ended is PackedStringArray) or not (String(arg) in ended or StringName(arg) in ended):
					return false
	return true


## "" = he buys it now; otherwise the reason (never a number, §7.4).
static func offer_block_reason(offer: StrangerOfferData, inv: Inventory, context: Dictionary) -> String:
	if offer == null:
		return TEXT_UNKNOWN
	for c: String in offer.conditions:
		var key := c.get_slice(":", 0)
		var arg := c.substr(key.length() + 1) if c.contains(":") else ""
		match key:
			COND_FLAG:
				if not GameState.flag_on(StringName(arg)):
					return TEXT_UNKNOWN
			COND_QUEST_ENDED:
				if not offer_visible(offer, context):
					return TEXT_NOT_YET
	if inv == null:
		return TEXT_NO_INVENTORY
	for c: String in offer.conditions:
		var key := c.get_slice(":", 0)
		var arg := c.substr(key.length() + 1) if c.contains(":") else ""
		match key:
			COND_FRESH:
				if not inv.has(SOIL_ITEM):
					return TEXT_SOIL if context.get("soil_ready", false) == true else TEXT_NO_FRESH
			COND_HAS_ITEM:
				if not inv.has(StringName(arg)):
					return TEXT_NOT_WITH_YOU
	if offer.item == &"" and str(context.get("specimen_uid", "")) == "":
		return TEXT_NO_SPECIMEN
	if offer.item != &"" and not _has_condition(offer, COND_FRESH) and not _has_condition(offer, COND_HAS_ITEM) \
			and not inv.has(offer.item):
		return TEXT_NOT_WITH_YOU
	return ""


## The days a grave counts as fresh for the soil (`fresh_grave_days:<n>` of the offer; 5 without one).
static func fresh_days(offer: StrangerOfferData) -> int:
	if offer != null:
		for c: String in offer.conditions:
			if c.begins_with(COND_FRESH + ":"):
				return maxi(int(c.get_slice(":", 1)), 0)
	return 5


## Brenneisen's price of a specimen: Quast's price × specimen_factor, rounded (§2.5.2).
static func specimen_price(quast_price: int, cfg: StrangerConfig) -> int:
	if quast_price <= 0:
		return 0
	return roundi(quast_price * (cfg.specimen_factor if cfg != null else 1.5))


## The question of the `visit`-th visit (1, 2, …): a new one each visit, in the order of cfg.questions.
static func question(visit: int, cfg: StrangerConfig) -> String:
	if cfg == null or cfg.questions.is_empty() or visit <= 0:
		return ""
	return cfg.questions[(visit - 1) % cfg.questions.size()]


static func _has_condition(offer: StrangerOfferData, key: String) -> bool:
	for c: String in offer.conditions:
		if c.get_slice(":", 0) == key:
			return true
	return false


static func _int(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback
