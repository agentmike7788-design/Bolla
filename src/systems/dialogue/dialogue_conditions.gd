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

enum _Result { FALSE, TRUE, INVALID }


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
	return _Result.INVALID


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
