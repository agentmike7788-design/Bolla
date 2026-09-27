class_name NotificationStack
extends VBoxContainer
## Stack of short messages (EventBus.notification_requested) – newest at the bottom,
## coloured by kind (&"info", &"reward", &"warning"), each fades out after `lifetime`.
## Repeating the newest text within `merge_window` refreshes it instead of stacking.

const KIND_STYLES: Dictionary[StringName, StringName] = {
	&"info": &"NoteInfo",
	&"reward": &"NoteReward",
	&"warning": &"NoteWarning",
}
const DEFAULT_STYLE := &"NoteInfo"
const META_TEXT := &"note_text"
const META_KIND := &"note_kind"
const META_BORN := &"note_born"
const META_TWEEN := &"note_tween"

## Seconds a message stays fully visible.
@export var lifetime: float = 4.0
## Seconds of the fade-out.
@export var fade_time: float = 0.6
@export var max_entries: int = 5
@export var entry_width: float = 460.0
@export var merge_window: float = 1.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.notification_requested.connect(push)


## Adds a message. Unknown kinds are shown as info.
func push(text: String, kind: StringName = &"info") -> void:
	if text.strip_edges() == "":
		return
	var newest := _newest()
	var now := Time.get_ticks_msec()
	if newest != null and String(newest.get_meta(META_TEXT)) == text \
			and StringName(newest.get_meta(META_KIND)) == kind \
			and now - int(newest.get_meta(META_BORN)) < merge_window * 1000.0:
		newest.set_meta(META_BORN, now)
		_start_fade(newest)
		return
	var entry := UIKit.panel(KIND_STYLES.get(kind, DEFAULT_STYLE))
	entry.custom_minimum_size.x = entry_width
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.set_meta(META_TEXT, text)
	entry.set_meta(META_KIND, kind)
	entry.set_meta(META_BORN, now)
	var l := UIKit.label(text, &"HudLabel", true)
	l.custom_minimum_size.x = entry_width - 40.0
	entry.add_child(l)
	add_child(entry)
	while _live_entries().size() > max_entries:
		_remove(_live_entries()[0])
	_start_fade(entry)


## Texts currently shown (oldest first).
func texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for entry: Control in _live_entries():
		out.append(String(entry.get_meta(META_TEXT)))
	return out


## Kind of every shown message (oldest first).
func kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Control in _live_entries():
		out.append(StringName(entry.get_meta(META_KIND)))
	return out


func clear() -> void:
	for entry: Control in _live_entries():
		_remove(entry)


func _start_fade(entry: Control) -> void:
	if entry.has_meta(META_TWEEN):
		var old := entry.get_meta(META_TWEEN) as Tween
		if old != null and old.is_valid():
			old.kill()
	entry.modulate.a = 1.0
	var tween := entry.create_tween()
	tween.tween_interval(lifetime)
	tween.tween_property(entry, ^"modulate:a", 0.0, fade_time)
	tween.tween_callback(_remove.bind(entry))
	entry.set_meta(META_TWEEN, tween)


func _remove(entry: Control) -> void:
	if is_instance_valid(entry) and entry.get_parent() == self:
		remove_child(entry)
		entry.queue_free()


func _live_entries() -> Array[Control]:
	var out: Array[Control] = []
	for child: Node in get_children():
		if child is Control and not child.is_queued_for_deletion():
			out.append(child as Control)
	return out


func _newest() -> Control:
	var live := _live_entries()
	return live.back() if not live.is_empty() else null
