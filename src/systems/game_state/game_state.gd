extends Node
## Autoload GameState – story flags & statistics (docs/VERTICAL_SLICE_DESIGN.md §3.4).
## flags: StringName -> bool/int/float/String. stats: StringName -> int (default keys below).

## Phase 4 (§3.4): + piety (−100…100), utilized, prepared, trader_sales.
## Phase 5 (docs/PHASE5_DESIGN.md §2.7, §5.1): + crafted, stones_set, coins_spent, trees_felled and the
## coin ledger by purpose coins_spent_<reason> (COIN_REASONS) for the chapter panel / day summary.
## Phase 6 (docs/PHASE6_DESIGN.md §2.7, §5.1): + services_held, devotions_held, bones_lifted,
## bones_reinterred, niche_waits and the ledger stat coins_spent_building.
const DEFAULT_STATS: Array[StringName] = [&"burials", &"valuables_taken", &"reputation", &"missed_deliveries", &"days_played",
		&"piety", &"utilized", &"prepared", &"trader_sales",
		&"crafted", &"stones_set", &"coins_spent", &"trees_felled",
		&"coins_spent_license", &"coins_spent_build", &"coins_spent_osric", &"coins_spent_ilse",
		&"services_held", &"devotions_held", &"bones_lifted", &"bones_reinterred", &"niche_waits",
		&"coins_spent_building"]
## Phase 5 §3.3: the reasons of EventBus.coins_spent (license, stations, Osric's goods, Ilse's shop);
## Phase 6 §2.7: + building (the building levels; altar candles run under osric).
const COIN_REASONS: Array[StringName] = [&"license", &"build", &"osric", &"ilse", &"building"]
const STAT_COINS_SPENT := &"coins_spent"
const COINS_SPENT_PREFIX := "coins_spent_"

var flags: Dictionary = {}
var stats: Dictionary = {}
## Reputation tier source; null = data/config/reputation_config.tres (resolved lazily).
var reputation_config: ReputationConfig


func _ready() -> void:
	reset()


## Stores a flag. Allowed values: bool, int, float, String (StringName is stored as String).
func set_flag(flag: StringName, value: Variant = true) -> void:
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			flags[flag] = value
		TYPE_STRING_NAME:
			flags[flag] = String(value)
		_:
			push_warning("[GameState] flag '%s': unsupported value type %s ignored" % [flag, type_string(typeof(value))])


func get_flag(flag: StringName, default: Variant = null) -> Variant:
	return flags.get(flag, default)


func has_flag(flag: StringName) -> bool:
	return flags.has(flag)


## The flag as a truth value of any stored type (bool; a number ≠ 0; a non-empty string) – safe
## where `get_flag(f) == true` would compare a damaged save's float or int with a bool (a script
## error, QA6-10).
func flag_on(flag: StringName) -> bool:
	var value: Variant = flags.get(flag, false)
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return str(value) != ""
	return false


func clear_flag(flag: StringName) -> void:
	flags.erase(flag)


func clear_flags() -> void:
	flags.clear()


func add_stat(stat: StringName, amount: int) -> void:
	stats[stat] = get_stat(stat) + amount


## Unknown stats read as 0.
func get_stat(stat: StringName) -> int:
	return int(stats.get(stat, 0))


## Phase 5 §3.3 (the sender's side of EventBus.coins_spent): stats.coins_spent + amount, the ledger
## stat coins_spent_<reason> + amount, then EventBus.coins_spent(amount, reason). Every system that
## spends the player's coins (Workshop.build, Osric's dialogue, NightTrade.buy) calls this once per
## payment, after the coins are gone. amount <= 0 → nothing.
func note_coins_spent(amount: int, reason: StringName) -> void:
	if amount <= 0:
		return
	add_stat(STAT_COINS_SPENT, amount)
	add_stat(coin_ledger_stat(reason), amount)
	EventBus.coins_spent.emit(amount, reason)


## "coins_spent_<reason>" – the ledger stat of one purpose (unknown reasons get their own stat).
static func coin_ledger_stat(reason: StringName) -> StringName:
	return StringName(COINS_SPENT_PREFIX + String(reason))


## {reason: coins} of the ledger for COIN_REASONS (Phase 5 spending by purpose).
func coin_ledger() -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for reason: StringName in COIN_REASONS:
		out[reason] = get_stat(coin_ledger_stat(reason))
	return out


## Tier label of stats.reputation (0…100, Phase 3 §2.6): "Verrufen" … "Gerühmt".
func reputation_label() -> String:
	return ReputationRules.label(ReputationRules.tier(get_stat(&"reputation"), _reputation_config()))


## No flags, all default stats 0. Dictionaries are cleared in place (references stay valid).
func reset() -> void:
	_clear_values()
	reputation_config = null


func save_state() -> Dictionary:
	return {"flags": flags.duplicate(true), "stats": stats.duplicate(true)}


## Replaces flags and stats completely; missing default stats become 0.
func load_state(data: Dictionary) -> void:
	_clear_values()
	var saved_flags: Variant = data.get("flags", {})
	if saved_flags is Dictionary:
		for key: Variant in saved_flags:
			set_flag(StringName(str(key)), (saved_flags as Dictionary)[key])
	var saved_stats: Variant = data.get("stats", {})
	if saved_stats is Dictionary:
		for key: Variant in saved_stats:
			var value: Variant = (saved_stats as Dictionary)[key]
			if value is int or value is float:
				stats[StringName(str(key))] = int(value)
			else:
				push_warning("[GameState] stat '%s': non-numeric value ignored" % str(key))


func _clear_values() -> void:
	flags.clear()
	stats.clear()
	for key: StringName in DEFAULT_STATS:
		stats[key] = 0


func _reputation_config() -> ReputationConfig:
	if reputation_config == null:
		reputation_config = Database.config(&"reputation_config") as ReputationConfig
		if reputation_config == null:
			reputation_config = ReputationConfig.new()
	return reputation_config
