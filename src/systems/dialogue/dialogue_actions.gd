class_name DialogueActions
extends RefCounted
## Action interpreter of the dialogue mini-language (docs/VERTICAL_SLICE_DESIGN.md §3.4),
## used by DialogueRunner – the syntax is documented in dialogue_runner.gd. Changes GameState
## flags / stats and the context inventory, emits notifications. Stateless.
## Phase 4 (docs/PHASE4_DESIGN.md §3.4): open_panel:<id> (ui_panel_requested with {speaker,
## inventory}) · open_trade (= open_panel:trader) · add_clue:<id> (JournalManager) · trader_tools
## (NightTrade.give_tools; success → flag trader_tools_given) · trader_talked (NightTrade.note_talk)
## · set_flag_night:<name> (flag = the current night, for flag_night:<name>).
## Phase 7 (docs/PHASE7_DESIGN.md §3.4, P6): meet:<npc> · talked:<npc> (Relationships.note_talk) ·
## open_shop:<shop> · open_gifts:<npc> · order_offer:<id> (Orders.offer + the order card) · order_accept:<id>
## · order_turn_in:<id> · buy_round · donate · consecrate_pay · anatomy_case (Quast: the case, his recipe
## book, the basic teachings, flag anatomy_known) · open_anatomist · open_lecture (only on a lecture night)
## · lecture_invite · rel_add:<npc>:<n> · set_flag_day:<name> (flag = TimeManager.day, for flag_days_gte). take_item:coin:<n> without a reason: a villager speaking → &"village".

const NOTIFY_INFO := &"info"
const NOTIFY_REWARD := &"reward"
const NOTIFY_WARNING := &"warning"
## "+2 Leinen"
const REWARD_FORMAT := "+%d %s"
const NO_ROOM_FORMAT := "Kein Platz für %d %s"
const TRADER_PANEL := &"trader"
## Set when Ilse's tools are in the inventory (or were handed over before).
const TOOLS_FLAG := &"trader_tools_given"
const JOURNAL_GROUP := &"journal"
const NIGHT_TRADE_GROUP := &"night_trade"
## Phase 5 §3.3: coin payments in dialogues (take_item:coin:<n>[:<reason>]).
const COIN_ITEM := &"coin"
const TRADER_NPC_ID := &"trader"
const REASON_OSRIC := &"osric"
const REASON_ILSE := &"ilse"
# Phase 7
const REASON_VILLAGE := &"village"
const VILLAGERS: Array[StringName] = [&"innkeeper", &"smith", &"grocer", &"priest", &"mayor", &"surgeon", &"washer", &"oldwoman"]
const SHOP_PANEL := &"shop"
const GIFT_PANEL := &"gift"
const ORDERS_PANEL := &"orders"
const ANATOMIST_PANEL := &"anatomist"
const LECTURE_PANEL := &"lecture"
const ANATOMY_FLAG := &"anatomy_known"
const RECIPES_FLAG := &"quast_recipes"
const INVITE_FLAG := &"lecture_invited"
const CASE_ITEM := &"anatomy_case"
const REASON_TALK := "Gespräch"


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
		# Phase 4 (docs/PHASE4_DESIGN.md §2.6, §2.12, §3.4).
		"open_panel":
			var p := DialogueSyntax.parts(text, 1)
			if DialogueSyntax.has_name(p, text):
				_open_panel(StringName(p[0]), context)
		"open_trade":
			_open_panel(TRADER_PANEL, context)
		"add_clue":
			var p := DialogueSyntax.parts(text, 1)
			if not DialogueSyntax.has_name(p, text):
				return
			var journal := DialogueSyntax.system(JOURNAL_GROUP)
			if journal == null or not journal.has_method(&"add_clue"):
				push_warning("[DialogueRunner] '%s': no journal" % text)
				return
			journal.call(&"add_clue", StringName(p[0]), "", false)
		"trader_tools":
			_trader_tools(context)
		"trader_talked":
			var trade := DialogueSyntax.system(NIGHT_TRADE_GROUP)
			if trade == null or not trade.has_method(&"note_talk"):
				push_warning("[DialogueRunner] trader_talked: no night trade")
				return
			trade.call(&"note_talk")
		"set_flag_night":
			var p := DialogueSyntax.parts(text, 1)
			if DialogueSyntax.has_name(p, text):
				GameState.set_flag(StringName(p[0]), DialogueConditions.night_id())
		# Phase 7 (docs/PHASE7_DESIGN.md §3.4).
		"meet", "talked":
			var p := DialogueSyntax.parts(text, 1)
			if DialogueSyntax.has_name(p, text):
				_call(&"relationships", &"meet" if DialogueSyntax.key(text) == "meet" else &"note_talk", [StringName(p[0])], text)
		"rel_add":
			var p := DialogueSyntax.parts(text, 2)
			var n: Variant = DialogueSyntax.int_arg(p, 1, null)
			if not DialogueSyntax.has_name(p, text) or n == null:
				return
			_call(&"relationships", &"add", [StringName(p[0]), int(n), REASON_TALK], text)
		"open_shop":
			var p := DialogueSyntax.parts(text, 1)
			if DialogueSyntax.has_name(p, text):
				_open_panel_with(SHOP_PANEL, context, {"shop_id": StringName(p[0])})
		"open_gifts":
			var p := DialogueSyntax.parts(text, 1)
			if DialogueSyntax.has_name(p, text):
				_open_panel_with(GIFT_PANEL, context, {"npc_id": StringName(p[0])})
		"order_offer":
			var p := DialogueSyntax.parts(text, 1)
			if DialogueSyntax.has_name(p, text):
				_call(&"orders", &"offer", [StringName(p[0])], text)
				_open_panel_with(ORDERS_PANEL, context, {"board": false, "orders": [StringName(p[0])] as Array[StringName]})
		"order_accept":
			var p := DialogueSyntax.parts(text, 1)
			if DialogueSyntax.has_name(p, text):
				_call(&"orders", &"accept", [StringName(p[0])], text)
		"order_turn_in":
			var p := DialogueSyntax.parts(text, 1)
			var inv := DialogueSyntax.inventory(context, &"remove_item")
			if DialogueSyntax.has_name(p, text) and inv != null:
				_call(&"orders", &"turn_in", [StringName(p[0]), inv], text)
		"buy_round", "donate", "consecrate_pay":
			var inv := DialogueSyntax.inventory(context, &"remove_item")
			if inv != null:
				var method: StringName = {"buy_round": &"buy_round", "donate": &"donate", "consecrate_pay": &"pay_consecration"}[DialogueSyntax.key(text)]
				_call(&"village", method, [inv], text)
		"anatomy_case":
			_anatomy_case(context)
		"open_anatomist":
			_open_panel(ANATOMIST_PANEL, context)
		"open_lecture":
			var lectures := DialogueSyntax.system(&"lectures")
			if lectures != null and lectures.has_method(&"tonight") and bool(lectures.call(&"tonight")):
				_open_panel(LECTURE_PANEL, context)
		"set_flag_day":
			var p := DialogueSyntax.parts(text, 1)
			if DialogueSyntax.has_name(p, text):
				GameState.set_flag(StringName(p[0]), TimeManager.day)
		"lecture_invite":
			GameState.set_flag(INVITE_FLAG, true)
			var lectures := DialogueSyntax.system(&"lectures")
			if lectures != null and lectures.has_method(&"invite"):
				lectures.call(&"invite")
		_:
			push_warning("[DialogueRunner] unknown action '%s' ignored" % action)


# --- Phase-7 actions ---

## Calls `method` on the first node of `group` (warning without it).
static func _call(group: StringName, method: StringName, args: Array, text: String) -> Variant:
	var node := DialogueSyntax.system(group)
	if node == null or not node.has_method(method):
		push_warning("[DialogueRunner] '%s': no %s.%s" % [text, group, method])
		return null
	return node.callv(method, args)


## ui_panel_requested(panel, {speaker, inventory, player} + extra).
static func _open_panel_with(panel: StringName, context: Dictionary, extra: Dictionary) -> void:
	var ctx := {"speaker": context.get("speaker")}
	if context.has("inventory"):
		ctx["inventory"] = context.get("inventory")
	var tree := Engine.get_main_loop() as SceneTree
	var player := tree.get_first_node_in_group(&"player") if tree != null else null
	if player != null:
		ctx["player"] = player
	ctx.merge(extra, true)
	EventBus.ui_panel_requested.emit(panel, ctx)


