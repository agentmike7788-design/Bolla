extends RefCounted
## Phase-4 helpers of graveyard_builder.gd (build-time tool, static, preloaded –
## docs/PHASE4_DESIGN.md §3.1, §4): the new system nodes (CorpseCare, Piety, Journal,
## NightTrade), the elder bushes of the Holunderwinkel, the props of §4.2 (wash basin, smoke
## bowl on the morgue table, Ilse's wall ledge) and the note at the hut door. The Holunderwinkel's
## plots, obstacles, fence and tending spots come from the layout through the Phase-2/3 helpers;
## Ilse (npc_trader) is a layout entity (graveyard_build_entities.gd).
## Scripts are loaded by path (see graveyard_builder.gd: no class_name of autoload users).

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Colliders := preload("res://src/world/graveyard/graveyard_build_colliders.gd")
const ELDER_BUSH_ASSET := "ph_env_elder_bush"
const DOOR_NOTE_SCRIPT := "res://src/world/graveyard/door_note.gd"
const PAINTED_MATERIAL := "res://assets/materials/mat_painted.tres"
const TABLE_SLOT := "slot_corpse"
## §3.1: node name → script (groups / save_id / save_order are set by the scripts themselves).
## Journal (save order 40) and NightTrade (45) load after the Phase-3 systems.
const SYSTEMS := [
	["CorpseCare", "res://src/systems/corpse/corpse_care.gd"],
	["Piety", "res://src/systems/piety/piety.gd"],
	["Journal", "res://src/systems/journal/journal_manager.gd"],
	["NightTrade", "res://src/systems/utilization/night_trade.gd"],
]


static func build_systems(ctx: Ctx, systems: Node) -> void:
	for entry: Array in SYSTEMS:
		var node: Node = load(entry[1]).new()
		node.name = entry[0]
		ctx.add(systems, node)


## Three large elder bushes (§4.1): foliage like the other bushes (WorldRoot moves them to the
## foliage render layer), a trunk collider each.
static func build_elder_bushes(ctx: Ctx, decor: Node3D) -> void:
	var group := ctx.group(decor, "ElderBushes")
	var k := 0
	for b: Dictionary in ctx.layout.get("elder_bushes", []):
		k += 1
		var bush := ctx.place(ELDER_BUSH_ASSET, group, Ctx.v2(b.pos), float(b.rot_y), "ElderBush_%d" % k)
		bush.scale = Vector3.ONE * float(b.scale)
		Colliders.collider(ctx, ELDER_BUSH_ASSET, ctx.ground_xform(Ctx.v2(b.pos), float(b.rot_y)), "ElderBush_%d" % k, float(b.scale))


## §4.2 props: on the ground (with the layout colliders, if any) or – "on": a station – as a child
## of that station node on its table top (height of the slot_corpse marker).
static func build_props(ctx: Ctx, entities: Node3D, decor: Node3D) -> void:
	var group := ctx.group(decor, "Phase4Props")
	for pr: Dictionary in ctx.layout.get("phase4_props", []):
		var asset := String(pr.asset)
		if pr.has("on"):
			var station := entities.get_node(String(pr.on)) as Node3D
			var local := Ctx.v2(pr.local)
			var top := _slot_height(station)
			var inst := (load(Ctx.model_path(asset)) as PackedScene).instantiate() as Node3D
			inst.name = _node_name(pr)
			inst.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(pr.rot_y))), Vector3(local.x, top, local.y))
			ctx.add(station, inst)
			continue
		var node := ctx.place(asset, group, Ctx.v2(pr.pos), float(pr.rot_y), _node_name(pr))
		if ctx.layout.colliders.has(asset):
			Colliders.collider(ctx, asset, node.transform, _node_name(pr))


## Ilse's note (§2.11 (5)): a small painted sheet on the door leaf of the hut (door_note.gd shows
## it from trader_known until the first meeting).
static func build_door_note(ctx: Ctx, decor: Node3D) -> void:
	var cfg: Dictionary = ctx.layout.get("door_note", {})
	if cfg.is_empty():
		return
	var hut := decor.get_node("Hut") as Node3D
	var note := Node3D.new()
	note.name = "DoorNote"
	note.set_script(load(DOOR_NOTE_SCRIPT))
	var local := Ctx.v3(cfg.local)
	note.transform = hut.transform * Transform3D(Basis(Vector3.BACK, deg_to_rad(float(cfg.tilt_deg))), local)
	ctx.add(decor, note)
	var mesh := BoxMesh.new()
	mesh.size = Ctx.v3(cfg.size)
	var mat := (load(PAINTED_MATERIAL) as ShaderMaterial).duplicate() as ShaderMaterial
	mat.resource_name = "mat_door_note"
	mat.set_shader_parameter(&"tint", Color(cfg.color))
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Sheet"
	mesh.resource_name = "ph_door_note"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ctx.add(note, mi)
	note.visible = false


static func _slot_height(station: Node3D) -> float:
	var slot := station.find_child(TABLE_SLOT, true, false) as Node3D
	return Ctx.rel_xform(slot, station).origin.y if slot != null else 0.0


static func _node_name(pr: Dictionary) -> String:
	return "".join(String(pr.id).capitalize().split(" "))
