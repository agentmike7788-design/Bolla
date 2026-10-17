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


# --- Phase 9: larger requests (docs/PHASE9_DESIGN.md §2.3, §3.4) -----------------------------------------------
#
# A larger request is an OrderData with size large, kind &"large" and 2–4 parts (OrderData, kinds KINDS +
# OrderData.PART_KINDS). It hangs at the gate (place gate) or – from village_open – at the parish board (place
# village); one is accepted at a time, its parts count in any order unless parts_in_order is set, and at the
# deadline half of the parts done is half the coins (no reputation), less is a missed one (large_fail_rep).
#
# part_done(part, event, args, state) – `event` (EV_*) with its `args`:
#   EV_CRAFT     {recipe, station, amount}       CraftingSystem → EventBus.craft_finished
#   EV_GATHER    {item, amount}                  the item came into the player's inventory (piles, felling, quarry,
#                                                clearing – ResourceNode piles send no resource_gathered)
#   EV_GHOST     {grave, section, night_graves}  ghost_spoke; night_graves = distinct graves heard this night (incl.)
#   EV_VISIT     {place}                         the TimedAction of a visit part finished at its place
#   EV_MEET      {npc, place, minute}            the gravekeeper spoke to npc at place
#   EV_DEVOTION  {grave}                         devotion_held in the chapel
#   EV_FLOWERS   {grave}                         grave_care_changed(grave, flowers, true)
#   EV_CHECK     {}                              re-check of tend parts (dirt_changed, part opened, targets set)
#   EV_EXAM      {corpse, full}                  exam_step_done of a fully examined corpse
#   EV_BURIED    {corpse, grave, record}         corpse_buried
#   EV_MARKER    {grave, record}                 grave_completed (record: GraveRecord)
#   EV_CLEAR     {section}                       obstacle_cleared
#   EV_DECOR     {decor, section, near}          decor_changed (placed); near = place ids within NEAR_RADIUS
#   EV_DELIVER   {recipient}                     the items handed over (turn_in at the recipient)
# `state` – the part's own state in HillRequests: progress (int, before this event), targets (PackedStringArray:
# tend → care spots, flowers → graves still without flowers), assigned (bool: targets are known), corpse / grave
# (the dead of an exam → prep → marker chain), levels (care spot → level).
#
# large_offer_block(request, ctx) – the context of HillRequests.large_offer_context: everything of offer_block plus
#   large_on_board Array       large ids on both boards
#   large_ended    Dictionary  id → day the large request last ended
#   givers         Array       givers of every request on both boards (small and large)
#   marked_by_section Dictionary section id → MARKED graves
#   stations       Array       stations that can craft now (workbench + the built workyard stations)
#   gather_items   Array       items that can be gathered now (wood / stone piles, open gather nodes)
#   node_items     Array       items of the open gather nodes (they regrow: any amount)
#   pile_daily     Dictionary  item → what the piles give each morning (res_wood / res_stone)
#   clear_yields   Dictionary  item → what clearing the open obstacles of the workable sections still yields
#   places         Array       known waypoint ids (visit)
#   chapel         bool        a devotion can be held (chapel built)
#   kin_graves     Dictionary  kin id → graves it mourns at (flowers / meet at kin_grave)

