class_name BuildMode
extends Node
## Systems/BuildMode (docs/PHASE3_DESIGN.md §3.4, §3.6; group build_mode, not saved – loading,
## a new game, entering the hut or a modal ends it). Mouse placement (user decision §14.3):
## the mouse picks the cell (ray camera → ground plane y = 0, clamped to cursor_reach around
## the gravekeeper), the preview follows it; left click / [E] place, right click / [X] remove,
## R / mouse wheel rotate, 1–8 select, Esc / B leave. Without mouse motion since entering (or
## without a camera) the cell in front of the gravekeeper is used (keyboard fallback).
## While active, Player.set_build_mode(true) suppresses his [E]/[Q] and CameraRig ignores the
## wheel (build_mode_changed). Placing / removing are timed actions (5 min) of the player.

const GROUP := &"build_mode"
const HOTBAR_SLOTS := 8
const TEXT_PLACE := "%s aufstellen"
const TEXT_REMOVE := "%s abbauen"

var active: bool = false
var selected: StringName = &""
var rotation_step: int = 0

var config: DecorConfig
## Overrides for tests; otherwise the nodes of groups player / decorations.
var player: Player
var decorations: DecorationManager
var cursor: BuildCursor
## True once the mouse moved while in build mode (resets on enter).
var mouse_active: bool = false
var mouse_position: Vector2 = Vector2.ZERO


func _init() -> void:
	add_to_group(GROUP, true)


func _ready() -> void:
	_cfg()
	EventBus.game_loaded.connect(_on_force_exit.unbind(1))
	EventBus.new_game_started.connect(_on_force_exit)
	EventBus.interior_changed.connect(_on_interior_changed)
	EventBus.ui_modal_changed.connect(_on_modal_changed)


func _exit_tree() -> void:
	if active:
		exit()


## Only outdoors, hands free, not busy, no modal; build_mode_changed(true).
func enter() -> bool:
	if active:
		return true
	var p := _player()
	if p == null or _decorations() == null or UIState.is_modal():
		return false
	if p.in_interior or p.is_busy() or p.carried != null or p.state != Player.State.FREE:
		return false
	active = true
	mouse_active = false
	var list := available()
	if not list.has(selected):
		selected = list[0] if not list.is_empty() else &""
	p.set_build_mode(true)
	EventBus.build_mode_changed.emit(true)
	_update_cursor()
	return true


func exit() -> void:
	if not active:
		return
	active = false
	mouse_active = false
	if cursor != null:
		cursor.hide_cursor()
	var p := _player()
	if p != null:
		p.set_build_mode(false)
	EventBus.build_mode_changed.emit(false)


func toggle() -> void:
	if active:
		exit()
	else:
		enter()


## DECOR items in the inventory (order = build bar = decor ids sorted); all kinds with free_build.
func available() -> Array[StringName]:
	var out: Array[StringName] = []
	var d := _decorations()
	var p := _player()
	if d == null:
		return out
	for id: StringName in d.decor_ids():
		if d.free_build or (p != null and p.inventory != null and p.inventory.has(id, 1)):
			out.append(id)
	return out


func select(decor_id: StringName) -> void:
	selected = decor_id
	_update_cursor()


func rotate() -> void:
	rotation_step = (rotation_step + 1) % 4
	_update_cursor()


## Cell under the mouse (ray camera → ground plane y = 0), clamped to DecorConfig.cursor_reach
## around the gravekeeper; without mouse motion since entering / no camera / ray missing the
## ground: the cell cursor_distance in front of the gravekeeper (keyboard fallback).
func cursor_cell() -> Vector2i:
	var m := _mask()
	var p := _player()
	if m == null or p == null:
		return Vector2i.ZERO
	var centre := Vector2(p.global_position.x, p.global_position.z)
	if mouse_active:
		var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam != null:
			var hit: Variant = pick_ground_point(cam.project_ray_origin(mouse_position), cam.project_ray_normal(mouse_position), centre, _cfg().cursor_reach)
			if hit is Vector2:
				return m.world_to_cell(hit)
	return fallback_cell(p.global_transform, _cfg().cursor_distance, m)


## Pure: where the ray (origin, dir) meets the ground plane y = 0, clamped to `reach` around
## `centre` (world XZ); null if the ray points away from / along the ground.
static func pick_ground_point(origin: Vector3, dir: Vector3, centre: Vector2, reach: float) -> Variant:
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if hit == null:
		return null
	var p := Vector2((hit as Vector3).x, (hit as Vector3).z)
	var off := p - centre
	if reach > 0.0 and off.length() > reach:
		p = centre + off.normalized() * reach
	return p


## Pure: mouse ray → cell on `mask` (null = no ground hit).
static func pick_cell(origin: Vector3, dir: Vector3, centre: Vector2, reach: float, mask: BuildMask) -> Variant:
	var p: Variant = pick_ground_point(origin, dir, centre, reach)
	return mask.world_to_cell(p) if p is Vector2 else null


## Pure: the cell `distance` in front of `xform` (the gravekeeper faces his +Z).
static func fallback_cell(xform: Transform3D, distance: float, mask: BuildMask) -> Vector2i:
	var fwd := xform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.BACK
	var p := xform.origin + fwd * distance
	return mask.world_to_cell(Vector2(p.x, p.z))


