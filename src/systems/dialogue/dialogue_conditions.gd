class_name DialogueConditions
extends RefCounted
## Condition interpreter of the dialogue mini-language (docs/VERTICAL_SLICE_DESIGN.md §3.4),
## used by DialogueRunner – the syntax is documented in dialogue_runner.gd. Reads GameState,
## TimeManager and the context inventory; changes nothing. Stateless.

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
	return _Result.INVALID


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
