class_name HillRules
extends RefCounted
## Pure rules of the requests of the gate's notice board (G8 Runde 6 „Bitten vom Hügel",
## docs/PHASE8_DESIGN.md G8 Runde 6 §1–§2): places and limits before / after village_open, the offer
## conditions, the deterministic pick, deadlines, the completion checks and the reward words. Stateless:
## reads nothing but its arguments and static data (Database).
##
## offer_block(request, ctx) – `ctx` is the context HillRequests builds:
##   day          int         today
##   village      bool        village_open (the village rules: one place, longer cooldown)
##   on_board     Array       ids on the board now (offered or accepted)
##   givers       Array       givers of the requests on the board
##   ended        Dictionary  id → day the request last ended (completed / failed / taken down)
##   levels       Dictionary  care spot id → level
##   dirty_graves Array       grave ids whose own care spot (dirt_<grave>) is at least at level 1
##   free_plots   int         EMPTY / DUG plots (another corpse can come)
##   marked       int         MARKED graves (a ghost can walk)
##   items        Array       item ids the player owns (requires_item)
##   open_obstacles Dictionary section id → uncleared obstacles of a workable (unlocked or open) section

const KIND_DELIVER := &"deliver"
const KIND_TEND := &"tend"
const KIND_EXAM := &"exam"
const KIND_PREP := &"prep"
const KIND_MARKER := &"marker"
const KIND_GHOST := &"ghost"
const KIND_CLEAR := &"clear"
const KIND_DECOR := &"decor"
const KINDS: Array[StringName] = [KIND_DELIVER, KIND_TEND, KIND_EXAM, KIND_PREP, KIND_MARKER, KIND_GHOST, KIND_CLEAR, KIND_DECOR]
## Kinds that need a corpse still to come (a free plot).
const CORPSE_KINDS: Array[StringName] = [KIND_EXAM, KIND_PREP, KIND_MARKER]
const PHASE_EARLY := &"early"
const PHASE_VILLAGE := &"village"
## conditions.grave: a MARKED grave whose own care spot is dirty, chosen when the request is pinned.
const GRAVE_MARKED_DIRTY := "marked_dirty"
const GRAVE_SPOT_PREFIX := "dirt_"
const CARTER := &"carter"
const COIN_ITEM := &"coin"
## Reason of payments / reputation changes (the reward card of a grave ignores them).
const REASON_PREFIX := "Bitte: "
const REASON := "Bitte: %s"
const REASON_FAILED := "Bitte versäumt: %s"

const TEXT_ACCEPTED := "Schon angenommen."
const TEXT_NOT_ON_BOARD := "Hängt nicht am Tor."
const TEXT_MAX_ACTIVE_ONE := "Eine Bitte läuft schon."
const TEXT_MAX_ACTIVE := "%d Bitten laufen schon."


# --- places and limits ------------------------------------------------------------------------------

static func slots(cfg: HillRequestsConfig, village: bool) -> int:
	return maxi(0, cfg.slots_village if village else cfg.slots_early)


static func max_active(cfg: HillRequestsConfig, village: bool) -> int:
	return maxi(0, cfg.max_active_village if village else cfg.max_active_early)


static func refill_days(cfg: HillRequestsConfig, village: bool) -> int:
	return maxi(0, cfg.refill_days_village if village else cfg.refill_days_early)


## "" = `request` may be accepted with `active` accepted requests; else the reason.
static func accept_block(state: StringName, active: int, cfg: HillRequestsConfig, village: bool) -> String:
	if state == &"accepted":
		return TEXT_ACCEPTED
	if state != &"offered":
		return TEXT_NOT_ON_BOARD
	var cap := max_active(cfg, village)
	if active >= cap:
		return TEXT_MAX_ACTIVE_ONE if cap <= 1 else TEXT_MAX_ACTIVE % cap
	return ""


# --- offer ------------------------------------------------------------------------------------------

