class_name GravePlot
extends Node3D
## One grave place (group grave_plot). Visual follows the GraveRecord state (grave_state_changed):
## EMPTY staked plot · DUG open pit · FILLED fresh mound · MARKED mound + marker at the head (−Z)
## · OLD (is_old) the layout's stone + mound, no interaction · LOCKED (section not yet unlocked,
## Phase 3) nothing: no visual, no collision, no prompt.
## Interaction: dig (EMPTY, free hands) → bury (DUG, carrying) → place marker (FILLED, free
## hands; a choice panel when both marker types are in the inventory) → upgrade the marker
## (MARKED with a wooden cross and a better marker in the inventory, Phase 3). The Graveyard
## owns the records; this node only starts the timed actions and calls it.
## Optional child "Collision" (StaticBody3D, added by the world builder): its shapes carry the
## meta "role" (pit, mound, marker:<id>, old) and are enabled for the matching state
## (visual and colliders: grave_plot_visuals.gd).

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
## Gap (m) between the ground and the capsule when testing an exit spot for obstacles.
const EXIT_CLEARANCE := 0.1

const PROMPT_DIG := "[E] Grab ausheben (%d Min)"
const PROMPT_BURY := "[E] Bestatten (%d Min)"
const PROMPT_FETCH := "Offenes Grab – Leiche holen"
const PROMPT_MARKER_ONE := "[E] %s setzen (%d Min)"
const PROMPT_MARKER_CHOICE := "[E] Grabzeichen setzen (%d Min)"
const PROMPT_NO_MARKER := "Kein Grabzeichen – Werkbank"
const PROMPT_CORPSE_HERE := "Hier liegt eine Leiche – erst wegtragen"
const PROMPT_INFO := "Grab von %s – Qualität %d/%d"
const PROMPT_UPGRADE := "[E] %s statt %s setzen (%d Min)"
const LABEL_DIG := "Grab ausheben"
const LABEL_BURY := "Bestatten"
const LABEL_MARKER := "%s setzen"
const LABEL_UPGRADE := "%s statt %s setzen"
const TEXT_CANNOT_MARK := "Das Grabzeichen kann hier nicht gesetzt werden."
# Phase 5 (docs/PHASE5_DESIGN.md §2.5, §3.4): a designed stone from the mason's rack.
const STONEMASONRY_GROUP := &"stonemasonry"
const PROMPT_SET_STONE := "[E] Gestalteten Stein setzen (%d Min)"
const LABEL_SET_STONE := "Gestalteten Stein setzen"
const TEXT_CANNOT_SET_STONE := "Der Stein passt hier nicht mehr."
const NAME_UNKNOWN := "Unbekannt"

@export var grave_id: String = ""
@export var is_old: bool = false
## Phase 3: section of this plot; plots of a locked section are LOCKED
## (no visuals, no collision, no prompt).
@export var section_id: StringName = &"yard"
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
## Phase 5: StoneDesign.to_dict of the grave ({} = none) – drives the designed-stone visual.
var design: Dictionary = {}

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

## Builds the state visual and toggles the colliders (grave_plot_visuals.gd).
var _visuals: GravePlotVisuals
## Player of the last marker-choice request (request_marker runs the action for them).
var _player: Player


func _init() -> void:
	add_to_group(GROUP, true)
	_visuals = GravePlotVisuals.new(self)


func _ready() -> void:
	EventBus.grave_state_changed.connect(_on_grave_state_changed)
	EventBus.grave_quality_changed.connect(_on_grave_quality_changed)
	if is_old:
		state = GraveRecord.State.OLD
		if interactable != null:
			interactable.enabled = false
			interactable.monitorable = false
	else:
		var grave := _grave()
		state = grave.state if grave != null else GraveRecord.State.EMPTY
		marker_id = grave.marker_id if grave != null else &""
		design = grave.design.duplicate(true) if grave != null else {}
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
			return not _is_carrying(player) and (has_stone_to_set() or not available_markers(player.inventory).is_empty())
		GraveRecord.State.MARKED:
			return not _is_carrying(player) and (has_stone_to_set() or upgrade_marker_id(player.inventory) != &"")
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
			if has_stone_to_set():
				return PROMPT_SET_STONE % _stone_config().set_minutes
			var options := available_markers(player.inventory if player != null else null)
			if options.is_empty():
				return PROMPT_NO_MARKER
			if options.size() == 1:
				return PROMPT_MARKER_ONE % [_item_name(options[0]), _actions(player).marker_minutes]
			return PROMPT_MARKER_CHOICE % _actions(player).marker_minutes
		GraveRecord.State.MARKED:
			if has_stone_to_set() and not carrying:
				return PROMPT_SET_STONE % _stone_config().set_minutes
			var better := upgrade_marker_id(player.inventory if player != null else null)
			if better != &"" and not carrying:
				return PROMPT_UPGRADE % [_item_name(better), _item_name(grave.marker_id), _actions(player).marker_minutes]
			return PROMPT_INFO % [_buried_name(grave), grave.quality, _economy().quality_max]
	return ""


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var grave := _grave()
	var actions := _actions(player)
	if (grave.state == GraveRecord.State.FILLED or grave.state == GraveRecord.State.MARKED) and has_stone_to_set():
		player.start_timed_action(LABEL_SET_STONE, _stone_config().set_minutes, _finish_set_stone.bind(player.inventory),
				true, ANIM_MARKER)
		return
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
		GraveRecord.State.MARKED:
			var better := upgrade_marker_id(player.inventory)
			player.start_timed_action(LABEL_UPGRADE % [_item_name(better), _item_name(grave.marker_id)], actions.marker_minutes,
					_finish_upgrade.bind(better, player.inventory), true, ANIM_MARKER)


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
		if not StoneDesignRules.is_shape(id) and inv.has(id):
			out.append(id)
	return out


