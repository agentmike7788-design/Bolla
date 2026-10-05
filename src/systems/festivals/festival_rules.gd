class_name FestivalRules
extends RefCounted
## Pure festival rules (docs/PHASE8_DESIGN.md §2.7, §3.2.1): the effective day (calendar_day; shift_rule
## open_plus moves a festival that would fall before p8_open_day + shift_days onto that day – once;
## shift_rule none drops a festival before p8_open_day), the window, the presence (≥ 30 minutes), the dance
## partners (≥ „Bekannt", at most 2), the guests of a minute, lights_all / lights_some at 18:00.
## No tree, no state.

const RESULT_ALL := &"all"
const RESULT_SOME := &"some"
const RESULT_NONE := &"none"
const TEXT_NO_DANCE := "Heute wird nicht getanzt."
const TEXT_NOT_IN_ROOM := "Getanzt wird in der Gaststube."
const TEXT_NOT_HERE := "%s ist gerade nicht da."
const TEXT_TIER := "Dafür kennt ihr euch zu wenig."
const TEXT_DANCED := "Mit %s hast du schon getanzt."
const TEXT_PARTNERS := "Zwei Tänze sind genug für einen Totengräber."


## The day `fest` takes place with Phase 8 open since `open_day` (−1 = it falls out). §2.7.1: Kathrein
## before p8_open_day is dropped; §2.7.2: the Lichtgang before p8_open_day + 3 moves there.
static func effective_day(fest: FestivalData, open_day: int) -> int:
	if fest == null or open_day <= 0:
		return -1
	if fest.shift_rule == FestivalData.SHIFT_OPEN_PLUS:
		return maxi(fest.calendar_day, open_day + maxi(0, fest.shift_days))
	return fest.calendar_day if fest.calendar_day >= open_day else -1


## The festival was shifted (its day differs from the calendar).
static func shifted(fest: FestivalData, day: int) -> bool:
	return fest != null and day > 0 and day != fest.calendar_day


## `minute` lies in the festival window [from, to).
static func in_window(fest: FestivalData, minute: int) -> bool:
	return fest != null and minute >= fest.window.x and minute < fest.window.y


## Guests present at `minute` (effects.guests {npc: [from, to]}), sorted.
static func guests_at(fest: FestivalData, minute: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var raw: Variant = fest.effects.get("guests") if fest != null else null
	if raw is Dictionary:
		for key: Variant in raw:
			var w: Variant = (raw as Dictionary)[key]
			if w is Array and w.size() >= 2 and minute >= int(w[0]) and minute < int(w[1]):
				out.append(StringName(str(key)))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## Presence: at least effects.presence_minutes (30) since `since_total` (−1 = not there).
static func presence_reached(fest: FestivalData, since_total: int, now_total: int) -> bool:
	if fest == null or since_total < 0:
		return false
	return now_total - since_total >= int(fest.effects.get("presence_minutes", 30))


## "" = the dance with `npc_id` is possible. ctx: running (bool), in_room (bool), present (bool),
## tier_ok (bool), danced (Array), name (String).
static func dance_block_reason(fest: FestivalData, npc_id: StringName, ctx: Dictionary) -> String:
	if fest == null or not bool(ctx.get("running", false)):
		return TEXT_NO_DANCE
	if not bool(ctx.get("in_room", false)):
		return TEXT_NOT_IN_ROOM
	var name := str(ctx.get("name", String(npc_id)))
	if not bool(ctx.get("present", false)):
		return TEXT_NOT_HERE % name
	var danced: Array = ctx.get("danced", [])
	if danced.has(npc_id) or danced.has(String(npc_id)):
		return TEXT_DANCED % name
	if danced.size() >= int(fest.effects.get("dance_partners", 2)):
		return TEXT_PARTNERS
	if not bool(ctx.get("tier_ok", false)):
		return TEXT_TIER
	return ""


## 18:00 (§2.7.2): a light on every occupied grave → all; at least `share` of them → some; else none.
static func lights_result(lit: int, occupied: int, fest: FestivalData) -> StringName:
	if occupied <= 0:
		return RESULT_NONE
	if lit >= occupied:
		return RESULT_ALL
	var some: Variant = fest.effects.get("lights_some", {}) if fest != null else {}
	var share := float((some as Dictionary).get("share", 0.5)) if some is Dictionary else 0.5
	return RESULT_SOME if float(lit) >= float(occupied) * share else RESULT_NONE


## An effects sub-dictionary (lights_all, lights_some, early_ghosts …) or {}.
static func effect(fest: FestivalData, key: String) -> Dictionary:
	var raw: Variant = fest.effects.get(key) if fest != null else null
	return raw if raw is Dictionary else {}
