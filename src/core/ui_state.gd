extends Node
## Autoload UIState: stack of open modal UI (panels, dialogue, debug console).
## While any modal is open the player is locked and game time is paused.
## Only this node emits EventBus.ui_modal_changed (on 0 <-> 1 transitions).

const PAUSE_REASON := &"modal"

var _stack: Array[StringName] = []


func push_modal(id: StringName) -> void:
	if id in _stack:
		return
	_stack.append(id)
	if _stack.size() == 1:
		TimeManager.push_pause(PAUSE_REASON)
		EventBus.ui_modal_changed.emit(true)


func pop_modal(id: StringName) -> void:
	if not id in _stack:
		return
	_stack.erase(id)
	if _stack.is_empty():
		TimeManager.pop_pause(PAUSE_REASON)
		EventBus.ui_modal_changed.emit(false)


func clear() -> void:
	var was_open := not _stack.is_empty()
	_stack.clear()
	if was_open:
		TimeManager.pop_pause(PAUSE_REASON)
		EventBus.ui_modal_changed.emit(false)


func is_modal() -> bool:
	return not _stack.is_empty()


func is_open(id: StringName) -> bool:
	return id in _stack


func top() -> StringName:
	return _stack.back() if not _stack.is_empty() else &""


func reset() -> void:
	_stack.clear()
