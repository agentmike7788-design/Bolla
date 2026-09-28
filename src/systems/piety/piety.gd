class_name Piety
extends Node
## Systems/Piety (docs/PHASE4_DESIGN.md §2.7, §3.4), group &"piety", not saved: the value lives
## in GameState.stats.piety (−100…100), the last recovery day in flag piety_last_day, the last
## harvesting day in flag piety_used_day (set by CorpseCare.harvest). Events are called directly
## by the triggering system (change / event), never from signal listeners. Time-driven:
## day_started → apply_daily (recovery). new_game_started → start_value. No HUD value: a tier
## change only shows a quiet notification without a number (§7).

const GROUP := &"piety"
const STAT := &"piety"
const FLAG_LAST_DAY := &"piety_last_day"
const FLAG_USED_DAY := &"piety_used_day"
const REASON_RECOVERY := "Die Zeit heilt"
const NOTE_KIND := &"info"
## Tier change downwards / upwards (§2.7).
const TEXT_TIER_DOWN := "Du merkst, dass dir das nicht mehr schwerfällt."
const TEXT_TIER_UP := "Du merkst, dass du leiser gehst."

## Piety rules; null = data/config/piety_config.tres.
var config: PietyConfig


func _init() -> void:
	add_to_group(GROUP, true)


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.new_game_started.connect(_on_new_game_started)
	EventBus.game_loaded.connect(_on_game_loaded)


## GameState.stats.piety, clamped to min_value…max_value.
func value() -> int:
	var cfg := _cfg()
	return clampi(GameState.get_stat(STAT), cfg.min_value, cfg.max_value)


func tier() -> StringName:
	return PietyRules.tier(value(), _cfg())


## Clamps, writes GameState.stats.piety, piety_changed (only when the value moves);
## tier change → quiet notification.
func change(delta: int, reason: String) -> void:
	var cfg := _cfg()
	var old := value()
	var new_value := clampi(old + delta, cfg.min_value, cfg.max_value)
	GameState.stats[STAT] = new_value
	if new_value == old:
		return
	var old_tier := PietyRules.tier(old, cfg)
	var new_tier := PietyRules.tier(new_value, cfg)
	EventBus.piety_changed.emit(new_value, new_tier, new_value - old, reason)
	if new_tier != old_tier:
		var up := PietyRules.tier_index(new_tier) > PietyRules.tier_index(old_tier)
		EventBus.notification_requested.emit(TEXT_TIER_UP if up else TEXT_TIER_DOWN, NOTE_KIND)


## PietyConfig.events[kind]; unknown kinds are ignored (warning).
func event(kind: StringName, reason: String) -> void:
	var events := _cfg().events
	if not events.has(kind):
		push_warning("[Piety] unknown event '%s'" % kind)
		return
	change(int(events[kind]), reason)


## Idempotent (flag piety_last_day): +daily_recovery towards 0 when below 0 and nothing was
## harvested the day before (flag piety_used_day). Returns the applied delta.
func apply_daily(day: int) -> int:
	if int(GameState.get_flag(FLAG_LAST_DAY, 0)) >= day:
		return 0
	GameState.set_flag(FLAG_LAST_DAY, day)
	var used := GameState.has_flag(FLAG_USED_DAY) and int(GameState.get_flag(FLAG_USED_DAY, 0)) >= day - 1
	var before := value()
	change(PietyRules.recovery(before, used, _cfg()), REASON_RECOVERY)
	return value() - before


## PietyConfig.gift_by_tier of the current tier.
func gift_coins() -> int:
	return PietyRules.per_tier(_cfg().gift_by_tier, tier())


## PietyConfig.buyer_bonus_by_tier of the current tier.
func buyer_bonus() -> int:
	return PietyRules.per_tier(_cfg().buyer_bonus_by_tier, tier())


## Phase 13+ hook (PietyRules.affinity of the current value).
func affinity() -> StringName:
	return PietyRules.affinity(value(), _cfg())


func _on_day_started(day: int) -> void:
	apply_daily(day)


## A new game starts at start_value; the first day never recovers.
func _on_new_game_started() -> void:
	GameState.stats[STAT] = _cfg().start_value
	GameState.set_flag(FLAG_LAST_DAY, TimeManager.day)


## A save with an out-of-range value (damaged / edited) is repaired silently.
func _on_game_loaded(_slot: int) -> void:
	if GameState.get_stat(STAT) != value():
		push_warning("[Piety] saved piety %d out of range – clamped" % GameState.get_stat(STAT))
		GameState.stats[STAT] = value()


func _cfg() -> PietyConfig:
	if config == null:
		config = PietyRules._cfg(null)
	return config
