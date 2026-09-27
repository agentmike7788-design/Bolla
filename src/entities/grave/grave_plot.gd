class_name GravePlot
extends Node3D
## One grave place (group grave_plot). Visual follows the GraveRecord state (grave_state_changed):
## EMPTY staked plot · DUG open pit · FILLED fresh mound · MARKED mound + marker at the head (−Z)
## · OLD (is_old) the layout's stone + mound, no interaction.
## Interaction: dig (EMPTY, free hands) → bury (DUG, carrying) → place marker (FILLED, free
## hands; a choice panel when both marker types are in the inventory). The Graveyard owns the
## records; this node only starts the timed actions and calls it.
## Optional child "Collision" (StaticBody3D, added by the world builder): its shapes carry the
## meta "role" (pit, mound, marker:<id>, old) and are enabled for the matching state.

const GROUP := &"grave_plot"
const GRAVEYARD_GROUP := &"graveyard"
const MANAGER_GROUP := &"corpse_manager"
const MARKER_PANEL := &"marker_choice"
const ANIM_DIG := &"dig"
const ANIM_MARKER := &"interact"
const ROLE_META := &"role"
const ROLE_PIT := "pit"
const ROLE_MOUND := "mound"
const ROLE_MARKER := "marker:"
const ROLE_OLD := "old"
const OLD_STONE_PATH := "res://assets/models/props/ph_prop_gravestone_%s.glb"
const OLD_MOUND_PATH := "res://assets/models/props/ph_prop_grave_mound_%s.glb"

const PROMPT_DIG := "[E] Grab ausheben (%d Min)"
const PROMPT_BURY := "[E] Bestatten (%d Min)"
const PROMPT_FETCH := "Offenes Grab – Leiche holen"
const PROMPT_MARKER_ONE := "[E] %s setzen (%d Min)"
const PROMPT_MARKER_CHOICE := "[E] Grabzeichen setzen (%d Min)"
const PROMPT_NO_MARKER := "Kein Grabzeichen – Werkbank"
const PROMPT_CORPSE_HERE := "Hier liegt eine Leiche – erst wegtragen"
const PROMPT_INFO := "Grab von %s – Qualität %d/%d"
const LABEL_DIG := "Grab ausheben"
const LABEL_BURY := "Bestatten"
const LABEL_MARKER := "%s setzen"
const TEXT_CANNOT_MARK := "Das Grabzeichen kann hier nicht gesetzt werden."
const NAME_UNKNOWN := "Unbekannt"

@export var grave_id: String = ""
@export var is_old: bool = false
@export_group("Old grave")
## Layout variants of an old grave: ph_prop_gravestone_<old_stone>, ph_prop_grave_mound_<old_mound>.
@export var old_stone: String = ""
@export var old_mound: String = ""
## Stone position of the approved art-prototype graves (head end).
@export var old_stone_offset: Vector3 = Vector3(0, 0, -1.12)
@export_group("Visuals")
@export var empty_model: PackedScene = preload("res://assets/models/props/ph_prop_grave_plot_empty.glb")
@export var pit_model: PackedScene = preload("res://assets/models/props/ph_prop_grave_pit.glb")
@export var mound_model: PackedScene = preload("res://assets/models/props/ph_prop_grave_mound_fresh.glb")
@export var marker_models: Dictionary[StringName, PackedScene] = {
	&"wooden_cross": preload("res://assets/models/props/ph_prop_cross_wood.glb"),
	&"gravestone_simple": preload("res://assets/models/props/ph_prop_gravestone_round.glb"),
}
## The Phase-1 mound meshes sit 0.1 m towards −Z; this centres them on the 1 × 2 m footprint.
@export var mound_offset: Vector3 = Vector3(0, 0, 0.1)
## Marker at the head end, same relation to the mound as the prototype stones.
@export var marker_offset: Vector3 = Vector3(0, 0, -1.02)
@export_group("Footprint")
## Plot-local XZ area of the open pit incl. its earth heap (+X). The player is moved out of
## it after digging; a corpse lying inside blocks digging.
@export var footprint: Rect2 = Rect2(-0.72, -1.25, 2.32, 2.5)
## Extra distance (player capsule) kept from the footprint when moving the player out.
@export var eject_margin: float = 0.35

## Current visual state (GraveRecord.State).
var state: int = GraveRecord.State.EMPTY
var marker_id: StringName = &""

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

var _visual: Node3D
var _visual_key: String = ""
## Player of the last marker-choice request (request_marker runs the action for them).
var _player: Player


func _init() -> void:
	add_to_group(GROUP, true)