const KIND_LARGE := &"large"
const KIND_CRAFT := &"craft"
const KIND_GATHER := &"gather"
const KIND_GHOSTS := &"ghosts"
const KIND_VISIT := &"visit"
const KIND_MEET := &"meet"
const KIND_DEVOTION := &"devotion"
const KIND_FLOWERS := &"flowers"
const EV_CRAFT := &"craft_finished"
const EV_GATHER := &"gathered"
const EV_GHOST := &"ghost_spoke"
const EV_VISIT := &"visit"
const EV_MEET := &"meet"
const EV_DEVOTION := &"devotion_held"
const EV_FLOWERS := &"flowers"
const EV_CHECK := &"check"
const EV_EXAM := &"exam"
const EV_BURIED := &"buried"
const EV_MARKER := &"grave_completed"
const EV_CLEAR := &"obstacle_cleared"
const EV_DECOR := &"decor_placed"
const EV_DELIVER := &"delivered"
## conditions.grave of a tend part: the two graves beside the request's dead (exam → prep chain) / the graves whose
## ghosts spoke in the night of the ghosts part.
const GRAVE_NEIGHBORS := "neighbors"
const GRAVE_GHOSTS_TONIGHT := "ghosts_tonight"
## meet: the place „at the grave of the giver's family“.
const PLACE_KIN_GRAVE := &"kin_grave"
const STATION_WORKBENCH := &"workbench"
const ITEM_RAKE := &"rake"
## Items the piles of the cemetery give from day 1 (ResourceNode res_wood / res_stone).
const PILE_ITEMS: Array[StringName] = [&"wood", &"stone"]

const TEXT_LARGE_ACTIVE := "Eine große Bitte läuft schon."
const TEXT_LARGE_NOT_AT_GATE := "Hängt nicht am Tor."
const TEXT_LARGE_NOT_AT_BOARD := "Hängt nicht an der Gemeindetafel."
const TEXT_SAME_GIVER := "Für %s läuft schon eine Bitte."
## „Die Gräber der Fähre: 2 von 3“
const TEXT_PART_DONE := "%s: %d von %d"
const TEXT_POSTED_GATE := "Osric hat einen großen Bogen ans Tor geheftet: „%s“."
const TEXT_POSTED_ALSO := "… und einen großen Bogen: „%s“."
const TEXT_POSTED_VILLAGE := "An der Gemeindetafel hängt ein großer Bogen: „%s“."
const TEXT_DONE := "Große Bitte erfüllt: %s – %s"
const TEXT_HALF := "Zur Hälfte erfüllt: %s – %s"
const TEXT_HALF_PLAIN := "Zur Hälfte erfüllt: %s"
## The thanks of a half done one – no reproach (§2.3.2).
const TEXT_HALF_THANKS := "%s lässt ausrichten: „Was du geschafft hast, hat geholfen. Den Rest machen wir selbst.“"
const TEXT_FAILED_GATE := "Zu spät: %s. Der große Bogen hängt nicht mehr am Tor."
const TEXT_FAILED_VILLAGE := "Zu spät: %s. Der große Bogen hängt nicht mehr an der Gemeindetafel."
const TEXT_REWARD_THANKS := "Die Gemeinde wird es dir danken."
const TEXT_REWARD_THANKS_ONE := "Die Gemeinde wird es dir danken."
const REASON_HALF := "Bitte zur Hälfte: %s"
## Visit parts (visit_block_reason).
const TEXT_VISIT_NOT_RUNNING := "Diese Bitte läuft nicht."
const TEXT_VISIT_NONE := "Für diese Bitte ist hier nichts zu tun."
const TEXT_VISIT_FIRST := "Erst die anderen Teile der Bitte."
const TEXT_VISIT_HERE := "Nicht hier."
const TEXT_VISIT_WINDOW := "Erst zwischen %s und %s."
const TEXT_VISIT_BUSY := "Gerade nicht möglich."
## HUD: „Bitte: Die Gräber der Fähre – Zwei Zierstücke im Alten Hof (1/2)“
const TEXT_OBJECTIVE := "Bitte: %s – %s"
const TEXT_OBJECTIVE_COUNT := "Bitte: %s – %s (%d/%d)"
const TEXT_WAITING_GATE := "Eine große Bitte am Tor wartet"
const TEXT_WAITING_VILLAGE := "Eine große Bitte an der Gemeindetafel wartet"


## Every part kind a larger request may hold (G8 Runde 6 kinds + the Phase-9 ones).
static func part_kinds() -> Array[StringName]:
	var out: Array[StringName] = KINDS.duplicate()
	out.append_array(OrderData.PART_KINDS)
	return out


static func is_large(request: OrderData) -> bool:
	return request != null and request.size == OrderData.SIZE_LARGE


