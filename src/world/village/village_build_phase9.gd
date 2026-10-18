extends RefCounted
## Phase-9 parts of the village build (docs/PHASE9_DESIGN.md §3.1, §4.3, §4.6 D8/D10/D12, W1-Anschlüsse 2/5; build-time
## tool, static, preloaded by village_build.gd): at the Siebers' house the KnockDoor door_sieber at its door (the house's
## marker door_outside, facing away from the house – layout phase9.knock_doors), the watch place watch_sieber (WatchSpot,
## phase9.watch_spots), the marker win_sieber_attic at the Altenteil window upstairs with its SickLight (a candle on the
## inner sill, phase9.sick_lights: house-local pane and candle; the house's window light sits there – village_build.gd
## window_light); the visit spot of the large request at v_bridge_unload (VisitSpot, phase9.visit_spots). The bench, the
## waypoints of the way to the Siebers and the new Npc (Johann, Brenneisen, the watchman's lantern) are layout data that
## village_build.gd builds. Region-local coordinates.

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const KNOCK_SCENE := "res://src/entities/knock_door/knock_door.tscn"
const WATCH_SCENE := "res://src/entities/watch_spot/watch_spot.tscn"
const SICK_SCENE := "res://src/entities/sick_light/sick_light.tscn"
const VISIT_SCRIPT := "res://src/world/graveyard/visit_spot.gd"
const DOOR_MARKER := "door_outside"


static func build(ctx: Ctx, entities: Node3D, buildings: Node3D) -> void:
	var cfg: Dictionary = ctx.layout.get("phase9", {})
	for k: Dictionary in cfg.get("knock_doors", []):
		var house := buildings.get_node(String(k.house)) as Node3D
		var marker := house.find_child(DOOR_MARKER, true, false) as Node3D
		var at := house.transform * Ctx.rel_xform(marker, house).origin if marker != null else house.position
		var away := Vector2(at.x - house.position.x, at.z - house.position.z)
		var door := (load(KNOCK_SCENE) as PackedScene).instantiate() as Node3D
		door.name = String(k.id)
		door.transform = Transform3D(Basis(Vector3.UP, atan2(away.x, away.y)), at)
		door.set("door_id", StringName(k.id))
		if k.has("dialogue_id"):
			door.set("dialogue_id", StringName(k.dialogue_id))
		if k.has("npc_id"):
			door.set("npc_id", StringName(k.npc_id))
		ctx.add(entities, door)
	for w: Dictionary in cfg.get("watch_spots", []):
		var spot := (load(WATCH_SCENE) as PackedScene).instantiate() as Node3D
		spot.name = String(w.id)
		spot.set("spot_id", StringName(w.id))
		spot.transform = ctx.ground_xform(Ctx.v2(w.pos), float(w.get("rot_y", 0.0)))
		ctx.add(entities, spot)
	for s: Dictionary in cfg.get("sick_lights", []):
		var house := buildings.get_node(String(s.house)) as Node3D
		var marker := Marker3D.new()
		marker.name = String(s.marker)
		marker.position = Ctx.v3(s.local)
		ctx.add(house, marker)
		var light := (load(SICK_SCENE) as PackedScene).instantiate() as Node3D
		light.name = String(s.id)
		light.set("house", StringName(s.house))
		# The candle stands on the inner sill: the marker sits in the middle of the pane, the candle (house-local offset)
		# on the sill a hand inside the room.
		var candle := Ctx.v3(s.get("candle", [0.0, -0.5, -0.12]))
		light.transform = Transform3D(Basis.IDENTITY, house.transform * (marker.position + candle))
		ctx.add(entities, light)
	for v: Dictionary in cfg.get("visit_spots", []):
		var spot := Node3D.new()
		spot.name = String(v.id)
		spot.set_script(load(VISIT_SCRIPT))
		spot.set("place_id", StringName(v.place))
		spot.transform = ctx.ground_xform(Ctx.v2(ctx.layout.waypoints[String(v.place)]), 0.0)
		ctx.add(entities, spot)
