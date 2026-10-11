class_name Reputation
extends Node
## Systems/Reputation (docs/PHASE3_DESIGN.md §2.6, §3.4), group &"reputation". The value lives
## in GameState.stats.reputation (0…100), the last daily drift day in flag rep_last_day – this
## node itself is not saved. Events are called directly by the triggering system (change /
## event), never from signal listeners. Time-driven: day_started → apply_daily (drift, then
## stipend). new_game_started → start_value.
## STUB (P3) → implemented in W1; this marker line stays for test_phase3_scaffold.

const GROUP := &"reputation"
const STAT := &"reputation"
const FLAG_LAST_DAY := &"rep_last_day"
const COIN_ITEM := &"coin"
const REASON_DRIFT := "Ruf im Dorf"
const REASON_STIPEND := "Pflegegeld der Gemeinde"
const TEXT_WITHHELD := "Das Pflegegeld bleibt heute in der Gemeindekasse. Fenner: „Wer %d Münzen im Kasten hat, braucht keins.“"

## Reputation rules; null = data/config/reputation_config.tres (ReputationRules resolves it).
var config: ReputationConfig
## Inventory the stipend is paid into; null = the player's inventory (group &"player").
var stipend_inventory: Inventory

var _last_daily: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.new_game_started.connect(_on_new_game_started)
	EventBus.game_loaded.connect(_on_game_loaded)


## GameState.stats.reputation, clamped to min_value…max_value (a damaged save cannot push it
## out of range – QA-09).
func value() -> int:
	var cfg := _cfg()
	return clampi(GameState.get_stat(STAT), cfg.min_value, cfg.max_value)


func tier() -> StringName:
	return ReputationRules.tier(value(), _cfg())


## Clamps, writes GameState.stats.reputation, reputation_changed (only when the value moves).
func change(delta: int, reason: String) -> void:
	var cfg := _cfg()
	var old := value()
	var new_value := clampi(old + delta, cfg.min_value, cfg.max_value)
	GameState.stats[STAT] = new_value
	if new_value != old:
		EventBus.reputation_changed.emit(new_value, ReputationRules.tier(new_value, cfg), new_value - old, reason)


## ReputationConfig.event_points[kind]; unknown kinds are ignored (warning).
func event(kind: StringName, reason: String) -> void:
	var points := _cfg().event_points
	if not points.has(kind):
		push_warning("[Reputation] unknown event '%s'" % kind)
		return
	change(int(points[kind]), reason)


## Idempotent per day (flag rep_last_day): drift towards the cemetery quality's target, then the
## stipend of the (new) tier into the player's inventory. {drift, stipend}; a day already
## applied returns {drift: 0, stipend: 0}.
func apply_daily(day: int) -> Dictionary:
	if int(GameState.get_flag(FLAG_LAST_DAY, 0)) >= day:
		return {"drift": 0, "stipend": 0}
	GameState.set_flag(FLAG_LAST_DAY, day)
	var cfg := _cfg()
	var before := value()
	change(ReputationRules.drift(before, ReputationRules.target(_cemetery_total(), cfg), cfg), REASON_DRIFT)
	var drift := value() - before
	var coins := ReputationRules.stipend(tier(), cfg)
	var inv := _inventory()
	var withheld := coins > 0 and stipend_withheld(inv)
	if withheld:
		coins = 0
		EventBus.notification_requested.emit(TEXT_WITHHELD % cfg.stipend_purse_cap, &"info")
	if coins > 0:
		if inv != null:
			inv.add_item(COIN_ITEM, coins)
			EventBus.payment_received.emit(coins, REASON_STIPEND)
		else:
			push_warning("[Reputation] no inventory for the stipend of day %d" % day)
			coins = 0
	_last_daily = {"day": day, "drift": drift, "stipend": coins, "value": value(), "tier": tier()}
	if withheld:
		_last_daily["stipend_withheld"] = true
	return {"drift": drift, "stipend": coins}


## G8 Runde 1 (E8-2): Phase 8 open (ReputationConfig.stipend_cap_flag) and the gravekeeper holds stipend_purse_cap
## coins or more – the purse `inv` plus the coins in every Chest of the world (the hut chest, Jakob's box) and the wage
## tin – so the Gemeinde keeps the day's stipend.
func stipend_withheld(inv: Inventory = null) -> bool:
	var cfg := _cfg()
	if cfg.stipend_purse_cap <= 0 or (cfg.stipend_cap_flag != &"" and not GameState.flag_on(cfg.stipend_cap_flag)):
		return false
	return holdings(inv if inv != null else _inventory()) >= cfg.stipend_purse_cap


## The gravekeeper's coins: `inv` + every Chest's storage + the wage tin of Jakob's box.
func holdings(inv: Inventory) -> int:
	var total := inv.count(COIN_ITEM) if inv != null else 0
	if not is_inside_tree():
		return total
	for node: Node in get_tree().get_nodes_in_group(&"saveable"):
		if node is Chest:
			var storage := (node as Chest).get_node_or_null(^"Storage") as Inventory
			if storage != null and storage != inv:
				total += storage.count(COIN_ITEM)
			var tin: Variant = node.get(&"coins")
			if tin is int:
				total += int(tin)
	return total


## Drift the next day change would bring (HUD arrow).
func forecast() -> int:
	var cfg := _cfg()
	var now := value()
	var next := clampi(now + ReputationRules.drift(now, ReputationRules.target(_cemetery_total(), cfg), cfg), cfg.min_value, cfg.max_value)
	return next - now


## For the day summary: {day, drift, stipend, value, tier} of the last apply_daily ({} = none yet).
func last_daily() -> Dictionary:
	return _last_daily.duplicate()


## A save with an out-of-range value (damaged / edited) is repaired silently.
func _on_game_loaded(_slot: int) -> void:
	if GameState.get_stat(STAT) != value():
		push_warning("[Reputation] saved reputation %d out of range – clamped" % GameState.get_stat(STAT))
		GameState.stats[STAT] = value()


func _on_day_started(day: int) -> void:
	apply_daily(day)


## A new game starts at start_value; the first day never drifts.
func _on_new_game_started() -> void:
	GameState.stats[STAT] = _cfg().start_value
	GameState.set_flag(FLAG_LAST_DAY, TimeManager.day)
	_last_daily = {}


## Cemetery quality from CemeteryScore (group &"cemetery_score"); without one: 0.
func _cemetery_total() -> int:
	var score := get_tree().get_first_node_in_group(&"cemetery_score") if is_inside_tree() else null
	if score != null and score.has_method(&"total"):
		return int(score.call(&"total"))
	return 0


func _inventory() -> Inventory:
	if stipend_inventory != null:
		return stipend_inventory
	var player := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	if player != null:
		return player.get(&"inventory") as Inventory
	return null


func _cfg() -> ReputationConfig:
	if config == null:
		config = ReputationRules._cfg(null)
	return config
