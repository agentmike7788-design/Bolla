class_name NightTrade
extends Node
## Systems/NightTrade (docs/PHASE4_DESIGN.md §2.6, §2.11 (5), §3.4, §5.1), groups &"night_trade",
## &"saveable": Ilse Kranich's trade at the west wall, the note at the hut door, her tools, talks
## and nightly stock. Coins are paid at once.
## - Presence: the Npc node npc_trader (group npc, npc_id trader) when it exists, otherwise the
##   same rule straight from her schedule and the clock (standing at a dialogue spot, visible,
##   flag trader_known).
## - Night: GhostManager.night_index (a night starts at 12:00). The shop stock resets with a new
##   night id – derived when read, so loading never refills it.
## - Time-driven (like deliveries): time_tick → apply_morning (the note from intro_day at the
##   first minute ≥ intro_minute) and the quiet 22:45 notice (once per night, only outside).
## - Sales count per item in GameState.stats.trader_sales; from rumor_after_sales on the flag
##   trader_rumor is set (Osric remarks on it once).

const GROUP := &"night_trade"
const NPC_ID := &"trader"
const COIN_ITEM := &"coin"
## Phase 5 §3.3: reason of EventBus.coins_spent for her shop (gold leaf, linen, juniper).
const COIN_REASON := &"ilse"
const FLAG_KNOWN := &"trader_known"
const FLAG_RUMOR := &"trader_rumor"
const STAT_SALES := &"trader_sales"
const CLUE_NOTE := &"c_trader_note"
const NOTE_INFO := &"info"
const NOTE_WARNING := &"warning"
const TEXT_NOTE := "An deiner Hüttentür steckt ein Zettel."
const TEXT_WAITING := "Jemand wartet an der Westmauer."
const TEXT_TOOLS_FULL := "Komm wieder, wenn du Platz hast."

@export var save_id: String = "night_trade"
@export var save_order: int = 45

## Rules; null = the data/config files (resolved lazily).
var trader_config: TraderConfig
var utilization_config: UtilizationConfig
## Ilse's schedule for the presence fallback; null = Database.schedule(&"trader").
var schedule: NpcSchedule

var _intro_done: bool = false
var _tools_given: bool = false
var _talks: int = 0
var _last_talk_night: int = -1
## Night the stored stock belongs to (-1 = none yet → full stock).
var _stock_night: int = -1
var _stock_left: Dictionary = {}
## Night the 22:45 notice was shown (not saved: at worst it shows once more after a load).
var _notice_night: int = -1


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.game_loaded.connect(_on_game_loaded)


## Flag trader_known.
func is_known() -> bool:
	return _flag_on(FLAG_KNOWN)


## Ilse stands at trader_spot right now (via the Npc node npc_trader; without one from her
## schedule and the clock).
func is_present() -> bool:
	if not is_known():
		return false
	var npc := _npc()
	if npc != null:
		return npc.is_present() and npc.is_talkable() and not npc.is_walking()
	var sched := _schedule()
	if sched == null or sched.entries.is_empty():
		return false
	var entry := ScheduleResolver.entry_at(sched, TimeManager.minute_of_day)
	return entry != null and entry.visible and entry.dialogue_id != &"" \
			and ScheduleResolver.progress(entry, float(TimeManager.minute_of_day)) >= 1.0


## GhostManager.night_index logic: a night starts at 12:00 → stock / greeting per night.
func night_id() -> int:
	return GhostManager.night_index(TimeManager.day, TimeManager.minute_of_day)


## Coins at once; only sell_prices items; only while present; all or nothing (the inventory
## must hold `amount`); stats.trader_sales; trader_trade; flag trader_rumor from
## rumor_after_sales on. Returns the coins paid (0 = refused).
func sell(item_id: StringName, amount: int, inv: Inventory) -> int:
	if amount <= 0 or inv == null or not is_present() or not _util().sell_prices.has(item_id):
		return 0
	if inv.count(item_id) < amount:
		return 0
	var coins := quote(item_id, amount)
	if not inv.remove_item(item_id, amount):
		return 0
	if coins > 0:
		inv.add_item(COIN_ITEM, coins)
	GameState.add_stat(STAT_SALES, amount)
	if GameState.get_stat(STAT_SALES) >= _trader().rumor_after_sales and not _flag_on(FLAG_RUMOR):
		GameState.set_flag(FLAG_RUMOR, true)
	EventBus.trader_trade.emit(coins, {item_id: amount}, {})
	return coins


