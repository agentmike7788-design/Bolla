class_name GravePlot
extends Node3D
## One grave place (group grave_plot). Visual follows the GraveRecord state (grave_state_changed):
## EMPTY staked plot · DUG open pit · FILLED fresh mound · MARKED mound + marker at the head (−Z)
## · OLD (is_old) the layout's stone + mound · LOCKED (section not yet unlocked, Phase 3) nothing:
## no visual, no collision, no prompt.
## Phase 6 (§2.3, §3.4): an OLD plot has no interaction until buildings_open; then „[E] Altes Grab
## heben: <Name> (Jahre)" (or the block reason, dimmed) → Ossuary.lift → Graveyard.lift_old
## (OLD → EMPTY). From then on it is an ordinary place (is_old stays true: it is still an old
## plot); pit_variant &"foot" puts the spoil heap at the foot end (ph_prop_grave_pit_foot).
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
# Phase 6 (docs/PHASE6_DESIGN.md §2.3, §3.4; P3): lifting an old grave.
const OSSUARY_GROUP := &"ossuary"
const PROMPT_LIFT := "[E] Altes Grab heben: %s"
const LABEL_LIFT := "Altes Grab heben"
const TEXT_CANNOT_LIFT := "Das alte Grab lässt sich nicht heben."
const PIT_FOOT := &"foot"
const PIT_FOOT_PATH := "res://assets/models/props/ph_prop_grave_pit_foot.glb"
# Phase 7 (docs/PHASE7_DESIGN.md §2.5, §2.6.2, §3.4; P4): give a specimen back, a new stone on a
# rest-period grave (against the P3 API Graveyard.replace_old_marker).
const SPECIMENS_GROUP := &"specimens"
const PROMPT_RETURN := "[E] Präparat beisetzen: %s von %s (%d Min)"
const LABEL_RETURN := "Präparat beisetzen"
const TEXT_CANNOT_RETURN := "Das Präparat lässt sich hier nicht beisetzen."
const PROMPT_NEW_STONE := "[E] Neuen Stein setzen (%d Min)"
const LABEL_NEW_STONE := "Neuen Stein setzen"
# Phase 8 (docs/PHASE8_DESIGN.md §1.3, §2.2.5, §2.3, §3.4, §7.5; P2): grave care after the Phase-3–7 prompts in
# this order – coins on the stone (without a TipStone child) · close the disturbed grave · water the flowers ·
# plant grave flowers / lay a wax wreath · light a grave candle · mortsafe on / off · chisel a wish line.
const GRAVE_CARE_GROUP := &"grave_care"
const VISITORS_GROUP := &"visitors"
const APPRENTICE_GROUP := &"apprentice"
const CARE_COINS := &"coins"
const CARE_CLOSE := &"close"
const CARE_WATER := &"water"
const CARE_PLANT := &"plant"
const CARE_WREATH := &"wreath"
const CARE_CANDLE := &"candle"
const CARE_MORTSAFE_ON := &"mortsafe_on"
const CARE_MORTSAFE_OFF := &"mortsafe_off"
const CARE_LINE := &"line"
## §2.4 Liesel 1 (P4's order of_liesel_1, task name_line): Kaspar's real name on the stone of S5.
const CARE_NAME := &"name_line"
const CARE_ORDER: Array[StringName] = [CARE_COINS, CARE_CLOSE, CARE_WATER, CARE_PLANT, CARE_WREATH, CARE_CANDLE, CARE_MORTSAFE_ON,
		CARE_MORTSAFE_OFF, CARE_LINE, CARE_NAME]
