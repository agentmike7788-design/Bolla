class_name FavorRules
extends RefCounted
## Pure favour rules (docs/PHASE8_DESIGN.md §2.4 „Gefallen & Gegengefallen", §3.2.1): may a favour be
## asked (story done, cooldown 5 days, the 7-day rest after an unreturned favour, no open return favour,
## not „gereizt"), the return favour picked from the pool (deterministic), its offer day and deadline, the
## choice of a favour with choices, the night a minute belongs to. No tree, no state.

const MOOD_CROSS := &"cross"
const MINUTES_PER_DAY := 1440
## A minute before 06:00 belongs to the night that began the evening before (W0-Notizen 10).
const MORNING_MINUTE := 360
const TEXT_NO_FAVOR := "-"
const TEXT_STORY := "Erst wenn ihr euch richtig kennt."
const TEXT_COOLDOWN := "Gerade erst. Frag in %d Tagen wieder."
const TEXT_COOLDOWN_ONE := "Gerade erst. Frag morgen wieder."
const TEXT_LOCKED := "Nach dem letzten Mal fragst du besser nicht so bald."
const TEXT_OWED := "Erst der Gegengefallen."
const TEXT_MOOD := "Heute nicht."
const TEXT_CHOICE := "Was genau?"


## "" = the favour can be asked now. ctx: done (steps), day, favor_day (0 = never), locked_until (0),
## owed (bool: a return favour is open), mood.
static func block_reason(favor: FavorData, ctx: Dictionary) -> String:
	if favor == null:
		return TEXT_NO_FAVOR
	if int(ctx.get("done", 0)) < FriendRules.STEPS:
		return TEXT_STORY
	var day := int(ctx.get("day", 0))
	if day < int(ctx.get("locked_until", 0)):
		return TEXT_LOCKED
	if bool(ctx.get("owed", false)):
		return TEXT_OWED
	var used := int(ctx.get("favor_day", 0))
	if used > 0 and day < used + favor.cooldown_days:
		var left := used + favor.cooldown_days - day
		return TEXT_COOLDOWN_ONE if left == 1 else TEXT_COOLDOWN % left
	if StringName(str(ctx.get("mood", ""))) == MOOD_CROSS:
		return TEXT_MOOD
	return ""


## The day the return favour is offered (the day after, §2.4).
static func offer_day(favor: FavorData, favor_day: int) -> int:
	return favor_day + maxi(0, favor.return_after_days)


## The morning the return favour lapses (3 days to do it).
static func deadline_day(favor: FavorData, offered_day: int) -> int:
	return offered_day + maxi(1, favor.return_days)


## One order of the pool, deterministic from (day, npc); `busy` (accepted order ids) are skipped
## where possible. &"" = empty pool.
static func pick_return(favor: FavorData, day: int, busy: Array = []) -> StringName:
	if favor == null or favor.return_orders.is_empty():
		return &""
	var pool: Array[StringName] = []
	for id: StringName in favor.return_orders:
		if not busy.has(id):
			pool.append(id)
	if pool.is_empty():
		return &""
	return pool[posmod(hash([day, String(favor.npc_id)]), pool.size())]


## The choice of a favour with choices (Esch: params.choices {iron_fittings: 3, steel_rod: 1,
## mortsafe_loan: 10}); &"" = the first in sorted order; an unknown choice → &"" with ok false.
static func choice(favor: FavorData, wanted: StringName) -> Dictionary:
	var raw: Variant = favor.params.get("choices") if favor != null else null
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return {"ok": true, "choice": wanted, "amount": 0}
	var keys: Array = (raw as Dictionary).keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	var pick: Variant = null
	if wanted == &"":
		pick = keys[0]
	else:
		for k: Variant in keys:
			if StringName(str(k)) == wanted:
				pick = k
	if pick == null:
		return {"ok": false, "choice": &"", "amount": 0}
	return {"ok": true, "choice": StringName(str(pick)), "amount": int((raw as Dictionary)[pick])}


## The night (its evening's day) a minute of `day` belongs to: before 06:00 → the day before.
static func night_of(day: int, minute: int) -> int:
	return day - 1 if minute < MORNING_MINUTE else day


## params.items {item: n} of a favour (Quast: 2 fever tinctures).
static func items(favor: FavorData) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	var raw: Variant = favor.params.get("items") if favor != null else null
	if raw is Dictionary:
		for key: Variant in raw:
			out[StringName(str(key))] = int((raw as Dictionary)[key])
	return out