## Price incl. the piety bonus (PietyConfig.buyer_bonus_by_tier); 0 for items she does not buy.
func quote(item_id: StringName, amount: int) -> int:
	return UtilizationRules.sale_value({item_id: amount}, _buyer_bonus(), _util())


## Shop: coins off, item in, stock of the night; atomic (present, known item, stock, coins and
## room – otherwise nothing changes). trader_trade with negative coins; Phase 5 §3.4: the coins
## go into the ledger (GameState.note_coins_spent → stats.coins_spent, coins_spent(cost, &"ilse")).
func buy(item_id: StringName, amount: int, inv: Inventory) -> bool:
	var cfg := _trader()
	if amount <= 0 or inv == null or not is_present() or not offers(item_id):
		return false
	var cost := cfg.price(item_id) * amount
	if stock_left(item_id) < amount or inv.count(COIN_ITEM) < cost or not inv.can_add(item_id, amount):
		return false
	if cost > 0 and not inv.remove_item(COIN_ITEM, cost):
		return false
	var rest := inv.add_item(item_id, amount)
	if rest > 0:
		# can_add promised room – undo the whole trade rather than lose coins.
		inv.remove_item(item_id, amount - rest)
		if cost > 0:
			inv.add_item(COIN_ITEM, cost)
		return false
	var left := _current_stock()
	left[String(item_id)] = int(left.get(String(item_id), 0)) - amount
	_stock_left = left
	_stock_night = night_id()
	GameState.note_coins_spent(cost, COIN_REASON)
	EventBus.trader_trade.emit(-cost, {}, {item_id: amount})
	return true


## Stock left tonight (per_night after a new night); 0 for items she does not sell (yet).
func stock_left(item_id: StringName) -> int:
	if not offers(item_id):
		return 0
	return maxi(int(_current_stock().get(String(item_id), 0)), 0)


## The item is in her shop right now: listed in TraderConfig.shop and its optional
## "requires_flag" is set (Phase 5 §1.2: gold leaf only from workshop_open on – before that the
## Phase-5 goods are not offered). The trade panel hides rows for which this is false.
func offers(item_id: StringName) -> bool:
	var cfg := _trader()
	if not cfg.shop.has(item_id):
		return false
	var flag := StringName(str((cfg.shop[item_id] as Dictionary).get("requires_flag", "")))
	return flag == &"" or _flag_on(flag)


## Once (tools_given): shears and pliers (UtilizationConfig.tool_items) – atomic; a tool already
## held is not given twice. Full inventory → false and "Komm wieder, wenn du Platz hast.".
## Called by the dialogue action trader_tools.
func give_tools(inv: Inventory) -> bool:
	if _tools_given or inv == null:
		return false
	var added: Array[StringName] = []
	for tool: StringName in _util().tool_items:
		if inv.has(tool):
			continue
		if inv.add_item(tool, 1) > 0:
			for undo: StringName in added:
				inv.remove_item(undo, 1)
			EventBus.notification_requested.emit(TEXT_TOOLS_FULL, NOTE_WARNING)
			return false
		added.append(tool)
	_tools_given = true
	return true


func tools_given() -> bool:
	return _tools_given


## Once per night: talks +1 (for c_trader_lorenz).
func note_talk() -> void:
	var night := night_id()
	if night == _last_talk_night:
		return
	_last_talk_night = night
	_talks += 1


## Talks in different nights (dialogue condition trader_talks_gte).
func talks() -> int:
	return _talks


## Items sold to Ilse so far (stats.trader_sales).
func sales() -> int:
	return GameState.get_stat(STAT_SALES)


## Ilse's greeting for the current piety tier (TraderConfig.greetings).
func greeting() -> String:
	return str(_trader().greetings.get(_piety_tier(), ""))