const ORDERS_TASK_GROUP := &"orders"
const PROMPT_NAME := "[E] Namen nachmeißeln (%d Min, 1 Tinte)"
const LABEL_NAME := "Namen nachmeißeln"
const NAME_MINUTES := 40
const NAME_FALLBACK := "Kaspar Dorn"
const PROMPT_COINS := "[E] %s"
const PROMPT_CLOSE := "[E] Grab wieder schließen (%d Min)"
const PROMPT_WATER := "[E] Blumen gießen (%d Min)"
const PROMPT_PLANT := "[E] Grabblumen setzen (%d Min)"
const PROMPT_WREATH := "[E] Wachskranz legen (%d Min)"
const PROMPT_CANDLE := "[E] Grabkerze anzünden (%d Min)"
const PROMPT_MORTSAFE_ON := "[E] Grabgitter aufsetzen (%d Min)"
const PROMPT_MORTSAFE_OFF := "[E] Grabgitter abnehmen (%d Min)"
const PROMPT_LINE := "[E] Zeile nachmeißeln: ‚%s' (%d Min)"
const LABEL_CLOSE := "Grab wieder schließen"
const LABEL_WATER := "Blumen gießen"
const LABEL_PLANT := "Grabblumen setzen"
const LABEL_WREATH := "Wachskranz legen"
const LABEL_CANDLE := "Grabkerze anzünden"
const LABEL_MORTSAFE_ON := "Grabgitter aufsetzen"
const LABEL_MORTSAFE_OFF := "Grabgitter abnehmen"
const LABEL_LINE := "Zeile nachmeißeln"
const TEXT_CARE_FAILED := "Das geht hier gerade nicht."
## The flowers ask for water when they are wilted or would wilt within a day (§2.5.2 "heute oder morgen").
const WATER_SOON_MINUTES := 1440
const ANIM_KNEEL := &"kneel_place"
const ANIM_WATER := &"water"

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
## Phase 6 (§2.3, §3.4; P3): &"foot" for the old graves – the spoil heap lies at the foot end
## (ph_prop_grave_pit_foot) once an old grave was lifted and is dug again.
@export var pit_variant: StringName = &""
## Plot-local XZ area of the pit with the heap at the foot end (+Z) – pit_variant &"foot".
@export var foot_footprint: Rect2 = Rect2(-0.72, -1.25, 1.44, 3.38)
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
## Phase 8: lines chiselled on afterwards (GraveRecord.extra_lines) – shown under the carved text.
var extra_lines: PackedStringArray = []

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
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.grave_care_changed.connect(_on_grave_care_changed)
	var grave := _grave()
	if grave != null:
		state = grave.state
	else:
		state = GraveRecord.State.OLD if is_old else GraveRecord.State.EMPTY
	marker_id = grave.marker_id if grave != null else &""
	design = grave.design.duplicate(true) if grave != null else {}
	extra_lines = grave.extra_lines.duplicate() if grave != null else PackedStringArray()
	_apply_visual()


func can_interact(player: Player) -> bool:
	if _base_can_interact(player):
		return true
	return player != null and not player.is_busy() and _care_action(player, true) != &""


func get_interaction_prompt(player: Player) -> String:
	if _base_can_interact(player):
		return _base_prompt(player)
	var care := _care_action(player, false)
	if care != &"":
		return care_prompt(care, player)
	return _base_prompt(player)


func interact(player: Player) -> void:
	if _base_can_interact(player):
		_base_interact(player)
		return
	if player == null or player.is_busy():
		return
	var care := _care_action(player, true)
	if care != &"":
		_start_care(care, player)


func _base_can_interact(player: Player) -> bool:
	if player == null or player.is_busy():
		return false
	var grave := _grave()
	if grave == null:
		return false
	match grave.state:
		GraveRecord.State.OLD:
			if has_old_stone_to_set():
				return not _is_carrying(player)
			return is_old and _lift_open() and not _is_carrying(player) and _lift_block_reason(player) == ""
		GraveRecord.State.EMPTY:
			return not _is_carrying(player) and not _corpse_on_plot()
		GraveRecord.State.DUG:
			return _is_carrying(player)
		GraveRecord.State.FILLED:
			return not _is_carrying(player) and (has_stone_to_set() or returnable_specimen(player.inventory) != ""
					or not available_markers(player.inventory).is_empty())
		GraveRecord.State.MARKED:
			return not _is_carrying(player) and (has_stone_to_set() or returnable_specimen(player.inventory) != ""
					or upgrade_marker_id(player.inventory) != &"")
	return false


