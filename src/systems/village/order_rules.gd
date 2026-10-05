class_name OrderRules
extends RefCounted
## Pure order rules (docs/PHASE7_DESIGN.md §2.5, §3.4): offer conditions, the burial result
## (&"done" | &"wait" | &"broken"), the stone match, a delivery ready, the deterministic board pick.
## Stateless; reads nothing but its arguments – except the grave's section (Graveyard in the running
## tree, group graveyard) and specimen records (Specimens, group specimens) where an order needs them.
##
## offer_block_reason(order, state, rel_tier, active, cfg) – `state` is the offer context Orders builds:
##   state      StringName  the order's current state (&"" | offered | accepted | completed | failed)
##   completed  Array       ids of completed orders (requires_orders)
##   board      Array       today's board offers (board orders are offerable only while on the board)
##   giver_started  int     orders of this giver already accepted / completed / failed (a „Fremd" giver
##                          offers only the first one, §2.4)
##   teachings  Array       known teachings (condition `teaching`, W0-Notizen 12)
##   standing   int         university standing (condition `standing`)
##   flags      Dictionary  optional – flags to test requires_flag against (else GameState)
## Condition keys read here (W0-Notizen 12): dress, service, prepared, unharvested, section, stone_shape,
## ornament, gilded, inscription (bury / stone), substitutes (deliver), teaching, standing (offer),
## organ, min_clarity (specimen deliveries), mornings (tend, Orders). chapel_level is checked by Orders
## (the chapel's level is no part of the record).

const RESULT_DONE := &"done"
const RESULT_WAIT := &"wait"
const RESULT_BROKEN := &"broken"
const TEXT_MAX_ACTIVE := "Vier Aufträge laufen schon."
const TEXT_MAX_FRIEND := "Zwei Bitten von Freunden laufen schon."
const TEXT_ACCEPTED := "Schon angenommen."
const TEXT_COMPLETED := "Schon erledigt."
const TEXT_FAILED := "Dafür ist es zu spät."
const TEXT_NOT_YET := "Noch nicht."
const TEXT_NOT_ON_BOARD := "Heute nicht an der Tafel."
const TEXT_NEEDS_ORDER := "Erst: %s"
const TEXT_NEEDS_TIER := "Erst „%s“"
const TEXT_STRANGER := "Erst „Bekannt“ – einem Fremden traut man nur eine Bitte zu."
const TEXT_NEEDS_TEACHING := "Dir fehlt das Wissen dafür."
const TEXT_NEEDS_STANDING := "Dafür reicht dein Ansehen bei der Universität noch nicht."
const TIERS: Array[StringName] = RelationshipRules.TIERS
const TIER_WORDS: Array[String] = RelationshipRules.WORDS
const SPECIMEN_ITEMS: Array[StringName] = [&"specimen_jar", &"specimen_bundle", &"display_specimen", &"bone_specimen"]
const COIN_ITEM := &"coin"
const NEXT_DELIVERY := "next_delivery"


## "" = the order may be offered / accepted now; else the reason (§2.5 order: state · flag · board ·
## predecessors · tier · stranger rule · teaching · standing · four active).
static func offer_block_reason(order: OrderData, state: Dictionary, rel_tier: StringName, active: int, cfg: OrdersConfig) -> String:
	if order == null:
		return TEXT_NOT_YET
	if order.category == OrderData.CATEGORY_FRIEND:
		return friend_block_reason(order, state, active, cfg)
	match StringName(str(state.get("state", ""))):
		&"accepted":
			return TEXT_ACCEPTED
		&"completed":
			if not order.board:
				return TEXT_COMPLETED
		&"failed":
			if not order.board:
				return TEXT_FAILED
	if order.requires_flag != &"" and not _flag(order.requires_flag, state):
		return TEXT_NOT_YET
	if order.board and not _list(state, "board").has(order.id):
		return TEXT_NOT_ON_BOARD
	var completed := _list(state, "completed")
	for dep: StringName in order.requires_orders:
		if not completed.has(dep):
			var dep_data := Database.order_data(dep) as OrderData if Database.has_method(&"order_data") else null
			return TEXT_NEEDS_ORDER % (dep_data.title if dep_data != null and dep_data.title != "" else String(dep))
	if not order.board:
		if order.requires_tier != &"" and tier_index(rel_tier) < tier_index(order.requires_tier):
			return TEXT_NEEDS_TIER % tier_word(order.requires_tier)
		if rel_tier == TIERS[0] and int(state.get("giver_started", 0)) > 0:
			return TEXT_STRANGER
	var teaching := StringName(str(order.conditions.get("teaching", "")))
	if teaching != &"" and not _list(state, "teachings").has(teaching):
		return TEXT_NEEDS_TEACHING
	if order.conditions.has("standing") and int(state.get("standing", 0)) < int(order.conditions.standing):
		return TEXT_NEEDS_STANDING
	var limit := cfg.max_active if cfg != null else OrdersConfig.new().max_active
	if active >= limit:
		return TEXT_MAX_ACTIVE
	return ""