## Quast's case (§2.12): the tool (once), his recipe book (flag), the basic teachings (Lectures.learn) and
## anatomy_known. A full inventory still gives the knowledge; the case then waits (flag stays unset).
static func _anatomy_case(context: Dictionary) -> void:
	var inv := DialogueSyntax.inventory(context, &"add_item")
	var has_case := inv != null and inv.has_method(&"has") and bool(inv.call(&"has", CASE_ITEM, 1))
	if not has_case and not GameState.flag_on(ANATOMY_FLAG) and inv != null:
		var rest_v: Variant = inv.call(&"add_item", CASE_ITEM, 1)
		if (rest_v is int or rest_v is float) and int(rest_v) > 0:
			EventBus.notification_requested.emit(NO_ROOM_FORMAT % [1, _item_name(CASE_ITEM)], NOTIFY_WARNING)
			return
		EventBus.notification_requested.emit(REWARD_FORMAT % [1, _item_name(CASE_ITEM)], NOTIFY_REWARD)
	GameState.set_flag(ANATOMY_FLAG, true)
	GameState.set_flag(RECIPES_FLAG, true)
	var cfg := Database.config(&"anatomy_config") as AnatomyConfig
	var basics: Array[StringName] = cfg.basic_teachings if cfg != null else AnatomyConfig.new().basic_teachings
	var lectures := DialogueSyntax.system(&"lectures")
	if lectures != null and lectures.has_method(&"learn"):
		for t: StringName in basics:
			lectures.call(&"learn", t)


# --- Phase-4 actions ---

## ui_panel_requested(panel, {speaker, inventory}) – the panel opens over the dialogue; a
## choice with next &"" ends the dialogue at the same time.
static func _open_panel(panel: StringName, context: Dictionary) -> void:
	var ctx := {"speaker": context.get("speaker")}
	if context.has("inventory"):
		ctx["inventory"] = context.get("inventory")
	EventBus.ui_panel_requested.emit(panel, ctx)


## Ilse's first gift (NightTrade.give_tools, once). Flag trader_tools_given when handed over now
## or earlier (state tools_given) – a full inventory leaves it unset ("Komm wieder …").
static func _trader_tools(context: Dictionary) -> void:
	var trade := DialogueSyntax.system(NIGHT_TRADE_GROUP)
	if trade == null or not trade.has_method(&"give_tools"):
		push_warning("[DialogueRunner] trader_tools: no night trade")
		return
	var inv := DialogueSyntax.inventory(context, &"add_item")
	var given := DialogueSyntax.truthy(trade.call(&"give_tools", inv))
	if not given and trade.has_method(&"save_state"):
		var state: Variant = trade.call(&"save_state")
		given = state is Dictionary and typeof((state as Dictionary).get("tools_given")) == TYPE_BOOL and bool((state as Dictionary).get("tools_given"))
	if given:
		GameState.set_flag(TOOLS_FLAG, true)


# --- item actions ---

## take_item:<id>:<n>[:<reason>]. Phase 5 (docs/PHASE5_DESIGN.md §3.3, §3.4): taking coins is a
## payment – GameState.note_coins_spent(n, reason) (stats.coins_spent, the ledger, EventBus
## coins_spent). The reason is the optional 3rd part (e.g. &"license"), else the speaker's:
## Ilse (npc_id trader) → &"ilse", everyone else (Osric) → &"osric".
static func _take_item(text: String, context: Dictionary) -> void:
	var p := DialogueSyntax.parts(text, 3)
	var n: Variant = _item_amount(p, text)
	if n == null or int(n) == 0:
		return
	var inv := DialogueSyntax.inventory(context, &"remove_item")
	if inv == null:
		return
	var id := StringName(p[0])
	if not DialogueSyntax.truthy(inv.call(&"remove_item", id, int(n))):
		push_warning("[DialogueRunner] '%s': not enough items, nothing taken" % text)
		return
	if id == COIN_ITEM:
		var reason := StringName(p[2]) if p.size() > 2 and p[2] != "" else coin_reason(context)
		GameState.note_coins_spent(int(n), reason)


## Default reason of a coin payment in a dialogue: the speaker's npc_id trader → &"ilse", a villager →
## &"village" (Phase 7), else &"osric".
static func coin_reason(context: Dictionary) -> StringName:
	var speaker: Variant = context.get("speaker")
	if is_instance_valid(speaker) and StringName(str((speaker as Object).get(&"npc_id"))) == TRADER_NPC_ID:
		return REASON_ILSE
	if is_instance_valid(speaker) and StringName(str((speaker as Object).get(&"npc_id"))) in VILLAGERS:
		return REASON_VILLAGE
	return REASON_OSRIC


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