func _base_prompt(player: Player) -> String:
	var grave := _grave()
	if grave == null:
		return ""
	var carrying := player != null and _is_carrying(player)
	match grave.state:
		GraveRecord.State.OLD:
			if has_old_stone_to_set():
				return Player.TEXT_HANDS_FULL if carrying else PROMPT_NEW_STONE % _stone_config().set_minutes
			if not is_old or not _lift_open():
				return ""
			if carrying:
				return Player.TEXT_HANDS_FULL
			var reason := _lift_block_reason(player)
			return reason if reason != "" else PROMPT_LIFT % OssuaryRules.label(_ossuary().data_of(grave_id))
		GraveRecord.State.EMPTY:
			if carrying:
				return Player.TEXT_HANDS_FULL
			if _corpse_on_plot():
				return PROMPT_CORPSE_HERE
			return PROMPT_DIG % _dig_minutes(player)
		GraveRecord.State.DUG:
			return PROMPT_BURY % _bury_minutes(player) if carrying else PROMPT_FETCH
		GraveRecord.State.FILLED:
			if carrying:
				return Player.TEXT_HANDS_FULL
			if has_stone_to_set():
				return PROMPT_SET_STONE % _stone_config().set_minutes
			# QA7: the marker first – with a specimen of this dead in the pack the grave could not be
			# marked by [E] at all (and the marker brings the payment); „Präparat beisetzen" follows on MARKED.
			var options := available_markers(player.inventory if player != null else null)
			var back := return_prompt(player.inventory if player != null else null)
			if options.is_empty() and back != "":
				return back
			if options.is_empty():
				return PROMPT_NO_MARKER
			if options.size() == 1:
				return PROMPT_MARKER_ONE % [_item_name(options[0]), _actions(player).marker_minutes]
			return PROMPT_MARKER_CHOICE % _actions(player).marker_minutes
		GraveRecord.State.MARKED:
			if has_stone_to_set() and not carrying:
				return PROMPT_SET_STONE % _stone_config().set_minutes
			var back := return_prompt(player.inventory if player != null else null)
			if back != "" and not carrying:
				return back
			var better := upgrade_marker_id(player.inventory if player != null else null)
			if better != &"" and not carrying:
				return PROMPT_UPGRADE % [_item_name(better), _item_name(grave.marker_id), _actions(player).marker_minutes]
			return PROMPT_INFO % [_buried_name(grave), grave.quality, _economy().quality_max]
	return ""


func _base_interact(player: Player) -> void:
	if not _base_can_interact(player):
		return
	var grave := _grave()
	var actions := _actions(player)
	if (grave.state == GraveRecord.State.FILLED or grave.state == GraveRecord.State.MARKED) and has_stone_to_set():
		player.start_timed_action(LABEL_SET_STONE, _stone_config().set_minutes, _finish_set_stone.bind(player.inventory),
				true, ANIM_MARKER)
		return
	if grave.state == GraveRecord.State.OLD and has_old_stone_to_set():
		player.start_timed_action(LABEL_NEW_STONE, _stone_config().set_minutes, _finish_new_stone, true, ANIM_MARKER)
		return
	var uid := returnable_specimen(player.inventory)
	var marks_first := grave.state == GraveRecord.State.FILLED and not available_markers(player.inventory).is_empty()
	if (grave.state == GraveRecord.State.FILLED or grave.state == GraveRecord.State.MARKED) and uid != "" and not marks_first:
		player.start_timed_action(LABEL_RETURN, _return_minutes(), _finish_return.bind(uid, player.inventory), true, ANIM_MARKER)
		return
	match grave.state:
		GraveRecord.State.OLD:
			player.start_timed_action(LABEL_LIFT, _ossuary().lift_minutes(player.inventory, _actions(player)),
					_finish_lift.bind(player.inventory), true, ANIM_DIG)
		GraveRecord.State.EMPTY:
			if player.start_timed_action(LABEL_DIG, _dig_minutes(player), _finish_dig.bind(player), true, ANIM_DIG):
				_note_noise(&"dig")
		GraveRecord.State.DUG:
			# G7 Runde 2 (Bestatten): he lays the dead into the pit and fills it (PlayerBurial).
			player.start_burial(LABEL_BURY, _bury_minutes(player), _finish_bury.bind(player.carried_id), self)
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
					_finish_upgrade.bind(better, player.inventory), true, ToolAnimConfig.clip_for(&"grave_marker", ANIM_MARKER))


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
			_finish_marker.bind(id, player.inventory), cancellable, ToolAnimConfig.clip_for(&"grave_marker", ANIM_MARKER))


func _finish_dig(player: Player) -> void:
	var graveyard := _graveyard()
	if graveyard != null and graveyard.dig(grave_id):
		_move_out(player)


func _finish_lift(inv: Inventory) -> void:
	var ossuary := _ossuary()
	if ossuary == null or not ossuary.lift(grave_id, inv):
		EventBus.notification_requested.emit(TEXT_CANNOT_LIFT, &"warning")


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
	var area := active_footprint().grow(eject_margin)
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