## The parts of `request` as OrderData (non-OrderData entries become null and count as never done).
static func parts_of(request: OrderData) -> Array[OrderData]:
	var out: Array[OrderData] = []
	if request == null:
		return out
	for p: Resource in request.parts:
		out.append(p as OrderData)
	return out


## Large places, limits and refill (§2.3.2).
static func large_slots(cfg: HillRequestsConfig, place: StringName, village: bool) -> int:
	if place == OrderData.PLACE_VILLAGE:
		return maxi(0, cfg.large_slots_village) if village else 0
	return maxi(0, cfg.large_slots_gate)


static func large_refill_days(cfg: HillRequestsConfig, village: bool) -> int:
	return maxi(0, cfg.large_refill_days_village if village else cfg.large_refill_days_early)


## "" = the offered large request may be accepted; else the reason. `busy_giver`: another accepted request (small or
## large) has the same giver.
static func large_accept_block(state: StringName, place: StringName, active_large: int, cfg: HillRequestsConfig,
		busy_giver: String = "") -> String:
	if state == &"accepted":
		return TEXT_ACCEPTED
	if state != &"offered":
		return TEXT_LARGE_NOT_AT_BOARD if place == OrderData.PLACE_VILLAGE else TEXT_LARGE_NOT_AT_GATE
	if active_large >= maxi(0, cfg.large_max_active):
		return TEXT_LARGE_ACTIVE
	if busy_giver != "":
		return TEXT_SAME_GIVER % busy_giver
	return ""


## Every part of `o` can be solved now (§2.3.2) and the request itself may hang now (day, place, flag, cooldown,
## giver, not on a board) – see large_offer_block.
static func large_offerable(o: OrderData, context: Dictionary) -> bool:
	return large_offer_block(o, context) == ""


## "" = the large request may be pinned now; else a short reason (tests / debug).
static func large_offer_block(o: OrderData, ctx: Dictionary) -> String:
	if o == null or o.category != OrderData.CATEGORY_HILL or o.size != OrderData.SIZE_LARGE:
		return "no large request"
	var parts := parts_of(o)
	if parts.size() < 2:
		return "no parts"
	var day := int(ctx.get("day", 0))
	if day < int(o.conditions.get("min_day", 0)):
		return "too early"
	if o.place == OrderData.PLACE_VILLAGE and not bool(ctx.get("village", false)):
		return "village only"
	if o.requires_flag != &"" and not GameState.flag_on(o.requires_flag):
		return "flag"
	if (ctx.get("large_on_board", []) as Array).has(o.id):
		return "on board"
	if (ctx.get("givers", []) as Array).has(o.giver):
		return "giver on board"
	var ended: Dictionary = ctx.get("large_ended", {})
	if ended.has(o.id) and day < int(ended[o.id]) + maxi(1, o.cooldown_days):
		return "cooldown"
	for i: int in parts.size():
		var reason := part_offer_block(parts[i], o, ctx)
		if reason != "":
			return "part %d: %s" % [i + 1, reason]
	return ""