## Phase 8 (docs/PHASE8_DESIGN.md §2.4): a friend order (story step / return favour) – the Friendship
## checks thresholds, mood and gaps; here only: not while it runs, its flag, at most max_active_friend
## friend orders at once (`active` counts the friend orders only). A completed / failed one may run again
## (a return favour of a later favour).
static func friend_block_reason(order: OrderData, state: Dictionary, active: int, cfg: OrdersConfig) -> String:
	if StringName(str(state.get("state", ""))) == &"accepted":
		return TEXT_ACCEPTED
	if order.requires_flag != &"" and not _flag(order.requires_flag, state):
		return TEXT_NOT_YET
	var limit := cfg.max_active_friend if cfg != null else OrdersConfig.new().max_active_friend
	if active >= limit:
		return TEXT_MAX_FRIEND
	return ""


## Phase 8: items the giver hands over on acceptance (conditions.gives {item: n}); with `key`
## "reward_items" the present on completion.
static func gives(order: OrderData, field: String = "gives") -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	var raw: Variant = order.conditions.get(field) if order != null else null
	if raw is Dictionary:
		for key: Variant in raw:
			var n := int((raw as Dictionary)[key]) if ((raw as Dictionary)[key] is int or (raw as Dictionary)[key] is float) else 0
			if n > 0:
				out[StringName(str(key))] = n
	return out


## Phase 8: by_minute – a delivery only up to that minute of the day (Quast's crate by 07:40).
static func time_ok(order: OrderData, minute: int) -> bool:
	if order == null or not order.conditions.has("by_minute"):
		return true
	return minute <= int(order.conditions.by_minute)


## Phase 8: or_items – the alternative set of a delivery (Fenner: {dropsy_powder: 1}).
static func or_items(order: OrderData) -> Dictionary:
	var raw: Variant = order.conditions.get("or_items") if order != null else null
	var out := {}
	if raw is Dictionary:
		for key: Variant in raw:
			out[StringName(str(key))] = int((raw as Dictionary)[key])
	return out


## Every item of `items` (with the substitutes / matching specimens of `order`) is in `inv`.
static func items_ready(order: OrderData, items: Dictionary, inv: Inventory) -> bool:
	if items.is_empty():
		return false
	for item: Variant in items:
		if available(order, StringName(str(item)), inv) < int(items[item]):
			return false
	return true


## Phase 8 meet: `npc_id` at `place_id` inside the window [from, to] (conditions npc, place, window).
static func meet_matches(order: OrderData, npc_id: StringName, place_id: StringName, minute: int) -> bool:
	if order == null or order.kind != &"meet":
		return false
	var c := order.conditions
	if c.has("npc") and StringName(str(c.npc)) != npc_id:
		return false
	if c.has("place") and StringName(str(c.place)) != place_id:
		return false
	return in_window(c.get("window"), minute)


static func meet_times(order: OrderData) -> int:
	return maxi(1, int(order.conditions.get("times", 1)))


## Phase 8 task: the action id (conditions.action_id).
static func task_action(order: OrderData) -> StringName:
	return StringName(str(order.conditions.get("action_id", ""))) if order != null else &""


## Phase 8 task: `action_id` is this order's and the minute lies in its window (none = any time).
static func task_matches(order: OrderData, action_id: StringName, minute: int) -> bool:
	if order == null or order.kind != &"task" or task_action(order) != action_id:
		return false
	return in_window(order.conditions.get("window"), minute)


## [from, to] (Array / Vector2i) contains `minute`; anything else = no window.
static func in_window(window: Variant, minute: int) -> bool:
	if window is Vector2i:
		return minute >= (window as Vector2i).x and minute <= (window as Vector2i).y
	if (window is Array or window is PackedInt32Array) and window.size() >= 2:
		return minute >= int(window[0]) and minute <= int(window[1])
	return true