## G7 Runde 2 (Bestatten): whether the player could stand at `spot` (global, on the ground) – the
## burial step to the pit's side (PlayerBurial.stand_transform).
func spot_is_free(player: Player, spot: Vector3) -> bool:
	return not is_inside_tree() or _exit_is_free(player, spot)


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


## Success = the stone left the rack for this grave (QA5-03): a quality difference of 0 (the
## grave's total clamped at quality_min, e.g. a robbed, rotten corpse) is still a set stone.
func _finish_set_stone(inv: Inventory) -> void:
	var masonry := _stonemasonry()
	var order := masonry.ready_for(grave_id) if masonry != null else {}
	if masonry == null or order.is_empty():
		EventBus.notification_requested.emit(TEXT_CANNOT_SET_STONE, &"warning")
		return
	masonry.set_stone(grave_id, inv)
	var grave := _grave()
	if grave == null or grave.design != (order.design as Dictionary):
		EventBus.notification_requested.emit(TEXT_CANNOT_SET_STONE, &"warning")


# --- Phase 7 (P4): „Präparat beisetzen", „Neuen Stein setzen" -----------------------------------

## The first specimen of the buried dead in `inv` that can go back into this grave ("" = none).
func returnable_specimen(inv: Inventory) -> String:
	var grave := _grave()
	var specimens := _specimens()
	if grave == null or inv == null or specimens == null or grave.corpse_id == "":
		return ""
	for uid: String in specimens.of_corpse(grave.corpse_id):
		if inv.has_uid(uid) and specimens.return_block_reason(uid, grave_id) == "":
			return uid
	return ""


## „[E] Präparat beisetzen: Herz von Hedwig Lamprecht (10 Min)" ("" = nothing to give back).
func return_prompt(inv: Inventory) -> String:
	var uid := returnable_specimen(inv)
	if uid == "":
		return ""
	var specimens := _specimens()
	var spec := specimens.get_record(uid)
	return PROMPT_RETURN % [specimens.organ_label(spec.organ), spec.corpse_name, _return_minutes()]


## A rest-period grave (OLD) whose designed stone waits in the mason's rack (an active stone order, P3).
func has_old_stone_to_set() -> bool:
	var grave := _grave()
	var masonry := _stonemasonry()
	if grave == null or grave.state != GraveRecord.State.OLD or masonry == null:
		return false
	return not masonry.ready_for(grave_id).is_empty()


func _finish_return(uid: String, inv: Inventory) -> void:
	var specimens := _specimens()
	if specimens == null or not specimens.return_to_grave(uid, grave_id, inv):
		EventBus.notification_requested.emit(TEXT_CANNOT_RETURN, &"warning")


func _finish_new_stone() -> void:
	var masonry := _stonemasonry()
	var graveyard := _graveyard()
	var order := masonry.ready_for(grave_id) if masonry != null else {}
	# W-Welt (W1 note P4): through Stonemasonry.set_stone – it calls Graveyard.replace_old_marker for the
	# rest-period grave and takes the stone out of the mason's rack (stone_order_changed &"set").
	if graveyard == null or order.is_empty() or masonry.set_stone(grave_id, null) <= 0:
		EventBus.notification_requested.emit(TEXT_CANNOT_SET_STONE, &"warning")
		return
	# W-Welt (G7 shot p7_26): replace_old_marker sends grave_stone_set only (the state stays OLD, no
	# quality signal) – the new stone shows at once, not after the next load.
	var grave := _grave()
	marker_id = grave.marker_id if grave != null else marker_id
	design = grave.design.duplicate(true) if grave != null else design
	_apply_visual()


func _return_minutes() -> int:
	var specimens := _specimens()
	if specimens != null:
		return specimens.get_config().return_minutes
	var cfg := Database.config(&"anatomy_config") as AnatomyConfig
	return cfg.return_minutes if cfg != null else 10


func _specimens() -> Specimens:
	return get_tree().get_first_node_in_group(SPECIMENS_GROUP) as Specimens if is_inside_tree() else null


func _finish_upgrade(id: StringName, inv: Inventory) -> void:
	var graveyard := _graveyard()
	if graveyard != null and graveyard.upgrade_marker(grave_id, id, inv) <= 0:
		EventBus.notification_requested.emit(TEXT_CANNOT_MARK, &"warning")