## The best marker in `inv` that upgrades this MARKED grave (Graveyard.upgrade_options), &"" = none.
func upgrade_marker_id(inv: Inventory) -> StringName:
	var graveyard := _graveyard()
	if graveyard == null or inv == null:
		return &""
	var options := graveyard.upgrade_options(grave_id, inv)
	return options.back() if not options.is_empty() else &""


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


## Keeps the player out of the new pit collision: moves them to the nearest edge of the grown
## footprint where their capsule is free of world bodies – plots stand 2.4 m apart along X,
## so a ±X exit can lie inside the neighbour's mound or pit (C4). None free: the nearer ±Z exit.
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
	var best := exits[2] if exits[2].distance_squared_to(p) < exits[3].distance_squared_to(p) else exits[3]
	exits.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(p) < b.distance_squared_to(p))
	for e: Vector2 in exits:
		if _exit_is_free(player, to_global(Vector3(e.x, local.y, e.y))):
			best = e
			break
	player.global_position = to_global(Vector3(best.x, local.y, best.y))


## Whether the player's capsule, standing at `spot` (lifted by EXIT_CLEARANCE off the ground),
## touches no world body (layer 1) other than this plot's own collision.
func _exit_is_free(player: Player, spot: Vector3) -> bool:
	var capsule := player.get_node_or_null(^"Collision") as CollisionShape3D
	if capsule == null or capsule.shape == null:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	query.collision_mask = Player.WORLD_MASK
	query.transform = Transform3D(Basis.IDENTITY, spot + Vector3(0.0, EXIT_CLEARANCE, 0.0)) * capsule.transform
	var own := get_node_or_null(^"Collision") as CollisionObject3D
	if own != null:
		query.exclude = [own.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Phase 5: a finished stone for this grave waits in the mason's rack and still is an improvement
## (Stonemasonry.ready_for → fits_still). It takes precedence over inventory markers (§3.4).
func has_stone_to_set() -> bool:
	var masonry := _stonemasonry()
	if masonry == null:
		return false
	var order := masonry.ready_for(grave_id)
	return not order.is_empty() and bool(order.get("fits_still", false))


func _finish_set_stone(inv: Inventory) -> void:
	var masonry := _stonemasonry()
	if masonry == null or masonry.set_stone(grave_id, inv) <= 0:
		EventBus.notification_requested.emit(TEXT_CANNOT_SET_STONE, &"warning")


func _finish_upgrade(id: StringName, inv: Inventory) -> void:
	var graveyard := _graveyard()
	if graveyard != null and graveyard.upgrade_marker(grave_id, id, inv) <= 0:
		EventBus.notification_requested.emit(TEXT_CANNOT_MARK, &"warning")


# --- visuals & collision ------------------------------------------------------------------

func _on_grave_state_changed(id: String, new_state: int) -> void:
	if id != grave_id or is_old:
		return
	state = new_state
	var grave := _grave()
	marker_id = grave.marker_id if grave != null else &""
	design = grave.design.duplicate(true) if grave != null else {}
	_apply_visual()


## Marker upgrade: same state, new marker model.
func _on_grave_quality_changed(id: String, _quality: int) -> void:
	if id != grave_id or is_old:
		return
	var grave := _grave()
	marker_id = grave.marker_id if grave != null else marker_id
	design = grave.design.duplicate(true) if grave != null else design
	_apply_visual()


## Visual + colliders; a LOCKED plot also switches its Interactable off.
func _apply_visual() -> void:
	_visuals.apply()
	if interactable != null and not is_old:
		var open := state != GraveRecord.State.LOCKED
		interactable.enabled = open
		interactable.set_deferred(&"monitorable", open)


## Shapes that are active for the current state (for tests / debugging).
func active_collision_roles() -> PackedStringArray:
	return GravePlotVisuals.active_roles(self)


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


func _stonemasonry() -> Stonemasonry:
	return get_tree().get_first_node_in_group(STONEMASONRY_GROUP) as Stonemasonry if is_inside_tree() else null


static func _stone_config() -> StoneConfig:
	var cfg := Database.config(&"stone_config") as StoneConfig
	return cfg if cfg != null else StoneConfig.new()


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