## "" = `request` may be pinned now (see the class doc for `ctx`); else a short reason (for tests / debug).
static func offer_block(request: OrderData, ctx: Dictionary) -> String:
	if request == null or request.category != OrderData.CATEGORY_HILL:
		return "no request"
	if not request.kind in KINDS:
		return "unknown kind"
	var day := int(ctx.get("day", 0))
	if day < int(request.conditions.get("min_day", 0)):
		return "too early"
	var phase := StringName(str(request.conditions.get("phase", "")))
	var village := bool(ctx.get("village", false))
	if phase == PHASE_EARLY and village:
		return "early only"
	if phase == PHASE_VILLAGE and not village:
		return "village only"
	if request.requires_flag != &"" and not GameState.flag_on(request.requires_flag):
		return "flag"
	if (ctx.get("on_board", []) as Array).has(request.id):
		return "on board"
	if (ctx.get("givers", []) as Array).has(request.giver):
		return "giver on board"
	var ended: Dictionary = ctx.get("ended", {})
	if ended.has(request.id) and day < int(ended[request.id]) + maxi(1, request.cooldown_days):
		return "cooldown"
	var need_item := StringName(str(request.conditions.get("requires_item", "")))
	if need_item != &"" and not (ctx.get("items", []) as Array).has(need_item):
		return "item"
	match request.kind:
		KIND_TEND:
			if str(request.conditions.get("grave", "")) == GRAVE_MARKED_DIRTY:
				if (ctx.get("dirty_graves", []) as Array).is_empty():
					return "no dirty grave"
			elif not any_dirty(spots_of(request), ctx.get("levels", {})):
				return "clean"
		KIND_EXAM, KIND_PREP, KIND_MARKER:
			if int(ctx.get("free_plots", 0)) <= 0:
				return "no plot"
		KIND_GHOST:
			if int(ctx.get("marked", 0)) <= 0:
				return "no ghost"
		KIND_CLEAR:
			var open: Dictionary = ctx.get("open_obstacles", {})
			var any := false
			for s: String in sections_of(request):
				if int(open.get(StringName(s), 0)) > 0:
					any = true
			if not any:
				return "nothing to clear"
	return ""


## The request for place `slot` on `day`: the offerable one with the lowest hash([day, slot, id]) –
## deterministic, no global random numbers. &"" = none offerable.
static func pick(pool: Array, ctx: Dictionary, slot: int) -> StringName:
	var best: StringName = &""
	var best_key := 0
	var day := int(ctx.get("day", 0))
	for raw: Variant in pool:
		var r := raw as OrderData
		if r == null or offer_block(r, ctx) != "":
			continue
		var key := hash([day, slot, String(r.id)])
		if best == &"" or key < best_key or (key == best_key and String(r.id) < String(best)):
			best = r.id
			best_key = key
	return best


## A dirty grave for conditions.grave marked_dirty: the one with the lowest hash([day, grave]).
static func pick_grave(graves: Array, day: int) -> String:
	var best := ""
	var best_key := 0
	for g: Variant in graves:
		var key := hash([day, str(g)])
		if best == "" or key < best_key:
			best = str(g)
			best_key = key
	return best


# --- deadlines --------------------------------------------------------------------------------------

## Morning the accepted request falls due (accepted on day D with a deadline of n days → the 06:00 check of
## day D + n; at least one day).
static func deadline_day(request: OrderData, accepted_day: int) -> int:
	return accepted_day + maxi(1, request.days_limit if request != null else 1)


## Days left counted like the orders (Phase7Texts.days_left): 1 = today is the last day.
static func days_left(deadline: int, day: int) -> int:
	return maxi(0, deadline - day)


# --- completion -------------------------------------------------------------------------------------