# --- Phase 8: grave care (P2) ------------------------------------------------------------------

## The first care action at this grave for `player` in CARE_ORDER: `enabled_only` = only one that can run
## now, else also a dimmed one (its prompt is the block reason). &"" = none.
func _care_action(player: Player, enabled_only: bool) -> StringName:
	var grave := _grave()
	if grave == null or player == null or _is_carrying(player):
		return &""
	if not grave.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED, GraveRecord.State.OLD]:
		return &""
	var dimmed := &""
	for action: StringName in care_order(player):
		var state := _care_state(action, player)
		if state == 1:
			return action
		if state == 0 and dimmed == &"":
			dimmed = action
	return &"" if enabled_only else dimmed


## W3 (QA8-08): CARE_ORDER, but a candle that can be lit now comes before planting flowers and laying a wreath –
## the candle has its hours (15:00–07:00), flowers can be set any time, and [E] at dusk with seedlings and a
## candle in the bag lit the candle only after the seedlings were used up. Two presses still do both.
func care_order(player: Player) -> Array[StringName]:
	var order: Array[StringName] = CARE_ORDER.duplicate()
	if player != null and _care_state(CARE_CANDLE, player) == 1:
		order.erase(CARE_CANDLE)
		order.insert(order.find(CARE_PLANT), CARE_CANDLE)
	return order


## 1 = possible now, 0 = shown dimmed (block reason), −1 = not offered here.
func _care_state(action: StringName, player: Player) -> int:
	var care := _grave_care()
	var inv := player.inventory
	var grave := _grave()
	var fresh_grave := grave.state == GraveRecord.State.FILLED or grave.state == GraveRecord.State.MARKED
	match action:
		CARE_COINS:
			if get_node_or_null(^"TipStone") != null:
				return -1
			return 1 if _coins_on_stone() > 0 else -1
		CARE_CLOSE:
			return 1 if care != null and care.is_disturbed(grave_id) else -1
		CARE_WATER:
			if care == null or inv == null or not inv.has(care.get_config().can_item):
				return -1
			var f := care.flowers_state(grave_id)
			if f != GraveCare.FLOWERS_WILTED and not (f == GraveCare.FLOWERS_FRESH and care.fresh_minutes_left(grave_id) <= WATER_SOON_MINUTES):
				return -1
			return 1 if care.can_fill() > 0 else 0
		CARE_PLANT:
			return 1 if care != null and care.plant_block_reason(grave_id, inv) == "" else -1
		CARE_WREATH:
			return 1 if care != null and care.wreath_block_reason(grave_id, inv) == "" else -1
		CARE_CANDLE:
			if care == null or inv == null or not inv.has(care.get_config().candle_item) or care.candle_lit(grave_id):
				return -1
			return 1 if care.light_block_reason(grave_id, inv) == "" else 0
		CARE_MORTSAFE_ON:
			if care == null or not fresh_grave or care.has_mortsafe(grave_id) or inv == null or not inv.has(care.get_config().mortsafe_item):
				return -1
			return 1 if care.mortsafe_block_reason(grave_id, true, inv) == "" else 0
		CARE_MORTSAFE_OFF:
			if care == null or not care.has_mortsafe(grave_id):
				return -1
			return 1 if care.mortsafe_block_reason(grave_id, false, inv) == "" else 0
		CARE_LINE:
			var line := _wish_line()
			if line == "":
				return -1
			var graveyard := _graveyard()
			if graveyard == null or not graveyard.can_append_inscription(grave_id) or inv == null:
				return -1
			return 1 if inv.has(care.get_config().line_item if care != null else &"ink") else 0
		CARE_NAME:
			var order := _name_order()
			if order == null or grave.design.is_empty() or inv == null:
				return -1
			return 1 if inv.has(StringName(str(order.conditions.get("item", "ink")))) else 0
	return -1


