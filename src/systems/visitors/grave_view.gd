class_name GraveView
extends RefCounted
## How a visitor sees the grave (docs/PHASE8_DESIGN.md §2.2.4, §3.4): disturbed > neglected (care spot ≥
## level 2) > bare (no marker yet) > kept, + bonus (fresh grave flowers or a wax wreath, a candle last night,
## a grave vase ≤ 1.5 m), + specimen_rumor (the dead whose specimen was sold – Specimens state sold; returned
## ones do not count). Reads the systems through their groups; the effects are Visitors'.

const VIEWS: Array[StringName] = [&"disturbed", &"neglected", &"bare", &"kept"]
const VIEW_DISTURBED := &"disturbed"
const VIEW_NEGLECTED := &"neglected"
const VIEW_BARE := &"bare"
const VIEW_KEPT := &"kept"
const NEGLECTED_LEVEL := 2
const DIRT_PREFIX := "dirt_"
const VASE_DECOR := &"decor_grave_vase"
## §2.2.5: the vase stands ≤ 1.5 m from the grave (the 1 × 2 m footprint of the plot).
const VASE_DISTANCE := 1.5
const FOOT_HALF := Vector2(0.5, 1.0)


## {view, bonus, specimen_rumor} – specimen_rumor = the corpse id of a dead with a sold specimen ("" = none).
static func view(grave_id: String, tree: SceneTree, _cfg: VisitorConfig) -> Dictionary:
	var graveyard := _first(tree, &"graveyard") as Graveyard
	var grave := graveyard.get_grave(grave_id) if graveyard != null else null
	var care := _first(tree, &"grave_care") as GraveCare
	var out := {"view": VIEW_KEPT, "bonus": false, "specimen_rumor": ""}
	if (care != null and care.is_disturbed(grave_id)) or (grave != null and grave.disturbed):
		out.view = VIEW_DISTURBED
	elif dirt_level(grave_id, tree) >= NEGLECTED_LEVEL:
		out.view = VIEW_NEGLECTED
	elif grave != null and grave.state != GraveRecord.State.MARKED and grave.state != GraveRecord.State.OLD:
		out.view = VIEW_BARE
	if care != null:
		var flowers := care.flowers_state(grave_id)
		out.bonus = flowers == GraveCare.FLOWERS_FRESH or flowers == GraveCare.FLOWERS_WREATH or care.lit_last_night(grave_id)
	if not out.bonus:
		out.bonus = has_vase(grave_id, tree)
	if grave != null and grave.corpse_id != "":
		var specimens := _first(tree, &"specimens") as Specimens
		if specimens != null:
			for uid: String in specimens.of_corpse(grave.corpse_id):
				var rec := specimens.get_record(uid)
				if rec != null and rec.state == Specimens.STATE_SOLD:
					out.specimen_rumor = grave.corpse_id
					break
	return out


## The care spot level of the grave (dirt_<grave>, 0 without CleanlinessManager).
static func dirt_level(grave_id: String, tree: SceneTree) -> int:
	var clean := _first(tree, &"cleanliness")
	if clean == null or not clean.has_method(&"level"):
		return 0
	return int(clean.call(&"level", DIRT_PREFIX + grave_id))


## A grave vase (decor_grave_vase) stands ≤ VASE_DISTANCE m from the plot's footprint.
static func has_vase(grave_id: String, tree: SceneTree) -> bool:
	var decor := _first(tree, &"decorations")
	var plot := plot_of(grave_id, tree)
	if decor == null or plot == null or not decor.has_method(&"placements") or not decor.has_method(&"centre_of"):
		return false
	for p: Variant in decor.call(&"placements"):
		if p == null or StringName(p.get(&"decor_id")) != VASE_DECOR:
			continue
		var c: Vector2 = decor.call(&"centre_of", p)
		var local := plot.to_local(Vector3(c.x, plot.global_position.y, c.y))
		var nearest := Vector2(clampf(local.x, -FOOT_HALF.x, FOOT_HALF.x), clampf(local.z, -FOOT_HALF.y, FOOT_HALF.y))
		if nearest.distance_to(Vector2(local.x, local.z)) <= VASE_DISTANCE:
			return true
	return false


## The GravePlot node of `grave_id` (null = none in the tree).
static func plot_of(grave_id: String, tree: SceneTree) -> Node3D:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(&"grave_plot"):
		var id: Variant = node.get("grave_id")
		if node is Node3D and (id is String or id is StringName) and String(id) == grave_id:
			return node as Node3D
	return null


static func _first(tree: SceneTree, group: StringName) -> Node:
	return tree.get_first_node_in_group(group) if tree != null else null
