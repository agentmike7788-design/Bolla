class_name DialogueActions
extends RefCounted
## Action interpreter of the dialogue mini-language (docs/VERTICAL_SLICE_DESIGN.md §3.4),
## used by DialogueRunner – the syntax is documented in dialogue_runner.gd. Changes GameState
## flags / stats and the context inventory, emits notifications. Stateless.

const NOTIFY_INFO := &"info"
const NOTIFY_REWARD := &"reward"
const NOTIFY_WARNING := &"warning"
## "+2 Leinen"
const REWARD_FORMAT := "+%d %s"
const NO_ROOM_FORMAT := "Kein Platz für %d %s"


## Applies every action in order.
static func run_all(actions: Array[String], context: Dictionary) -> void:
	for action: String in actions:
		apply(action, context)


static func apply(action: String, context: Dictionary) -> void:
	var text := action.strip_edges()
	match DialogueSyntax.key(text):
		"set_flag":
			var p := DialogueSyntax.parts(text, 2)
			if not DialogueSyntax.has_name(p, text):
				return
			GameState.set_flag(StringName(p[0]), DialogueSyntax.parse_value(p[1]) if p.size() > 1 else true)
		"clear_flag":
			var p := DialogueSyntax.parts(text, 1)
			if DialogueSyntax.has_name(p, text):
				GameState.clear_flag(StringName(p[0]))
		"take_item":
			_take_item(text, context)
		"give_item":
			_give_item(text, context)
		"stat_add":
			var p := DialogueSyntax.parts(text, 2)
			if not DialogueSyntax.has_name(p, text):
				return
			var n: Variant = DialogueSyntax.int_arg(p, 1, null)
			if n == null:
				push_warning("[DialogueRunner] '%s': expected stat_add:<name>:<n>" % text)
				return
			GameState.add_stat(StringName(p[0]), int(n))
		"notify":
			var p := DialogueSyntax.parts(text, 1)
			if p.is_empty() or p[0] == "":
				push_warning("[DialogueRunner] '%s': empty notification" % text)
				return
			EventBus.notification_requested.emit(p[0], NOTIFY_INFO)
		_:
			push_warning("[DialogueRunner] unknown action '%s' ignored" % action)


# --- item actions ---

static func _take_item(text: String, context: Dictionary) -> void:
	var p := DialogueSyntax.parts(text, 2)
	var n: Variant = _item_amount(p, text)
	if n == null or int(n) == 0:
		return
	var inv := DialogueSyntax.inventory(context, &"remove_item")
	if inv == null:
		return
	if not DialogueSyntax.truthy(inv.call(&"remove_item", StringName(p[0]), int(n))):
		push_warning("[DialogueRunner] '%s': not enough items, nothing taken" % text)


static func _give_item(text: String, context: Dictionary) -> void:
	var p := DialogueSyntax.parts(text, 2)
	var n: Variant = _item_amount(p, text)
	if n == null or int(n) == 0:
		return
	var inv := DialogueSyntax.inventory(context, &"add_item")
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
	var n: Variant = DialogueSyntax.int_arg(p, 1, 1)
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