func _ready() -> void:
	EventBus.grave_state_changed.connect(_on_grave_state_changed)
	if is_old:
		state = GraveRecord.State.OLD
		if interactable != null:
			interactable.enabled = false
			interactable.monitorable = false
	else:
		var grave := _grave()
		state = grave.state if grave != null else GraveRecord.State.EMPTY
		marker_id = grave.marker_id if grave != null else &""
	_apply_visual()


func can_interact(player: Player) -> bool:
	if is_old or player == null or player.is_busy():
		return false
	var grave := _grave()
	if grave == null:
		return false
	match grave.state:
		GraveRecord.State.EMPTY:
			return not _is_carrying(player) and not _corpse_on_plot()
		GraveRecord.State.DUG:
			return _is_carrying(player)
		GraveRecord.State.FILLED:
			return not _is_carrying(player) and not available_markers(player.inventory).is_empty()
	return false


func get_interaction_prompt(player: Player) -> String:
	if is_old:
		return ""
	var grave := _grave()
	if grave == null:
		return ""
	var carrying := player != null and _is_carrying(player)
	match grave.state:
		GraveRecord.State.EMPTY:
			if carrying:
				return Player.TEXT_HANDS_FULL
			if _corpse_on_plot():
				return PROMPT_CORPSE_HERE
			return PROMPT_DIG % _actions(player).dig_minutes
		GraveRecord.State.DUG:
			return PROMPT_BURY % _actions(player).bury_minutes if carrying else PROMPT_FETCH
		GraveRecord.State.FILLED:
			if carrying:
				return Player.TEXT_HANDS_FULL
			var options := available_markers(player.inventory if player != null else null)
			if options.is_empty():
				return PROMPT_NO_MARKER
			if options.size() == 1:
				return PROMPT_MARKER_ONE % [_item_name(options[0]), _actions(player).marker_minutes]
			return PROMPT_MARKER_CHOICE % _actions(player).marker_minutes
		GraveRecord.State.MARKED:
			return PROMPT_INFO % [_buried_name(grave), grave.quality, _economy().quality_max]
	return ""


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var grave := _grave()
	var actions := _actions(player)
	match grave.state:
		GraveRecord.State.EMPTY:
			player.start_timed_action(LABEL_DIG, actions.dig_minutes, _finish_dig.bind(player), true, ANIM_DIG)
		GraveRecord.State.DUG:
			player.start_timed_action(LABEL_BURY, actions.bury_minutes, _finish_bury.bind(player.carried_id), true, ANIM_DIG)
		GraveRecord.State.FILLED:
			var options := available_markers(player.inventory)
			if options.size() == 1:
				_start_marker(player, options[0], true)
			else:
				_player = player
				EventBus.ui_panel_requested.emit(MARKER_PANEL, {"grave_id": grave_id, "plot": self, "options": options})


## Marker-choice panel: places `id` (timed, not cancellable) for the player who asked.
func request_marker(id: StringName) -> void:
	var player := _player if is_instance_valid(_player) else _first_player()
	var grave := _grave()
	if player == null or grave == null or grave.state != GraveRecord.State.FILLED or player.is_busy() \
			or _is_carrying(player) or not id in available_markers(player.inventory):
		EventBus.notification_requested.emit(TEXT_CANNOT_MARK, &"warning")
		return
	_start_marker(player, id, false)


## Marker items in `inv`, in EconomyConfig.marker_quality order (e.g. wooden_cross, gravestone_simple).
func available_markers(inv: Inventory) -> Array[StringName]:
	var out: Array[StringName] = []
	if inv == null:
		return out
	for id: StringName in _economy().marker_quality:
		if inv.has(id):
			out.append(id)
	return out


func _start_marker(player: Player, id: StringName, cancellable: bool) -> void:
	player.start_timed_action(LABEL_MARKER % _item_name(id), _actions(player).marker_minutes,
			_finish_marker.bind(id, player.inventory), cancellable, ANIM_MARKER)


func _finish_dig(player: Player) -> void:
	var graveyard := _graveyard()
	if graveyard != null and graveyard.dig(grave_id):
		_move_out(player)


func _finish_bury(corpse_id: String) -> void:
	var graveyard := _graveyard()
	if graveyard != null:
		graveyard.bury(grave_id, corpse_id)


func _finish_marker(id: StringName, inv: Inventory) -> void:
	var graveyard := _graveyard()
	if graveyard != null:
		graveyard.place_marker(grave_id, id, inv)


## Keeps the player out of the new pit collision: moves them to the nearest footprint edge.
func _move_out(player: Player) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var local := to_local(player.global_position)
	var area := footprint.grow(eject_margin)
	var p := Vector2(local.x, local.z)
	if not area.has_point(p):
		return
	var exits: Array[Vector2] = [Vector2(area.position.x, p.y), Vector2(area.end.x, p.y),
			Vector2(p.x, area.position.y), Vector2(p.x, area.end.y)]
	var best := exits[0]
	for e: Vector2 in exits:
		if e.distance_squared_to(p) < best.distance_squared_to(p):
			best = e
	player.global_position = to_global(Vector3(best.x, local.y, best.y))