## The prompt of care action `action` (the block reason when it cannot run now).
func care_prompt(action: StringName, player: Player) -> String:
	var care := _grave_care()
	var cfg := care.get_config() if care != null else GraveCareConfig.new()
	var inv := player.inventory if player != null else null
	match action:
		CARE_COINS:
			return PROMPT_COINS % Phase8Texts.coins_on_stone(_coins_on_stone(), _tip_giver())
		CARE_CLOSE:
			return PROMPT_CLOSE % _close_minutes(player)
		CARE_WATER:
			return PROMPT_WATER % cfg.water_minutes if care.can_fill() > 0 else GraveCare.TEXT_CAN_EMPTY
		CARE_PLANT:
			return PROMPT_PLANT % cfg.plant_minutes
		CARE_WREATH:
			return PROMPT_WREATH % cfg.plant_minutes
		CARE_CANDLE:
			var reason := care.light_block_reason(grave_id, inv)
			return PROMPT_CANDLE % cfg.candle_minutes if reason == "" else reason
		CARE_MORTSAFE_ON:
			var reason := care.mortsafe_block_reason(grave_id, true, inv)
			return PROMPT_MORTSAFE_ON % cfg.mortsafe_set_minutes if reason == "" else reason
		CARE_MORTSAFE_OFF:
			var reason := care.mortsafe_block_reason(grave_id, false, inv)
			return PROMPT_MORTSAFE_OFF % cfg.mortsafe_remove_minutes if reason == "" else reason
		CARE_LINE:
			if inv == null or not inv.has(cfg.line_item):
				return "Für die Zeile fehlt Tinte."
			return PROMPT_LINE % [_wish_line(), cfg.line_minutes]
		CARE_NAME:
			var order := _name_order()
			if inv == null or order == null or not inv.has(StringName(str(order.conditions.get("item", "ink")))):
				return "Für den Namen fehlt Tinte."
			return PROMPT_NAME % int(order.conditions.get("minutes", NAME_MINUTES))
	return ""


func _start_care(action: StringName, player: Player) -> void:
	var care := _grave_care()
	var cfg := care.get_config() if care != null else GraveCareConfig.new()
	var inv := player.inventory
	match action:
		CARE_COINS:
			var visitors := _visitors()
			if visitors != null:
				visitors.take_tip(grave_id, inv)
		CARE_CLOSE:
			if player.start_timed_action(LABEL_CLOSE, _close_minutes(player), _finish_care.bind(action, inv, player), true, ANIM_DIG):
				_note_noise(&"dig")
		CARE_WATER:
			player.start_timed_action(LABEL_WATER, cfg.water_minutes, _finish_care.bind(action, inv, player), true,
					ToolAnimConfig.clip_for(&"grave_water", ANIM_WATER))
		CARE_PLANT:
			player.start_timed_action(LABEL_PLANT, cfg.plant_minutes, _finish_care.bind(action, inv, player), true,
					ToolAnimConfig.clip_for(&"grave_flowers", ANIM_MARKER))
		CARE_WREATH:
			player.start_timed_action(LABEL_WREATH, cfg.plant_minutes, _finish_care.bind(action, inv, player), true,
					ToolAnimConfig.clip_for(&"grave_flowers", ANIM_MARKER))
		CARE_CANDLE:
			player.start_timed_action(LABEL_CANDLE, cfg.candle_minutes, _finish_care.bind(action, inv, player), false,
					ToolAnimConfig.clip_for(&"grave_candle", ANIM_MARKER))
		CARE_MORTSAFE_ON:
			player.start_timed_action(LABEL_MORTSAFE_ON, cfg.mortsafe_set_minutes, _finish_care.bind(action, inv, player), true,
					ToolAnimConfig.clip_for(&"grave_marker", ANIM_MARKER))
		CARE_MORTSAFE_OFF:
			player.start_timed_action(LABEL_MORTSAFE_OFF, cfg.mortsafe_remove_minutes, _finish_care.bind(action, inv, player), true,
					ToolAnimConfig.clip_for(&"grave_marker", ANIM_MARKER))
		CARE_LINE:
			if player.start_timed_action(LABEL_LINE, cfg.line_minutes, _finish_care.bind(action, inv, player), true,
					ToolAnimConfig.clip_for(&"grave_marker", ANIM_MARKER)):
				_note_noise(&"chisel")
		CARE_NAME:
			var order := _name_order()
			var minutes := int(order.conditions.get("minutes", NAME_MINUTES)) if order != null else NAME_MINUTES
			if player.start_timed_action(LABEL_NAME, minutes, _finish_care.bind(action, inv, player), true,
					ToolAnimConfig.clip_for(&"grave_marker", ANIM_MARKER)):
				_note_noise(&"chisel")