## "" = `part` of `request` can be solved with what the world holds now; else the reason.
static func part_offer_block(part: OrderData, request: OrderData, ctx: Dictionary) -> String:
	if part == null:
		return "no part"
	if not part.kind in part_kinds():
		return "unknown kind"
	var c := part.conditions
	var need_item := StringName(str(c.get("requires_item", "")))
	if need_item != &"" and not (ctx.get("items", []) as Array).has(need_item):
		return "item"
	match part.kind:
		KIND_TEND:
			var grave := str(c.get("grave", ""))
			if grave == GRAVE_NEIGHBORS:
				if int(ctx.get("free_plots", 0)) <= 0:
					return "no plot"
			elif grave == GRAVE_GHOSTS_TONIGHT:
				if int(ctx.get("marked", 0)) <= 0:
					return "no ghost"
			elif grave == GRAVE_MARKED_DIRTY:
				if (ctx.get("dirty_graves", []) as Array).is_empty():
					return "no dirty grave"
			elif not any_dirty(spots_of(part), ctx.get("levels", {})):
				return "clean"
		KIND_EXAM, KIND_PREP, KIND_MARKER:
			if int(ctx.get("free_plots", 0)) <= 0:
				return "no plot"
		KIND_GHOST:
			if _marked_for(part, ctx) <= 0:
				return "no ghost"
		KIND_GHOSTS:
			if _marked_for(part, ctx) < need(part):
				return "too few ghosts"
		KIND_CLEAR:
			var open: Dictionary = ctx.get("open_obstacles", {})
			var any := false
			for s: String in sections_of(part):
				if int(open.get(StringName(s), 0)) > 0:
					any = true
			if not any:
				return "nothing to clear"
		KIND_CRAFT:
			var recipe := Database.recipe(recipe_of(part)) as RecipeData
			if recipe == null:
				return "no recipe"
			if recipe.station != STATION_WORKBENCH and not (ctx.get("stations", []) as Array).has(recipe.station):
				return "station"
		KIND_GATHER:
			var item := StringName(str(c.get("item", "")))
			var from_clearing := int((ctx.get("clear_yields", {}) as Dictionary).get(item, 0))
			if (ctx.get("node_items", []) as Array).has(item):
				return ""
			if not (ctx.get("gather_items", PILE_ITEMS) as Array).has(item) and from_clearing <= 0:
				return "cannot gather"
			# The piles refill every morning before the deadline; the rest has to come from clearing („roden").
			if ctx.has("pile_daily"):
				var mornings := maxi(0, (request.days_limit if request != null else 1) - 1)
				var from_piles := int((ctx.get("pile_daily", {}) as Dictionary).get(item, 0)) * mornings
				if from_piles + from_clearing < need(part):
					return "not enough to gather"
		KIND_VISIT:
			if ctx.has("places") and not (ctx.get("places", []) as Array).has(StringName(str(c.get("place", "")))):
				return "no place"
		KIND_DEVOTION:
			if not bool(ctx.get("chapel", false)):
				return "no chapel"
		KIND_FLOWERS:
			if (ctx.get("kin_graves", {}) as Dictionary).get(flowers_kin(part, request), []).is_empty():
				return "no graves"
		KIND_MEET:
			if StringName(str(c.get("place", ""))) == PLACE_KIN_GRAVE:
				var kin := StringName(str(c.get("npc", "")))
				if (ctx.get("kin_graves", {}) as Dictionary).get(kin, []).is_empty():
					return "no grave"
	return ""


## The large request for `place` on `day`: the offerable one of that place with the lowest hash([day, place, id]).
static func large_pick(pool: Array, ctx: Dictionary, place: StringName) -> StringName:
	var best: StringName = &""
	var best_key := 0
	var day := int(ctx.get("day", 0))
	for raw: Variant in pool:
		var r := raw as OrderData
		if r == null or r.place != place or large_offer_block(r, ctx) != "":
			continue
		var key := hash([day, String(place), String(r.id)])
		if best == &"" or key < best_key or (key == best_key and String(r.id) < String(best)):
			best = r.id
			best_key = key
	return best


# --- parts ------------------------------------------------------------------------------------------

## The amount a counting part needs (craft / gather / decor amount, ghosts times; 1 for the others).
static func need(part: OrderData) -> int:
	if part == null:
		return 1
	match part.kind:
		KIND_GHOSTS:
			return maxi(1, int(part.conditions.get("times", 1)))
		KIND_CRAFT, KIND_GATHER, KIND_DECOR:
			return maxi(1, int(part.conditions.get("amount", 1)))
	return 1


static func recipe_of(part: OrderData) -> StringName:
	return StringName(str(part.conditions.get("recipe", ""))) if part != null else &""


## Whose graves a flowers part means: conditions.graves (a kin id), else the request's giver.
static func flowers_kin(part: OrderData, request: OrderData) -> StringName:
	var kin := StringName(str(part.conditions.get("graves", ""))) if part != null else &""
	return kin if kin != &"" else (request.giver if request != null else &"")


