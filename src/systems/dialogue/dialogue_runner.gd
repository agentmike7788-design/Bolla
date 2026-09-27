class_name DialogueRunner
extends RefCounted
## Runs a DialogueData (conditions/actions mini-language, docs/VERTICAL_SLICE_DESIGN.md §3.4).
## Entering a node runs its actions; a node whose conditions fail is skipped to its
## fallback_next (chains allowed, a cycle ends the dialogue). choose() takes an index into
## available_choices(). The runner never emits dialogue_ended – the dialogue UI does.
##
## Conditions (a node/choice needs all of them):
##   has_item:<id>:<n> · flag:<name> · !flag:<name> · stat_gte:<name>:<n> · stat_lt:<name>:<n>
##   time_between:<a>:<b> (minute of day, a <= t < b, wraps over midnight when a > b)
##   flag_eq:<name>:<value> · flag_today:<name> (flag value == TimeManager.day)
##   A leading "!" negates any valid condition (an invalid one stays false).
## Actions:
##   set_flag:<name>[:<value>] · clear_flag:<name> · take_item:<id>:<n> · give_item:<id>:<n>
##   stat_add:<name>:<n> · notify:<text> (text may contain colons)
## <n> may be omitted for item conditions/actions (= 1). Values are parsed as bool, int,
## float or String. Unknown or malformed entries warn and count as false / do nothing.
## context: {inventory: Inventory (duck-typed: has/add_item/remove_item), speaker: Node}.

const NOTIFY_INFO := &"info"
const NOTIFY_REWARD := &"reward"
const NOTIFY_WARNING := &"warning"
## "+2 Leinen"
const REWARD_FORMAT := "+%d %s"
const NO_ROOM_FORMAT := "Kein Platz für %d %s"

enum _Result { FALSE, TRUE, INVALID }

var _data: DialogueData
var _context: Dictionary = {}
var _current: DialogueNode


## Starts `data` at data.start_node (skipping nodes whose conditions fail).
func start(data: DialogueData, context: Dictionary) -> void:
	_data = data
	_context = context
	_current = null
	if data == null:
		push_warning("[DialogueRunner] start() without dialogue data")
		return
	_enter(data.start_node)


## The node shown right now; null before start() and after the end.
func current_node() -> DialogueNode:
	return _current


func current_text() -> String:
	return _current.text if _current != null else ""


## Choices of the current node whose conditions all hold (evaluated now).
func available_choices() -> Array[DialogueChoice]:
	var out: Array[DialogueChoice] = []
	if _current == null:
		return out
	for choice: DialogueChoice in _current.choices:
		if choice != null and _conditions_met(choice.conditions, _context):
			out.append(choice)
	return out


## Picks available_choices()[index]: runs its actions, then enters `next` (&"" ends).
func choose(index: int) -> void:
	if _current == null:
		push_warning("[DialogueRunner] choose(%d) without a running dialogue" % index)
		return
	var choices := available_choices()
	if index < 0 or index >= choices.size():
		push_warning("[DialogueRunner] choose(%d): only %d choice(s) available" % [index, choices.size()])
		return
	var choice := choices[index]
	_run_actions(choice.actions, _context)
	_enter(choice.next)


## True before start(), after the last choice and when no node could be entered.
func is_finished() -> bool:
	return _current == null


static func check_condition(cond: String, context: Dictionary) -> bool:
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


static func apply_action(action: String, context: Dictionary) -> void:
	var text := action.strip_edges()
	match _key(text):
		"set_flag":
			var p := _parts(text, 2)
			if not _has_name(p, text):
				return
			GameState.set_flag(StringName(p[0]), _parse_value(p[1]) if p.size() > 1 else true)
		"clear_flag":
			var p := _parts(text, 1)
			if _has_name(p, text):
				GameState.clear_flag(StringName(p[0]))
		"take_item":
			_take_item(text, context)
		"give_item":
			_give_item(text, context)
		"stat_add":
			var p := _parts(text, 2)
			if not _has_name(p, text):
				return
			var n: Variant = _int_arg(p, 1, null)
			if n == null:
				push_warning("[DialogueRunner] '%s': expected stat_add:<name>:<n>" % text)
				return
			GameState.add_stat(StringName(p[0]), int(n))
		"notify":
			var p := _parts(text, 1)
			if p.is_empty() or p[0] == "":
				push_warning("[DialogueRunner] '%s': empty notification" % text)
				return
			EventBus.notification_requested.emit(p[0], NOTIFY_INFO)
		_:
			push_warning("[DialogueRunner] unknown action '%s' ignored" % action)


# --- runner internals ---

## Enters node_id, following fallback_next while conditions fail. Ends on &"", an
## unknown id or a cycle (every node at most once per resolution).
func _enter(node_id: StringName) -> void:
	_current = null
	var visited: Dictionary[StringName, bool] = {}
	var id := node_id
	while id != &"":
		if visited.has(id):
			push_warning("[DialogueRunner] %s: fallback cycle at '%s' ends the dialogue" % [_data.id, id])
			return
		visited[id] = true
		var node := _data.get_node_by_id(id)
		if node == null:
			push_warning("[DialogueRunner] %s: unknown node '%s' ends the dialogue" % [_data.id, id])
			return
		if _conditions_met(node.conditions, _context):
			_current = node
			_run_actions(node.actions, _context)
			return
		id = node.fallback_next


static func _conditions_met(conditions: Array[String], context: Dictionary) -> bool:
	for cond: String in conditions:
		if not check_condition(cond, context):
			return false
	return true


static func _run_actions(actions: Array[String], context: Dictionary) -> void:
	for action: String in actions:
		apply_action(action, context)