## W0-Notizen 12: the specimen record `spec` fits a specimen delivery of `order` (organ / min_clarity
## at harvest – the repair of saves where the handover left the record „held").
static func specimen_fits(order: OrderData, spec: SpecimenRecord) -> bool:
	if order == null or spec == null:
		return false
	var raw: Variant = order.conditions.get("organ")
	if raw is Array and not raw.is_empty() and not (raw.has(String(spec.organ)) or raw.has(spec.organ)):
		return false
	return true


## Burial conditions of a bury order on `record` in `grave` (null = not buried yet): a violation that
## cannot heal any more (harvested, wrong section, wrong dress / no service / not prepared once buried)
## → broken; a missing grave marker or a stone that does not match yet → wait; all met on a MARKED
## grave → done. The target (story id / next delivery) is matched by the caller.
static func bury_result(order: OrderData, record: CorpseRecord, grave: GraveRecord) -> StringName:
	if order == null or record == null:
		return RESULT_WAIT
	var c := order.conditions
	if _truthy(c.get("unharvested")) and not record.harvested.is_empty():
		return RESULT_BROKEN
	var buried := grave != null and (grave.state == GraveRecord.State.FILLED or grave.state == GraveRecord.State.MARKED)
	if not buried:
		return RESULT_WAIT
	var section := StringName(str(c.get("section", "")))
	if section != &"" and section_of(grave.id) != section:
		return RESULT_BROKEN
	var dress := StringName(str(c.get("dress", "")))
	if dress != &"" and not dress_matches(record.dress, dress):
		return RESULT_BROKEN
	if _truthy(c.get("service")) and not record.service_held:
		return RESULT_BROKEN
	if _truthy(c.get("prepared")) and not record.is_fully_prepared():
		return RESULT_BROKEN
	if grave.state != GraveRecord.State.MARKED:
		return RESULT_WAIT
	if not design_matches(c, grave):
		return RESULT_WAIT
	return RESULT_DONE


## A stone order: `grave` is the target and carries a designed stone with the conditions.
static func stone_matches(order: OrderData, grave: GraveRecord) -> bool:
	if order == null or grave == null or grave.design.is_empty():
		return false
	if order.target != "" and order.target != grave.id:
		return false
	return design_matches(order.conditions, grave)


## Every item (deliver) / item + coin (donate) is in `inv`. substitutes {item: alternative} counts the
## alternative too (o_rosine_tincture: bitter drops for the tincture). Specimen items with organ /
## min_clarity conditions count only matching held specimens (Specimens in the running tree).
static func deliver_ready(order: OrderData, inv: Inventory) -> bool:
	if order == null or inv == null:
		return false
	var main_ok := true
	for item: StringName in order.items:
		if available(order, item, inv) < int(order.items[item]):
			main_ok = false
	if not main_ok and not items_ready(order, or_items(order), inv):
		return false
	if order.kind == &"donate" and order.coins > 0 and inv.count(COIN_ITEM) < order.coins:
		return false
	return true


## How many pieces of `item` (with its substitute, or the matching specimens) count for `order`.
static func available(order: OrderData, item: StringName, inv: Inventory) -> int:
	if item in SPECIMEN_ITEMS:
		return matching_specimens(order, item, inv).size()
	var n := inv.count(item)
	var sub := substitute(order, item)
	if sub != &"":
		n += inv.count(sub)
	return n


## The substitute of `item` (&"" = none).
static func substitute(order: OrderData, item: StringName) -> StringName:
	var subs: Variant = order.conditions.get("substitutes")
	if subs is Dictionary:
		for key: Variant in subs:
			if StringName(str(key)) == item:
				return StringName(str((subs as Dictionary)[key]))
	return &""


## uids of `item` in `inv` whose specimen record fits the order's organ / min_clarity conditions
## (newest first, like Inventory.remove_item). Without a Specimens node only the condition-free
## items count (by uid).
static func matching_specimens(order: OrderData, item: StringName, inv: Inventory) -> PackedStringArray:
	var out := PackedStringArray()
	var organs: Array = []
	var raw: Variant = order.conditions.get("organ")
	if raw is Array:
		organs = raw
	elif raw != null and str(raw) != "":
		organs = [str(raw)]
	var min_clarity := float(order.conditions.get("min_clarity", 0.0))
	var specimens := _system(&"specimens")
	var uids := inv.uids(item)
	for i: int in range(uids.size() - 1, -1, -1):
		var uid := uids[i]
		if organs.is_empty() and min_clarity <= 0.0:
			out.append(uid)
			continue
		if specimens == null or not specimens.has_method(&"get_record"):
			continue
		var spec := specimens.call(&"get_record", uid) as SpecimenRecord
		if spec == null:
			continue
		if not organs.is_empty() and not (organs.has(String(spec.organ)) or organs.has(spec.organ)):
			continue
		if min_clarity > 0.0:
			var cfg := Database.config(&"anatomy_config") as AnatomyConfig
			if SpecimenRules.clarity(spec, TimeManager.total_minutes(), cfg) + 1e-6 < min_clarity:
				continue
		out.append(uid)
	return out


