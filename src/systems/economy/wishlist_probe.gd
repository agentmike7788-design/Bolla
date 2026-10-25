class_name WishlistProbe
extends RefCounted
## Tests / debug only (docs/PHASE10_DESIGN.md §2.3 Grundsatz 2, §3.4, §6 `wish`, §10.3 curve10; P1): the sum of the
## lasting purchases of the wish list (data/economy/wishlist.tres) the player does not own yet and that are available
## (available_flag on; "" = always).
##
## Owned / open per kind (WishlistEntryData.kind):
## - station: Workshop.is_built(ref) → 0, else coins
## - building: one entry per level – max_count is the level it buys; Buildings.level(ref) ≥ max_count → 0, else coins
## - tool, item: (max_count − owned) × coins; owned = pack + every chest (hut, shed, Jakob's box) + placed decor of that id
## - per_grave: coins for every occupied grave (FILLED / MARKED) without it, at most max_count graves; „without it" by
##   ref: mortsafe → GraveCare.has_mortsafe, gold_leaf → the stone of the grave is not gilded, rose_bush →
##   GraveCare.has_rose (P4; missing method = no grave has one), anything else → every occupied grave
## Missing systems (a test world without them) count as „not owned".

const KIND_STATION := &"station"
const KIND_BUILDING := &"building"
const KIND_TOOL := &"tool"
const KIND_ITEM := &"item"
const KIND_PER_GRAVE := &"per_grave"


static func open_cost(tree: SceneTree, data: WishlistData) -> int:
	if data == null:
		return 0
	var total := 0
	for e: WishlistEntryData in data.entries:
		if e == null or e.coins <= 0:
			continue
		if e.available_flag != &"" and not GameState.flag_on(e.available_flag):
			continue
		total += entry_cost(tree, e)
	return total


## The open coins of one entry (availability not checked).
static func entry_cost(tree: SceneTree, e: WishlistEntryData) -> int:
	match e.kind:
		KIND_STATION:
			var ws := _first(tree, &"workshop")
			return 0 if ws != null and bool(ws.call(&"is_built", e.ref)) else e.coins
		KIND_BUILDING:
			var b := _first(tree, &"buildings")
			var lvl := int(b.call(&"level", e.ref)) if b != null else 0
			return 0 if lvl >= maxi(1, e.max_count) else e.coins
		KIND_TOOL, KIND_ITEM:
			return maxi(0, maxi(1, e.max_count) - owned(tree, e.ref)) * e.coins
		KIND_PER_GRAVE:
			return mini(graves_without(tree, e.ref), maxi(0, e.max_count)) * e.coins
	return 0


## Pieces of `item` the gravekeeper has: pack, every chest, placed decor.
static func owned(tree: SceneTree, item: StringName) -> int:
	if tree == null:
		return 0
	var n := 0
	var player := tree.get_first_node_in_group(&"player")
	var pack: Inventory = player.get(&"inventory") as Inventory if player != null else null
	if pack != null:
		n += pack.count(item)
	for node: Node in tree.get_nodes_in_group(&"saveable"):
		if node is Chest:
			var storage := node.get_node_or_null(^"Storage") as Inventory
			if storage != null and storage != pack:
				n += storage.count(item)
	var deco := _first(tree, &"decorations")
	if deco != null and deco.has_method(&"count_of"):
		n += int(deco.call(&"count_of", item))
	return n


## Occupied graves (FILLED / MARKED) that do not have `ref` yet.
static func graves_without(tree: SceneTree, ref: StringName) -> int:
	var gy := _first(tree, &"graveyard") as Graveyard
	if gy == null:
		return 0
	var care := _first(tree, &"grave_care")
	var n := 0
	for g: GraveRecord in gy.graves():
		if not g.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED]:
			continue
		var has := false
		match ref:
			&"mortsafe":
				has = care != null and bool(care.call(&"has_mortsafe", g.id))
			&"gold_leaf":
				has = bool(g.design.get("gilded", false))
			&"rose_bush":
				has = care != null and care.has_method(&"has_rose") and bool(care.call(&"has_rose", g.id))
		if not has:
			n += 1
	return n


static func _first(tree: SceneTree, group: StringName) -> Node:
	return tree.get_first_node_in_group(group) if tree != null else null