## The care spots a tend request means: conditions.spots, or the grave's own spot dirt_<grave>.
static func spots_of(request: OrderData, target_grave: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	if request == null:
		return out
	if target_grave != "":
		out.append(GRAVE_SPOT_PREFIX + target_grave)
		return out
	var raw: Variant = request.conditions.get("spots", [])
	if raw is Array or raw is PackedStringArray:
		for s: Variant in raw:
			out.append(str(s))
	return out


static func sections_of(request: OrderData) -> PackedStringArray:
	var out := PackedStringArray()
	var raw: Variant = request.conditions.get("sections", []) if request != null else []
	if raw is Array or raw is PackedStringArray:
		for s: Variant in raw:
			out.append(str(s))
	return out


static func any_dirty(spots: PackedStringArray, levels: Dictionary) -> bool:
	for s: String in spots:
		if int(levels.get(s, 0)) >= 1:
			return true
	return false


## tend: every spot at level 0 and at least one tended since the acceptance.
static func tend_done(spots: PackedStringArray, levels: Dictionary, touched: bool) -> bool:
	if spots.is_empty() or not touched:
		return false
	for s: String in spots:
		if int(levels.get(s, 0)) > 0:
			return false
	return true


## prep: the buried dead was washed / dressed / laid out as the request asks (washed and dressed by default).
static func prep_ok(request: OrderData, record: CorpseRecord) -> bool:
	if request == null or record == null:
		return false
	var c := request.conditions
	if bool(c.get("washed", true)) and not record.washed:
		return false
	if bool(c.get("dressed", true)) and not record.is_dressed():
		return false
	if bool(c.get("laid_out", false)) and not record.laid_out:
		return false
	return true


## marker: the grave carries the marker the request asks for (any marker when none is named).
static func marker_ok(request: OrderData, grave: GraveRecord) -> bool:
	if request == null or grave == null or grave.state != GraveRecord.State.MARKED:
		return false
	var want := StringName(str(request.conditions.get("marker", "")))
	return want == &"" or grave.marker_id == want


## decor: a placed decor the request names (any decor when none is named).
static func decor_ok(request: OrderData, decor_id: StringName) -> bool:
	if request == null:
		return false
	var raw: Variant = request.conditions.get("decor", [])
	if raw is Array and not (raw as Array).is_empty():
		return (raw as Array).has(String(decor_id)) or (raw as Array).has(decor_id)
	if raw is String or raw is StringName:
		return str(raw) == "" or StringName(str(raw)) == decor_id
	return true


static func clear_ok(request: OrderData, section_id: StringName) -> bool:
	return sections_of(request).has(String(section_id))


## deliver: the items are in `inv`.
static func deliver_ready(request: OrderData, inv: Inventory) -> bool:
	if request == null or inv == null or request.kind != KIND_DELIVER or request.items.is_empty():
		return false
	for item: StringName in request.items:
		if inv.count(item) < int(request.items[item]):
			return false
	return true


## Who takes a delivery (recipient, else Osric).
static func recipient(request: OrderData) -> StringName:
	return request.recipient if request != null and request.recipient != &"" else CARTER


# --- reward and words ---------------------------------------------------------------------------------

## {item: n} of conditions.reward_items.
static func reward_items(request: OrderData) -> Dictionary[StringName, int]:
	return OrderRules.gives(request, "reward_items")


## „3 Münzen“, „Ruf +1“, „1× Leinen“.
static func reward_parts(request: OrderData) -> PackedStringArray:
	var out := PackedStringArray()
	if request == null:
		return out
	if request.reward_coins > 0:
		out.append("%d %s" % [request.reward_coins, "Münze" if request.reward_coins == 1 else "Münzen"])
	if request.reward_rep != 0:
		out.append("Ruf %s" % UIKit.signed(request.reward_rep))
	var items := reward_items(request)
	for item: StringName in items:
		out.append("%d× %s" % [items[item], UIKit.item_name(item)])
	return out


## The giver's name: a villager (VillagerData), Osric, a mourner (KinData) – else the id.
static func giver_name(giver: StringName) -> String:
	if giver == CARTER:
		return "Osric Faulhaber"
	var v: Resource = Database.villager(giver) if Database.has_method(&"villager") else null
	if v != null and str(v.get("display_name")) != "":
		return str(v.get("display_name"))
	var k: Resource = Database.kin(giver) if Database.has_method(&"kin") else null
	if k != null and str(k.get("display_name")) != "":
		return str(k.get("display_name"))
	return String(giver)


## `text` with its %s filled by `fill` (a text without %s stays as it is).
static func fill(text: String, value: String) -> String:
	return text % value if text.contains("%s") else text


# --- Phase 9: larger requests (STUB (P2) – docs/PHASE9_DESIGN.md §2.3.2, §3.4; W1 (P2) fills the bodies) --------

## Is `part` (a part of a large request, kinds HillRules.KINDS + OrderData.PART_KINDS) done by `event` with `args`?
static func part_done(_part: OrderData, _event: StringName, _args: Dictionary, _state: Dictionary) -> bool:
	return false


## Every part of `o` can be solved now (the offer conditions per part, §2.3.2).
static func large_offerable(_o: OrderData, _context: Dictionary) -> bool:
	return false
