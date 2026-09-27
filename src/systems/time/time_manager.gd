extends Node
## Autoload TimeManager – game clock (docs/VERTICAL_SLICE_DESIGN.md §3.4).
## Ticks in real time only while `running` and no pause reason is active; stays
## PROCESS_MODE_INHERIT so a paused SceneTree stops it as well. advance() skips time
## (also while paused) and reports every crossed boundary in chronological order.

const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := 1440
## Guard against a zero/negative seconds_per_game_minute in a broken config.
const MIN_SECONDS_PER_MINUTE := 0.001

var config: TimeConfig
var day: int = 1
var minute_of_day: int = 0
var running: bool = false
var paused: bool:
	get:
		return not _pauses.is_empty()

## Active pause reasons (a set: pushing the same reason twice needs one pop).
var _pauses: Dictionary[StringName, bool] = {}
## Real seconds accumulated towards the next game minute.
var _accum: float = 0.0


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	if not running or paused:
		return
	var step := _seconds_per_minute()
	_accum += delta
	# Re-check every minute: a listener may pause or stop the clock mid-frame.
	while _accum >= step and running and not paused:
		_accum -= step
		advance(1)
	# Stopped mid-frame: the rest of this frame belongs after the pause, not before it.
	if _accum >= step:
		_accum = fmod(_accum, step)


func push_pause(reason: StringName) -> void:
	_pauses[reason] = true


func pop_pause(reason: StringName) -> void:
	_pauses.erase(reason)


func clear_pauses() -> void:
	_pauses.clear()


## Skips `minutes` of game time (works while paused). Emits day_started/hour_changed for
## every crossed boundary in order (day_started before hour 0), then time_skipped when
## minutes > 1, then exactly one time_tick. Listeners see the boundary time during
## boundary signals and the final time afterwards.
func advance(minutes: int) -> void:
	if minutes < 0:
		push_warning("[TimeManager] advance(%d) ignored – time only runs forward" % minutes)
		return
	if minutes == 0:
		return
	var from_total := total_minutes()
	var to_total := from_total + minutes
	var boundary := (_div(from_total, MINUTES_PER_HOUR) + 1) * MINUTES_PER_HOUR
	while boundary <= to_total:
		_set_total(boundary)
		if minute_of_day == 0:
			EventBus.day_started.emit(day)
		EventBus.hour_changed.emit(day, _div(minute_of_day, MINUTES_PER_HOUR))
		boundary += MINUTES_PER_HOUR
	_set_total(to_total)
	if minutes > 1:
		EventBus.time_skipped.emit(from_total, to_total)
	EventBus.time_tick.emit(day, minute_of_day)


## Jumps forward to the given time. A target earlier than now resolves to the next
## occurrence of that clock time (e.g. 20:00 → set_time(day, 06:00) = next morning).
func set_time(new_day: int, new_minute_of_day: int) -> void:
	var minute := posmod(new_minute_of_day, MINUTES_PER_DAY)
	if minute != new_minute_of_day:
		push_warning("[TimeManager] set_time minute %d wrapped to %d" % [new_minute_of_day, minute])
	var target := (new_day - 1) * MINUTES_PER_DAY + minute
	var now := total_minutes()
	advance(target - now if target >= now else minutes_until(minute))


## Minutes (0..1439) until the clock next shows `target_minute_of_day`.
func minutes_until(target_minute_of_day: int) -> int:
	return posmod(target_minute_of_day - minute_of_day, MINUTES_PER_DAY)


## minute_of_day plus the fraction of the running real-time accumulator (smooth clock).
func get_minute_f() -> float:
	return float(minute_of_day) + clampf(_accum / _seconds_per_minute(), 0.0, 0.999)


func total_minutes() -> int:
	return (day - 1) * MINUTES_PER_DAY + minute_of_day


## True inside [night_start_minute, night_end_minute), wrapping over midnight.
func is_night() -> bool:
	var start := config.night_start_minute
	var end := config.night_end_minute
	if start > end:
		return minute_of_day >= start or minute_of_day < end
	return minute_of_day >= start and minute_of_day < end


## "HH:MM", e.g. "07:40".
func format_clock() -> String:
	return "%02d:%02d" % [_div(minute_of_day, MINUTES_PER_HOUR), minute_of_day % MINUTES_PER_HOUR]


## Exactly one time_tick with the current time (after loading / new game).
func emit_refresh() -> void:
	EventBus.time_tick.emit(day, minute_of_day)


## Config start time, not running, no pauses, empty accumulator.
func reset() -> void:
	config = _load_config()
	day = config.start_day
	minute_of_day = config.start_minute
	running = false
	_pauses.clear()
	_accum = 0.0


func save_state() -> Dictionary:
	return {"day": day, "minute_of_day": minute_of_day}


## Silent: restores the clock without emitting any signal.
func load_state(data: Dictionary) -> void:
	day = maxi(1, _num(data.get("day"), config.start_day))
	minute_of_day = clampi(_num(data.get("minute_of_day"), config.start_minute), 0, MINUTES_PER_DAY - 1)
	_accum = 0.0


## int of a saved number; anything else (damaged save) → `fallback` (QA-10).
static func _num(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback


func _load_config() -> TimeConfig:
	var cfg := Database.config(&"time_config") as TimeConfig
	return cfg if cfg != null else TimeConfig.new()


func _seconds_per_minute() -> float:
	return maxf(config.seconds_per_game_minute, MIN_SECONDS_PER_MINUTE)


func _set_total(total: int) -> void:
	day = _div(total, MINUTES_PER_DAY) + 1
	minute_of_day = total % MINUTES_PER_DAY


@warning_ignore("integer_division")
func _div(a: int, b: int) -> int:
	return a / b
