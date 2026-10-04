class_name AudioEvents
extends Node
## Game events → sounds (AudioEventMap): every EventBus signal named in signal_cues, the timed
## actions (a work cue repeats while the bar fills), buttons and panels (SceneTree.node_added),
## the gravekeeper's hands (carried corpse) and MorgueTable.sound_hook. Listens only.

const ARG_SEP := "@"
const VALUE_SEP := "="
const CUE_SEP := ","
const META_HOOKED := &"audio_hooked"

var audio: AudioManager
var map: AudioEventMap

## signal name -> {"any": PackedStringArray cues, "rules": [[arg index, value, cues], …]}
var _rules: Dictionary[StringName, Dictionary] = {}
var _work_cue: StringName = &""
var _work_left: float = 0.0
## G7 Runde 2: the player's tool clip sounds the work cue in step (work_beat) – no timer then.
var _work_synced: bool = false
var _carried: WeakRef = null
var _carried_was_corpse: bool = false


func setup(owner_audio: AudioManager, event_map: AudioEventMap) -> void:
	audio = owner_audio
	map = event_map if event_map != null else AudioEventMap.new()
	_build_rules()
	for sig_name: StringName in _rules:
		if not EventBus.has_signal(sig_name):
			push_warning("[Audio] audio_events: EventBus has no signal '%s'" % sig_name)
			continue
		EventBus.connect(sig_name, _on_signal.bind(sig_name))
	EventBus.timed_action_started.connect(_on_action_started)
	EventBus.timed_action_finished.connect(_on_action_finished)
	get_tree().node_added.connect(_on_node_added)


func connected_signals() -> Array[StringName]:
	return _rules.keys()


## The cues `sig_name` plays for these arguments (the rule with most matching conditions
## first, else the plain key).
func cues_for(sig_name: StringName, args: Array) -> PackedStringArray:
	var entry: Dictionary = _rules.get(sig_name, {})
	if entry.is_empty():
		return PackedStringArray()
	for rule: Array in entry["rules"]:
		var ok := true
		for cond: Array in rule[0]:
			var idx: int = cond[0]
			if idx >= args.size() or str(args[idx]) != String(cond[1]):
				ok = false
				break
		if ok:
			return rule[1]
	return entry["any"]


func work_cue() -> StringName:
	return _work_cue


func reset() -> void:
	_work_cue = &""
	_work_synced = false
	_carried = null


func _build_rules() -> void:
	_rules.clear()
	for key: String in map.signal_cues:
		var cues := PackedStringArray()
		for c: String in map.signal_cues[key].split(CUE_SEP, false):
			cues.append(c.strip_edges())
		var parts := key.split(ARG_SEP)
		var sig_name := StringName(parts[0])
		if not _rules.has(sig_name):
			_rules[sig_name] = {"any": PackedStringArray(), "rules": []}
		if parts.size() == 1:
			_rules[sig_name]["any"] = cues
			continue
		var conds: Array = []
		for i in range(1, parts.size()):
			conds.append([int(parts[i].get_slice(VALUE_SEP, 0)), parts[i].get_slice(VALUE_SEP, 1)])
		(_rules[sig_name]["rules"] as Array).append([conds, cues])
	for sig_name: StringName in _rules:
		(_rules[sig_name]["rules"] as Array).sort_custom(func(a: Array, b: Array) -> bool:
			return (a[0] as Array).size() > (b[0] as Array).size())


func _on_signal(...args: Array) -> void:
	var sig_name: StringName = args.pop_back()
	if audio.settling():
		return
	for c: String in cues_for(sig_name, args):
		audio.play(StringName(c))


# --- timed actions ---------------------------------------------------------------------

## The work cue for an action label (keywords in order, then the player's action animation).
func cue_for_action(label: String, animation: StringName) -> StringName:
	var low := label.to_lower()
	for word: String in map.action_keywords:
		if low.contains(word.to_lower()):
			return map.action_keywords[word]
	return map.action_animation_cues.get(animation, &"")


func _on_action_started(label: String, duration_sec: float) -> void:
	var player := audio.player()
	var anim: StringName = &"interact"
	if player != null and player._action != null:
		anim = player._action.animation
	_work_cue = cue_for_action(label, anim)
	_work_synced = _work_cue != &"" and duration_sec > 0.0 and player != null and player.syncs_work_cue(anim)
	if _work_cue == &"" or _work_synced:
		return
	audio.play(_work_cue)
	_work_left = _interval()
	if duration_sec <= 0.0:
		_work_cue = &""


func _on_action_finished(_completed: bool) -> void:
	_work_cue = &""
	_work_synced = false


## The running action's work cue once, now (the player's tool clip calls it when the blade bites).
func work_beat() -> void:
	if _work_cue != &"" and _work_synced and not get_tree().paused:
		audio.play(_work_cue)


func _interval() -> float:
	return float(map.work_intervals.get(_work_cue, map.work_interval)) * randf_range(0.9, 1.1)


func _process(delta: float) -> void:
	_watch_hands()
	if _work_cue == &"" or _work_synced or get_tree().paused:
		return
	_work_left -= delta
	if _work_left <= 0.0:
		_work_left = _interval()
		audio.play(_work_cue)


# --- the gravekeeper's hands -----------------------------------------------------------

func _watch_hands() -> void:
	var player := audio.player()
	var now: Node3D = player.carried if player != null and is_instance_valid(player.carried) else null
	var before: Node3D = _carried.get_ref() as Node3D if _carried != null else null
	if now == before:
		return
	if now != null:
		_carried = weakref(now)
		_carried_was_corpse = now is Corpse
		if not audio.settling():
			audio.play(map.corpse_pickup_cue if _carried_was_corpse else map.pickup_cue)
	else:
		_carried = null
		if not audio.settling():
			audio.play(map.corpse_putdown_cue if _carried_was_corpse else map.putdown_cue)


# --- UI & hooks ------------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node.has_meta(META_HOOKED):
		return
	if node is BaseButton or node is UIPanel or node is MorgueTable:
		node.set_meta(META_HOOKED, true)
	if node is BaseButton:
		var b := node as BaseButton
		b.pressed.connect(_on_button_pressed.bind(b))
		b.mouse_entered.connect(_on_button_hovered.bind(b))
	elif node is UIPanel:
		var panel := node as UIPanel
		panel.visibility_changed.connect(_on_panel_visibility.bind(panel))
	elif node is MorgueTable:
		var table := node as MorgueTable
		if not table.sound_hook.is_valid():
			table.sound_hook = audio.play_hook


func _on_button_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	var panel := _panel_of(button)
	if panel != null and panel.panel_id in map.page_panels:
		audio.play(map.page_cue)
	else:
		audio.play(map.button_press)


func _on_button_hovered(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.disabled and button.is_visible_in_tree():
		audio.play(map.button_hover)


func _on_panel_visibility(panel: UIPanel) -> void:
	if not is_instance_valid(panel) or panel.panel_id == &"" or audio.settling():
		return
	if panel.visible:
		audio.play(map.panel_open_cues.get(panel.panel_id, map.panel_open))
	else:
		audio.play(map.panel_close_cues.get(panel.panel_id, map.panel_close))


static func _panel_of(node: Node) -> UIPanel:
	var n := node.get_parent()
	while n != null:
		if n is UIPanel:
			return n as UIPanel
		n = n.get_parent()
	return null


func _input(event: InputEvent) -> void:
	if not UIState.is_open(&"journal"):
		return
	if event.is_action_pressed(&"journal_page_prev") or event.is_action_pressed(&"journal_page_next"):
		audio.play(map.page_cue)
