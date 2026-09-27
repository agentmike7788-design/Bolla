class_name DecorationManager
extends Node
## Systems/Decorations (docs/PHASE3_DESIGN.md §2.3, §3.4; groups decorations, saveable;
## save_id "decorations", save_order 15). Owns the placements and their PlacedDecor nodes under
## container_path (Decor/Placed); load_state re-creates the nodes (the world's _ready creates none).
## can_place checks, in this order: &"no_item" → &"limit" (place_max / max_placed) →
## BuildGrid.check (&"blocked" … &"occupied") → &"player" (capsule inside the footprint) →
## &"corpse" (corpse on the ground inside the footprint) → &"ok".
## Other systems read it through the group API: decor_score (CemeteryScore),
## suppresses_dirt_at (CleanlinessManager), ghost_bonus_at (GhostManager).

const GROUP := &"decorations"
const REASON_NO_ITEM := &"no_item"
const REASON_LIMIT := &"limit"
const REASON_PLAYER := &"player"
const REASON_CORPSE := &"corpse"
const UID_PREFIX := "d_"
const PLACED_SCENE := "res://src/entities/decor/placed_decor.tscn"
## Gravekeeper capsule radius (player.tscn) – a piece may not be placed on top of him.
const PLAYER_RADIUS := 0.3
## A corpse on the ground blocks the footprint within this margin of its centre (m).
const CORPSE_MARGIN := 0.3
const DEFAULT_GHOST_BONUS_MAX := 2
const TEXT_INVENTORY_FULL := "Kein Platz im Inventar"

@export var mask: BuildMask
## Decor/Placed
@export var container_path: NodePath
@export var save_id: String = "decorations"
@export var save_order: int = 15

var config: DecorConfig
## Decor kinds by id; empty = Database.decors() (tests inject fixtures).
var decor_table: Dictionary[StringName, DecorData] = {}
## Sections for the caps; empty = Database.sections() (tests inject fixtures).
var section_list: Array[SectionData] = []
## Unlocked section indices when no ExpansionManager (group expansion) is in the tree.
var fallback_unlocked: PackedInt32Array = PackedInt32Array([1])
## Debug "build free on": no items needed, none taken or given back (§6).
var free_build: bool = false

var _placements: Dictionary[String, DecorPlacement] = {}
## {Vector2i: uid}
var _occupied: Dictionary = {}
var _nodes: Dictionary[String, Node3D] = {}
var _next_uid: int = 1
var _grid: BuildGrid


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	if config == null:
		config = Database.config(&"decor_config") as DecorConfig
	if config == null:
		config = DecorConfig.new()


func grid() -> BuildGrid:
	if _grid == null or _grid.mask != mask:
		_grid = BuildGrid.new(mask)
	return _grid


func placements() -> Array[DecorPlacement]:
	var out: Array[DecorPlacement] = []
	out.assign(_placements.values())
	return out


func get_placement(uid: String) -> DecorPlacement:
	return _placements.get(uid)


func decor(decor_id: StringName) -> DecorData:
	if not decor_table.is_empty():
		return decor_table.get(decor_id)
	return Database.decor(decor_id) as DecorData


## All decor kinds, sorted by id (= build bar order).
func decor_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if not decor_table.is_empty():
		out.assign(decor_table.keys())
		out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		return out
	for d: Resource in Database.decors():
		out.append(StringName(d.get("id")))
	return out


func count_of(decor_id: StringName) -> int:
	var n := 0
	for p: DecorPlacement in _placements.values():
		if p.decor_id == decor_id:
			n += 1
	return n


func can_place(decor_id: StringName, cell: Vector2i, rot: int, inv: Inventory = null, player: Player = null) -> StringName:
	var d := decor(decor_id)
	if d == null or mask == null:
		return BuildGrid.REASON_BLOCKED
	if inv != null and not free_build and not inv.has(decor_id, 1):
		return REASON_NO_ITEM
	if _placements.size() >= _cfg().max_placed or (d.place_max > 0 and count_of(decor_id) >= d.place_max):
		return REASON_LIMIT
	var reason := grid().check(d, cell, rot, _occupied, blockers(), unlocked_sections())
	if reason != BuildGrid.REASON_OK:
		return reason
	var rect := grid().footprint_rect(cell, d.footprint, rot)
	if player != null and not d.walkable and _circle_hits_rect(_xz(player.global_position), PLAYER_RADIUS, rect):
		return REASON_PLAYER
	for p: Vector2 in ground_corpse_points():
		if rect.grow(CORPSE_MARGIN).has_point(p):
			return REASON_CORPSE
	return BuildGrid.REASON_OK


