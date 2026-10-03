class_name DialogueConditions
extends RefCounted
## Condition interpreter of the dialogue mini-language (docs/VERTICAL_SLICE_DESIGN.md §3.4),
## used by DialogueRunner – the syntax is documented in dialogue_runner.gd. Reads GameState,
## TimeManager and the context inventory; changes nothing. Stateless.
## Phase 3 adds: day_gte:<n> (TimeManager.day >= n) · day_odd · day_even (odd-day deliveries
## at "Verrufen", docs/PHASE3_DESIGN.md §2.7).
## Phase 4 (docs/PHASE4_DESIGN.md §3.4): piety_tier:<id> (tier of stats.piety equals id, §2.7) ·
## trader_talks_gte:<n> (nights talked with Ilse, NightTrade) · clue_known:<id> (journal clue,
## flag clue_<id>) · flag_night:<name> (flag value == the current night, a night starts 12:00).
## stat_gte / stat_lt take negative numbers (piety).
## Phase 7 (docs/PHASE7_DESIGN.md §3.4, P6): rel_gte:<npc>:<n> (relationship value) · rel_tier:<npc>:<tier>
## (the relationship is on <tier> or higher) · met:<npc> · rep_tier:<tier> (reputation tier equals) ·
## order:<id>:<state> (none = no state) · order_offerable:<id> · shop_open:<shop> · region:<id> ·
## specimens_held_gte:<n> · specimen_sold_any · alive:<npc> (its Npc's hide_flag is off; oldwoman →
## hagedorn_dead) · lecture_tonight · village_open_days_gte:<n> (days since village_open_day) ·
## flag_days_gte:<flag>:<n> (the flag holds a day; at least n days since) · order_ready:<id> (accepted and
## its items in the context inventory) · village_can:<round|donate|consecrate> (Village's block reason is "")
## · mourning_today (a mourning ribbon hangs today).

enum _Result { FALSE, TRUE, INVALID }

## Phase 7: hide flags known without an Npc node in the world (§2.2: Wiebke Hagedorn after her death).
const HIDE_FLAGS := {&"oldwoman": &"hagedorn_dead"}


## True when every condition holds (an empty list holds).
static func all_met(conditions: Array[String], context: Dictionary) -> bool:
	for cond: String in conditions:
		if not check(cond, context):
			return false
	return true


static func check(cond: String, context: Dictionary) -> bool:
	var text := cond.strip_edges()
	var negate := false
	while text.begins_with("!"):
		negate = not negate
		text = text.substr(1).strip_edges()
	var result := _evaluate(text, context)
	if result == _Result.INVALID:
		push_warning("[DialogueRunner] invalid condition '%s' counts as false" % cond)
		return false
	return (result == _Result.TRUE) != negate


