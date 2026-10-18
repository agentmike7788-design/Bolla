extends RefCounted
## Phase-9 helpers of graveyard_builder.gd (build-time tool, static, preloaded – docs/PHASE9_DESIGN.md §3.1, §4.2–§4.6,
## W1-Anschlüsse 1–7): the four system nodes (Quests 81, WhoKnows 82, Letters 83, Stranger 84 – groups and save ids are
## set by the scripts), the visit spot of the large requests at gate_outside (VisitSpot, layout phase9.visit_spots), the
## letter prompt at the forge (ForgeLetter under Entities/station_forge), Johann on Osric's cart (CartRider, ending A)
## and the case of Brenneisen's figures (StrangerCaseView). The fourth Lindenacker row (section, plots, fence, walls,
## obstacles stump_row4 / bramble_row4, overgrowth), Brenneisen's and Johann's places at the gate and the new Npc are
## layout data that the Phase-3…8 helpers build. Scripts are loaded by path (see graveyard_builder.gd).

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const SYSTEMS := [
	["Quests", "res://src/systems/quests/quests.gd"],
	["WhoKnows", "res://src/systems/quests/who_knows/who_knows.gd"],
	["Letters", "res://src/systems/letters/letters.gd"],
	["Stranger", "res://src/systems/stranger/stranger.gd"],
]
const VISIT_SCRIPT := "res://src/world/graveyard/visit_spot.gd"
const FORGE_LETTER_SCRIPT := "res://src/world/graveyard/forge_letter.gd"
const CART_RIDER_SCRIPT := "res://src/world/graveyard/cart_rider.gd"
const CASE_VIEW_SCRIPT := "res://src/world/graveyard/stranger_case_view.gd"
const FORGE_STATION := "station_forge"
const RIDER_MODEL := "ph_chr_mourner_m_b"


static func build_systems(ctx: Ctx, systems: Node) -> void:
	for entry: Array in SYSTEMS:
		var node: Node = load(entry[1]).new()
		node.name = entry[0]
		ctx.add(systems, node)


## Entities/<id> per layout phase9.visit_spots entry: a VisitSpot at the waypoint it names.
static func build_visit_spots(ctx: Ctx, entities: Node3D) -> void:
	for v: Dictionary in ctx.layout.get("phase9", {}).get("visit_spots", []):
		var spot := Node3D.new()
		spot.name = String(v.id)
		spot.set_script(load(VISIT_SCRIPT))
		spot.set("place_id", StringName(v.place))
		spot.transform = ctx.ground_xform(Ctx.v2(ctx.layout.waypoints[String(v.place)]), 0.0)
		ctx.add(entities, spot)


## W1-Anschlüsse 6: Entities/station_forge/ForgeLetter over the forge's footprint (its station Interactable box).
static func build_forge_letter(ctx: Ctx, entities: Node3D) -> void:
	var forge := entities.get_node_or_null(FORGE_STATION) as Node3D
	if forge == null:
		push_error("[phase9] no %s" % FORGE_STATION)
		return
	var node := Node3D.new()
	node.name = "ForgeLetter"
	node.set_script(load(FORGE_LETTER_SCRIPT))
	var reach := forge.get_node_or_null(^"Interactable/Shape") as CollisionShape3D
	if reach != null and reach.shape is BoxShape3D:
		node.set("reach_size", (reach.shape as BoxShape3D).size + Vector3(0.0, 0.4, 0.0))
		node.set("reach_center", reach.position + Vector3(0.0, 0.2, 0.0))
	ctx.add(forge, node)


## §4.5 (ending A with Osric) and W1-Anschlüsse 7: Entities/CartRider beside the two Npc it watches.
static func build_cart_rider(ctx: Ctx, entities: Node3D) -> void:
	var rider := Node3D.new()
	rider.name = "CartRider"
	rider.set_script(load(CART_RIDER_SCRIPT))
	rider.set("model", load(Ctx.model_path(RIDER_MODEL)))
	ctx.add(entities, rider)


## W1-Anschlüsse 7: the case of Brenneisen's figures (graveyard and village) follows Stranger.case_holder().
static func build_case_view(ctx: Ctx, scene_root: Node3D) -> void:
	var view := Node.new()
	view.name = "StrangerCase"
	view.set_script(load(CASE_VIEW_SCRIPT))
	ctx.add(scene_root, view)