# --- visuals & collision ------------------------------------------------------------------

func _on_grave_state_changed(id: String, new_state: int) -> void:
	if id != grave_id or is_old:
		return
	state = new_state
	var grave := _grave()
	marker_id = grave.marker_id if grave != null else &""
	_apply_visual()


func _apply_visual() -> void:
	var key := "%d:%s" % [state, marker_id]
	if key == _visual_key and _visual != null:
		return
	_visual_key = key
	if _visual != null:
		remove_child(_visual)
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	move_child(_visual, 0)
	var roles: PackedStringArray = []
	match state:
		GraveRecord.State.EMPTY:
			_add_model(empty_model, Vector3.ZERO)
		GraveRecord.State.DUG:
			_add_model(pit_model, Vector3.ZERO)
			roles.append(ROLE_PIT)
		GraveRecord.State.FILLED, GraveRecord.State.MARKED:
			_add_model(mound_model, mound_offset)
			roles.append(ROLE_MOUND)
			if state == GraveRecord.State.MARKED and marker_models.has(marker_id):
				_add_model(marker_models[marker_id], marker_offset)
				roles.append(ROLE_MARKER + String(marker_id))
		GraveRecord.State.OLD:
			_add_model(_load_scene(OLD_MOUND_PATH % old_mound), Vector3.ZERO)
			_add_model(_load_scene(OLD_STONE_PATH % old_stone), old_stone_offset)
			roles.append(ROLE_OLD)
	_update_collision(roles)


func _add_model(scene: PackedScene, offset: Vector3) -> void:
	if scene == null:
		return
	var inst := scene.instantiate() as Node3D
	inst.position = offset
	_visual.add_child(inst)


func _load_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		push_warning("[GravePlot] %s: model '%s' not found" % [grave_id, path])
		return null
	return load(path) as PackedScene


## Enables the builder-made collision shapes whose "role" meta is in `roles`.
func _update_collision(roles: PackedStringArray) -> void:
	var body := get_node_or_null(^"Collision")
	if body == null:
		return
	for shape: Node in body.get_children():
		if shape is CollisionShape3D:
			var role := String(shape.get_meta(ROLE_META, ""))
			shape.set_deferred(&"disabled", not role in roles)


## Shapes that are active for the current state (for tests / debugging).
func active_collision_roles() -> PackedStringArray:
	var out: PackedStringArray = []
	var body := get_node_or_null(^"Collision")
	if body == null:
		return out
	for shape: Node in body.get_children():
		if shape is CollisionShape3D and not (shape as CollisionShape3D).disabled:
			var role := String(shape.get_meta(ROLE_META, ""))
			if not role in out:
				out.append(role)
	return out


# --- lookups ------------------------------------------------------------------------------

func _corpse_on_plot() -> bool:
	var manager := _manager()
	if manager == null:
		return false
	for record: CorpseRecord in manager.records():
		if record.location != CorpseRecord.LOCATION_GROUND:
			continue
		var local := to_local(record.position)
		if footprint.has_point(Vector2(local.x, local.z)):
			return true
	return false


func _buried_name(grave: GraveRecord) -> String:
	var manager := _manager()
	var record: CorpseRecord = manager.get_record(grave.corpse_id) if manager != null else null
	return record.display_name if record != null and record.display_name != "" else NAME_UNKNOWN


func _item_name(id: StringName) -> String:
	var item := Database.item(id) as ItemData if Database.has_item(id) else null
	return item.display_name if item != null and item.display_name != "" else String(id)


func _grave() -> GraveRecord:
	var graveyard := _graveyard()
	return graveyard.get_grave(grave_id) if graveyard != null else null


func _graveyard() -> Graveyard:
	return get_tree().get_first_node_in_group(GRAVEYARD_GROUP) as Graveyard if is_inside_tree() else null


func _manager() -> CorpseManager:
	return get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager if is_inside_tree() else null


func _first_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null


## The Graveyard's EconomyConfig when it has one (tests inject fixtures), else the data file.
func _economy() -> EconomyConfig:
	var graveyard := _graveyard()
	if graveyard != null and graveyard.economy != null:
		return graveyard.economy
	var cfg := Database.config(&"economy_config") as EconomyConfig
	return cfg if cfg != null else EconomyConfig.new()


static func _actions(player: Player) -> ActionConfig:
	if player != null and player.actions != null:
		return player.actions
	var cfg := Database.config(&"action_config") as ActionConfig
	return cfg if cfg != null else ActionConfig.new()


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)
