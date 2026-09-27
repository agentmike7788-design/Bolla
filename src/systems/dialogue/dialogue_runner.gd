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
## The interpreter lives in DialogueConditions / DialogueActions (parsing: DialogueSyntax);
## this script is the runner state machine.

const NOTIFY_INFO := DialogueActions.NOTIFY_INFO
const NOTIFY_REWARD := DialogueActions.NOTIFY_REWARD
const NOTIFY_WARNING := DialogueActions.NOTIFY_WARNING
## "+2 Leinen"
const REWARD_FORMAT := DialogueActions.REWARD_FORMAT
const NO_ROOM_FORMAT := DialogueActions.NO_ROOM_FORMAT

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
	return DialogueConditions.check(cond, context)


static func apply_action(action: String, context: Dictionary) -> void:
	DialogueActions.apply(action, context)


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
	return DialogueConditions.all_met(conditions, context)


static func _run_actions(actions: Array[String], context: Dictionary) -> void:
	DialogueActions.run_all(actions, context)