## uid or ""; takes 1 item; decor_changed.
func place(decor_id: StringName, cell: Vector2i, rot: int, inv: Inventory) -> String:
	var reason := can_place(decor_id, cell, rot, inv, _player())
	if reason != BuildGrid.REASON_OK:
		return ""
	if inv != null and not free_build and not inv.remove_item(decor_id, 1):
		return ""
	var p := DecorPlacement.new()
	p.uid = UID_PREFIX + str(_next_uid)
	_next_uid += 1
	p.decor_id = decor_id
	p.cell = cell
	p.rot = posmod(rot, 4)
	_add(p)
	EventBus.decor_changed.emit(p.uid, decor_id, true)
	return p.uid


## Gives 1 item back; inventory full → false (notification "Kein Platz im Inventar").
func remove(uid: String, inv: Inventory) -> bool:
	var p: DecorPlacement = _placements.get(uid)
	if p == null:
		return false
	if inv != null and not free_build:
		if not inv.can_add(p.decor_id, 1):
			EventBus.notification_requested.emit(TEXT_INVENTORY_FULL, &"warning")
			return false
		inv.add_item(p.decor_id, 1)
	_erase(p)
	EventBus.decor_changed.emit(uid, p.decor_id, false)
	return true


## Debug "decor clear": removes every piece without giving items back.
func clear_all() -> void:
	for p: DecorPlacement in placements():
		_erase(p)
		EventBus.decor_changed.emit(p.uid, p.decor_id, false)


func placement_at(cell: Vector2i) -> DecorPlacement:
	var uid: Variant = _occupied.get(cell)
	return _placements.get(uid) if uid != null else null


func occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_occupied.keys())
	return out


## Σ over sections min(decor_cap, Σ contributions) (§2.3).
func decor_score() -> int:
	var total := 0
	var by := score_by_section()
	for order: int in by:
		total += int(by[order].capped)
	return total


## {order: {raw: int, capped: int, cap: int}} – every known section, plus any section that
## holds decor without SectionData (cap 0).
func score_by_section() -> Dictionary:
	var counts := {}  # order -> {decor_id: n}
	for p: DecorPlacement in _placements.values():
		var order := mask.section_at(p.cell) if mask != null else 0
		var per: Dictionary = counts.get_or_add(order, {})
		per[p.decor_id] = int(per.get(p.decor_id, 0)) + 1
	var out := {}
	for s: SectionData in _sections():
		out[s.order] = {"raw": 0, "capped": 0, "cap": s.decor_cap}
	for order: int in counts:
		var raw := 0
		var per: Dictionary = counts[order]
		for id: StringName in per:
			raw += contribution(decor(id), int(per[id]))
		var entry: Dictionary = out.get_or_add(order, {"raw": 0, "capped": 0, "cap": 0})
		entry.raw = raw
		entry.capped = mini(raw, int(entry.cap))
	return out


## floor(min(n, counted_max) × zier / zier_divisor); counted_max 0 = unlimited.
static func contribution(d: DecorData, n: int) -> int:
	if d == null or n <= 0:
		return 0
	var counted := mini(n, d.counted_max) if d.counted_max > 0 else n
	return floori(float(counted * d.zier) / float(maxi(d.zier_divisor, 1)))


## True when a dirt-suppressing piece (flower bed, gravel) covers world XZ point `p`.
func suppresses_dirt_at(p: Vector2) -> bool:
	if mask == null:
		return false
	var placement := placement_at(mask.world_to_cell(p))
	if placement == null:
		return false
	var d := decor(placement.decor_id)
	return d != null and d.suppresses_dirt


## 0..2 (§2.8): +1 for every decor kind with a ghost_bonus_radius that has a piece within its
## radius of `p` (flower bed / vase 1.8 m, lantern 3.0 m), at most GhostConfig.decor_bonus_max.
func ghost_bonus_at(p: Vector2) -> int:
	var kinds := {}
	for placement: DecorPlacement in _placements.values():
		var d := decor(placement.decor_id)
		if d == null or d.ghost_bonus_radius <= 0.0 or kinds.has(d.id):
			continue
		if centre_of(placement).distance_to(p) <= d.ghost_bonus_radius:
			kinds[d.id] = true
	return mini(kinds.size(), _ghost_bonus_max())


## World XZ centre of a placement's footprint.
func centre_of(placement: DecorPlacement) -> Vector2:
	var d := decor(placement.decor_id)
	if d == null or mask == null:
		return Vector2.ZERO
	return grid().footprint_rect(placement.cell, d.footprint, placement.rot).get_center()


## Unlocked section indices: ExpansionManager.unlocked_indices(), else fallback_unlocked.
func unlocked_sections() -> PackedInt32Array:
	var expansion := _first(&"expansion")
	if expansion != null and expansion.has_method(&"unlocked_indices"):
		return expansion.call(&"unlocked_indices")
	return fallback_unlocked


