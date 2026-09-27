class_name PlayerActionRunner
extends RefCounted
## Timed-action runner of the Player: holds the running Player.TimedAction, pauses the clock
## (Player.ACTION_PAUSE) while it runs, advances it in whole minutes as the bar fills and calls
## on_done at the end. Emits EventBus.timed_action_started / _progress / _finished.

## The running action (null when idle).
var current: Player.TimedAction


## Makes `action` the running one: pauses the clock and reports the start.
func start(action: Player.TimedAction) -> void:
	current = action
	TimeManager.push_pause(Player.ACTION_PAUSE)
	EventBus.timed_action_started.emit(action.label, action.duration)


## Stops the running action: minutes already advanced stay, on_done is NOT called.
func cancel() -> void:
	if current == null:
		return
	current = null
	TimeManager.pop_pause(Player.ACTION_PAUSE)
	EventBus.timed_action_finished.emit(false)


## Fills the bar by `delta` real seconds; completes the action once it is full.
func tick(delta: float) -> void:
	var action := current
	action.elapsed = minf(action.elapsed + maxf(delta, 0.0), action.duration)
	var ratio := action.elapsed / action.duration if action.duration > 0.0 else 1.0
	_advance_to(action, floori(action.minutes * ratio + Player.MINUTE_EPSILON))
	if current != action:
		return  # a time listener cancelled it
	EventBus.timed_action_progress.emit(ratio)
	if ratio >= 1.0:
		_complete(action)


## Advances the clock to `minutes` of the action (whole minutes, never backwards).
func _advance_to(action: Player.TimedAction, minutes: int) -> void:
	var step := mini(minutes, action.minutes) - action.advanced
	if step <= 0:
		return
	action.advanced += step
	TimeManager.advance(step)


func _complete(action: Player.TimedAction) -> void:
	_advance_to(action, action.minutes)
	if current != action:
		return
	current = null
	TimeManager.pop_pause(Player.ACTION_PAUSE)
	EventBus.timed_action_finished.emit(true)
	if action.on_done.is_valid():
		action.on_done.call()
	elif not action.on_done.is_null():
		push_warning("[Player] on_done of '%s' is no longer valid" % action.label)
