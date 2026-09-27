class_name NpcPose
extends RefCounted
## Path and pose evaluation of an Npc: builds (and caches) each schedule entry's waypoint
## polyline, samples it by arc length on the ground, and works out the standing heading
## (waypoint facing / arrival direction) and the figure's turn towards a nearby player.
## The Npc node applies the results; everything here follows from its schedule and world.

## Below this (m) a path segment has no direction.
const EPSILON := Npc.EPSILON

var _npc: Npc
## entry instance id -> {points: PackedVector3Array, lengths: PackedFloat32Array, total: float}
var _paths: Dictionary = {}


func _init(npc: Npc) -> void:
	_npc = npc


func path(e: ScheduleEntry) -> Dictionary:
	var key := e.get_instance_id()
	if _paths.has(key):
		return _paths[key]
	var points := PackedVector3Array()
	for id: String in e.path:
		points.append(_waypoint(StringName(id)))
	if points.is_empty():
		points.append(_npc.global_position)
	var lengths := PackedFloat32Array([0.0])
	for k: int in range(1, points.size()):
		lengths.append(lengths[k - 1] + flat(points[k] - points[k - 1]).length())
	var result := {"points": points, "lengths": lengths, "total": lengths[lengths.size() - 1]}
	_paths[key] = result
	return result


## [position, direction] at `t` (0..1) of the path's arc length.
func sample(p: Dictionary, t: float) -> Array:
	var points: PackedVector3Array = p.points
	var lengths: PackedFloat32Array = p.lengths
	var total: float = p.total
	if points.size() == 1 or total <= EPSILON:
		return [points[points.size() - 1], Vector3.ZERO]
	var s := clampf(t, 0.0, 1.0) * total
	for k: int in range(1, points.size()):
		if s <= lengths[k] or k == points.size() - 1:
			var seg := lengths[k] - lengths[k - 1]
			var u := clampf((s - lengths[k - 1]) / seg, 0.0, 1.0) if seg > EPSILON else 1.0
			var pos := points[k - 1].lerp(points[k], u)
			return [on_ground(pos), flat(points[k] - points[k - 1]).normalized()]
	return [points[points.size() - 1], Vector3.ZERO]


## `pos` with y on the world's ground (unchanged without a world that knows ground_height).
func on_ground(pos: Vector3) -> Vector3:
	var w := _npc._world()
	if w != null and w.has_method(&"ground_height"):
		pos.y = float(w.call(&"ground_height", Vector2(pos.x, pos.z)))
	return pos


## Figure yaw relative to the root: towards a player closer than face_player_range while
## standing at a dialogue spot (`standing_talkable`), else 0.
func look_yaw(heading: float, standing_talkable: bool) -> float:
	if not standing_talkable:
		return 0.0
	var player := _npc.get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return 0.0
	var to := player.global_position - _npc.global_position
	to.y = 0.0
	if to.length_squared() <= EPSILON or to.length() >= _npc.face_player_range:
		return 0.0
	return wrapf(atan2(to.x, to.z) - heading, -PI, PI)


## Standing at `e`: the waypoint's facing (layout waypoint_facing), else the arrival heading,
## else `current`.
func waypoint_yaw(e: ScheduleEntry, current: float) -> float:
	var w := _npc._world()
	if w != null and w.has_method(&"get_waypoint_facing") and not e.path.is_empty():
		var yaw := float(w.call(&"get_waypoint_facing", StringName(e.path[e.path.size() - 1])))
		if not is_nan(yaw):
			return yaw
	var arrival := arrival_yaw(e)
	return arrival if not is_nan(arrival) else current


## Heading (rad) of the last path segment of the walk that brought the NPC to where `e` stands:
## the entries before `e` (wrapping) that stand at the same waypoint are skipped. NAN if the
## phase before is no walk to that waypoint.
func arrival_yaw(e: ScheduleEntry) -> float:
	var entries := _npc._schedule().entries
	var index := entries.find(e)
	if index < 0 or e.path.is_empty():
		return NAN
	var spot := e.path[e.path.size() - 1]
	for k: int in range(1, entries.size()):
		var before := entries[(index - k + entries.size()) % entries.size()]
		if before.path.is_empty() or before.path[before.path.size() - 1] != spot:
			return NAN
		if before.path.size() >= 2:
			var points: PackedVector3Array = path(before).points
			var dir := flat(points[points.size() - 1] - points[points.size() - 2])
			return atan2(dir.x, dir.z) if dir.length_squared() > EPSILON else NAN
	return NAN


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _waypoint(id: StringName) -> Vector3:
	var w := _npc._world()
	if w == null:
		push_warning("[Npc] %s: no world with waypoints" % _npc.name)
		return _npc.global_position
	return w.call(&"get_waypoint", id)