# --- conditions ---

static func _evaluate(text: String, context: Dictionary) -> _Result:
	match _key(text):
		"has_item":
			var p := _parts(text, 2)
			var n: Variant = _int_arg(p, 1, 1)
			if p.is_empty() or p[0] == "" or n == null:
				return _Result.INVALID
			var inv := _inventory(context, &"has")
			if inv == null:
				return _Result.FALSE
			return _bool(inv.call(&"has", StringName(p[0]), int(n)))
		"flag":
			var p := _parts(text, 1)
			if p.is_empty() or p[0] == "":
				return _Result.INVALID
			return _bool(GameState.get_flag(StringName(p[0])))
		"stat_gte", "stat_lt":
			var p := _parts(text, 2)
			var n: Variant = _int_arg(p, 1, null)
			if p.is_empty() or p[0] == "" or n == null:
				return _Result.INVALID
			var value := GameState.get_stat(StringName(p[0]))
			return _bool(value >= int(n) if _key(text) == "stat_gte" else value < int(n))
		"time_between":
			var p := _parts(text, 2)
			var a: Variant = _int_arg(p, 0, null)
			var b: Variant = _int_arg(p, 1, null)
			if a == null or b == null:
				return _Result.INVALID
			return _bool(_in_window(TimeManager.minute_of_day, int(a), int(b)))
		"flag_eq":
			var p := _parts(text, 2)
			if p.size() < 2 or p[0] == "":
				return _Result.INVALID
			var flag := StringName(p[0])
			return _bool(GameState.has_flag(flag) and _value_matches(GameState.get_flag(flag), p[1]))
		"flag_today":
			var p := _parts(text, 1)
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


# --- item actions ---

static func _take_item(text: String, context: Dictionary) -> void:
	var p := _parts(text, 2)
	var n: Variant = _item_amount(p, text)
	if n == null or int(n) == 0:
		return
	var inv := _inventory(context, &"remove_item")
	if inv == null:
		return
	if not _truthy(inv.call(&"remove_item", StringName(p[0]), int(n))):
		push_warning("[DialogueRunner] '%s': not enough items, nothing taken" % text)


static func _give_item(text: String, context: Dictionary) -> void:
	var p := _parts(text, 2)
	var n: Variant = _item_amount(p, text)
	if n == null or int(n) == 0:
		return
	var inv := _inventory(context, &"add_item")
	if inv == null:
		return
	var id := StringName(p[0])
	var rest_v: Variant = inv.call(&"add_item", id, int(n))
	var rest: int = clampi(int(rest_v), 0, int(n)) if (rest_v is int or rest_v is float) else 0
	var added: int = int(n) - rest
	if added > 0:
		EventBus.notification_requested.emit(REWARD_FORMAT % [added, _item_name(id)], NOTIFY_REWARD)
	if rest > 0:
		push_warning("[DialogueRunner] '%s': %d did not fit into the inventory" % [text, rest])
		EventBus.notification_requested.emit(NO_ROOM_FORMAT % [rest, _item_name(id)], NOTIFY_WARNING)


## Parsed, non-negative <n> of an item action (default 1), or null (with a warning).
static func _item_amount(p: PackedStringArray, text: String) -> Variant:
	var n: Variant = _int_arg(p, 1, 1)
	if p.is_empty() or p[0] == "" or n == null or int(n) < 0:
		push_warning("[DialogueRunner] '%s': expected <action>:<item_id>:<n> with n >= 0" % text)
		return null
	return n


## Database display name ("Leinen") when the item is registered, else the raw id.
static func _item_name(id: StringName) -> String:
	if Database.has_item(id):
		var item := Database.item(id) as ItemData
		if item != null and item.display_name != "":
			return item.display_name
	return String(id)


## context.inventory if it is a live object with `method` (Inventory or a test double).
static func _inventory(context: Dictionary, method: StringName) -> Object:
	var inv: Variant = context.get("inventory")
	if is_instance_valid(inv) and (inv as Object).has_method(method):
		return inv
	push_warning("[DialogueRunner] context has no inventory with %s()" % method)
	return null


# --- parsing helpers ---

## "key:a:b" → "key"
static func _key(text: String) -> String:
	return text.get_slice(":", 0).strip_edges()


## Arguments after the first colon, at most `max_parts` (the last keeps further colons).
static func _parts(text: String, max_parts: int) -> PackedStringArray:
	var sep := text.find(":")
	if sep < 0:
		return PackedStringArray()
	var rest := text.substr(sep + 1)
	# split() treats maxsplit 0 as "unlimited", so a single part is taken as is.
	var out: PackedStringArray = [rest] if max_parts <= 1 else rest.split(":", true, max_parts - 1)
	for i: int in out.size():
		out[i] = out[i].strip_edges()
	return out


## Integer argument `index`; `default` when it is missing, null when it is not an integer.
static func _int_arg(p: PackedStringArray, index: int, default: Variant) -> Variant:
	if index >= p.size():
		return default
	return p[index].to_int() if p[index].is_valid_int() else null


static func _has_name(p: PackedStringArray, text: String) -> bool:
	if p.is_empty() or p[0] == "":
		push_warning("[DialogueRunner] '%s': missing name" % text)
		return false
	return true


## "true"/"false" → bool, integers → int, decimals → float, anything else stays String.
static func _parse_value(text: String) -> Variant:
	var lower := text.to_lower()
	if lower == "true" or lower == "false":
		return lower == "true"
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return text


static func _truthy(value: Variant) -> bool:
	return true if value else false


static func _bool(value: Variant) -> _Result:
	return _Result.TRUE if value else _Result.FALSE
