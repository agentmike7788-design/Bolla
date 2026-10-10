extends RefCounted
## Phase-8 parts of the village build (docs/PHASE8_DESIGN.md §3.1, §4.6 D1–D5; build-time tool, static, preloaded by
## village_build.gd): the two watch places (WatchSpot watch_ott / watch_kehr, layout phase8.watch_spots) and the
## sick lights (SickLight at the marker light_window of house_ott / house_kehr, layout phase8.sick_lights). The
## door places, Veit's and Hanne's places, the Lichtgang gathering and the new Npc (Jakob, Veit, Hanne – hidden
## before p8_open) are layout waypoints / npcs that village_build.gd builds. Region-local coordinates.

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const WATCH_SCENE := "res://src/entities/watch_spot/watch_spot.tscn"
const SICK_SCENE := "res://src/entities/sick_light/sick_light.tscn"
## Meta of a window light: the building it belongs to (village_dressing.gd keeps a sick house's light on).
const META_HOUSE := &"house"


static func build(ctx: Ctx, entities: Node3D, buildings: Node3D) -> void:
	var cfg: Dictionary = ctx.layout.get("phase8", {})
	for w: Dictionary in cfg.get("watch_spots", []):
		var spot := (load(WATCH_SCENE) as PackedScene).instantiate() as Node3D
		spot.name = String(w.id)
		spot.set("spot_id", StringName(w.id))
		spot.transform = ctx.ground_xform(Ctx.v2(w.pos), float(w.get("rot_y", 0.0)))
		ctx.add(entities, spot)
	for s: Dictionary in cfg.get("sick_lights", []):
		var house := buildings.get_node(String(s.house)) as Node3D
		var marker := house.find_child(String(s.get("marker", "light_window")), true, false) as Node3D
		var light := (load(SICK_SCENE) as PackedScene).instantiate() as Node3D
		light.name = String(s.id)
		light.set("house", StringName(s.house))
		var at := house.transform * Ctx.rel_xform(marker, house) if marker != null else house.transform
		# The candle stands on the inner sill: the marker sits in the pane, a hand inside the room.
		var inward := Vector3(house.position.x - at.origin.x, 0.0, house.position.z - at.origin.z).normalized()
		light.transform = Transform3D(Basis.IDENTITY, at.origin + inward * float(s.get("inset", 0.12)) + Vector3.DOWN * float(s.get("drop", 0.0)))
		ctx.add(entities, light)
	for b: Node in buildings.get_children():
		for l: Node in b.find_children("Light_window*", "OmniLight3D", true, false):
			l.set_meta(META_HOUSE, String(b.name))