## Idempotent: the note at the door from intro_day on, at the first minute ≥ intro_minute of
## that day (or at once for a later day) – flag trader_known, clue c_trader_note, notification.
## A trader_known set otherwise (debug) only marks the note as done.
func apply_morning(day: int) -> void:
	if _intro_done:
		return
	if is_known():
		_intro_done = true
		return
	var cfg := _trader()
	if day < cfg.intro_day:
		return
	if day >= TimeManager.day and TimeManager.minute_of_day < cfg.intro_minute:
		return
	_intro_done = true
	GameState.set_flag(FLAG_KNOWN, true)
	var journal := _system(&"journal")
	if journal != null and journal.has_method(&"add_clue"):
		journal.call(&"add_clue", CLUE_NOTE, "", false)
	EventBus.notification_requested.emit(TEXT_NOTE, NOTE_INFO)


## {"intro_done", "tools_given", "talks", "last_talk_night", "stock_night", "stock_left"} (§5.1).
func save_state() -> Dictionary:
	return {"intro_done": _intro_done, "tools_given": _tools_given, "talks": _talks,
			"last_talk_night": _last_talk_night, "stock_night": _stock_night, "stock_left": _stock_left.duplicate()}


## Tolerant: missing / damaged keys fall back to the defaults ({} = a fresh trader).
func load_state(data: Dictionary) -> void:
	_intro_done = _bool(data.get("intro_done"))
	_tools_given = _bool(data.get("tools_given"))
	_talks = maxi(_num(data.get("talks"), 0), 0)
	_last_talk_night = _num(data.get("last_talk_night"), -1)
	_stock_night = _num(data.get("stock_night"), -1)
	_stock_left = {}
	var raw: Variant = data.get("stock_left", {})
	if raw is Dictionary:
		for key: Variant in raw:
			_stock_left[str(key)] = maxi(_num((raw as Dictionary)[key], 0), 0)
	_notice_night = -1


# --- internals ------------------------------------------------------------------------------

func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	apply_morning(day)
	_maybe_notice(minute)


func _on_game_loaded(_slot: int) -> void:
	apply_morning(TimeManager.day)


## "Jemand wartet an der Westmauer." once per night from notice_minute on, only outside.
func _maybe_notice(minute: int) -> void:
	if not is_known() or minute < _trader().notice_minute:
		return
	var night := night_id()
	if night == _notice_night:
		return
	var player := _system(&"player")
	if player != null and player.get(&"in_interior") == true:
		return
	_notice_night = night
	EventBus.notification_requested.emit(TEXT_WAITING, NOTE_INFO)


## Stock of the current night: the stored one, or full per_night after a new night.
func _current_stock() -> Dictionary:
	if _stock_night == night_id():
		return _stock_left.duplicate()
	var full := {}
	var cfg := _trader()
	for id: StringName in cfg.shop:
		full[String(id)] = cfg.per_night(id)
	return full


func _buyer_bonus() -> int:
	var piety := _system(&"piety")
	if piety != null and piety.has_method(&"buyer_bonus"):
		return int(piety.call(&"buyer_bonus"))
	var cfg := PietyRules._cfg(null)
	return PietyRules.per_tier(cfg.buyer_bonus_by_tier, PietyRules.tier(GameState.get_stat(&"piety"), cfg))


func _piety_tier() -> StringName:
	var piety := _system(&"piety")
	if piety != null and piety.has_method(&"tier"):
		return piety.call(&"tier")
	return PietyRules.tier(GameState.get_stat(&"piety"), PietyRules._cfg(null))


func _npc() -> Npc:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null and npc.npc_id == NPC_ID:
			return npc
	return null


func _schedule() -> NpcSchedule:
	if schedule == null:
		schedule = Database.schedule(NPC_ID) as NpcSchedule
	return schedule


func _system(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _trader() -> TraderConfig:
	if trader_config == null:
		trader_config = Database.config(&"trader_config") as TraderConfig
		if trader_config == null:
			trader_config = TraderConfig.new()
	return trader_config


func _util() -> UtilizationConfig:
	if utilization_config == null:
		utilization_config = UtilizationRules._cfg(null)
	return utilization_config


static func _flag_on(flag: StringName) -> bool:
	if not GameState.has_flag(flag):
		return false
	var v: Variant = GameState.get_flag(flag)
	return not (typeof(v) == TYPE_BOOL and not v)


static func _bool(v: Variant) -> bool:
	return typeof(v) == TYPE_BOOL and v


static func _num(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback
