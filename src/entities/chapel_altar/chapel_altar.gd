class_name ChapelAltar
extends Node3D
## The altar inside the chapel (docs/PHASE6_DESIGN.md §2.4, §3.4), group &"chapel_altar": „[E]
## Aussegnung halten (45 Min)" while the catafalque is occupied → panel &"chapel" {corpse_id, altar,
## inventory, player}; otherwise „[E] Andacht halten" → panel &"devotion" {altar, inventory, player}.
## The panels call request_service / request_devotion: a TimedAction that cannot be cancelled
## (animation interact) → ChapelRites.hold_service / hold_devotion at its end. During a service the
## mourners of the chapel level sit in the pews (MournerSet). rite_active is true while a service or
## a devotion runs (the room's lighting lights the altar candles from it).

const GROUP := &"chapel_altar"
const RITES_GROUP := &"chapel_rites"
const CATAFALQUE_GROUP := &"catafalque"
const MOURNERS_GROUP := &"mourner_set"
const PANEL_SERVICE := &"chapel"
const PANEL_DEVOTION := &"devotion"
const PROMPT_SERVICE := "[E] Aussegnung halten (%d Min)"
const PROMPT_DEVOTION := "[E] Andacht halten"
const LABEL_SERVICE := "Aussegnung"
const LABEL_DEVOTION := "Andacht"
const TEXT_BUSY := "Gerade nicht möglich."
const ANIM := &"interact"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

## True while a service or a devotion runs at this altar (not saved).
var rite_active: bool = false

## Player of the last interaction (the panels act for them).
var _player: Player


func _init() -> void:
	add_to_group(GROUP, true)


## A free player with empty hands in a chapel of level ≥ 1.
func can_interact(player: Player) -> bool:
	if player == null or player.is_busy() or is_instance_valid(player.carried):
		return false
	var rites := _rites()
	return rites != null and rites.level() >= 1


func get_interaction_prompt(player: Player) -> String:
	if not can_interact(player):
		return ""
	if _corpse_id() != "":
		return PROMPT_SERVICE % _rites().get_config().service_minutes
	return PROMPT_DEVOTION


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	_player = player
	var id := _corpse_id()
	if id != "":
		EventBus.ui_panel_requested.emit(PANEL_SERVICE, {"corpse_id": id, "altar": self, "inventory": player.inventory, "player": player})
	else:
		EventBus.ui_panel_requested.emit(PANEL_DEVOTION, {"altar": self, "inventory": player.inventory, "player": player})


## Panel &"chapel": the service for the corpse on the catafalque (the time window counts at the start).
func request_service() -> void:
	var rites := _rites()
	var player := _acting_player()
	if rites == null or not _can_act(player):
		_warn(TEXT_BUSY)
		return
	var id := _corpse_id()
	var reason := rites.service_block_reason(id, player.inventory)
	if reason != "":
		_warn(reason)
		return
	var cfg := rites.get_config()
	var mourners := _mourners()
	rite_active = true
	if mourners != null:
		mourners.show_mourners(ChapelRules.mourners(rites.level(), cfg))
	if not player.start_timed_action(LABEL_SERVICE, cfg.service_minutes, _finish_service.bind(id, player.inventory), false, ANIM):
		_end_rite()
		_warn(TEXT_BUSY)


## Panel &"devotion": a devotion for `grave_id` (any time of day).
func request_devotion(grave_id: String) -> void:
	var rites := _rites()
	var player := _acting_player()
	if rites == null or not _can_act(player):
		_warn(TEXT_BUSY)
		return
	var reason := rites.devotion_block_reason(grave_id, player.inventory)
	if reason != "":
		_warn(reason)
		return
	rite_active = true
	if not player.start_timed_action(LABEL_DEVOTION, rites.get_config().devotion_minutes, _finish_devotion.bind(grave_id, player.inventory),
			false, ANIM):
		_end_rite()
		_warn(TEXT_BUSY)


## Corpse id on the catafalque ("" = none).
func _corpse_id() -> String:
	var catafalque := _first(CATAFALQUE_GROUP) as Catafalque
	return catafalque.occupant() if catafalque != null else ""


func _finish_service(id: String, inv: Inventory) -> void:
	var rites := _rites()
	var fee := rites.hold_service(id, inv) if rites != null else -1
	_end_rite()
	if fee < 0:
		_warn(TEXT_BUSY)


func _finish_devotion(grave_id: String, inv: Inventory) -> void:
	var rites := _rites()
	var ok := rites != null and rites.hold_devotion(grave_id, inv)
	_end_rite()
	if not ok:
		_warn(TEXT_BUSY)


func _end_rite() -> void:
	rite_active = false
	var mourners := _mourners()
	if mourners != null and mourners.shown_count() > 0:
		mourners.hide_mourners()


func _acting_player() -> Player:
	if is_instance_valid(_player):
		return _player
	return _first(&"player") as Player


func _can_act(player: Player) -> bool:
	return player != null and not player.is_busy() and not is_instance_valid(player.carried)


func _rites() -> ChapelRites:
	return _first(RITES_GROUP) as ChapelRites


func _mourners() -> MournerSet:
	return _first(MOURNERS_GROUP) as MournerSet


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _warn(text: String) -> void:
	EventBus.notification_requested.emit(text, &"warning")
