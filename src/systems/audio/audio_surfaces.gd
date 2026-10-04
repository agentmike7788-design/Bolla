class_name AudioSurfaces
extends RefCounted
## Ground under a position (footsteps) and the outdoor soundscape zone – pure lookups in the
## AudioConfig areas (region-local x/z). Rooms come first: an active InteriorRoom (group
## "interior_room") whose bounds contain the point gives room_surfaces[room_id].

const DEFAULT_SURFACE := &"grass"


## local = position minus the region origin (x, z).
static func surface_at(cfg: AudioConfig, region: StringName, local: Vector2) -> StringName:
	for zone: Dictionary in cfg.surface_zones:
		if StringName(zone.get("region", &"")) != region:
			continue
		if zone_contains(zone, local):
			return StringName(zone.get("surface", DEFAULT_SURFACE))
	return cfg.region_surfaces.get(region, DEFAULT_SURFACE)


static func room_surface(cfg: AudioConfig, room: StringName) -> StringName:
	return cfg.room_surfaces.get(room, &"wood")


static func zone_contains(zone: Dictionary, p: Vector2) -> bool:
	if zone.has("rect"):
		var r: Rect2 = zone["rect"]
		return r.abs().has_point(p)
	if zone.has("circle"):
		var c: Vector3 = zone["circle"]
		return p.distance_to(Vector2(c.x, c.y)) <= c.z
	if zone.has("line"):
		var pts: PackedVector2Array = zone["line"]
		var half := float(zone.get("width", 2.0)) * 0.5
		for i in range(pts.size() - 1):
			var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			if q.distance_to(p) <= half:
				return true
	return false


## The outdoor soundscape zone at `local` for `phase` (&"" = none).
static func zone_profile(cfg: AudioConfig, region: StringName, local: Vector2, phase: StringName) -> StringName:
	for zone: Dictionary in cfg.zone_profiles:
		if StringName(zone.get("region", &"")) != region:
			continue
		var phases: PackedStringArray = zone.get("phases", PackedStringArray())
		if not phases.is_empty() and not String(phase) in phases:
			continue
		if zone_contains(zone, local):
			return StringName(zone.get("profile", &""))
	return &""


## The active interior room containing a world position (null = none).
static func room_at(tree: SceneTree, world: Vector3) -> InteriorRoom:
	for node: Node in tree.get_nodes_in_group(InteriorRoom.GROUP):
		var room := node as InteriorRoom
		if room == null or not room.active or not room.is_inside_tree():
			continue
		var o := room.global_position
		var lo := Vector2(o.x, o.z) + room.bounds_min - Vector2.ONE * 2.0
		var hi := Vector2(o.x, o.z) + room.bounds_max + Vector2.ONE * 2.0
		if world.x >= lo.x and world.x <= hi.x and world.z >= lo.y and world.z <= hi.y:
			return room
	return null