## Anchor (bottom-left) of the selected piece so its footprint is centred on the cursor cell.
func anchor_cell() -> Vector2i:
	return anchor_for(cursor_cell(), _selected_footprint(), rotation_step)


static func anchor_for(cell: Vector2i, footprint: Vector2i, rot: int) -> Vector2i:
	var s := BuildGrid.rotated_size(footprint, rot)
	return cell - Vector2i((s.x - 1) / 2, (s.y - 1) / 2)


## can_place at the cursor (anchor_cell) for the selected piece.
func cursor_reason() -> StringName:
	var d := _decorations()
	var p := _player()
	if d == null or selected == &"":
		return DecorationManager.REASON_NO_ITEM
	return d.can_place(selected, anchor_cell(), rotation_step, p.inventory if p != null else null, p)


## Decor under the cursor (for removing).
func focused_placement() -> DecorPlacement:
	var d := _decorations()
	return d.placement_at(cursor_cell()) if d != null else null


## Timed action 5 min (movement cancels, rotating does not: cell/rot are fixed at the start).
func confirm_place() -> bool:
	var p := _player()
	var d := _decorations()
	if not active or p == null or d == null or p.is_busy() or cursor_reason() != BuildGrid.REASON_OK:
		return false
	var id := selected
	var cell := anchor_cell()
	var rot := rotation_step
	var data := d.decor(id)
	var label := TEXT_PLACE % (data.display_name if data != null else String(id))
	return p.start_timed_action(label, _cfg().place_minutes, func() -> void: _finish_place(id, cell, rot), true, &"interact")


func confirm_remove() -> bool:
	var p := _player()
	var d := _decorations()
	if not active or p == null or d == null or p.is_busy():
		return false
	var placement := focused_placement()
	if placement == null:
		return false
	if not d.free_build and p.inventory != null and not p.inventory.can_add(placement.decor_id, 1):
		EventBus.notification_requested.emit(DecorationManager.TEXT_INVENTORY_FULL, &"warning")
		return false
	var uid := placement.uid
	var data := d.decor(placement.decor_id)
	var label := TEXT_REMOVE % (data.display_name if data != null else String(placement.decor_id))
	return p.start_timed_action(label, _cfg().remove_minutes, func() -> void: _finish_remove(uid), true, &"interact")


# --- input ----------------------------------------------------------------------------------

## Esc must leave build mode before UIRoot opens the pause menu (it listens in _unhandled_input).
func _input(event: InputEvent) -> void:
	if active and event.is_action_pressed(&"pause"):
		exit()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_mode"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event is InputEventMouseMotion:
		mouse_active = true
		mouse_position = (event as InputEventMouseMotion).position
		return
	if event is InputEventMouseButton:
		mouse_position = (event as InputEventMouseButton).position
	if event.is_action_pressed(&"build_rotate"):
		rotate()
	elif event.is_action_pressed(&"build_place"):
		if event is InputEventMouseButton:
			mouse_active = true
		confirm_place()
	elif event.is_action_pressed(&"build_remove_mouse") or event.is_action_pressed(&"build_remove"):
		if event is InputEventMouseButton:
			mouse_active = true
		confirm_remove()
	else:
		var slot := _hotbar_slot(event)
		if slot < 0:
			return
		var list := available()
		if slot < list.size():
			select(list[slot])
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if active:
		_update_cursor()


static func _hotbar_slot(event: InputEvent) -> int:
	for i: int in HOTBAR_SLOTS:
		if event.is_action_pressed(StringName("hotbar_%d" % (i + 1))):
			return i
	return -1


# --- internals ------------------------------------------------------------------------------

func _finish_place(id: StringName, cell: Vector2i, rot: int) -> void:
	var d := _decorations()
	var p := _player()
	if d == null or d.place(id, cell, rot, p.inventory if p != null else null) == "":
		return
	if active and not available().has(selected):
		var list := available()
		selected = list[0] if not list.is_empty() else &""


func _finish_remove(uid: String) -> void:
	var d := _decorations()
	var p := _player()
	if d != null:
		d.remove(uid, p.inventory if p != null else null)


func _update_cursor() -> void:
	if not active or not is_inside_tree():
		return
	var d := _decorations()
	var m := _mask()
	if d == null or m == null:
		return
	if cursor == null:
		cursor = BuildCursor.new()
		cursor.config = _cfg()
		add_child(cursor)
	var data := d.decor(selected)
	if data == null:
		cursor.hide_cursor()
		return
	cursor.show_at(data, anchor_cell(), rotation_step, cursor_reason() == BuildGrid.REASON_OK, m)


func _selected_footprint() -> Vector2i:
	var d := _decorations()
	var data: DecorData = d.decor(selected) if d != null and selected != &"" else null
	return data.footprint if data != null else Vector2i.ONE


func _mask() -> BuildMask:
	var d := _decorations()
	return d.mask if d != null else null


func _player() -> Player:
	if is_instance_valid(player):
		return player
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"player") as Player


func _decorations() -> DecorationManager:
	if is_instance_valid(decorations):
		return decorations
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"decorations") as DecorationManager


func _cfg() -> DecorConfig:
	if config == null:
		config = Database.config(&"decor_config") as DecorConfig
		if config == null:
			config = DecorConfig.new()
	return config


func _on_force_exit() -> void:
	exit()


func _on_interior_changed(inside: bool) -> void:
	if inside:
		exit()


func _on_modal_changed(open: bool) -> void:
	if open:
		exit()