## The end of a care action: the effect through GraveCare / Graveyard (the same calls as the apprentice's);
## watering and candles tell the apprentice (an apprentice watching learns it).
func _finish_care(action: StringName, inv: Inventory, player: Player) -> void:
	var care := _grave_care()
	var ok := false
	match action:
		CARE_CLOSE:
			ok = care != null and care.close_disturbed(grave_id)
		CARE_WATER:
			ok = care != null and care.water(grave_id)
		CARE_PLANT:
			ok = care != null and care.plant(grave_id, inv)
		CARE_WREATH:
			ok = care != null and care.lay_wreath(grave_id, inv)
		CARE_CANDLE:
			ok = care != null and care.light(grave_id, inv)
		CARE_MORTSAFE_ON:
			ok = care != null and care.set_mortsafe(grave_id, true, inv)
		CARE_MORTSAFE_OFF:
			ok = care != null and care.set_mortsafe(grave_id, false, inv)
		CARE_LINE:
			var line := _wish_line()
			var item := care.get_config().line_item if care != null else &"ink"
			var graveyard := _graveyard()
			ok = line != "" and graveyard != null and inv != null and inv.has(item) and graveyard.append_inscription(grave_id, line)
			if ok:
				inv.remove_item(item, 1)
		CARE_NAME:
			var order := _name_order()
			var item := StringName(str(order.conditions.get("item", "ink"))) if order != null else &"ink"
			var graveyard := _graveyard()
			ok = order != null and graveyard != null and inv != null and inv.has(item) \
					and graveyard.replace_name_line(grave_id, _true_name())
			if ok:
				inv.remove_item(item, 1)
				var orders := _first_in(ORDERS_TASK_GROUP)
				if orders != null and orders.has_method(&"note_task"):
					orders.call(&"note_task", CARE_NAME)
	if not ok:
		EventBus.notification_requested.emit(TEXT_CARE_FAILED, &"warning")
		return
	if action == CARE_WATER or action == CARE_CANDLE:
		var apprentice := _first_in(APPRENTICE_GROUP)
		if apprentice != null and apprentice.has_method(&"note_player_job") and is_instance_valid(player):
			apprentice.call(&"note_player_job", action, global_position)


## The active task order name_line whose target is this grave or the story of its dead (null = none).
func _name_order() -> OrderData:
	var orders := _first_in(ORDERS_TASK_GROUP)
	if orders == null or not orders.has_method(&"active") or not orders.has_method(&"order_data"):
		return null
	var grave := _grave()
	var manager := _manager()
	var record: CorpseRecord = manager.get_record(grave.corpse_id) if manager != null and grave != null else null
	for id: StringName in orders.call(&"active"):
		var o := orders.call(&"order_data", id) as OrderData
		if o == null or o.kind != &"task" or StringName(str(o.conditions.get("action_id", ""))) != CARE_NAME:
			continue
		if o.target == grave_id or (record != null and record.story_id != &"" and o.target == String(record.story_id)):
			return o
	return null


## The real name of the dead (the insight that renames its story, else Kaspar Dorn).
func _true_name() -> String:
	var grave := _grave()
	var manager := _manager()
	var record: CorpseRecord = manager.get_record(grave.corpse_id) if manager != null and grave != null else null
	if record != null and record.story_id != &"":
		for res: Resource in Database.insights():
			var insight := res as InsightData
			if insight != null and insight.rename_story == record.story_id and insight.rename_to != "":
				return insight.rename_to
	return NAME_FALLBACK


## The line of an accepted line wish at this grave ("" = none).
func _wish_line() -> String:
	var visitors := _visitors()
	if visitors == null:
		return ""
	for w: Dictionary in visitors.open_wishes():
		if str(w.get("grave_id", "")) == grave_id and str(w.get("kind", "")) == "line" and str(w.get("state", "")) == "accepted":
			return WishRules.line_of(w)
	return ""


func _coins_on_stone() -> int:
	var visitors := _visitors()
	return visitors.tip_on_stone(grave_id).x if visitors != null else 0


func _tip_giver() -> String:
	var visitors := _visitors()
	return visitors.tip_giver(grave_id) if visitors != null else ""


func _close_minutes(player: Player) -> int:
	var care := _grave_care()
	var base := care.get_config().close_minutes if care != null else 30
	return _tool_minutes(player, &"dig", base)