## World XZ rects of the obstacles still standing (group clearable, not cleared).
func blockers() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_inside_tree():
		return out
	var expansion := _first(&"expansion")
	for node: Node in get_tree().get_nodes_in_group(&"clearable"):
		if not node.has_method(&"world_rect"):
			continue
		var id := str(node.get(&"obstacle_id"))
		if expansion != null and expansion.has_method(&"is_cleared") and bool(expansion.call(&"is_cleared", id)):
			continue
		out.append(node.call(&"world_rect"))
	return out


## World XZ positions of corpses lying on the ground (CorpseManager records).
func ground_corpse_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var manager := _first(&"corpse_manager") as CorpseManager
	if manager == null:
		return out
	for record: CorpseRecord in manager.records():
		if record.location != CorpseRecord.LOCATION_GROUND:
			continue
		var node := manager.get_corpse_node(record.id)
		out.append(_xz(node.global_position) if node != null and node.is_inside_tree() else _xz(record.position))
	return out


func save_state() -> Dictionary:
	var list: Array = []
	var sorted := placements()
	sorted.sort_custom(func(a: DecorPlacement, b: DecorPlacement) -> bool: return _uid_num(a.uid) < _uid_num(b.uid))
	for p: DecorPlacement in sorted:
		list.append(p.to_dict())
	return {"next_uid": _next_uid, "placements": list}


## Replaces everything and re-creates the nodes; {} = no decor. Unknown kinds and pieces that
## overlap an earlier one are dropped with a warning.
func load_state(data: Dictionary) -> void:
	for p: DecorPlacement in placements():
		_erase(p)
	_placements.clear()
	_occupied.clear()
	var next: Variant = data.get("next_uid", 1)
	_next_uid = maxi(1, int(next) if (next is int or next is float) else 1)
	var list: Variant = data.get("placements", [])
	if not list is Array:
		list = []
	for raw: Variant in list:
		if not raw is Dictionary:
			continue
		var p := DecorPlacement.from_dict(raw)
		if p.uid == "" or _placements.has(p.uid) or decor(p.decor_id) == null:
			push_warning("[DecorationManager] dropped saved decor %s" % [raw])
			continue
		if _cells_of(p).any(func(c: Vector2i) -> bool: return _occupied.has(c)):
			push_warning("[DecorationManager] saved decor '%s' overlaps another – dropped" % p.uid)
			continue
		_add(p)
		_next_uid = maxi(_next_uid, _uid_num(p.uid) + 1)


# --- internals ------------------------------------------------------------------------------

func _add(p: DecorPlacement) -> void:
	_placements[p.uid] = p
	for c: Vector2i in _cells_of(p):
		_occupied[c] = p.uid
	var node := _create_node(p)
	if node != null:
		_nodes[p.uid] = node


func _erase(p: DecorPlacement) -> void:
	_placements.erase(p.uid)
	for c: Vector2i in _cells_of(p):
		if _occupied.get(c) == p.uid:
			_occupied.erase(c)
	var node: Node3D = _nodes.get(p.uid)
	_nodes.erase(p.uid)
	if is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()


func _cells_of(p: DecorPlacement) -> Array[Vector2i]:
	var d := decor(p.decor_id)
	return BuildGrid.footprint_cells(p.cell, d.footprint if d != null else Vector2i.ONE, p.rot)


func _create_node(p: DecorPlacement) -> Node3D:
	var parent := _container()
	if parent == null:
		return null
	var node := (load(PLACED_SCENE) as PackedScene).instantiate() as PlacedDecor
	node.setup(decor(p.decor_id), p, mask)
	parent.add_child(node)
	return node


func node_of(uid: String) -> Node3D:
	return _nodes.get(uid)


func _container() -> Node:
	if container_path.is_empty() or not is_inside_tree():
		return null
	return get_node_or_null(container_path)


func _sections() -> Array[SectionData]:
	if not section_list.is_empty():
		return section_list
	var out: Array[SectionData] = []
	for s: Resource in Database.sections():
		out.append(s as SectionData)
	return out


func _cfg() -> DecorConfig:
	if config == null:
		config = Database.config(&"decor_config") as DecorConfig
		if config == null:
			config = DecorConfig.new()
	return config


func _ghost_bonus_max() -> int:
	var cfg := Database.config(&"ghost_config") as GhostConfig
	return cfg.decor_bonus_max if cfg != null else DEFAULT_GHOST_BONUS_MAX


func _player() -> Player:
	return _first(&"player") as Player


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _uid_num(uid: String) -> int:
	return uid.trim_prefix(UID_PREFIX).to_int()


static func _circle_hits_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return nearest.distance_squared_to(c) < r * r