static func _evaluate(text: String, context: Dictionary) -> _Result:
	match DialogueSyntax.key(text):
		"has_item":
			var p := DialogueSyntax.parts(text, 2)
			var n: Variant = DialogueSyntax.int_arg(p, 1, 1)
			if p.is_empty() or p[0] == "" or n == null:
				return _Result.INVALID
			var inv := DialogueSyntax.inventory(context, &"has")
			if inv == null:
				return _Result.FALSE
			return _bool(inv.call(&"has", StringName(p[0]), int(n)))
		"flag":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(GameState.get_flag(StringName(p[0])))
		"stat_gte", "stat_lt":
			var p := DialogueSyntax.parts(text, 2)
			var n: Variant = DialogueSyntax.int_arg(p, 1, null)
			if p.is_empty() or p[0] == "" or n == null:
				return _Result.INVALID
			var value := GameState.get_stat(StringName(p[0]))
			return _bool(value >= int(n) if DialogueSyntax.key(text) == "stat_gte" else value < int(n))
		"time_between":
			var p := DialogueSyntax.parts(text, 2)
			var a: Variant = DialogueSyntax.int_arg(p, 0, null)
			var b: Variant = DialogueSyntax.int_arg(p, 1, null)
			if a == null or b == null:
				return _Result.INVALID
			return _bool(_in_window(TimeManager.minute_of_day, int(a), int(b)))
		"flag_eq":
			var p := DialogueSyntax.parts(text, 2)
			if p.size() < 2 or p[0] == "":
				return _Result.INVALID
			var flag := StringName(p[0])
			return _bool(GameState.has_flag(flag) and _value_matches(GameState.get_flag(flag), p[1]))
		"flag_today":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var value: Variant = GameState.get_flag(StringName(p[0]))
			return _bool((value is int or value is float) and float(value) == float(TimeManager.day))
		# Phase 3 (docs/PHASE3_DESIGN.md §1.3, §2.7): day of the game.
		"day_gte":
			var p := DialogueSyntax.parts(text, 1)
			var n: Variant = DialogueSyntax.int_arg(p, 0, null)
			if n == null:
				return _Result.INVALID
			return _bool(TimeManager.day >= int(n))
		"day_odd", "day_even":
			if text.contains(":"):
				return _Result.INVALID
			return _bool((TimeManager.day % 2 == 1) == (text == "day_odd"))
		# Phase 4 (docs/PHASE4_DESIGN.md §2.6, §2.7, §3.4).
		"piety_tier":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or not StringName(p[0]) in JournalRules.PIETY_TIERS:
				return _Result.INVALID
			return _bool(piety_tier() == StringName(p[0]))
		"trader_talks_gte":
			var p := DialogueSyntax.parts(text, 1)
			var n: Variant = DialogueSyntax.int_arg(p, 0, null)
			if n == null:
				return _Result.INVALID
			return _bool(trader_talks() >= int(n))
		"clue_known":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(GameState.get_flag(StringName(JournalManager.CLUE_FLAG_PREFIX + p[0])))
		"flag_night":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var value: Variant = GameState.get_flag(StringName(p[0]))
			return _bool((value is int or value is float) and int(value) == night_id())
		# Phase 7 (docs/PHASE7_DESIGN.md §3.4).
		"rel_gte":
			var p := DialogueSyntax.parts(text, 2)
			var n: Variant = DialogueSyntax.int_arg(p, 1, null)
			if p.is_empty() or p[0] == "" or n == null:
				return _Result.INVALID
			return _bool(rel_value(StringName(p[0])) >= int(n))
		"rel_tier":
			var p := DialogueSyntax.parts(text, 2)
			if p.size() < 2 or p[0] == "" or OrderRules.tier_index(StringName(p[1])) < 0:
				return _Result.INVALID
			return _bool(OrderRules.tier_index(rel_tier(StringName(p[0]))) >= OrderRules.tier_index(StringName(p[1])))
		"met":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var rel := DialogueSyntax.system(&"relationships")
			return _bool(rel != null and rel.has_method(&"met") and bool(rel.call(&"met", StringName(p[0]))))
		"rep_tier":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or not StringName(p[0]) in ReputationRules.TIERS:
				return _Result.INVALID
			return _bool(rep_tier() == StringName(p[0]))
		"order":
			var p := DialogueSyntax.parts(text, 2)
			if p.size() < 2 or p[0] == "":
				return _Result.INVALID
			var orders := DialogueSyntax.system(&"orders")
			var state: StringName = orders.call(&"state", StringName(p[0])) if orders != null and orders.has_method(&"state") else &""
			return _bool(String(state) == (p[1] if p[1] != "none" else ""))
		"order_offerable":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var orders := DialogueSyntax.system(&"orders")
			return _bool(orders != null and orders.has_method(&"block_reason") and str(orders.call(&"block_reason", StringName(p[0]))) == "")
		"order_ready":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(order_ready(StringName(p[0]), context))
		"shop_open":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			var shops := DialogueSyntax.system(&"village_shops")
			return _bool(shops != null and shops.has_method(&"is_open") and bool(shops.call(&"is_open", StringName(p[0]))))
		"region":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(RegionRoot.current(Engine.get_main_loop() as SceneTree) == StringName(p[0]))
		"specimens_held_gte":
			var p := DialogueSyntax.parts(text, 1)
			var n: Variant = DialogueSyntax.int_arg(p, 0, null)
			if n == null:
				return _Result.INVALID
			var specimens := DialogueSyntax.system(&"specimens")
			var held: Variant = specimens.call(&"held") if specimens != null and specimens.has_method(&"held") else PackedStringArray()
			return _bool((held as PackedStringArray).size() >= int(n) if held is PackedStringArray else false)
		"specimen_sold_any":
			if text.contains(":"):
				return _Result.INVALID
			return _bool(GameState.get_stat(&"specimens_sold") > 0)
		"alive":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(is_alive(StringName(p[0])))
		"lecture_tonight":
			if text.contains(":"):
				return _Result.INVALID
			var lectures := DialogueSyntax.system(&"lectures")
			return _bool(lectures != null and lectures.has_method(&"tonight") and bool(lectures.call(&"tonight")))
		"flag_days_gte":
			var p := DialogueSyntax.parts(text, 2)
			var n: Variant = DialogueSyntax.int_arg(p, 1, null)
			if p.size() < 2 or p[0] == "" or n == null:
				return _Result.INVALID
			var since: Variant = GameState.get_flag(StringName(p[0]))
			return _bool((since is int or since is float) and TimeManager.day - int(since) >= int(n))
		"village_can":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or not p[0] in ["round", "donate", "consecrate"]:
				return _Result.INVALID
			var village := DialogueSyntax.system(&"village")
			if village == null:
				return _Result.FALSE
			var method: StringName = {"round": &"round_block_reason", "donate": &"donation_block_reason", "consecrate": &"consecration_block_reason"}[p[0]]
			var inv: Variant = context.get("inventory")
			return _bool(village.has_method(method) and str(village.call(method, inv if inv is Inventory else null)) == "")
		"mourning_today":
			if text.contains(":"):
				return _Result.INVALID
			var village := DialogueSyntax.system(&"village")
			return _bool(village != null and village.has_method(&"mourning_house") and village.call(&"mourning_house", TimeManager.day) != &"")
		"village_open_days_gte":
			var p := DialogueSyntax.parts(text, 1)
			var n: Variant = DialogueSyntax.int_arg(p, 0, null)
			if n == null:
				return _Result.INVALID
			var since: Variant = GameState.get_flag(&"village_open_day")
			return _bool((since is int or since is float) and TimeManager.day - int(since) >= int(n))
	return _Result.INVALID


