class_name GateBell
extends Node3D
## G8 Runde 1 (B8-1, user decision): the little bell on the east gate post (ph_prop_gate_bell, layout
## phase8.gate_bell). When a visitor comes up (EventBus.visitor_changed … &"arriving" – households and the villagers
## who visit their dead) it rings: the cue VisitorConfig.bell_cue at the gate, the child mesh `bell` swings, and – only
## while the gravekeeper is on the graveyard (region graveyard, rooms included) – the HUD note „Am Tor läutet es –
## Martha Kehr kommt herauf." A load announces nothing, so a loaded visit does not ring again. No game state.

const GROUP := &"gate_bell"
const NOTE := "Am Tor läutet es – %s kommt herauf."
const NOTE_KIND := &"info"
const PHASE_ARRIVING := &"arriving"
const REGION := &"graveyard"
const DEFAULT_CUE := &"gate_bell"
## The swing of the bell (radians about the arm, seconds of real time per half swing).
const SWING: PackedFloat32Array = [0.55, -0.42, 0.3, -0.18, 0.08, 0.0]
const SWING_SECONDS := 0.22

## Rings so far (tests, the screenshot director).
var rings: int = 0
var last_note: String = ""
var _tween: Tween


func _init() -> void:
	add_to_group(GROUP, true)


func _ready() -> void:
	EventBus.visitor_changed.connect(_on_visitor_changed)


## The swinging part (the child mesh `bell` of the model), or null.
func bell_node() -> Node3D:
	var model := get_node_or_null(^"Model")
	return model.find_child("bell", true, false) as Node3D if model != null else null


## Rings for `display_name`: the cue at the gate, the swing, the note (on the graveyard only). Returns whether a note
## went out.
func ring(display_name: String) -> bool:
	rings += 1
	var audio := get_node_or_null(^"/root/Audio")
	if audio != null and audio.has_method(&"play") and is_inside_tree():
		audio.call(&"play", _cue(), global_position + Vector3(0, 1.6, 0))
	_swing()
	if display_name == "" or not _player_on_graveyard():
		return false
	last_note = NOTE % display_name
	EventBus.notification_requested.emit(last_note, NOTE_KIND)
	return true


func _on_visitor_changed(_visit_id: String, kin_id: StringName, _grave_id: String, phase: StringName) -> void:
	if phase != PHASE_ARRIVING:
		return
	var kin := Database.kin(kin_id) as KinData
	ring(kin.display_name if kin != null else "")


func _swing() -> void:
	var bell := bell_node()
	if bell == null or not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	bell.rotation.z = 0.0
	_tween = create_tween()
	for a: float in SWING:
		_tween.tween_property(bell, "rotation:z", a, SWING_SECONDS).set_trans(Tween.TRANS_SINE)


func _player_on_graveyard() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	return player != null and StringName(str(player.get(&"region_id"))) == REGION


func _cue() -> StringName:
	var cfg := Database.config(&"visitor_config") as VisitorConfig
	return cfg.bell_cue if cfg != null and cfg.bell_cue != &"" else DEFAULT_CUE
