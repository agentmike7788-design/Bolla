class_name WatchSpot
extends Node3D
## A place in the shadow to watch a sick house (docs/PHASE8_DESIGN.md §1.3, §3.1, §3.4, §4.6 D2): watch_ott
## (under the Remise eaves), watch_kehr (west corner of the office); the prompt only in nights with a sick
## light: „[E] Im Schatten warten (bis ≈ 22:20)" → a timed action of NightPaths.wait_minutes (≤ 120, abortable)
## – the night visit itself is watched in real time afterwards (nothing is skipped).

const PROMPT_FORMAT := "[E] Im Schatten warten (bis ≈ %s)"
const LABEL := "Im Schatten warten"
const NIGHT_PATHS_GROUP := &"night_paths"
const ANIM := &"idle"

@export var spot_id: StringName = &""

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	_update_interactable()


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and not is_instance_valid(player.carried) and minutes() > 0


func get_interaction_prompt(player: Player) -> String:
	var m := minutes()
	if m <= 0 or player == null:
		return ""
	if is_instance_valid(player.carried):
		return Player.TEXT_HANDS_FULL
	return PROMPT_FORMAT % clock_after(m)


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	player.start_timed_action(LABEL, minutes(), _noop, true, ANIM)


## Minutes to wait here now (0 = no sick light tonight / nothing to wait for).
func minutes() -> int:
	var paths := get_tree().get_first_node_in_group(NIGHT_PATHS_GROUP) as NightPaths if is_inside_tree() else null
	return paths.wait_minutes(spot_id) if paths != null else 0


## „hh:mm" `m` minutes from now.
static func clock_after(m: int) -> String:
	var t := posmod(TimeManager.minute_of_day + m, 1440)
	return "%02d:%02d" % [floori(t / 60.0), t % 60]


func _noop() -> void:
	pass


func _on_time_tick(_day: int, _minute: int) -> void:
	_update_interactable()


func _update_interactable() -> void:
	if interactable == null:
		return
	var open := minutes() > 0
	if interactable.enabled != open:
		interactable.enabled = open
		interactable.set_deferred(&"monitorable", open)