## Phase 7: the relationship value with `npc_id` (0 without Relationships).
static func rel_value(npc_id: StringName) -> int:
	var rel := DialogueSyntax.system(&"relationships")
	return int(rel.call(&"value", npc_id)) if rel != null and rel.has_method(&"value") else 0


## Phase 7: the relationship tier with `npc_id` (thresholds of data/config/relationship_config.tres).
static func rel_tier(npc_id: StringName) -> StringName:
	var cfg: RelationshipConfig = null
	if Database.has_method(&"config"):
		cfg = Database.config(&"relationship_config") as RelationshipConfig
	return OrderRules.rel_tier(rel_value(npc_id), cfg)


## Phase 7: the tier of GameState.stats.reputation.
static func rep_tier() -> StringName:
	var cfg: ReputationConfig = null
	if Database.has_method(&"config"):
		cfg = Database.config(&"reputation_config") as ReputationConfig
	return ReputationRules.tier(GameState.get_stat(&"reputation"), cfg)


## Phase 7: the order is accepted and its items are in the context inventory.
static func order_ready(order_id: StringName, context: Dictionary) -> bool:
	var orders := DialogueSyntax.system(&"orders")
	if orders == null or not orders.has_method(&"state") or orders.call(&"state", order_id) != &"accepted":
		return false
	var data: OrderData = orders.call(&"order_data", order_id) if orders.has_method(&"order_data") else null
	var inv: Variant = context.get("inventory")
	return data != null and inv is Inventory and OrderRules.deliver_ready(data, inv as Inventory)


## Phase 7: no Npc of `npc_id` hides behind its hide_flag (Wiebke Hagedorn: hagedorn_dead).
static func is_alive(npc_id: StringName) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		for node: Node in tree.get_nodes_in_group(&"npc"):
			if node.get(&"npc_id") == npc_id:
				var flag: Variant = node.get(&"hide_flag")
				if flag is StringName and flag != &"" and GameState.flag_on(flag):
					return false
	return not (HIDE_FLAGS.has(npc_id) and GameState.flag_on(HIDE_FLAGS[npc_id]))


## Tier of GameState.stats.piety (§2.7 thresholds from data/config/piety_config.tres).
static func piety_tier() -> StringName:
	var cfg: PietyConfig = null
	if Database.has_method(&"config"):
		cfg = Database.config(&"piety_config") as PietyConfig
	return JournalRules.piety_tier(GameState.get_stat(&"piety"), cfg)


## Nights talked with Ilse (NightTrade state "talks"); 0 without the system.
static func trader_talks() -> int:
	var trade := DialogueSyntax.system(&"night_trade")
	if trade == null or not trade.has_method(&"save_state"):
		return 0
	var state: Variant = trade.call(&"save_state")
	var talks: Variant = (state as Dictionary).get("talks", 0) if state is Dictionary else 0
	return int(talks) if (talks is int or talks is float) else 0


## The current night (GhostManager.night_index: a night starts at 12:00).
static func night_id() -> int:
	return GhostManager.night_index(TimeManager.day, TimeManager.minute_of_day)


## a <= t < b; a > b wraps over midnight; a == b is an empty window.
static func _in_window(t: int, a: int, b: int) -> bool:
	if a <= b:
		return t >= a and t < b
	return t >= a or t < b


## Compares a stored flag value with its text form from the data.
static func _value_matches(value: Variant, text: String) -> bool:
	match typeof(value):
		TYPE_BOOL:
			var lower := text.to_lower()
			return (lower == "true" and value) or (lower == "false" and not value)
		TYPE_INT:
			if text.is_valid_int():
				return int(value) == text.to_int()
			return text.is_valid_float() and is_equal_approx(float(value), text.to_float())
		TYPE_FLOAT:
			return text.is_valid_float() and is_equal_approx(float(value), text.to_float())
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value) == text
	return str(value) == text


static func _bool(value: Variant) -> _Result:
	return _Result.TRUE if value else _Result.FALSE