## The open parts of a large request: every part not done – or only the first one with parts_in_order.
static func open_parts(request: OrderData, done: Array[bool]) -> Array[int]:
	var out: Array[int] = []
	var n := request.parts.size() if request != null else 0
	for i: int in n:
		if i < done.size() and done[i]:
			continue
		out.append(i)
		if request.parts_in_order:
			break
	return out


static func done_count(done: Array[bool]) -> int:
	var n := 0
	for d: bool in done:
		if d:
			n += 1
	return n


## At least `ratio` of the parts are done (but not all – that one is completed).
static func half_reached(done: Array[bool], ratio: float) -> bool:
	var n := done.size()
	var k := done_count(done)
	return n > 0 and k < n and float(k) >= float(n) * ratio - 0.0001


## Half the coins (rounded down) of a half done one.
static func half_coins(request: OrderData) -> int:
	return floori(float(request.reward_coins) / 2.0) if request != null else 0


## How much `event` adds to a counting part (craft amount, gather amount, one decor piece, one grave with flowers);
## 0 = nothing for this part.
static func part_gain(part: OrderData, event: StringName, args: Dictionary, state: Dictionary) -> int:
	if part == null:
		return 0
	var c := part.conditions
	match part.kind:
		KIND_CRAFT:
			if event == EV_CRAFT and StringName(str(args.get("recipe", ""))) == recipe_of(part):
				return maxi(0, int(args.get("amount", 1)))
		KIND_GATHER:
			if event == EV_GATHER and StringName(str(args.get("item", ""))) == StringName(str(c.get("item", ""))):
				return maxi(0, int(args.get("amount", 0)))
		KIND_DECOR:
			if event == EV_DECOR and decor_ok(part, StringName(str(args.get("decor", "")))) and _decor_place_ok(part, args):
				return 1
		KIND_FLOWERS:
			if event == EV_FLOWERS and _targets(state).has(str(args.get("grave", ""))):
				return 1
	return 0


## Is `part` done by `event` with `args` (its own `state` before the event)? See the section doc.
static func part_done(part: OrderData, event: StringName, args: Dictionary, state: Dictionary) -> bool:
	if part == null:
		return false
	var c := part.conditions
	var progress := int(state.get("progress", 0))
	match part.kind:
		KIND_CRAFT, KIND_GATHER, KIND_DECOR:
			var gain := part_gain(part, event, args, state)
			return gain > 0 and progress + gain >= need(part)
		KIND_FLOWERS:
			if event != EV_FLOWERS:
				return false
			var left := _targets(state)
			var grave := str(args.get("grave", ""))
			return left.has(grave) and left.size() == 1
		KIND_GHOSTS:
			if event != EV_GHOST or not _section_ok(part, args):
				return false
			return (args.get("night_graves", []) as Array).size() >= need(part)
		KIND_GHOST:
			if event != EV_GHOST or not _section_ok(part, args):
				return false
			var graves := _targets(state)
			return not bool(state.get("assigned", false)) or graves.is_empty() or graves.has(str(args.get("grave", "")))
		KIND_VISIT:
			return event == EV_VISIT and StringName(str(args.get("place", ""))) == StringName(str(c.get("place", "")))
		KIND_MEET:
			if event != EV_MEET:
				return false
			var meet := {"npc": c.get("npc", ""), "place": c.get("place", ""), "window": c.get("window")}
			var o := OrderData.new()
			o.kind = &"meet"
			o.conditions = meet
			return OrderRules.meet_matches(o, StringName(str(args.get("npc", ""))), StringName(str(args.get("place", ""))),
					int(args.get("minute", 0)))
		KIND_DEVOTION:
			return event == EV_DEVOTION
		KIND_TEND:
			if event != EV_CHECK:
				return false
			if bool(state.get("assigned", true)) and _targets(state).is_empty():
				return true
			var spots := _targets(state)
			if spots.is_empty():
				return false
			var levels: Dictionary = state.get("levels", {})
			for s: String in spots:
				if int(levels.get(s, 0)) > 0:
					return false
			return true
		KIND_EXAM:
			return event == EV_EXAM and bool(args.get("full", false))
		KIND_PREP:
			if event != EV_BURIED:
				return false
			var corpse := str(state.get("corpse", ""))
			return (corpse == "" or corpse == str(args.get("corpse", ""))) and prep_ok(part, args.get("record") as CorpseRecord)
		KIND_MARKER:
			if event != EV_MARKER:
				return false
			var grave := args.get("record") as GraveRecord
			var want := str(state.get("grave", ""))
			return marker_ok(part, grave) and (want == "" or (grave != null and grave.id == want))
		KIND_CLEAR:
			return event == EV_CLEAR and clear_ok(part, StringName(str(args.get("section", ""))))
		KIND_DELIVER:
			return event == EV_DELIVER and StringName(str(args.get("recipient", ""))) == recipient(part)
	return false