## Deterministic from the day: up to `n` ids of `pool` (board orders the caller found eligible:
## flag set, not active), none twice, none within its cooldown_days after it ended (`history`
## {id: day completed / failed}). Ranked by a hash of (day, id).
static func board_pick(pool: Array[OrderData], day: int, history: Dictionary, n: int) -> Array[StringName]:
	var ranked: Array = []
	var seen := {}
	for o: OrderData in pool:
		if o == null or seen.has(o.id):
			continue
		seen[o.id] = true
		var ended: Variant = history.get(o.id, history.get(String(o.id)))
		if ended != null and (ended is int or ended is float) and day - int(ended) < o.cooldown_days:
			continue
		ranked.append([hash([day, String(o.id)]), String(o.id)])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array[StringName] = []
	for entry: Array in ranked:
		if out.size() >= n:
			break
		out.append(StringName(entry[1]))
	return out


# --- helpers ----------------------------------------------------------------------------------

## Stone conditions (stone_shape, ornament, gilded, inscription) against grave.design ({} = none set →
## true only without stone conditions).
static func design_matches(c: Dictionary, grave: GraveRecord) -> bool:
	var needs_stone := c.has("stone_shape") or c.has("ornament") or c.has("gilded") or c.has("inscription")
	if not needs_stone:
		return true
	if grave == null or grave.design.is_empty():
		return false
	var d := StoneDesign.from_dict(grave.design)
	var shape := StringName(str(c.get("stone_shape", "")))
	if shape != &"" and d.shape != shape:
		return false
	var ornament := StringName(str(c.get("ornament", "")))
	if ornament != &"" and d.ornament != ornament:
		return false
	if _truthy(c.get("gilded")) and not d.gilded:
		return false
	if _truthy(c.get("inscription")) and d.inscription == &"":
		return false
	return true


## A burial gown is also a shroud (more, not less); a gown order needs the gown.
static func dress_matches(dress: StringName, wanted: StringName) -> bool:
	if wanted == &"shroud":
		return dress == &"shroud" or dress == &"gown"
	return dress == wanted


## Section of `grave_id` from the Graveyard in the running tree (&"" without one).
static func section_of(grave_id: String) -> StringName:
	var graveyard := _system(&"graveyard")
	if graveyard != null and graveyard.has_method(&"section_of"):
		return StringName(str(graveyard.call(&"section_of", grave_id)))
	return &""


## Index of a relationship tier (−1 = unknown / &"") – RelationshipRules (QA7: one source for tiers).
static func tier_index(t: StringName) -> int:
	return RelationshipRules.tier_index(t)


static func tier_word(t: StringName) -> String:
	var w := RelationshipRules.word(t)
	return w if w != "" else String(t)


## Relationship tier of a value = RelationshipRules.tier (QA7: P2 was a stub when this was written;
## a malformed threshold list now falls back to the default 15/40/70 there, as everywhere else).
static func rel_tier(value: int, cfg: RelationshipConfig) -> StringName:
	return RelationshipRules.tier(value, cfg)


static func _flag(flag: StringName, state: Dictionary) -> bool:
	var flags: Variant = state.get("flags")
	if flags is Dictionary:
		var v: Variant = (flags as Dictionary).get(flag, (flags as Dictionary).get(String(flag)))
		return _truthy(v)
	return GameState.flag_on(flag)


static func _list(state: Dictionary, key: String) -> Array:
	var raw: Variant = state.get(key, [])
	var out: Array = []
	if raw is Array or raw is PackedStringArray:
		for v: Variant in raw:
			out.append(StringName(str(v)))
	return out


static func _truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v) != "" and str(v).to_lower() != "false"
	return false


static func _system(group: StringName) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group(group) if tree != null else null