## A loud action at this grave (digging, closing, chiselling) disturbs a mourner ≤ 8 m (Visitors.note_noise).
func _note_noise(action_id: StringName) -> void:
	var visitors := _visitors()
	if visitors != null and is_inside_tree():
		visitors.note_noise(global_position, action_id)


func _grave_care() -> GraveCare:
	return _first_in(GRAVE_CARE_GROUP) as GraveCare


func _visitors() -> Visitors:
	return _first_in(VISITORS_GROUP) as Visitors


func _first_in(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _on_grave_care_changed(id: String, _kind: StringName, _active: bool) -> void:
	if id == grave_id:
		_visuals.apply_care()


# --- visuals & collision ------------------------------------------------------------------

func _on_grave_state_changed(id: String, new_state: int) -> void:
	if id != grave_id:
		return
	state = new_state
	var grave := _grave()
	marker_id = grave.marker_id if grave != null else &""
	design = grave.design.duplicate(true) if grave != null else {}
	extra_lines = grave.extra_lines.duplicate() if grave != null else PackedStringArray()
	_apply_visual()


## Marker upgrade: same state, new marker model.
func _on_grave_quality_changed(id: String, _quality: int) -> void:
	if id != grave_id:
		return
	var grave := _grave()
	marker_id = grave.marker_id if grave != null else marker_id
	design = grave.design.duplicate(true) if grave != null else design
	extra_lines = grave.extra_lines.duplicate() if grave != null else extra_lines
	_apply_visual()


## Visual + colliders; a LOCKED plot also switches its Interactable off, an OLD one until
## buildings_open (Phase 6).
func _apply_visual() -> void:
	_visuals.apply()
	_visuals.apply_care()
	_update_interactable()


func _update_interactable() -> void:
	if interactable == null:
		return
	var open := state != GraveRecord.State.LOCKED
	if state == GraveRecord.State.OLD:
		# Phase 8: flowers and candles also go on the rest-period graves once Phase 8 is open.
		open = (is_old and _lift_open()) or (_grave_care() != null and GameState.flag_on(&"p8_open"))
	if interactable.enabled == open and interactable.monitorable == open:
		return
	interactable.enabled = open
	interactable.set_deferred(&"monitorable", open)


## buildings_open can come any minute (morning, load, debug): the old plot's Interactable follows.
func _on_time_tick(_day: int, _minute: int) -> void:
	if state == GraveRecord.State.OLD:
		_update_interactable()


## The pit model of this plot: the foot-end variant for the old graves (falls back to pit_model
## while the asset is missing).
func active_pit_model() -> PackedScene:
	if pit_variant == PIT_FOOT and ResourceLoader.exists(PIT_FOOT_PATH):
		return load(PIT_FOOT_PATH) as PackedScene
	return pit_model


## Pit + heap area of the open grave (foot_footprint for pit_variant &"foot").
func active_footprint() -> Rect2:
	return foot_footprint if pit_variant == PIT_FOOT else footprint


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
		if active_footprint().has_point(Vector2(local.x, local.z)):
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


func _ossuary() -> Ossuary:
	return get_tree().get_first_node_in_group(OSSUARY_GROUP) as Ossuary if is_inside_tree() else null


## Lifting shows only from buildings_open and with an Ossuary in the world.
func _lift_open() -> bool:
	var ossuary := _ossuary()
	return ossuary != null and ossuary.is_open()


func _lift_block_reason(player: Player) -> String:
	var ossuary := _ossuary()
	if ossuary == null:
		return TEXT_CANNOT_LIFT
	return ossuary.lift_block_reason(grave_id, player.inventory if player != null else null)


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


## Phase 5 §2.3 (P3): dig / bury minutes by the shovel tier on the player's belt (60/50/35, 30/25/20).
static func _dig_minutes(player: Player) -> int:
	return _tool_minutes(player, &"dig", _actions(player).dig_minutes)


static func _bury_minutes(player: Player) -> int:
	return _tool_minutes(player, &"bury", _actions(player).bury_minutes)


static func _tool_minutes(player: Player, action: StringName, base: int) -> int:
	if player == null:
		return base
	return ToolRules.action_minutes(_actions(player), action, base, player.inventory)


static func _actions(player: Player) -> ActionConfig:
	if player != null and player.actions != null:
		return player.actions
	var cfg := Database.config(&"action_config") as ActionConfig
	return cfg if cfg != null else ActionConfig.new()


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)