## A visit part's window [from, to] in minutes of the day (none = any time).
static func visit_window(part: OrderData) -> Vector2i:
	var w: Variant = part.conditions.get("window") if part != null else null
	if (w is Array or w is PackedInt32Array) and (w as Array).size() >= 2:
		return Vector2i(int(w[0]), int(w[1]))
	return Vector2i(-1, -1)


static func visit_minutes(part: OrderData) -> int:
	return maxi(1, int(part.conditions.get("minutes", 20))) if part != null else 20


## The prompt of a visit part („[E] Steine abladen (20 Min)“).
static func visit_prompt(part: OrderData) -> String:
	if part == null:
		return ""
	var label := str(part.conditions.get("label", ""))
	return label if label != "" else "[E] %s (%d Min)" % [part.title, visit_minutes(part)]


## The TimedAction label of a visit part: the prompt without „[E] “ and the minutes.
static func visit_action_label(part: OrderData) -> String:
	var text := visit_prompt(part).trim_prefix("[E] ")
	var cut := text.rfind(" (")
	return text.substr(0, cut) if cut > 0 else text


## „4 Münzen · 2× Altarkerze“ (no reputation number on the card, §2.3.4).
static func large_reward_line(request: OrderData) -> String:
	var parts := PackedStringArray()
	if request == null:
		return TEXT_REWARD_THANKS
	if request.reward_coins > 0:
		parts.append("%d %s" % [request.reward_coins, "Münze" if request.reward_coins == 1 else "Münzen"])
	var items := reward_items(request)
	for item: StringName in items:
		parts.append("%d× %s" % [items[item], UIKit.item_name(item)])
	if parts.is_empty():
		return TEXT_REWARD_THANKS
	return "%s %s." % [TEXT_REWARD_THANKS, " · ".join(parts)]


## {kin: n} of conditions.reward_goodwill.
static func reward_goodwill(request: OrderData) -> Dictionary[StringName, int]:
	return OrderRules.gives(request, "reward_goodwill")


static func _targets(state: Dictionary) -> PackedStringArray:
	var raw: Variant = state.get("targets", PackedStringArray())
	if raw is PackedStringArray:
		return raw
	var out := PackedStringArray()
	if raw is Array:
		for v: Variant in raw:
			out.append(str(v))
	return out


static func _section_ok(part: OrderData, args: Dictionary) -> bool:
	var want := str(part.conditions.get("section", ""))
	return want == "" or str(args.get("section", "")) == want


static func _decor_place_ok(part: OrderData, args: Dictionary) -> bool:
	var want := str(part.conditions.get("section", ""))
	if want != "" and str(args.get("section", "")) != want:
		return false
	var near := str(part.conditions.get("near", ""))
	return near == "" or (args.get("near", []) as Array).has(near) or (args.get("near", []) as Array).has(StringName(near))


static func _marked_for(part: OrderData, ctx: Dictionary) -> int:
	var section := str(part.conditions.get("section", ""))
	if section == "":
		return int(ctx.get("marked", 0))
	return int((ctx.get("marked_by_section", {}) as Dictionary).get(StringName(section), 0))
